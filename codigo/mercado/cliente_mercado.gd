extends Node
## Mercado entre jogadores (estilo casa de leilões): anúncios com preço fixo em Brasas, guardados no Supabase
## (ferramentas/mercado/). Identidade = código secreto do Ranking, um por jogador local. As Brasas e a mochila
## continuam no save: o jogo desconta antes de pedir ao banco e devolve se ele recusar.
## Queda de conexão no meio de um anúncio ou compra: a operação fica pendente em `arquivo` e é conferida no banco
## na próxima vez (reconciliar), sem devolver em dobro nem perder Brasas.

const Raridades := preload("res://codigo/dados/raridades.gd")
## Ferramentas e vara são do progresso da fazenda; arma e escudo básicos voltam de graça a quem fica sem nenhum
const CATEGORIAS_BLOQUEADAS := ["ferramenta", "vara"]
const TIPOS_BLOQUEADOS := ["espada_basica", "escudo_basico"]
const ERROS := {
	"mercado_fechado": "O MERCADO ESTA FECHADO NO MOMENTO",
	"item_invalido": "ESSE ITEM NAO PODE SER ANUNCIADO",
	"item_bloqueado": "ESSE ITEM NAO PODE SER ANUNCIADO",
	"preco_invalido": "PRECO FORA DO LIMITE",
	"prazo_invalido": "PRAZO INVALIDO",
	"limite_anuncios": "VOCE JA TEM O MAXIMO DE ANUNCIOS ABERTOS",
	"limite_diario": "LIMITE DE HOJE ATINGIDO, VOLTE AMANHA",
	"banido": "VOCE NAO PODE MAIS USAR O MERCADO",
	"indisponivel": "ESSE ANUNCIO NAO ESTA MAIS DISPONIVEL",
	"proprio_anuncio": "ESSE ANUNCIO E SEU",
	"preco_mudou": "O PRECO MUDOU, ATUALIZE A LISTA",
}
const SEM_CONEXAO := "SEM CONEXAO COM O MERCADO"
const EM_CONFERENCIA := "SEM CONEXAO: A OPERACAO SERA CONFERIDA QUANDO A CONEXAO VOLTAR"

## Perfil do Ranking do jogador (P1 ou P2): código e apelido
var perfil: Node
## Ids do correio já aplicados ao save e operações pendentes de conferência
var arquivo := "user://mercado.json"
var regras := {"ligado": true, "taxa_anuncio": 1, "taxa_venda_pct": 10, "preco_min": 1, "preco_max": 9999, "max_anuncios": 5, "horas": [24, 48]}
var _aplicados: Array = []
var _anuncio_pendente := {}
var _compra_pendente := {}

func preparar(jogador: Node) -> void:
	perfil = Ranking.para_jogador(jogador)
	arquivo = "user://mercado_p2.json" if jogador != null and bool(jogador.get("eh_p2")) else "user://mercado.json"
	_aplicados = []
	_anuncio_pendente = {}
	_compra_pendente = {}
	if not FileAccess.file_exists(arquivo):
		return
	var lido = JSON.parse_string(FileAccess.get_file_as_string(arquivo))
	if not lido is Dictionary:
		return
	if lido.get("aplicados") is Array:
		for id in lido["aplicados"]:
			_aplicados.append(int(id))
	if lido.get("anuncio_pendente") is Dictionary:
		_anuncio_pendente = lido["anuncio_pendente"]
	if lido.get("compra_pendente") is Dictionary:
		_compra_pendente = lido["compra_pendente"]

static func pode_anunciar(item: DadosItem) -> bool:
	return item != null and not item.categoria in CATEGORIAS_BLOQUEADAS and not item.tipo in TIPOS_BLOQUEADOS

func tem_pendencia() -> bool:
	return not _anuncio_pendente.is_empty() or not _compra_pendente.is_empty()

## Quanto o vendedor recebe depois da taxa (o banco usa o mesmo arredondamento para cima)
func liquido(preco: int) -> int:
	return preco - ceili(preco * int(regras.get("taxa_venda_pct", 10)) / 100.0)

## Chamada a uma função do banco. Devolve {"ok", "dados", "erro", "rede"}; "erro" já vem no texto da tela.
## "rede" = não houve resposta confiável (a operação pode ou não ter acontecido no banco).
func chamar(funcao: String, corpo: Dictionary) -> Dictionary:
	if not Ranking.disponivel():
		return {"ok": false, "erro": SEM_CONEXAO, "rede": true}
	var http := HTTPRequest.new()
	http.timeout = 12.0
	add_child(http)
	if http.request(Ranking.url_servico + "/rest/v1/rpc/" + funcao, Ranking.cabecalhos_servico(), HTTPClient.METHOD_POST, JSON.stringify(corpo)) != OK:
		http.queue_free()
		return {"ok": false, "erro": SEM_CONEXAO, "rede": true}
	var resposta: Array = await http.request_completed
	http.queue_free()
	var status: int = resposta[1]
	if resposta[0] != HTTPRequest.RESULT_SUCCESS or status == 0 or status >= 500:
		return {"ok": false, "erro": SEM_CONEXAO, "rede": true}
	var dados = JSON.parse_string((resposta[3] as PackedByteArray).get_string_from_utf8())
	if status < 200 or status >= 300:
		return {"ok": false, "erro": "O MERCADO RECUSOU O PEDIDO", "rede": false}
	if dados is Dictionary and dados.has("erro"):
		return {"ok": false, "erro": str(ERROS.get(str(dados["erro"]), "O MERCADO RECUSOU O PEDIDO")), "codigo": str(dados["erro"]), "rede": false}
	return {"ok": true, "dados": dados, "rede": false}

func atualizar_regras() -> void:
	var r := await chamar("mercado_regras", {})
	if r["ok"] and r["dados"] is Dictionary:
		regras = r["dados"]

func buscar(filtros: Dictionary, pagina: int) -> Dictionary:
	return await chamar("mercado_buscar", {"p_filtros": filtros, "p_pagina": pagina})

func meus() -> Dictionary:
	return await chamar("mercado_meus", {"p_codigo": perfil.codigo_secreto()})

## Entregas esperando no correio; -1 se não deu para consultar
func contar_correio() -> int:
	var r := await chamar("mercado_correio_contar", {"p_codigo": perfil.codigo_secreto()})
	return int(r["dados"]) if r["ok"] and (r["dados"] is float or r["dados"] is int) else -1

## Tira o item (ou `quantidade` da pilha) da mochila e a taxa das Brasas antes de pedir; se o banco recusar, devolve.
func anunciar(item: DadosItem, inventario: Node, preco: int, horas: int, quantidade := 1) -> Dictionary:
	if tem_pendencia():
		await reconciliar(inventario)
		if tem_pendencia():
			return {"ok": false, "erro": EM_CONFERENCIA}
	var taxa := int(regras.get("taxa_anuncio", 0))
	if Progresso.brasas < taxa:
		return {"ok": false, "erro": "FALTAM BRASAS PARA A TAXA"}
	var casa: int = inventario.indice_de(item)
	if casa == -1:
		return {"ok": false, "erro": "O ITEM PRECISA ESTAR NA MOCHILA"}
	var venda := item
	if item.empilhavel():
		quantidade = clampi(quantidade, 1, item.quantidade)
		if quantidade < item.quantidade:
			venda = DadosItem.de_dict(item.para_dict())
			venda.quantidade = quantidade
	var retirado: bool = inventario.remover_da_mochila(item) if venda == item else inventario.retirar_da_pilha(item, quantidade)
	if not retirado:
		return {"ok": false, "erro": "O ITEM PRECISA ESTAR NA MOCHILA"}
	var envio := Crypto.new().generate_random_bytes(16).hex_encode()
	_mudar_brasas(-taxa)
	inventario.salvar()
	_anuncio_pendente = {"envio": envio, "item": venda.para_dict(), "casa": casa, "taxa": taxa}
	_gravar()
	var r := await chamar("mercado_anunciar", {"p_codigo": perfil.codigo_secreto(), "p_apelido": perfil.apelido,
		"p_item": venda.para_dict(), "p_preco": preco, "p_horas": horas, "p_envio": envio})
	if r["ok"]:
		_anuncio_pendente = {}
		_gravar()
	elif r["rede"]:
		r["erro"] = EM_CONFERENCIA
	else:
		_devolver_anuncio(inventario)
	return r

## Desconta o preço antes de comprar; se a compra não acontecer, devolve. O item chega pelo correio.
func comprar(anuncio: Dictionary, inventario: Node) -> Dictionary:
	if tem_pendencia():
		await reconciliar(inventario)
		if tem_pendencia():
			return {"ok": false, "erro": EM_CONFERENCIA}
	var preco := int(anuncio.get("preco", 0))
	if Progresso.brasas < preco:
		return {"ok": false, "erro": "BRASAS INSUFICIENTES"}
	_mudar_brasas(-preco)
	_compra_pendente = {"anuncio": int(anuncio.get("id", 0)), "preco": preco}
	_gravar()
	var r := await chamar("mercado_comprar", {"p_codigo": perfil.codigo_secreto(), "p_anuncio": int(anuncio.get("id", 0)), "p_preco": preco})
	if r["ok"]:
		_compra_pendente = {}
		_gravar()
	elif r["rede"]:
		r["erro"] = EM_CONFERENCIA
	else:
		_compra_pendente = {}
		_mudar_brasas(preco)
		_gravar()
	return r

func cancelar(anuncio_id: int) -> Dictionary:
	return await chamar("mercado_cancelar", {"p_codigo": perfil.codigo_secreto(), "p_anuncio": anuncio_id})

## Confere no banco as operações que ficaram sem resposta. Devolve um texto para a tela ("" se nada mudou).
func reconciliar(inventario: Node) -> String:
	var textos: Array[String] = []
	if not _anuncio_pendente.is_empty():
		var r := await chamar("mercado_anuncio_status", {"p_codigo": perfil.codigo_secreto(), "p_envio": str(_anuncio_pendente.get("envio", ""))})
		if r["ok"] and r["dados"] is Dictionary:
			if bool(r["dados"].get("existe", false)):
				_anuncio_pendente = {}
				_gravar()
				textos.append("ANUNCIO CONFIRMADO")
			elif _devolver_anuncio(inventario):
				textos.append("O ANUNCIO NAO FOI FEITO: ITEM DEVOLVIDO")
			else:
				textos.append("LIBERE ESPACO NA MOCHILA PARA RECEBER O ITEM DE VOLTA")
	if not _compra_pendente.is_empty():
		var r := await chamar("mercado_compra_status", {"p_codigo": perfil.codigo_secreto(), "p_anuncio": int(_compra_pendente.get("anuncio", 0))})
		if r["ok"] and r["dados"] is Dictionary:
			if not bool(r["dados"].get("comprado", false)):
				_mudar_brasas(int(_compra_pendente.get("preco", 0)))
				textos.append("A COMPRA NAO FOI FEITA: BRASAS DEVOLVIDAS")
			_compra_pendente = {}
			_gravar()
	return " | ".join(PackedStringArray(textos))

## Busca o correio, aplica no save o que couber e confirma ao banco. Devolve {"textos": [...], "pendentes": n, "erro"}.
func retirar_correio(inventario: Node) -> Dictionary:
	var r := await chamar("mercado_correio_retirar", {"p_codigo": perfil.codigo_secreto()})
	if not r["ok"] or not r["dados"] is Array:
		return {"textos": [], "pendentes": 0, "erro": r.get("erro", SEM_CONEXAO)}
	var textos: Array[String] = []
	var aplicadas: Array = []
	var pendentes := 0
	var brasas := 0
	for entrega in r["dados"]:
		var id := int(entrega.get("id", 0))
		if id in _aplicados:
			aplicadas.append(id)
			continue
		if entrega.get("item") is Dictionary:
			var item := DadosItem.de_dict(entrega["item"])
			if inventario.receber(item) == -1:
				pendentes += 1
				continue
			textos.append("%s: %s" % [{"compra": "COMPROU", "cancelado": "CANCELADO", "devolvido": "VOLTOU SEM VENDER"}.get(str(entrega.get("motivo")), "RECEBEU"), resumo(item)])
		var valor := int(entrega.get("brasas", 0))
		if valor > 0:
			brasas += valor
			textos.append("VENDIDO: +%d BRASAS" % valor)
		aplicadas.append(id)
	if aplicadas.is_empty():
		return {"textos": textos, "pendentes": pendentes, "erro": ""}
	# Grava o save e os ids antes de confirmar: se cair no meio, a próxima retirada ignora o que já entrou
	if brasas > 0:
		_mudar_brasas(brasas)
	inventario.salvar()
	for id in aplicadas:
		if not id in _aplicados:
			_aplicados.append(id)
	_gravar()
	var confirmacao := await chamar("mercado_correio_confirmar", {"p_codigo": perfil.codigo_secreto(), "p_ids": aplicadas})
	if confirmacao["ok"]:
		for id in aplicadas:
			_aplicados.erase(id)
		_gravar()
	return {"textos": textos, "pendentes": pendentes, "erro": ""}

static func resumo(item: DadosItem) -> String:
	if item.empilhavel():
		return "%s x%d" % [item.nome(), item.quantidade]
	return "%s NV %d %s" % [item.nome(), item.nivel, Raridades.nome(item.raridade)]

## Põe de volta o item e a taxa do anúncio pendente. Mochila cheia: continua pendente e devolve false.
func _devolver_anuncio(inventario: Node) -> bool:
	var item := DadosItem.de_dict(_anuncio_pendente.get("item", {}))
	if inventario.receber(item, int(_anuncio_pendente.get("casa", -1))) == -1:
		return false
	_mudar_brasas(int(_anuncio_pendente.get("taxa", 0)))
	inventario.salvar()
	_anuncio_pendente = {}
	_gravar()
	return true

func _mudar_brasas(quantia: int) -> void:
	if quantia == 0:
		return
	Progresso.brasas = maxi(Progresso.brasas + quantia, 0)
	Progresso.salvar()
	Progresso.brasas_alteradas.emit(Progresso.brasas)

func _gravar() -> void:
	var arquivo_aberto := FileAccess.open(arquivo, FileAccess.WRITE)
	if arquivo_aberto != null:
		arquivo_aberto.store_string(JSON.stringify({"aplicados": _aplicados, "anuncio_pendente": _anuncio_pendente, "compra_pendente": _compra_pendente}))
