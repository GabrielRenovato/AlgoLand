extends Node

## Só novos jogos entram no prólogo. Ausência do arquivo preserva partidas anteriores.
signal alterada
const SAVE := "user://introducao.json"
const ARENA := "res://cenas/cenario.tscn"
const CIDADE := "res://cenas/cidade.tscn"
const FAZENDA := "res://cenas/fazenda.tscn"
enum Etapa { QUEDA, EQUIPAR, COMBATE, RESGATE, PORTAL, VILA, CAMINHO, PASSEIO, DESCANSO, CONCLUIDA }
var etapa: int = Etapa.CONCLUIDA
var parada := 0
var presentes: Dictionary = {}
var tarefas: Dictionary = {}
var alvos_tarefas: Dictionary = {}
var saida_liberada := false
var cinematica := false
var acompanhando := false
## Bento ainda vai explicar a janela entre as ondas (depois da primeira onda vencida). Só jogos novos: saves antigos não têm a chave
var aula_arena := false
var caminho_save := SAVE

func _ready() -> void:
	carregar()
	Transicao.dormiu.connect(_ao_dormir)

func ativa() -> bool:
	return etapa != Etapa.CONCLUIDA

func iniciar() -> void:
	etapa = Etapa.QUEDA
	parada = 0
	saida_liberada = false
	presentes.clear()
	tarefas.clear()
	alvos_tarefas.clear()
	cinematica = false
	acompanhando = false
	aula_arena = true
	InventarioJogador.limpar()
	salvar()

## Mundo cooperativo: começa direto no jogo livre (sem o prólogo de um jogador só), com a aula da arena guardada
func pular_prologo() -> void:
	etapa = Etapa.CONCLUIDA
	parada = 0
	saida_liberada = false
	presentes.clear()
	tarefas.clear()
	alvos_tarefas.clear()
	cinematica = false
	acompanhando = false
	aula_arena = true
	salvar()

func definir_etapa(nova: int) -> void:
	if nova != etapa:
		saida_liberada = false
	etapa = nova
	salvar()
	alterada.emit()

func cena_continuar() -> String:
	if etapa <= Etapa.PORTAL:
		return ARENA
	if etapa <= Etapa.CAMINHO:
		return CIDADE
	if ativa():
		return FAZENDA
	return CIDADE

func preparar_cena(cena: Node) -> void:
	if not ativa() or cena.has_node("SequenciaIntroducao"):
		return
	if cena.scene_file_path not in [ARENA, CIDADE, FAZENDA, "res://cenas/casa.tscn"]:
		return
	var sequencia: Node = load("res://codigo/introducao/sequencia_introducao.gd").new()
	sequencia.name = "SequenciaIntroducao"
	cena.add_child.call_deferred(sequencia)

func permite_interacao(zona: Node) -> bool:
	# A cinemática também vale fora do prólogo (aula da arena)
	if cinematica:
		return false
	if not ativa():
		return true
	if acompanhando:
		return false
	if zona.get("cena_destino") != null:
		var destino: String = zona.cena_destino
		if etapa == Etapa.PORTAL:
			return destino == CIDADE
		if etapa == Etapa.CAMINHO:
			return destino == FAZENDA and saida_liberada
		if etapa == Etapa.DESCANSO:
			return destino in [FAZENDA, "res://cenas/casa.tscn"]
	return etapa == Etapa.DESCANSO and zona.get("nome_tela") == "dormir"

func permite_tela(nome: String) -> bool:
	if nome == "introducao" or nome == "fim_partida":
		return true
	if cinematica:
		return false
	if not ativa():
		return true
	return nome in ["pausa", "inventario"] or (etapa == Etapa.DESCANSO and nome == "dormir")

## Reserva capacidade antes da entrega. Só registra o presente depois que foi recebido.
func entregar(tipo: String, quantidade := 1) -> bool:
	if presentes.has(tipo):
		return true
	if tipo.begins_with("semente:"):
		if not InventarioJogador.adicionar_sementes(tipo.trim_prefix("semente:"), quantidade):
			return false
	elif InventarioJogador.buscar_por_tipo(tipo) == null:
		var item = load("res://codigo/modelos/dados_item.gd").de_fazenda(tipo)
		if InventarioJogador.adicionar(item) < 0:
			return false
	presentes[tipo] = quantidade
	InventarioJogador.salvar()
	salvar()
	return true

func salvar() -> bool:
	# O inventário vai no mesmo checkpoint: retomar não repete presentes nem perde ferramentas.
	var mochila: Array = []
	for item in InventarioJogador.mochila:
		mochila.append(item.para_dict() if item != null else null)
	var equipados := {}
	for slot in InventarioJogador.SLOTS:
		var item = InventarioJogador.equipados[slot]
		equipados[slot] = item.para_dict() if item != null else null
	var dados := {"versao": 2, "tarefas": tarefas, "alvos_tarefas": alvos_tarefas, "etapa": etapa, "parada": parada, "presentes": presentes, "aula_arena": aula_arena,
		"inventario": {"mochila": mochila, "equipados": equipados, "mao": InventarioJogador.celulas_da_mao}}
	var arquivo := FileAccess.open(caminho_save + ".tmp", FileAccess.WRITE)
	if arquivo == null:
		return false
	arquivo.store_string(JSON.stringify(dados))
	arquivo.close()
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(caminho_save + ".tmp"), ProjectSettings.globalize_path(caminho_save)) == OK

func carregar() -> bool:
	saida_liberada = false
	etapa = Etapa.CONCLUIDA
	aula_arena = false
	cinematica = false
	acompanhando = false
	if not FileAccess.file_exists(caminho_save):
		return false
	var dados = JSON.parse_string(FileAccess.get_file_as_string(caminho_save))
	if not dados is Dictionary or int(dados.get("versao", 0)) not in [1, 2]:
		return false
	etapa = clampi(int(dados.get("etapa", Etapa.CONCLUIDA)), 0, Etapa.CONCLUIDA)
	parada = clampi(int(dados.get("parada", 0)), 0, 6)
	presentes = dados.get("presentes", {}) if dados.get("presentes", {}) is Dictionary else {}
	# Prólogos em andamento de antes desta aula também a recebem
	aula_arena = bool(dados.get("aula_arena", ativa()))
	tarefas = dados.get("tarefas", {}) if dados.get("tarefas", {}) is Dictionary else {}
	alvos_tarefas = dados.get("alvos_tarefas", {}) if dados.get("alvos_tarefas", {}) is Dictionary else {}
	# Introduções antigas em andamento voltam à primeira lição prática, mantendo os presentes.
	if int(dados.versao) == 1 and etapa == Etapa.PASSEIO:
		parada = mini(parada, 1)
	# Só restaura o checkpoint durante a introdução; saves antigos e o jogo livre usam o inventário normal.
	if ativa() and dados.get("inventario") is Dictionary:
		var temporario := "user://inventario_introducao_checkpoint.json"
		var arquivo := FileAccess.open(temporario, FileAccess.WRITE)
		if arquivo == null:
			return false
		arquivo.store_string(JSON.stringify(dados.inventario))
		arquivo.close()
		InventarioJogador.carregar(temporario)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporario))
	return true

func concluir_aula_arena() -> void:
	aula_arena = false
	salvar()

func _ao_dormir() -> void:
	if etapa == Etapa.DESCANSO:
		definir_etapa(Etapa.CONCLUIDA)
		get_tree().call_group("hud", "anunciar", "UM NOVO COMECO", "A FAZENDA E A VILA DAS FLORES CONTAM COM VOCE.", 4.0)

func reiniciar_apos_morte() -> void:
	if ativa() and etapa <= Etapa.COMBATE:
		definir_etapa(Etapa.QUEDA)
		get_tree().call_group("sequencia_introducao", "reiniciar_arena")
