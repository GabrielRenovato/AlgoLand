extends Node
## Ranking global de andares (Supabase). Identidade: apelido livre + código secreto guardado no aparelho.

signal lista_atualizada(lista: Array)
signal envio_concluido(erro: String)

const Config := preload("res://codigo/dados/ranking_config.gd")
const ARQUIVO := "user://ranking.json"
const TAMANHO_LISTA := 15
const Armas := preload("res://codigo/dados/armas_ranking.gd")
var armas_usadas := {}
var _uso_sujo := false
var _armas_enviadas := ""
var arquivo_save := ARQUIVO
var _perfil_p2: Node
const Visual := preload("res://codigo/dados/visual_ranking.gd")
var url_servico := Config.URL
var chave_servico := Config.CHAVE
var conexao_habilitada := true
var lista_cache: Array = []
var erro_consulta := ""
var visual_pendente := {}
var _visual_enviado := ""
var _buscando := false
var _apelido_enviado := ""

var apelido := ""
var pendente := 0
var _codigo := ""
var _enviado := 0
var _ocupado := false

func _ready() -> void:
	# Requisições e repetição continuam durante os menus e a pausa.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_carregar()
	var repeticao := Timer.new()
	repeticao.wait_time = 30.0
	repeticao.timeout.connect(_enviar_pendente)
	add_child(repeticao)
	repeticao.start()
	var salvar_usos := Timer.new()
	salvar_usos.wait_time = 1.0
	salvar_usos.timeout.connect(func() -> void:
		if _uso_sujo: _gravar())
	add_child(salvar_usos)
	salvar_usos.start()

## Uma identidade e uma fila por jogador local; P2 nunca usa o código/contagens do P1.
func para_jogador(jogador: Node) -> Node:
	if jogador == null or not bool(jogador.get("eh_p2")): return self
	if not is_instance_valid(_perfil_p2):
		_perfil_p2 = get_script().new()
		_perfil_p2.name = "RankingJogador2"
		_perfil_p2.arquivo_save = "user://ranking_p2.json"
		_perfil_p2.url_servico = url_servico
		_perfil_p2.chave_servico = chave_servico
		_perfil_p2.conexao_habilitada = conexao_habilitada
		add_child(_perfil_p2)
	_perfil_p2.url_servico = url_servico
	_perfil_p2.chave_servico = chave_servico
	_perfil_p2.conexao_habilitada = conexao_habilitada
	return _perfil_p2

func registrar_uso(jogador: Node, tipo: String) -> void:
	tipo = Armas.validar(tipo)
	if tipo.is_empty(): return
	var perfil := para_jogador(jogador)
	perfil.armas_usadas[tipo] = mini(Armas.LIMITE,int(perfil.armas_usadas.get(tipo,0))+1)
	# Só grava localmente. A rede recebe uma fotografia agregada, nunca uma chamada por golpe.
	perfil._uso_sujo = true

func gravar_perfis() -> void:
	_gravar()
	if is_instance_valid(_perfil_p2): _perfil_p2._gravar()

## O mesmo código secreto identifica o jogador no mercado (o banco só guarda o hash)
func codigo_secreto() -> String:
	return _codigo

func cabecalhos_servico() -> PackedStringArray:
	return _cabecalhos()

func ocupado() -> bool:
	return _ocupado

func disponivel() -> bool:
	return conexao_habilitada and not url_servico.is_empty() and not chave_servico.is_empty()

## Chamado ao fechar a partida. Sem apelido, guarda o andar até o jogador escolher um.
func enviar(andar: int) -> void:
	if andar <= 0:
		return
	apelido = apelido_personagem(apelido)
	pendente = maxi(pendente, andar)
	_gravar()
	if not apelido.is_empty():
		_enviar_pendente()

## O servidor cronometra a partida: o andar enviado depois só vale o tempo que de fato passou.
func iniciar_partida(andar_inicial: int) -> void:
	if not disponivel():
		return
	var http := HTTPRequest.new()
	http.timeout = 12.0
	add_child(http)
	http.request_completed.connect(func(_r: int, _c: int, _h: PackedStringArray, _b: PackedByteArray) -> void:
		http.queue_free())
	var corpo := JSON.stringify({"p_codigo": _codigo, "p_andar_inicial": maxi(andar_inicial, 1),"p_temporada":Config.TEMPORADA})
	if http.request(url_servico + "/rest/v1/rpc/iniciar_partida_ranking", _cabecalhos(), HTTPClient.METHOD_POST, corpo) != OK:
		http.queue_free()

static func apelido_personagem(texto: String) -> String:
	var limpo := RegEx.create_from_string("[[:cntrl:]]").sub(texto,"",true).strip_edges().left(16)
	return "sem apelido" if limpo.is_empty() else limpo

## Entrada automática: usa os dados atuais do personagem, nunca um cadastro separado.
func registrar_resultado(jogador: Node2D, andar: int) -> void:
	capturar_jogador(jogador)
	enviar(andar)

func _enviar_pendente() -> void:
	if _ocupado or not disponivel() or apelido.is_empty() or pendente <= 0:
		return
	if pendente <= _enviado and apelido == _apelido_enviado:
		_enviar_visual()
		return
	_ocupado = true
	var andar := pendente
	var nome_enviado := apelido
	var http := HTTPRequest.new()
	http.timeout = 12.0
	add_child(http)
	http.request_completed.connect(func(_r: int, codigo: int, _h: PackedStringArray, corpo: PackedByteArray) -> void:
		http.queue_free()
		_ocupado = false
		if codigo >= 200 and codigo < 300:
			_enviado = maxi(_enviado, andar)
			_apelido_enviado = nome_enviado
			_gravar()
			_enviar_pendente()
			envio_concluido.emit("")
		else:
			var texto := corpo.get_string_from_utf8()
			envio_concluido.emit("ATUALIZE O JOGO PARA ENVIAR AO RANKING" if texto.contains("atualize_o_jogo") or texto.contains("temporada_invalida") else "SEM CONEXAO COM O RANKING"))
	var corpo_json := JSON.stringify({"p_codigo": _codigo, "p_apelido": apelido, "p_andar": andar,"p_temporada":Config.TEMPORADA})
	if http.request(url_servico + "/rest/v1/rpc/enviar_pontuacao_ranking", _cabecalhos(), HTTPClient.METHOD_POST, corpo_json) != OK:
		http.queue_free()
		_ocupado = false
		envio_concluido.emit("SEM CONEXAO COM O RANKING")

## A praça e o encerramento da arena capturam antes de qualquer descarregamento/reset.
func capturar_jogador(jogador: Node2D) -> void:
	if jogador == null: return
	var dados := Visual.do_jogador(jogador)
	var nome := apelido_personagem(str(jogador.apelido))
	var nome_novo := nome != apelido
	if nome_novo: apelido = nome
	if dados == visual_pendente and not nome_novo: return
	visual_pendente = dados
	_gravar()

func sincronizar_visual() -> void:
	_enviar_pendente()

func _enviar_visual() -> void:
	if _ocupado or visual_pendente.is_empty() or (JSON.stringify(visual_pendente) == _visual_enviado and JSON.stringify(armas_usadas) == _armas_enviadas):
		return
	_ocupado = true
	var retrato := JSON.stringify(visual_pendente)
	var usos := JSON.stringify(armas_usadas)
	var http := HTTPRequest.new()
	http.timeout = 12.0
	add_child(http)
	http.request_completed.connect(func(_r: int, codigo: int, _h: PackedStringArray, resposta: PackedByteArray) -> void:
		http.queue_free()
		_ocupado = false
		if codigo >= 200 and codigo < 300:
			_visual_enviado = retrato
			_armas_enviadas = usos
			var agregado = JSON.parse_string(resposta.get_string_from_utf8())
			if agregado is Dictionary and agregado.get("armas_usadas") is Dictionary:
				_armas_enviadas = JSON.stringify(Armas.normalizar(agregado.armas_usadas))
				armas_usadas = Armas.mesclar(armas_usadas,agregado.armas_usadas)
			_gravar()
			if pendente > _enviado or apelido != _apelido_enviado: _enviar_pendente()
			envio_concluido.emit("")
		else:
			envio_concluido.emit("NAO FOI POSSIVEL ATUALIZAR O VISUAL"))
	var corpo := JSON.stringify({"p_codigo":_codigo,"p_aparencia":visual_pendente,"p_armas_usadas":armas_usadas,"p_temporada":Config.TEMPORADA})
	if http.request(url_servico + "/rest/v1/rpc/atualizar_perfil_ranking",_cabecalhos(),HTTPClient.METHOD_POST,corpo) != OK:
		http.queue_free()
		_ocupado = false
		envio_concluido.emit("SEM CONEXAO COM O RANKING")

func buscar() -> void:
	if _buscando: return
	if not disponivel():
		erro_consulta = "RANKING INDISPONIVEL"
		lista_atualizada.emit(lista_cache)
		return
	_buscando = true
	var http := HTTPRequest.new()
	http.timeout = 12.0
	add_child(http)
	http.request_completed.connect(func(_r: int, codigo: int, _h: PackedStringArray, corpo: PackedByteArray) -> void:
		http.queue_free()
		_buscando = false
		var dados = JSON.parse_string(corpo.get_string_from_utf8())
		if codigo == 200 and dados is Array:
			lista_cache = []
			for linha in dados:
				if linha is Dictionary and linha.get("apelido") is String and (linha.get("andar") is int or linha.get("andar") is float):
					lista_cache.append({"apelido":str(linha.apelido).left(16),"andar":clampi(int(linha.andar),1,1000),"aparencia":Visual.normalizar(linha.get("aparencia")),"arma_mais_usada":Armas.validar(linha.get("arma_mais_usada"))})
			erro_consulta = ""
		else:
			erro_consulta = "SEM CONEXAO - EXIBINDO ULTIMA CONSULTA" if not lista_cache.is_empty() else "SEM CONEXAO COM O RANKING"
		lista_atualizada.emit(lista_cache))
	var consulta := "/rest/v1/ranking_publico?select=apelido,andar,aparencia,arma_mais_usada&order=andar.desc,atualizado_em.asc&temporada=eq.%d&limit=%d" % [Config.TEMPORADA,TAMANHO_LISTA]
	if http.request(url_servico + consulta, _cabecalhos()) != OK:
		http.queue_free()
		_buscando = false
		erro_consulta = "SEM CONEXAO COM O RANKING"
		lista_atualizada.emit(lista_cache)

func _cabecalhos() -> PackedStringArray:
	var cabecalhos := PackedStringArray(["apikey: " + chave_servico, "Content-Type: application/json"])
	# Chaves antigas (anon) são JWT e vão também em Authorization; as sb_publishable_ vão só em apikey.
	if chave_servico.begins_with("eyJ"):
		cabecalhos.append("Authorization: Bearer " + chave_servico)
	return cabecalhos

func _carregar() -> void:
	var dados := {}
	if FileAccess.file_exists(arquivo_save):
		var lido = JSON.parse_string(FileAccess.get_file_as_string(arquivo_save))
		if lido is Dictionary:
			dados = lido
	if int(dados.get("temporada",-1)) != Config.TEMPORADA: dados = {}
	_codigo = str(dados.get("codigo", ""))
	if _codigo.length() < 24:
		var cripto := Crypto.new()
		_codigo = cripto.generate_random_bytes(18).hex_encode()
	apelido = apelido_personagem(str(dados.get("apelido", "")))
	pendente = int(dados.get("pendente", 0))
	_enviado = int(dados.get("enviado", 0))
	_apelido_enviado = str(dados.get("apelido_enviado",apelido if _enviado > 0 else ""))
	visual_pendente = Visual.normalizar(dados.get("visual"))
	_visual_enviado = str(dados.get("visual_enviado",""))
	armas_usadas = Armas.normalizar(dados.get("armas_usadas"))
	_armas_enviadas = str(dados.get("armas_enviadas",""))
	_gravar()

func _gravar() -> void:
	var arquivo := FileAccess.open(arquivo_save, FileAccess.WRITE)
	if arquivo != null:
		arquivo.store_string(JSON.stringify({"temporada":Config.TEMPORADA,"codigo": _codigo, "apelido": apelido,
			"pendente": pendente, "enviado": _enviado,"apelido_enviado":_apelido_enviado,
			"visual":visual_pendente,"visual_enviado":_visual_enviado,
			"armas_usadas":armas_usadas,"armas_enviadas":_armas_enviadas}))
		_uso_sujo = false
