extends Node

## Mundos salvos (autoload Saves): o jogo solo fica direto em user:// (como sempre foi) e o mundo cooperativo em
## user://coop/, com fazenda, cidade, calendário, progresso, baú, inventários e personagens próprios, como o Stardew.
## A tela inicial escolhe o mundo (trocar) antes de começar ou continuar; trocar repõe o caminho de cada save e
## recarrega tudo. As opções (user://opcoes.cfg) são do jogo, não do mundo.

signal mundo_trocado(mundo: String)

const SOLO := "solo"
const COOP := "coop"
const PASTAS := {SOLO: "user://", COOP: "user://coop/"}
const VersaoSave := preload("res://codigo/dados/versao_save.gd")

var mundo := SOLO

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Fechar a janela também precisa gravar o estado atual, como SAIR no menu de pausa.
	get_tree().auto_accept_quit = false

func _notification(aviso: int) -> void:
	if aviso == NOTIFICATION_WM_CLOSE_REQUEST:
		if get_node_or_null("/root/Fazenda") != null: salvar_tudo()
		get_tree().quit()
	elif aviso == NOTIFICATION_APPLICATION_PAUSED:
		# No celular o sistema pode encerrar o aplicativo depois que ele vai para o fundo.
		if get_node_or_null("/root/Fazenda") != null: salvar_tudo()

func salvar_tudo() -> void:
	_guardar_local()
	InventarioJogador.salvar()
	if Cooperativo.ativo:
		InventarioJogador2.salvar()
	Progresso.salvar()
	Calendario.salvar()
	Fazenda.salvar()
	BauCasa.salvar()
	Cidade._gravar()

func _enter_tree() -> void:
	# Este autoload é o primeiro: nenhum sistema deve carregar o progresso anterior.
	for qual in [SOLO, COOP]:
		var erro := VersaoSave.preparar(PASTAS[qual])
		if erro != OK:
			push_error("Não foi possível preparar o save %s: %s" % [qual, error_string(erro)])
			get_tree().quit(1)
			return

func pasta() -> String:
	return PASTAS[mundo]

func caminho(arquivo: String) -> String:
	return pasta() + arquivo

func eh_coop() -> bool:
	return mundo == COOP

## Personagem de cada jogador (aparência e apelido): o 2 só existe no mundo cooperativo
func caminho_personagem(jogador_2 := false) -> String:
	return caminho("configuracao_jogador_p2.json" if jogador_2 else "configuracao_jogador.json")

func existe_mundo(qual: String) -> bool:
	return FileAccess.file_exists(PASTAS[qual] + "configuracao_jogador.json")

## Passa a usar o mundo `qual`: aponta cada save para a pasta dele e recarrega (ou zera, se o arquivo não existe)
func trocar(qual: String) -> void:
	_restaurar_pendente = false
	mundo = qual
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(pasta()))
	Progresso.caminho_save = caminho("progresso.json")
	Calendario.caminho_save = caminho("calendario.json")
	Cidade.caminho_save = caminho("cidade.json")
	Fazenda.caminho_save = caminho("fazenda.json")
	Introducao.caminho_save = caminho("introducao.json")
	BauCasa.caminho_save = caminho("bau.json")
	Comercio.caminho_save = caminho("comercio.json")
	InventarioJogador.caminho_save = caminho("inventario.json")
	InventarioJogador2.caminho_save = caminho("inventario_p2.json")
	Progresso.carregar()
	if not Progresso.mochila_pendente.is_empty():
		push_error("Não foi possível recuperar a operação da mochila.")
		get_tree().quit(1)
		return
	Calendario.carregar()
	Cidade.carregar()
	Fazenda.carregar()
	Introducao.carregar()
	BauCasa.carregar()
	Comercio.carregar()
	InventarioJogador.limpar()
	InventarioJogador.carregar()
	InventarioJogador2.limpar()
	InventarioJogador2.carregar()
	Transicao.limpar()
	mundo_trocado.emit(mundo)

# Só cenas permanentes podem ser retomadas; arenas e destinos desconhecidos voltam à cidade.
const CIDADE := "res://cenas/cidade.tscn"
const LOCAIS := [CIDADE, "res://cenas/fazenda.tscn", "res://cenas/casa.tscn", "res://cenas/galinheiro.tscn", "res://cenas/cidade/carpintaria.tscn",
	"res://cenas/praia.tscn", "res://cenas/palafita.tscn",
	"res://cenas/cidade/forja.tscn", "res://cenas/cidade/casa_bento.tscn",
	"res://cenas/cidade/mistica.tscn", "res://cenas/cidade/pousada.tscn",
	"res://cenas/cidade/enfermaria.tscn", "res://cenas/cidade/sede.tscn", "res://cenas/cidade/venda.tscn"]
var _restaurar_pendente := false

func _guardar_local() -> void:
	if Introducao.ativa(): return
	for numero in [1, 2]:
		var jogador := Cooperativo._jogador1() if numero == 1 else Cooperativo.jogador2()
		if jogador == null: continue
		var cena := Cooperativo.cena_de(jogador)
		if cena == null: continue
		var destino: String = cena.scene_file_path
		var local := {"cena": CIDADE}
		if destino in LOCAIS:
			local = {"cena": destino, "x": jogador.global_position.x, "y": jogador.global_position.y}
		Progresso.local_jogadores[str(numero)] = local

func preparar_continuacao() -> String:
	_restaurar_pendente = false
	if Comercio.em_viagem: return "res://cenas/fazenda.tscn"
	if Introducao.ativa(): return Introducao.cena_continuar()
	_restaurar_pendente = true
	return _local_de(1).get("cena", CIDADE)

func _local_de(numero: int) -> Dictionary:
	var local = Progresso.local_jogadores.get(str(numero), {})
	if not local is Dictionary or local.get("cena", "") not in LOCAIS:
		return {"cena": CIDADE}
	return local

func restaurar_local() -> void:
	if not _restaurar_pendente: return
	_restaurar_pendente = false
	var p1 := Cooperativo._jogador1()
	if p1 == null: return
	if Cooperativo.ativo and Cooperativo.jogador2() == null:
		Cooperativo._criar_p2(p1)
	for numero in [1, 2]:
		var jogador := Cooperativo._jogador1() if numero == 1 else Cooperativo.jogador2()
		if jogador == null: continue
		var local := _local_de(numero)
		var cena := Cooperativo.cena_de(jogador)
		if cena.scene_file_path != local["cena"] and Cooperativo.ativo:
			await Cooperativo.viajar_local(jogador, local["cena"], "")
		if local.has("x") and local.has("y"):
			var posicao := Vector2(float(local["x"]), float(local["y"]))
			cena = Cooperativo.cena_de(jogador)
			if cena.has_method("ajustar_posicao_continuacao"): posicao = cena.ajustar_posicao_continuacao(posicao)
			if posicao.is_finite(): jogador.global_position = posicao
		jogador.velocity = Vector2.ZERO
		if jogador.camera != null: jogador.camera.reset_smoothing()
