extends Node

## Progresso permanente entre partidas (roguelite): Brasas, melhorias, moradores do acampamento e recorde.
## As estatísticas da partida atual ficam aqui só até a morte; ao cair, encerrar_partida() converte
## o desempenho em Brasas. Salva em user://progresso.json.

signal brasas_alteradas(brasas: int)
signal melhorias_alteradas
signal morador_contratado(id: String)
signal checkpoint_alterado(onda: int)
## A maior onda já vencida subiu (libera as linhas extras da mochila, ver modelo_inventario.gd)
signal onda_vencida_alterada(onda: int)
signal armas_liberadas_alteradas
signal materiais_forja_alterados
const DesafiosArmas := preload("res://codigo/dados/desafios_armas.gd")
const ForjaArmas := preload("res://codigo/dados/forja_armas.gd")
const Refeicoes := preload("res://codigo/dados/refeicoes.gd")
## Prato do Caio (codigo/dados/refeicoes.gd) para a partida atual ou a próxima; "" = nenhum. Acaba em encerrar_partida()
var refeicao: String = ""
signal refeicao_alterada(id: String)
var armas_liberadas: Dictionary = {}
var armas_fabricadas: Dictionary = {}
## Encomenda permanente e compartilhada: materiais entregues, prazo absoluto no calendário.
var encomenda_forja: Dictionary = {}
var _carregando := false

const CAMINHO_SAVE := "user://progresso.json"
const NIVEL_MAXIMO := 5
const CUSTOS_MELHORIA := [25, 60, 120, 220, 360]
const ANDARES_MELHORIA := [0, 5, 10, 20, 30]
# Brasas por onda concluída, por chefe e por estágio bônus
const BRASAS_POR_ONDA := 2
const BRASAS_POR_CHEFE := 15
const BRASAS_POR_BONUS := 5
const FATOR_BARDO := 0.25
# Checkpoints da Mística: um a cada INTERVALO_CHECKPOINT andares (5, 10, 15...), liberados pelo andar mais
# alto já alcançado. O ouro de quem começa adiantado é FRACAO_OURO_CHECKPOINT do que a mesma partida
# renderia do andar 1 até ali (sem bônus de saque, eventos ou tesouros): sempre menos que jogar desde o 1.
const INTERVALO_CHECKPOINT := 5
const FRACAO_OURO_CHECKPOINT := 0.4
# Fração dos pontos de cada andar que vira abate comum (o resto são elites, que valem mais pontos)
const ABATES_POR_PONTO := 0.85
const OURO_GUARDIAO := 250
# Fração da vida com que a Curandeira revive o jogador
const VIDA_REVIVER := 0.5
const INVULNERABILIDADE_REVIVER := 2.0

# por_nivel: fração (vigor, forca, couraca, folego, saque) ou ouro (bolsa) somado a cada nível
const ORDEM_MELHORIAS := ["vigor", "forca", "couraca", "folego", "bolsa", "saque"]
const MELHORIAS := {
	"vigor": {"nome": "VIGOR", "descricao": "+3% VIDA MAXIMA", "por_nivel": 0.03},
	"forca": {"nome": "FORCA", "descricao": "+2% DANO", "por_nivel": 0.02},
	"couraca": {"nome": "COURACA", "descricao": "+1% PROTECAO", "por_nivel": 0.01},
	"folego": {"nome": "FOLEGO", "descricao": "+4% ESTAMINA MAXIMA", "por_nivel": 0.04},
	"bolsa": {"nome": "BOLSA", "descricao": "+20 OURO INICIAL", "por_nivel": 20.0},
	"saque": {"nome": "SAQUE", "descricao": "+4% OURO POR ABATE", "por_nivel": 0.04},
}

const ORDEM_MORADORES := ["curandeira", "bardo", "mistica"]
const MORADORES := {
	"curandeira": {"nome": "CURANDEIRA", "descricao": "REVIVE 1 VEZ POR PARTIDA", "custo": 40},
	"bardo": {"nome": "BARDO", "descricao": "+25% DE BRASAS", "custo": 25},
	"mistica": {"nome": "MISTICA", "descricao": "COMECA NO CHECKPOINT", "custo": 50},
}

# --- Dados permanentes ---
var brasas: int = 0
var recorde_onda: int = 0
## Maior onda já VENCIDA (concluída), em qualquer partida; permanente como as melhorias
var maior_onda_vencida: int = 0
var melhorias: Dictionary = {}
var moradores: Dictionary = {}
## Onda do maior chefe já derrotado (10, 20...); 0 se nenhum
var checkpoint_max: int = 0

# --- Partida atual ---
## Veios e golpes desta partida: mantidos ao viajar, reiniciados junto da partida.
var veios_arena: Dictionary = {}
## Resultado do portal especial por andar nesta partida; viajar não repete o sorteio nem o prêmio.
var portais_tesouro: Dictionary = {}
## Uma escolha por andar/partida; viagens não permitem repetir a recompensa.
var encontros_andares: Dictionary = {}
var eventos_andares: Dictionary = {}
var partida_ativa: bool = false
var onda_maxima: int = 0
var ondas_concluidas: int = 0
var abates: int = 0
var ouro_ganho: int = 0
var chefes: int = 0
var bonus_concluidos: int = 0
var reviveu_na_partida: bool = false
## Onda em que a próxima partida começa (escolhida na Mística); 1 = início normal
var onda_inicial: int = 1
## Ouro de compensação já concedido pelo checkpoint escolhido
var ouro_compensacao: int = 0
## true depois que a primeira onda da partida começou: a Mística não aceita mais mudanças
var onda_comecou: bool = false
var ultimo_resultado: Dictionary = {}

## Local de retorno fora da arena, separado por mundo.
var local_jogadores: Dictionary = {}

var caminho_save: String = CAMINHO_SAVE
var _ondas_de_chefe_contadas: Dictionary = {}

func _ready() -> void:
	carregar()
	if not mochila_pendente.is_empty():
		push_error("Não foi possível recuperar a operação da mochila.")
		get_tree().quit(1)

# --- Partida ---

func iniciar_partida() -> void:
	veios_arena.clear()
	portais_tesouro.clear()
	encontros_andares.clear()
	eventos_andares.clear()
	partida_ativa = true
	onda_maxima = 0
	ondas_concluidas = 0
	abates = 0
	ouro_ganho = 0
	chefes = 0
	bonus_concluidos = 0
	reviveu_na_partida = false
	onda_inicial = 1
	ouro_compensacao = 0
	onda_comecou = false
	_ondas_de_chefe_contadas.clear()
	if refeicao != "":
		_anunciar_refeicao.call_deferred()

func registrar_abate() -> void:
	if partida_ativa:
		abates += 1

func registrar_ouro(quantidade: int) -> void:
	if partida_ativa and quantidade > 0:
		ouro_ganho += quantidade

func registrar_onda_iniciada(onda: int) -> void:
	if not partida_ativa:
		return
	if not onda_comecou and is_inside_tree():
		get_tree().root.get_node("Ranking").iniciar_partida(onda)
		var parceiro := get_tree().root.get_node("Cooperativo").jogador2() as Node2D
		if parceiro != null: get_tree().root.get_node("Ranking").para_jogador(parceiro).iniciar_partida(onda)
	onda_comecou = true
	onda_maxima = maxi(onda_maxima, onda)

func registrar_onda_concluida(onda: int, chefe: bool, bonus: bool) -> void:
	if not partida_ativa:
		return
	onda_maxima = maxi(onda_maxima, onda)
	if bonus:
		bonus_concluidos += 1
	else:
		ondas_concluidas += 1
		if onda > maior_onda_vencida:
			maior_onda_vencida = onda
			salvar()
			onda_vencida_alterada.emit(maior_onda_vencida)
	if chefe:
		registrar_chefe(onda)
	_atualizar_ranking(onda_maxima)

## Chamado na morte do chefe e na conclusão da onda dele; conta uma vez só por onda
func registrar_chefe(onda: int) -> void:
	if not partida_ativa or _ondas_de_chefe_contadas.has(onda):
		return
	_ondas_de_chefe_contadas[onda] = true
	chefes += 1
	if onda > checkpoint_max:
		checkpoint_max = onda
		salvar()

## Vitória envia imediatamente; morte reutiliza o retrato feito antes de reiniciar os itens.
func _atualizar_ranking(andar: int, capturar := true) -> void:
	if not is_inside_tree() or andar <= 0: return
	var coop: Node = get_tree().root.get_node("Cooperativo")
	var ranking: Node = get_tree().root.get_node("Ranking")
	for jogador in [coop._jogador1(),coop.jogador2()]:
		if jogador == null: continue
		var perfil: Node = ranking.para_jogador(jogador)
		if capturar: perfil.registrar_resultado(jogador,andar)
		else: perfil.enviar(andar)

func calcular_brasas_base() -> int:
	return BRASAS_POR_ONDA * ondas_concluidas + BRASAS_POR_CHEFE * chefes + BRASAS_POR_BONUS * bonus_concluidos

## Fecha a partida: converte o desempenho em Brasas, atualiza o recorde e salva. Chamar duas vezes devolve o mesmo resultado
func encerrar_partida() -> Dictionary:
	if not partida_ativa:
		return ultimo_resultado
	# O equipamento da arena é reiniciado abaixo; fotografa o visual antes disso.
	if is_inside_tree():
		var jogador := get_tree().root.get_node("Cooperativo")._jogador1() as Node2D
		get_tree().root.get_node("Ranking").capturar_jogador(jogador)
		var parceiro := get_tree().root.get_node("Cooperativo").jogador2() as Node2D
		if parceiro != null: get_tree().root.get_node("Ranking").para_jogador(parceiro).capturar_jogador(parceiro)
	partida_ativa = false
	if is_inside_tree():
		get_tree().root.get_node("BauCasa").reiniciar_equipamento_da_partida()
	# O prato valia a partida inteira: acabou junto com ela
	_acabar_refeicao()
	var base := calcular_brasas_base()
	var total := base
	if tem_morador("bardo"):
		total = roundi(base * (1.0 + FATOR_BARDO))
	var novo_recorde := onda_maxima > recorde_onda
	if novo_recorde:
		recorde_onda = onda_maxima
	brasas += total
	ultimo_resultado = {
		"onda": onda_maxima,
		"ondas_concluidas": ondas_concluidas,
		"abates": abates,
		"ouro": ouro_ganho,
		"chefes": chefes,
		"bonus": bonus_concluidos,
		"brasas_base": base,
		"brasas_bardo": total - base,
		"brasas": total,
		"novo_recorde": novo_recorde,
		"recorde": recorde_onda,
	}
	_atualizar_ranking(onda_maxima, false)
	salvar()
	brasas_alteradas.emit(brasas)
	return ultimo_resultado

# --- Melhorias ---

func nivel(id: String) -> int:
	return clampi(int(melhorias.get(id, 0)), 0, NIVEL_MAXIMO)

## Custo do próximo nível; -1 se já está no máximo ou o id não existe
func custo_proximo(id: String) -> int:
	if not MELHORIAS.has(id) or nivel(id) >= NIVEL_MAXIMO:
		return -1
	return CUSTOS_MELHORIA[nivel(id)]

func pode_comprar_melhoria(id: String) -> bool:
	var custo := custo_proximo(id)
	return custo != -1 and brasas >= custo and maior_onda_vencida >= ANDARES_MELHORIA[nivel(id)]

func comprar_melhoria(id: String) -> bool:
	if not pode_comprar_melhoria(id):
		return false
	var custo := custo_proximo(id)
	var anterior := nivel(id)
	brasas -= custo
	melhorias[id] = anterior + 1
	if not salvar():
		brasas += custo
		melhorias[id] = anterior
		return false
	brasas_alteradas.emit(brasas)
	melhorias_alteradas.emit()
	onda_vencida_alterada.emit(maior_onda_vencida)
	return true

## Efeito total da melhoria no nível atual (fração para as porcentagens, ouro para a bolsa)
func bonus(id: String) -> float:
	if not MELHORIAS.has(id):
		return 0.0
	return float(MELHORIAS[id]["por_nivel"]) * nivel(id) + Refeicoes.bonus(refeicao, id)

## Só a parte das melhorias compradas (a tela da Lia mostra o nível sem contar o prato)
func bonus_melhoria(id: String) -> float:
	if not MELHORIAS.has(id):
		return 0.0
	return float(MELHORIAS[id]["por_nivel"]) * nivel(id)

# --- Refeição ---

func comer_da_mochila(item: DadosItem, inventario: Node) -> String:
	if refeicao != "": return "VOCE JA TEM UMA REFEICAO ATIVA"
	if Refeicoes.dados(item.conteudo()).is_empty(): return "COMIDA DESCONHECIDA"
	if not resolver_mochila_pendente(): return "NAO FOI POSSIVEL SALVAR"
	var antes: Array = inventario.fotografar_mochila()
	if not inventario.gastar_tipo(item.tipo,1): return "COMIDA NAO ESTA NA MOCHILA"
	refeicao = item.conteudo()
	if not _confirmar_mochila(inventario):
		refeicao = ""
		inventario.restaurar_mochila(antes)
		return "NAO FOI POSSIVEL SALVAR"
	refeicao_alterada.emit(refeicao)
	melhorias_alteradas.emit()
	return ""

## Come o prato (o Caio já gastou a colheita): vale até o fim da próxima partida. false se já tem um prato
func comer(id: String) -> bool:
	if refeicao != "" or Refeicoes.dados(id).is_empty():
		return false
	refeicao = id
	salvar()
	refeicao_alterada.emit(refeicao)
	melhorias_alteradas.emit()
	return true

## Na entrada da arena: lembra qual prato está valendo nesta partida
func _anunciar_refeicao() -> void:
	if refeicao != "" and is_inside_tree():
		get_tree().call_group("hud", "anunciar", String(Refeicoes.dados(refeicao)["nome"]), Refeicoes.texto_bonus(refeicao) + " NESTA PARTIDA", 3.0)

func _acabar_refeicao() -> void:
	if refeicao == "":
		return
	refeicao = ""
	refeicao_alterada.emit(refeicao)
	melhorias_alteradas.emit()

func ouro_inicial() -> int:
	return roundi(bonus("bolsa"))

# --- Moradores ---

func tem_morador(id: String) -> bool:
	return bool(moradores.get(id, false))

func contratar(id: String) -> bool:
	if not MORADORES.has(id) or tem_morador(id):
		return false
	var custo: int = MORADORES[id]["custo"]
	if brasas < custo:
		return false
	brasas -= custo
	moradores[id] = true
	salvar()
	brasas_alteradas.emit(brasas)
	morador_contratado.emit(id)
	return true

## Curandeira: gasta o reviver da partida. Retorna false se não há curandeira ou já foi usado
func usar_reviver() -> bool:
	if not partida_ativa or not tem_morador("curandeira") or reviveu_na_partida:
		return false
	reviveu_na_partida = true
	return true

# --- Checkpoint (Mística) ---

## Andares em que dá para começar: o 1 e cada múltiplo de INTERVALO_CHECKPOINT que o jogador já alcançou
## (concluiu o andar anterior). `intervalo_chefe` ficou só por compatibilidade com quem chama.
func checkpoints_disponiveis(_intervalo_chefe: int = 10) -> Array[int]:
	var lista: Array[int] = [1]
	var andar := INTERVALO_CHECKPOINT
	while andar <= maior_onda_vencida + 1:
		lista.append(andar)
		andar += INTERVALO_CHECKPOINT
	return lista

## Ouro de começar no andar dado: FRACAO_OURO_CHECKPOINT do ouro estimado dos andares pulados (0 no andar 1)
static var _ouro_estimado: Dictionary = {}
func ouro_checkpoint(onda: int) -> int:
	if onda <= 1:
		return 0
	if not _ouro_estimado.has(onda):
		_ouro_estimado[onda] = roundi(ouro_estimado_ate(onda) * FRACAO_OURO_CHECKPOINT)
	return _ouro_estimado[onda]

## Ouro que uma partida junta do andar 1 até o anterior ao dado, com as mesmas contas dos andares:
## abates comuns para encher a barra, prêmio de fim de andar e o do guardião.
static func ouro_estimado_ate(andar: int) -> float:
	var Catalogo := preload("res://codigo/fendas/catalogo_andares.gd")
	var ondas := preload("res://codigo/logica/gerenciador_de_ondas.gd").new()
	var total := 0.0
	for n in range(1, andar):
		var combate: Dictionary = Catalogo.dados(n).combate
		var abates := float(Catalogo.meta(n)) / float(combate.pontos_comum) * ABATES_POR_PONTO
		total += abates * ondas.ouro_por_abate(n) + ondas.ouro_fim_onda(n) + OURO_GUARDIAO
	ondas.free()
	return total

## Qualquer jogador escolhe no mapa dos andares do portal, antes do primeiro andar da partida
func pode_escolher_checkpoint() -> bool:
	return partida_ativa and not onda_comecou

## Escolhe o andar inicial e acerta o ouro nas duas carteiras (cooperativo). Devolve "" ou o motivo da recusa.
## Trocar de checkpoint devolve a compensação anterior: o ouro não pode ficar negativo.
func escolher_checkpoint(onda: int) -> String:
	if not pode_escolher_checkpoint():
		return "SO ANTES DO PRIMEIRO ANDAR"
	if not checkpoints_disponiveis().has(onda):
		return "ANDAR AINDA NAO LIBERADO"
	var diferenca := ouro_checkpoint(onda) - ouro_compensacao
	var dados := get_tree().root.get_node("DadosJogo")
	if mini(dados.moedas, dados.moedas_p2 if get_tree().root.get_node("Cooperativo").com_dois() else dados.moedas) + diferenca < 0:
		return "OURO INSUFICIENTE PARA TROCAR"
	diferenca = definir_checkpoint(onda)
	dados.moedas += diferenca
	dados.moedas_p2 += diferenca
	dados.atualizar_ui_moedas()
	var gerenciador := get_tree().get_first_node_in_group("gerenciador_ondas")
	if gerenciador != null:
		gerenciador.definir_onda_inicial(onda)
	get_tree().call_group("tela_mercante", "atualizar_exibicao_moedas")
	return ""

## Define a onda inicial da partida. Retorna a diferença de ouro a aplicar (compensação nova menos a já
## concedida); 0 se a escolha for inválida ou nada mudar. Quem chama soma o ouro e ajusta o gerenciador
func definir_checkpoint(onda: int, intervalo_chefe: int = 10) -> int:
	if not pode_escolher_checkpoint() or not checkpoints_disponiveis(intervalo_chefe).has(onda):
		return 0
	var nova_compensacao := ouro_checkpoint(onda)
	var diferenca := nova_compensacao - ouro_compensacao
	onda_inicial = onda
	ouro_compensacao = nova_compensacao
	checkpoint_alterado.emit(onda)
	return diferenca

# --- Salvar / carregar ---

func salvar() -> bool:
	var temporario := caminho_save + ".tmp"
	var arquivo := FileAccess.open(temporario, FileAccess.WRITE)
	if arquivo == null:
		return false
	var dados := {
		"local_jogadores": local_jogadores,
		"brasas": brasas,
		"recorde_onda": recorde_onda,
		"maior_onda_vencida": maior_onda_vencida,
		"melhorias": melhorias,
		"moradores": moradores,
		"checkpoint_max": checkpoint_max,
		"armas_liberadas": armas_liberadas,
		"armas_fabricadas": armas_fabricadas,
		"encomenda_forja": encomenda_forja,
		"refeicao": refeicao,
		"mochila_pendente": mochila_pendente,
	}
	arquivo.store_string(JSON.stringify(dados, "\t"))
	arquivo.flush()
	var erro := arquivo.get_error()
	arquivo.close()
	if erro != OK:
		return false
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(temporario), ProjectSettings.globalize_path(caminho_save)) == OK

func carregar() -> bool:
	_zerar_dados()
	if not FileAccess.file_exists(caminho_save):
		return false
	var dados = JSON.parse_string(FileAccess.get_file_as_string(caminho_save))
	if not dados is Dictionary:
		return false
	_carregando = true
	var locais = dados.get("local_jogadores", {})
	if locais is Dictionary: local_jogadores = locais
	mochila_pendente = dados.get("mochila_pendente", {})
	brasas = maxi(int(dados.get("brasas", 0)), 0)
	recorde_onda = maxi(int(dados.get("recorde_onda", 0)), 0)
	maior_onda_vencida = maxi(int(dados.get("maior_onda_vencida", 0)), 0)
	checkpoint_max = maxi(int(dados.get("checkpoint_max", 0)), 0)
	refeicao = String(dados.get("refeicao", ""))
	if Refeicoes.dados(refeicao).is_empty():
		refeicao = ""
	var dados_melhorias = dados.get("melhorias", {})
	if dados_melhorias is Dictionary:
		for id in dados_melhorias:
			if MELHORIAS.has(id):
				melhorias[id] = clampi(int(dados_melhorias[id]), 0, NIVEL_MAXIMO)
	var dados_moradores = dados.get("moradores", {})
	if dados_moradores is Dictionary:
		for id in dados_moradores:
			if MORADORES.has(id):
				moradores[id] = bool(dados_moradores[id])
	var liberadas = dados.get("armas_liberadas", {})
	if liberadas is Dictionary:
		for tipo in ForjaArmas.RECEITAS:
			if bool(liberadas.get(tipo, false)):
				armas_liberadas[tipo] = true
	var fabricadas = dados.get("armas_fabricadas", {})
	if fabricadas is Dictionary:
		for tipo in ForjaArmas.RECEITAS:
			if receita_liberada(tipo) and bool(fabricadas.get(tipo, false)):
				armas_fabricadas[tipo] = true
	var encomenda = dados.get("encomenda_forja", {})
	if encomenda is Dictionary and ForjaArmas.RECEITAS.has(str(encomenda.get("tipo", ""))):
		var tipo := str(encomenda["tipo"])
		if receita_liberada(tipo) and not arma_liberada(tipo):
			var inicio := maxi(1,int(encomenda.get("dia_inicio",1)))
			encomenda_forja = {"tipo":tipo, "dia_inicio":inicio,
				"dia_pronto":maxi(inicio+1,int(encomenda.get("dia_pronto",inicio+ForjaArmas.dias_fabricacao(tipo)))),
				"jogador":clampi(int(encomenda.get("jogador",1)),1,2)}
			# Pedidos antigos não têm fotografia dos custos e seguem pagos.
			if encomenda.get("materiais") is Dictionary:
				var materiais := {}
				for id in encomenda.materiais:
					if ForjaArmas.MATERIAIS.has(id) and int(encomenda.materiais[id]) > 0:
						materiais[id] = int(encomenda.materiais[id])
				encomenda_forja["materiais"] = materiais
	materiais_forja_alterados.emit()
	brasas_alteradas.emit(brasas)
	melhorias_alteradas.emit()
	armas_liberadas_alteradas.emit()
	_carregando = false
	if not mochila_pendente.is_empty():
		return resolver_mochila_pendente()
	return true

## Novo jogo: apaga o arquivo e zera tudo na memória
func apagar() -> void:
	if FileAccess.file_exists(caminho_save):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(caminho_save))
	_zerar_dados()
	partida_ativa = false
	brasas_alteradas.emit(brasas)
	melhorias_alteradas.emit()
	onda_vencida_alterada.emit(maior_onda_vencida)
	armas_liberadas_alteradas.emit()
	materiais_forja_alterados.emit()

func _zerar_dados() -> void:
	portais_tesouro.clear()
	encontros_andares.clear()
	eventos_andares.clear()
	local_jogadores = {}
	veios_arena.clear()
	mochila_pendente.clear()
	armas_liberadas.clear()
	armas_fabricadas.clear()
	encomenda_forja.clear()
	brasas = 0
	recorde_onda = 0
	maior_onda_vencida = 0
	checkpoint_max = 0
	melhorias = {}
	moradores = {}
	refeicao = ""

func arma_liberada(tipo: String) -> bool:
	return tipo in ForjaArmas.INICIAIS_LIVRES or (ForjaArmas.RECEITAS.has(tipo) and bool(armas_fabricadas.get(tipo, false)))

func receita_liberada(tipo: String) -> bool:
	return ForjaArmas.RECEITAS.has(tipo) and bool(armas_liberadas.get(tipo, false))

func quantidade_material_forja(id: String, inventario: Node = null) -> int:
	var mochila: Node = inventario if inventario != null else (Engine.get_main_loop() as SceneTree).root.get_node("InventarioJogador")
	return mochila.quantidade_tipo("material:" + id)

func adicionar_materiais_forja(ganhos: Dictionary, inventario: Node = null) -> bool:
	var mochila: Node = inventario if inventario != null else (Engine.get_main_loop() as SceneTree).root.get_node("InventarioJogador")
	return mochila.receber_materiais(ganhos)

func aprender_receita(tipo: String, inventario: Node) -> String:
	if not resolver_mochila_pendente():
		return "NAO FOI POSSIVEL SALVAR. TENTE NOVAMENTE."
	if not ForjaArmas.RECEITAS.has(tipo) or tipo in ForjaArmas.ARMAS_RETIRADAS:
		return "RECEITA DESCONHECIDA"
	if receita_liberada(tipo):
		return "RECEITA JA APRENDIDA"
	if inventario == null or inventario.quantidade_tipo("receita:" + tipo) == 0:
		return "RECEITA NAO ESTA NA MOCHILA"
	var antes: Array = inventario.fotografar_mochila()
	inventario.gastar_tipo("receita:" + tipo, 1)
	armas_liberadas[tipo] = true
	if not _confirmar_mochila(inventario):
		armas_liberadas.erase(tipo)
		inventario.restaurar_mochila(antes)
		return "NAO FOI POSSIVEL SALVAR. TENTE NOVAMENTE."
	armas_liberadas_alteradas.emit()
	return ""

func motivo_fabricar_arma(tipo: String, inventario: Node = null) -> String:
	if not encomenda_forja.is_empty():
		return "IVO JA TEM UMA ENCOMENDA"
	if not ForjaArmas.RECEITAS.has(tipo) or tipo in ForjaArmas.ARMAS_RETIRADAS:
		return "RECEITA DESCONHECIDA"
	if arma_liberada(tipo):
		return "MODELO JA FABRICADO"
	if not receita_liberada(tipo):
		return "ENCONTRE E USE A RECEITA NA MOCHILA"
	var andar := ForjaArmas.onda_receita(tipo)
	if maior_onda_vencida < andar:
		return "VENCA O ANDAR %d PARA FABRICAR" % andar
	for id in ForjaArmas.RECEITAS[tipo]:
		if quantidade_material_forja(id, inventario) < int(ForjaArmas.RECEITAS[tipo][id]):
			return "FALTAM MATERIAIS NA MOCHILA"
	return ""

func encomendar_arma(tipo: String, inventario: Node) -> String:
	if inventario != InventarioJogador and inventario != InventarioJogador2:
		return "MOCHILA INVALIDA"
	if not resolver_mochila_pendente():
		return "NAO FOI POSSIVEL SALVAR. TENTE NOVAMENTE."
	var motivo := motivo_fabricar_arma(tipo,inventario)
	if motivo != "":
		return motivo
	var antes: Array = inventario.fotografar_mochila()
	encomenda_forja = {"tipo":tipo, "dia_inicio":Calendario.dia,
		"dia_pronto":Calendario.dia+ForjaArmas.dias_fabricacao(tipo),
		"materiais":ForjaArmas.RECEITAS[tipo].duplicate(),
		"jogador":2 if inventario == InventarioJogador2 else 1}
	for id in ForjaArmas.RECEITAS[tipo]:
		inventario.gastar_tipo("material:"+id,int(ForjaArmas.RECEITAS[tipo][id]))
	if not _confirmar_mochila(inventario):
		encomenda_forja.clear()
		inventario.restaurar_mochila(antes)
		materiais_forja_alterados.emit()
		return "NAO FOI POSSIVEL SALVAR. TENTE NOVAMENTE."
	materiais_forja_alterados.emit()
	return ""

func encomenda_forja_pronta() -> bool:
	return not encomenda_forja.is_empty() and Calendario.dia >= int(encomenda_forja["dia_pronto"])

func texto_encomenda_forja() -> String:
	if encomenda_forja.is_empty():
		return ""
	var nome: String = ForjaArmas.nome(str(encomenda_forja["tipo"]))
	if encomenda_forja_pronta():
		return "PRONTA PARA RETIRAR: %s.\nFALE COM O IVO (OU RETIRE NA BIGORNA) NO HORARIO DE ATENDIMENTO." % nome
	var dia := int(encomenda_forja["dia_pronto"])
	var faltam := maxi(0,dia-Calendario.dia)
	var data := "%s, DIA %d" % [Calendario.NOMES[Calendario.estacao(dia)],(dia-1)%Calendario.DIAS_POR_ESTACAO+1]
	if Calendario.ano(dia) != Calendario.ano():
		data += " DO ANO %d" % Calendario.ano(dia)
	return "ENCOMENDA: %s.\nPRONTA EM %s. FALTA%s %d DIA%s." % [nome,data,"M" if faltam != 1 else "",faltam,"S" if faltam != 1 else ""]

func retirar_encomenda_forja(inventario: Node) -> String:
	if inventario != InventarioJogador and inventario != InventarioJogador2:
		return "MOCHILA INVALIDA"
	if not resolver_mochila_pendente():
		return "NAO FOI POSSIVEL SALVAR. TENTE NOVAMENTE."
	if encomenda_forja.is_empty():
		return "NENHUMA ENCOMENDA PARA RETIRAR"
	if not encomenda_forja_pronta():
		return "A ENCOMENDA AINDA NAO ESTA PRONTA"
	var pedido := encomenda_forja.duplicate(true)
	var tipo := str(pedido["tipo"])
	armas_fabricadas[tipo] = true
	encomenda_forja.clear()
	if not salvar():
		encomenda_forja = pedido
		armas_fabricadas.erase(tipo)
		return "NAO FOI POSSIVEL SALVAR. TENTE NOVAMENTE."
	armas_liberadas_alteradas.emit()
	inventario.entregar_armas_liberadas(true)
	materiais_forja_alterados.emit()
	return ""

func fabricar_arma(tipo: String, inventario: Node = null) -> String:
	if not resolver_mochila_pendente():
		return "NAO FOI POSSIVEL SALVAR. TENTE NOVAMENTE."
	var mochila: Node = inventario if inventario != null else (Engine.get_main_loop() as SceneTree).root.get_node("InventarioJogador")
	var motivo := motivo_fabricar_arma(tipo, mochila)
	if motivo != "":
		return motivo
	var antes: Array = mochila.fotografar_mochila()
	for id in ForjaArmas.RECEITAS[tipo]:
		mochila.gastar_tipo("material:" + id, int(ForjaArmas.RECEITAS[tipo][id]))
	armas_fabricadas[tipo] = true
	if not _confirmar_mochila(mochila):
		mochila.restaurar_mochila(antes)
		armas_fabricadas.erase(tipo)
		return "NAO FOI POSSIVEL SALVAR. TENTE NOVAMENTE."
	materiais_forja_alterados.emit()
	armas_liberadas_alteradas.emit()
	return ""

## O progresso confirma a operação com uma fotografia da mochila. Se a gravação da
## mochila falhar ou o jogo fechar entre os arquivos, carregar reaplica a fotografia.
var mochila_pendente: Dictionary = {}

func _confirmar_mochila(mochila: Node) -> bool:
	mochila_pendente = {"caminho": mochila.caminho_save, "dados": mochila.dados_save()}
	if not salvar():
		mochila_pendente.clear()
		return false
	if mochila.salvar():
		mochila_pendente.clear()
		salvar()
	return true

func resolver_mochila_pendente() -> bool:
	if mochila_pendente.is_empty():
		return true
	var caminho := str(mochila_pendente.get("caminho", ""))
	var raiz := (Engine.get_main_loop() as SceneTree).root
	if caminho not in [raiz.get_node("InventarioJogador").caminho_save, raiz.get_node("InventarioJogador2").caminho_save]:
		return false
	if not load("res://codigo/modelos/modelo_inventario.gd").gravar_dados(caminho, mochila_pendente.get("dados", {})):
		return false
	mochila_pendente.clear()
	return salvar()
