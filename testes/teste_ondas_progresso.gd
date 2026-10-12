extends SceneTree

# Rodar: godot --headless --path . --script res://testes/teste_ondas_progresso.gd
# Joga uma onda de verdade (derrubando os inimigos) e confere o registro de abates, ouro e ondas no Progresso

const CAMINHO_PROGRESSO := "user://teste_ondas_progresso.json"

var _falhas: int = 0

func _initialize() -> void:
	_rodar()

func _verificar(nome: String, condicao: bool, detalhe: String = "") -> void:
	if condicao:
		print("OK ", nome)
	else:
		_falhas += 1
		print("FALHA ", nome, ": ", detalhe)

func _rodar() -> void:
	# O _ready dos autoloads (Progresso.carregar) roda no primeiro quadro; espera para não apagar os dados do teste
	await process_frame
	var progresso = root.get_node("Progresso")
	progresso.caminho_save = CAMINHO_PROGRESSO
	# O clima do mundo fica no autoload Fazenda (as ondas o mudam): arquivo de teste, sem o save real
	var fazenda_isolada = root.get_node("Fazenda")
	fazenda_isolada.caminho_save = "user://teste_ondas_progresso_fazenda.json"
	fazenda_isolada.apagar()
	progresso.melhorias = {"saque": 5}
	var cena: Node = load("res://cenas/cenario.tscn").instantiate()
	root.add_child(cena)
	current_scene = cena
	await create_timer(0.3).timeout
	var gerenciador: Node = cena.get_node("enemySpawner/GerenciadorOndas")
	var dados_jogo = root.get_node("DadosJogo")
	_verificar("partida ativa", progresso.partida_ativa and progresso.abates == 0, "")
	dados_jogo.moedas = 0
	progresso.ouro_ganho = 0
	gerenciador.iniciar_onda()
	await create_timer(1.0).timeout
	_verificar("onda iniciada registrada", progresso.onda_comecou and progresso.onda_maxima == 1, "onda_maxima=%d" % progresso.onda_maxima)
	var total: int = gerenciador.total_inimigos_onda
	var tentativas := 0
	while gerenciador.onda_em_andamento and tentativas < 60:
		for inimigo in get_nodes_in_group("enemy"):
			if is_instance_valid(inimigo) and not inimigo.esta_morto:
				inimigo.receber_dano(99999, Vector2.ZERO)
		await create_timer(0.3).timeout
		tentativas += 1
	_verificar("onda terminou", not gerenciador.onda_em_andamento, "tentativas=%d" % tentativas)
	_verificar("abates registrados", progresso.abates == total and total > 0, "abates=%d total=%d" % [progresso.abates, total])
	_verificar("onda concluida registrada", progresso.ondas_concluidas == 1 and progresso.onda_maxima == 1 and progresso.chefes == 0, "ondas=%d" % progresso.ondas_concluidas)
	# onda 1: 4 inimigos x 3 moedas, com saque nivel 5 (+50%): 4,5 por abate acumulando o resto; mais a recompensa final (ouro_fim_onda)
	var esperado_abates := int(total * 3 * 1.5)
	var final_onda: int = gerenciador.ouro_fim_onda(1)
	_verificar("saque nivel 5 soma 50% no ouro por abate", dados_jogo.moedas == esperado_abates + final_onda, "moedas=%d esperado=%d" % [dados_jogo.moedas, esperado_abates + final_onda])
	_verificar("ouro ganho acompanha as moedas", progresso.ouro_ganho == dados_jogo.moedas, "ouro_ganho=%d moedas=%d" % [progresso.ouro_ganho, dados_jogo.moedas])
	_verificar("onda seguinte e a 2", gerenciador.onda_atual == 2, "onda=%d" % gerenciador.onda_atual)
	if FileAccess.file_exists(CAMINHO_PROGRESSO):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CAMINHO_PROGRESSO))
	if FileAccess.file_exists("user://teste_ondas_progresso_fazenda.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://teste_ondas_progresso_fazenda.json"))
	quit(_falhas)
