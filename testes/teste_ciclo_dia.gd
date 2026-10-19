extends SceneTree

# Rodar: godot --headless --path . --script res://testes/teste_ciclo_dia.gd
# Ciclo do dia estilo Stardew (codigo/efeitos/iluminacao.gd): o dia vai das 06:00 as 02:00 (20 h) a 24 s reais por hora,
# passa da meia-noite, e as 02:00 o jogador apaga (Transicao.dormir: dia seguinte, 06:00). Em onda o relogio segura.
# Usa arquivos de teste para Calendario, Progresso e Fazenda. ATENCAO: dormir grava user://inventario.json (faca backup).

const CAMINHO_CALENDARIO := "user://teste_ciclo_calendario.json"
const CAMINHO_PROGRESSO := "user://teste_ciclo_progresso.json"
const CAMINHO_FAZENDA := "user://teste_ciclo_fazenda.json"

var _falhas: int = 0

func _initialize() -> void:
	_rodar()

func _verificar(nome: String, condicao: bool, detalhe: String = "") -> void:
	if condicao:
		print("OK ", nome)
	else:
		_falhas += 1
		print("FALHA ", nome, ": ", detalhe)

func _quadros(n: int) -> void:
	for i in n:
		await process_frame

# Espera ate `condicao` ficar verdadeira (ou `limite` s)
func _esperar(condicao: Callable, limite: float) -> bool:
	var fim := Time.get_ticks_msec() + int(limite * 1000.0)
	while Time.get_ticks_msec() < fim:
		if condicao.call():
			return true
		await process_frame
	return condicao.call()

func _rodar() -> void:
	await process_frame
	var calendario = root.get_node("Calendario")
	var progresso = root.get_node("Progresso")
	var fazenda = root.get_node("Fazenda")
	var transicao = root.get_node("Transicao")
	calendario.caminho_save = CAMINHO_CALENDARIO
	progresso.caminho_save = CAMINHO_PROGRESSO
	fazenda.caminho_save = CAMINHO_FAZENDA
	calendario.apagar()
	progresso.apagar()
	fazenda.apagar()
	transicao.limpar()

	# --- Ritmo: 24 s reais por hora (10 min do jogo a cada 4 s)
	var cena: Node = load("res://cenas/fazenda.tscn").instantiate()
	root.add_child(cena)
	current_scene = cena
	await _quadros(5)
	var luz: Node = get_nodes_in_group("iluminacao")[0]
	_verificar("ritmo padrao: 24 s reais por hora do jogo e o dia dura 20 h (06:00 a 02:00)", luz.segundos_reais_por_hora == 24.0 and luz.DURACAO_DIA_H == 20.0 and luz.HORA_DESPERTAR == 6.0, "")
	luz.definir_hora(8.0)
	var inicio := Time.get_ticks_msec()
	await _esperar(func(): return luz.hora >= 8.0 + 0.5, 20.0)
	var segundos := (Time.get_ticks_msec() - inicio) / 1000.0
	_verificar("meia hora do jogo leva ~12 s reais (24 s por hora)", absf(segundos - 12.0) < 1.0, "%.2f s" % segundos)
	_verificar("o dia todo (20 h) leva ~8 min reais", absf(luz.DURACAO_DIA_H * luz.segundos_reais_por_hora / 60.0 - 8.0) < 0.01, "")

	# --- Passa da meia-noite sem voltar o dia: 23:59 -> 00:0x e as horas decorridas seguem subindo
	luz.segundos_reais_por_hora = 1.0
	luz.definir_hora(23.9)
	var antes: float = luz.horas_decorridas
	await _esperar(func(): return luz.hora < 5.0, 3.0)
	_verificar("passa da meia-noite (hora volta a 0) e as horas decorridas continuam subindo (17,9 -> 18+)", luz.hora < 1.0 and luz.horas_decorridas > antes and luz.horas_decorridas >= 18.0,
			"hora=%.2f decorridas=%.2f" % [luz.hora, luz.horas_decorridas])
	_verificar("o relogio do HUD mostra a madrugada (00:00..)", get_nodes_in_group("hud")[0].texto_hora(luz.hora).begins_with("00:"), get_nodes_in_group("hud")[0].texto_hora(luz.hora))

	# --- 02:00: o jogador apaga, o dia seguinte comeca as 06:00
	var dia_antes: int = calendario.dia
	var jogador: Node = cena.get_node("Jogador")
	jogador.hp_atual = 10
	luz.segundos_reais_por_hora = 1.0
	luz.definir_hora(1.8)
	var fim_do_dia := {"n": 0}
	luz.fim_do_dia.connect(func(): fim_do_dia["n"] += 1)
	var dormiu := {"ok": false}
	transicao.dormiu.connect(func(): dormiu["ok"] = true)
	await _esperar(func(): return dormiu["ok"], 8.0)
	_verificar("as 02:00 o jogador apaga: dormir e chamado uma vez", fim_do_dia["n"] == 1 and dormiu["ok"], "n=%d" % fim_do_dia["n"])
	# O desmaio agora leva o jogador para a casa; a fazenda anterior foi liberada.
	cena = current_scene
	luz = cena.get_node("Iluminacao")
	jogador = cena.get_node("Jogador")
	_verificar("desmaio fora da cama acorda na casa", cena.scene_file_path == "res://cenas/casa.tscn", cena.scene_file_path)
	# (o relogio esta a 1 s por hora no teste: durante o fade ele ja andou um pouco depois das 06:00)
	_verificar("o dia seguinte comeca (calendario +1) e o relogio volta as 06:00", calendario.dia == dia_antes + 1 and luz.hora >= 6.0 and luz.hora < 8.5 and luz.horas_decorridas < 2.5,
			"dia=%d hora=%.2f dec=%.2f" % [calendario.dia, luz.hora, luz.horas_decorridas])
	_verificar("acorda curado e liberado", jogador.hp_atual == jogador.estatisticas.hp_maximo and jogador.movimento_habilitado, "hp=%d" % jogador.hp_atual)
	luz.segundos_reais_por_hora = 24.0
	cena.queue_free()
	await _quadros(3)

	# --- Durante uma onda o relogio NAO para: passa das 02:00 e so apaga quando a onda acaba
	transicao.limpar()
	var arena: Node = load("res://cenas/cenario.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	await _quadros(10)
	await create_timer(0.3).timeout
	var luz2: Node = get_nodes_in_group("iluminacao")[0]
	var gerenciador: Node = arena.get_node("enemySpawner/GerenciadorOndas")
	var dia_2: int = calendario.dia
	var tela_dormir := {"n": 0}
	luz2.fim_do_dia.connect(func(): tela_dormir["n"] += 1)
	gerenciador.onda_em_andamento = true
	luz2.segundos_reais_por_hora = 1.0
	luz2.definir_hora(1.8)
	await create_timer(1.6).timeout
	_verificar("em onda o relogio segue rolando depois das 02:00 (hora passa de 3h) mas nao apaga no combate", tela_dormir["n"] == 0 and calendario.dia == dia_2
			and luz2.horas_decorridas > 21.0 and luz2.hora > 3.0 and luz2.hora < 6.0, "n=%d hora=%.2f dec=%.2f" % [tela_dormir["n"], luz2.hora, luz2.horas_decorridas])
	luz2.segundos_reais_por_hora = 24.0
	gerenciador.onda_em_andamento = false
	var dormiu2 := {"ok": false}
	transicao.dormiu.connect(func(): dormiu2["ok"] = true)
	await _esperar(func(): return dormiu2["ok"], 8.0)
	arena = current_scene
	luz2 = arena.get_node("Iluminacao")
	_verificar("a onda acabou: apaga, passa o dia e volta as 06:00", tela_dormir["n"] == 1 and calendario.dia == dia_2 + 1 and luz2.hora >= 6.0 and luz2.hora < 8.5,
			"dia=%d hora=%.2f" % [calendario.dia, luz2.hora])
	arena.queue_free()
	await _quadros(3)

	calendario.apagar()
	progresso.apagar()
	fazenda.apagar()
	transicao.limpar()
	for caminho in [CAMINHO_CALENDARIO, CAMINHO_PROGRESSO, CAMINHO_FAZENDA]:
		if FileAccess.file_exists(caminho):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(caminho))
	print("FALHAS: ", _falhas)
	quit(_falhas)
