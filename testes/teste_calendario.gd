extends SceneTree

# Rodar: godot --headless --path . --script res://testes/teste_calendario.gd
# Confere o calendário de dias (autoload Calendario): dia -> estação/ano/data, dormir (avança, salva, sinais), salvar/carregar,
# arquivo ausente/corrompido, apagar, a estação seguindo o calendário na fazenda, a data no HUD e o "novo jogo" apagando tudo.
# Usa arquivos de teste em user:// (apagados no final); a cena da fazenda não grava inventário nem progresso.

const CAMINHO := "user://teste_calendario.json"
const CAMINHO_PROGRESSO := "user://teste_calendario_progresso.json"
## Dormir (Calendario.dormir) faz o autoload Fazenda avancar o dia e salvar: arquivo de teste proprio
const CAMINHO_FAZENDA := "user://teste_calendario_fazenda.json"

var _falhas: int = 0
var _cal: Node
var _fazenda: Node
var _sinais_dia: Array = []
var _sinais_estacao: Array = []

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

## Relógio do HUD: coluna da folha por hora (acompanha as cores do ciclo de iluminacao.gd) e texto da hora
func _testar_relogio() -> void:
	var hud_script = load("res://codigo/ui/hud.gd")
	var casos := [[0.0, 4], [3.0, 4], [5.0, 5], [8.0, 0], [12.0, 1], [17.0, 2], [20.0, 3], [22.5, 4], [23.99, 4]]
	var ok := true
	for caso in casos:
		if hud_script.coluna_relogio(caso[0]) != caso[1]:
			ok = false
			print("  hora ", caso[0], " coluna ", hud_script.coluna_relogio(caso[0]), " esperada ", caso[1])
	_verificar("relogio: coluna da folha por hora (madrugada, manha, dia, tarde, anoitecer, noite)", ok, "")
	_verificar("relogio: texto da hora de 10 em 10 minutos", hud_script.texto_hora(6.0) == "06:00" and hud_script.texto_hora(13.58) == "13:30" and hud_script.texto_hora(23.99) == "23:50" and hud_script.texto_hora(0.1) == "00:00", "%s %s %s" % [hud_script.texto_hora(6.0), hud_script.texto_hora(13.58), hud_script.texto_hora(23.99)])
	_verificar("relogio: uma linha da folha por estacao (verde, verde, outono, neve)", hud_script.LINHA_RELOGIO_POR_ESTACAO == [0, 0, 1, 2], "")

func _rodar() -> void:
	await process_frame
	_cal = root.get_node("Calendario")
	var caminho_original: String = _cal.caminho_save
	_cal.caminho_save = CAMINHO
	_cal.apagar()
	_fazenda = root.get_node("Fazenda")
	var caminho_fazenda: String = _fazenda.caminho_save
	_fazenda.caminho_save = CAMINHO_FAZENDA
	_fazenda.apagar()
	_cal.dia_passou.connect(func(d): _sinais_dia.append(d))
	_cal.estacao_mudou.connect(func(e): _sinais_estacao.append(e))
	_testar_constantes_e_mapa()
	_testar_data()
	_testar_dormir()
	_testar_salvar_carregar()
	_testar_arquivos_invalidos()
	_testar_apagar()
	_testar_relogio()
	await _testar_fazenda_segue_calendario()
	await _testar_novo_jogo()
	_cal.apagar()
	_cal.caminho_save = caminho_original
	await _quadros(2)   # grava o que ficou agendado ainda no arquivo de teste
	_fazenda.apagar()
	if FileAccess.file_exists(CAMINHO_FAZENDA):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CAMINHO_FAZENDA))
	_fazenda.caminho_save = caminho_fazenda
	print("FALHAS: ", _falhas)
	quit(_falhas)

func _testar_constantes_e_mapa() -> void:
	_verificar("dia inicial e 1", _cal.dia == 1, "dia=%d" % _cal.dia)
	_verificar("30 dias por estacao", _cal.DIAS_POR_ESTACAO == 30, "")
	var esperado := {1: 0, 30: 0, 31: 1, 60: 1, 61: 2, 90: 2, 91: 3, 120: 3, 121: 0, 150: 0, 151: 1, 240: 3, 241: 0}
	var ruins := []
	for dia in esperado:
		if _cal.estacao(dia) != esperado[dia]:
			ruins.append("%d->%d" % [dia, _cal.estacao(dia)])
	_verificar("estacao() por dia (primavera 1-30, verao 31-60, outono 61-90, inverno 91-120, depois repete)", ruins.is_empty(), str(ruins))
	var anos := {1: 1, 120: 1, 121: 2, 240: 2, 241: 3}
	var anos_ruins := []
	for dia in anos:
		if _cal.ano(dia) != anos[dia]:
			anos_ruins.append("%d->%d" % [dia, _cal.ano(dia)])
	_verificar("ano() por dia (120 dias por ano)", anos_ruins.is_empty(), str(anos_ruins))

func _testar_data() -> void:
	_cal.dia = 3
	_verificar("data do dia 3", _cal.texto_data() == "PRIMAVERA - DIA 3", _cal.texto_data())
	_cal.dia = 31
	_verificar("data do dia 31: primeiro dia do verao", _cal.texto_data() == "VERAO - DIA 1", _cal.texto_data())
	_cal.dia = 120
	_verificar("data do dia 120: ultimo dia do inverno", _cal.texto_data() == "INVERNO - DIA 30", _cal.texto_data())
	_cal.dia = 121
	_verificar("data do dia 121: volta a primavera (ano 2)", _cal.texto_data() == "PRIMAVERA - DIA 1" and _cal.ano() == 2, _cal.texto_data())
	_verificar("estacao do dia 61", _cal.estacao(61) == 2, "")
	_cal.dia = 1

func _testar_dormir() -> void:
	_cal.apagar()
	_sinais_dia.clear()
	_sinais_estacao.clear()
	_cal.dormir()
	_verificar("dormir avanca para o dia 2", _cal.dia == 2, "dia=%d" % _cal.dia)
	_verificar("dormir emite dia_passou(2)", _sinais_dia == [2], str(_sinais_dia))
	_verificar("dormir no meio da estacao nao emite estacao_mudou", _sinais_estacao.is_empty(), str(_sinais_estacao))
	_verificar("dormir salva o arquivo", FileAccess.file_exists(CAMINHO), "")
	# virada de estacao: ultimo dia da primavera -> verao (estacao_mudou antes de dia_passou)
	_cal.dia = 30
	_sinais_dia.clear()
	_sinais_estacao.clear()
	var ordem: Array = []
	var a := func(_e): ordem.append("estacao")
	var b := func(_d): ordem.append("dia")
	_cal.estacao_mudou.connect(a)
	_cal.dia_passou.connect(b)
	_cal.dormir()
	_cal.estacao_mudou.disconnect(a)
	_cal.dia_passou.disconnect(b)
	_verificar("dormir no dia 30: dia 31, verao", _cal.dia == 31 and _cal.estacao() == 1, "dia=%d" % _cal.dia)
	_verificar("estacao_mudou(1) e dia_passou(31)", _sinais_estacao == [1] and _sinais_dia == [31], "%s %s" % [_sinais_estacao, _sinais_dia])
	_verificar("estacao_mudou vem antes de dia_passou", ordem == ["estacao", "dia"], str(ordem))
	# varias noites: estacao_mudou so nas viradas (31->60 nenhuma; 60 -> 61 uma)
	_sinais_estacao.clear()
	for i in 29:
		_cal.dormir()
	_verificar("dias 32..60: nenhuma virada", _cal.dia == 60 and _sinais_estacao.is_empty(), "dia=%d %s" % [_cal.dia, _sinais_estacao])
	_cal.dormir()
	_verificar("dia 61: outono", _cal.estacao() == 2 and _sinais_estacao == [2], str(_sinais_estacao))
	# ano novo: do dia 120 para o 121 volta a primavera
	_cal.dia = 120
	_sinais_estacao.clear()
	_cal.dormir()
	_verificar("dia 121: primavera do ano 2", _cal.estacao() == 0 and _cal.ano() == 2 and _sinais_estacao == [0], "%s" % _sinais_estacao)

func _testar_salvar_carregar() -> void:
	_cal.dia = 12
	_cal.salvar()
	_cal.dia = 1
	_verificar("carregar devolve true", _cal.carregar(), "")
	_verificar("carregar restaura o dia salvo (12)", _cal.dia == 12, "dia=%d" % _cal.dia)
	# dormir persiste: dia 12 -> 13 salvo
	_cal.dormir()
	_cal.dia = 1
	_cal.carregar()
	_verificar("o dia depois de dormir fica salvo (13)", _cal.dia == 13, "dia=%d" % _cal.dia)
	var texto := FileAccess.get_file_as_string(CAMINHO)
	var dados = JSON.parse_string(texto)
	_verificar("arquivo e JSON com a chave dia", dados is Dictionary and int(dados.get("dia", 0)) == 13, texto)

func _testar_arquivos_invalidos() -> void:
	var arquivo := FileAccess.open(CAMINHO, FileAccess.WRITE)
	arquivo.store_string("isto nao e json {{")
	arquivo.close()
	_cal.dia = 9
	_verificar("arquivo corrompido: carregar devolve false e volta ao dia 1", not _cal.carregar() and _cal.dia == 1, "dia=%d" % _cal.dia)
	arquivo = FileAccess.open(CAMINHO, FileAccess.WRITE)
	arquivo.store_string(JSON.stringify({"dia": -5}))
	arquivo.close()
	_cal.carregar()
	_verificar("dia invalido (negativo) vira 1", _cal.dia == 1, "dia=%d" % _cal.dia)
	arquivo = FileAccess.open(CAMINHO, FileAccess.WRITE)
	arquivo.store_string(JSON.stringify({"outra": 1}))
	arquivo.close()
	_cal.carregar()
	_verificar("sem a chave dia: dia 1", _cal.dia == 1, "dia=%d" % _cal.dia)

func _testar_apagar() -> void:
	_cal.dia = 20
	_cal.salvar()
	_cal.apagar()
	_verificar("apagar volta ao dia 1", _cal.dia == 1, "dia=%d" % _cal.dia)
	_verificar("apagar remove o arquivo", not FileAccess.file_exists(CAMINHO), "")
	_verificar("carregar sem arquivo: false e dia 1", not _cal.carregar() and _cal.dia == 1, "")

# Na fazenda a estacao visual e a do calendario; dormir no ultimo dia troca com fade; a data aparece no HUD
func _testar_fazenda_segue_calendario() -> void:
	var progresso = root.get_node("Progresso")
	var caminho_progresso: String = progresso.caminho_save
	progresso.caminho_save = CAMINHO_PROGRESSO
	progresso.apagar()
	_cal.apagar()
	_cal.dia = 61  # outono
	var cena: Node = load("res://cenas/fazenda.tscn").instantiate()
	root.add_child(cena)
	current_scene = cena
	await _quadros(10)
	var est: Node = cena.get_node("Terrains/Estacoes")
	_verificar("fazenda abre no outono (dia 61)", est.estacao_atual == 2, "estacao=%d" % est.estacao_atual)
	var hud: Node = get_nodes_in_group("hud")[0]
	_verificar("HUD mostra a data (SEX  OUTONO - DIA 1)", hud.rotulo_data.text == "SEX  OUTONO - DIA 1", hud.rotulo_data.text)
	_cal.dia = 90
	_cal.dormir()
	await create_timer(est.DURACAO_FADE_SAIDA + est.ATRASO_AVISO + 0.5).timeout
	_verificar("dormir no dia 90: inverno na fazenda", est.estacao_atual == 3, "estacao=%d" % est.estacao_atual)
	_verificar("HUD atualiza a data (DOM  INVERNO - DIA 1)", hud.rotulo_data.text == "DOM  INVERNO - DIA 1", hud.rotulo_data.text)
	_verificar("clima de inverno na fazenda: neve", est.meteorologia.eh_neve(est.meteorologia.clima_atual), "clima=%d" % est.meteorologia.clima_atual)
	# sem gerenciador: o HUD esconde o quadro da onda (guarda o titulo da cena) e deixa so o relogio no canto
	_verificar("HUD da fazenda: titulo FAZENDA, sem linha de inimigos nem espera",
			hud.rotulo_onda.text == "FAZENDA" and not hud.linha_inimigos.visible and not hud.rotulo_espera.visible, "%s" % hud.rotulo_onda.text)
	_verificar("HUD da fazenda: sem quadro de onda, relogio visivel",
			not hud.painel_onda.visible and hud.relogio.is_visible_in_tree(), "painel=%s" % hud.painel_onda.visible)
	cena.queue_free()
	await _quadros(3)
	progresso.apagar()
	progresso.caminho_save = caminho_progresso

# "Novo jogo" (tela_inicial.gd) apaga tambem o calendario
func _testar_novo_jogo() -> void:
	var progresso = root.get_node("Progresso")
	var caminho_progresso: String = progresso.caminho_save
	progresso.caminho_save = CAMINHO_PROGRESSO
	_cal.dia = 40
	_cal.salvar()
	# um pedacinho de fazenda para o "novo jogo" apagar junto
	_fazenda.solo[Vector2i(18, 23)] = {"molhado": true, "planta": "cenoura", "dias": 1, "murcha": false}
	_fazenda.sementes["morango"] = 2
	_fazenda.colheita["batata"] = 3
	_fazenda.salvar()
	_verificar("fazenda salva antes do novo jogo", FileAccess.file_exists(CAMINHO_FAZENDA), "")
	var titulo: Node = load("res://cenas/inicio_do_jogo.tscn").instantiate()
	root.add_child(titulo)
	current_scene = titulo
	await _quadros(8)
	# Sem save de personagem, "Novo jogo" apaga direto (usa os caminhos de teste para nao tocar nos arquivos reais)
	titulo.caminho_save_personagem = "user://nao_existe_teste_cal_a.json"
	titulo.caminho_save_inventario = "user://nao_existe_teste_cal_b.json"
	_verificar("sem save de personagem de teste", not titulo.tem_save(), "")
	titulo.botao_novo_jogo.pressed.emit()
	await _quadros(2)
	_verificar("novo jogo: calendario volta ao dia 1", _cal.dia == 1, "dia=%d" % _cal.dia)
	_verificar("novo jogo: arquivo do calendario apagado", not FileAccess.file_exists(CAMINHO), "")
	_verificar("novo jogo: fazenda esvaziada e arquivo apagado", _fazenda.solo.is_empty() and _fazenda.sementes.is_empty() and _fazenda.colheita.is_empty() and not FileAccess.file_exists(CAMINHO_FAZENDA), "")
	_verificar("tela de titulo continua fixa no inverno", titulo.get_node("Cenario/Estacoes").estacao_atual == 3, "")
	titulo.queue_free()
	await _quadros(2)
	progresso.apagar()
	progresso.caminho_save = caminho_progresso
