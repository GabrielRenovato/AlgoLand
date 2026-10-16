extends SceneTree

# Rodar: godot --headless --path . --script res://testes/teste_defesa.gd
# Aparar e escudada do jogador (codigo/jogador/defesa_jogador.gd): segurar a guarda (pose da página 1 dos pacotes de combate),
# aparo perfeito (sem dano, empurra e atordoa, devolve estamina), bloqueio (dano reduzido, custa estamina), guarda quebrada,
# golpe pelas costas, contra-ataque de escudada com espada e escudo (quadros do shield bash, dano e atordoamento), e o
# atordoamento dos inimigos (parados, sem dano de contato; chefes não atordoam).
# ATENCAO: carrega a cena de jogo e equipa itens (grava user://inventario.json); faça backup do user:// antes.

const CAMINHO_PROGRESSO := "user://teste_defesa_progresso.json"
const CAMINHO_FAZENDA := "user://teste_defesa_fazenda.json"

var _falhas: int = 0
var _cena: Node
var _jogador: Node2D
var _inventario: Node
var _defesa: Node

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

func _fisica(n: int) -> void:
	for i in n:
		await physics_frame

func _ms(ms: int) -> void:
	await create_timer(ms / 1000.0).timeout

func _limpar_inimigos() -> void:
	for inimigo in get_nodes_in_group("enemy"):
		inimigo.queue_free()
	await _quadros(2)

# Slime parado (sem física, para não perseguir nem dar dano de contato sozinho) na frente do jogador
func _inimigo_em(deslocamento: Vector2, fisica := false) -> Node2D:
	var inimigo: Node2D = load("res://cenas/inimigos/slime.tscn").instantiate()
	_cena.add_child(inimigo)
	inimigo.global_position = _jogador.global_position + deslocamento
	inimigo.vida = 500
	if not fisica:
		inimigo.set_physics_process(false)
	return inimigo

func _soltar_tudo() -> void:
	for acao in ["aparar", "move_up", "move_down", "move_left", "move_right", "rolar", "attack"]:
		Input.action_release(acao)

# Reinicia o estado entre os casos: sem guarda, vida cheia, estamina cheia, sem invulnerabilidade
func _zerar() -> void:
	_soltar_tudo()
	_defesa.cancelar()
	_defesa._livre_ate_ms = 0
	_jogador.hp_atual = _jogador.estatisticas.hp_maximo
	_jogador.stamina = _jogador.stamina_maxima
	_jogador.invulneravel = false
	_jogador.temporizador_invul = 0.0
	_jogador.velocity = Vector2.ZERO
	_jogador.temporizador_knockback = 0.0

# Levanta a guarda virada para `dir` e espera uns quadros
func _guardar(dir: Vector2) -> void:
	_soltar_tudo()
	await _ms(350)   # recarga ao soltar
	_jogador._direcao_ataque = dir
	_jogador.invulneravel = false
	_jogador.temporizador_invul = 0.0
	Input.action_press("aparar")
	await _fisica(3)

func _rodar() -> void:
	if ProjectSettings.get_setting("application/config/name") != "AlgoLand testes Carrasco":
		push_error("Execute com saves isolados.")
		quit(1)
		return
	await process_frame
	var progresso = root.get_node("Progresso")
	progresso.caminho_save = CAMINHO_PROGRESSO
	progresso.apagar()
	var fazenda = root.get_node("Fazenda")
	fazenda.caminho_save = CAMINHO_FAZENDA
	fazenda.apagar()
	_inventario = root.get_node("InventarioJogador")
	_inventario.limpar()
	_inventario.criar_itens_iniciais()
	_cena = load("res://cenas/cenario.tscn").instantiate()
	root.add_child(_cena)
	current_scene = _cena
	await _quadros(10)
	await _ms(200)
	_jogador = _cena.get_node("Jogador")
	_defesa = _jogador.get_node("Defesa")
	_cena.get_node("enemySpawner/GerenciadorOndas").parar_ondas()
	await _limpar_inimigos()

	# --- sem arma: não levanta a guarda
	# O save de aparência do projeto de teste pode ter flags de uma arma anterior.
	_jogador.troca_sem_pose = true
	_jogador.desequipar_espada()
	_jogador.desequipar_lanca()
	_jogador.desequipar_arco()
	_jogador.desequipar_escudo()
	_jogador.troca_sem_pose = false
	Input.action_press("aparar")
	await _fisica(4)
	_verificar("desarmado: aparar não faz nada", _defesa.estado == _defesa.Estado.LIVRE and not _jogador.no_reacao.visible, "estado=%d" % _defesa.estado)
	_soltar_tudo()

	# --- espada e escudo
	_inventario.equipar(_inventario.buscar_por_tipo("espada_basica"))
	_inventario.equipar(_inventario.buscar_por_tipo("escudo_basico"))
	await _quadros(5)
	_verificar("espada e escudo equipados", _jogador.usando_espada and _jogador.usando_escudo, "")
	_zerar()
	_verificar("sem apertar o botão a guarda não sobe", _defesa.estado == _defesa.Estado.LIVRE, "")

	# guarda: pose, estamina, parado
	var stamina_antes: float = _jogador.stamina
	await _guardar(Vector2.RIGHT)
	_verificar("segurar o botão levanta a guarda", _defesa.estado == _defesa.Estado.GUARDA and _defesa.em_guarda(), "estado=%d" % _defesa.estado)
	_verificar("a pose de aparar aparece e esconde o corpo normal", _jogador.no_reacao.visible and not _jogador.get_node("CompositeSprites/BaseSprites").visible, "")
	_verificar("pose na coluna 3, linha da direita (quadro 19)", _jogador.no_reacao._corpo.frame == 2 * 8 + 3, "quadro=%d" % _jogador.no_reacao._corpo.frame)
	_verificar("entrar na guarda gasta estamina", _jogador.stamina < stamina_antes - _defesa.CUSTO_INICIAL + 1.0, "antes=%.1f agora=%.1f" % [stamina_antes, _jogador.stamina])
	_verificar("a guarda aponta para a direita", _defesa.direcao_guarda == Vector2.RIGHT, str(_defesa.direcao_guarda))
	_verificar("não anda segurando a guarda", _jogador.velocity.length() < 5.0, str(_jogador.velocity))
	# girar com as setas
	Input.action_press("move_up")
	await _fisica(3)
	_verificar("as setas giram a guarda (para cima, quadro 11) sem andar",
			_defesa.direcao_guarda == Vector2.UP and _jogador.no_reacao._corpo.frame == 1 * 8 + 3 and _jogador.velocity.length() < 5.0,
			"dir=%s quadro=%d" % [_defesa.direcao_guarda, _jogador.no_reacao._corpo.frame])
	Input.action_release("move_up")
	# soltar
	Input.action_release("aparar")
	await _fisica(3)
	_verificar("soltar o botão baixa a guarda e some a pose", _defesa.estado == _defesa.Estado.LIVRE and not _jogador.no_reacao.visible
			and _jogador.get_node("CompositeSprites/BaseSprites").visible, "")

	# --- aparo perfeito + escudada
	_zerar()
	await _limpar_inimigos()
	var alvo := _inimigo_em(Vector2(22, 0))
	await _guardar(Vector2.RIGHT)
	var hp := _jogador.hp_atual as int
	var stamina_pre: float = _jogador.stamina
	_jogador.receber_dano(10, Vector2(-150, 0))
	_verificar("aparo perfeito (golpe logo ao levantar a guarda): sem dano", _jogador.hp_atual == hp, "hp %d -> %d" % [hp, _jogador.hp_atual])
	_verificar("aparo perfeito devolve estamina", _jogador.stamina > stamina_pre + 5.0, "%.1f -> %.1f" % [stamina_pre, _jogador.stamina])
	_verificar("aparo perfeito deixa invulnerável um instante", _jogador.invulneravel, "")
	_verificar("com espada e escudo vira contra-ataque", _defesa.estado == _defesa.Estado.CONTRA, "estado=%d" % _defesa.estado)
	_verificar("quem estava na frente fica atordoado", alvo.esta_atordoado(), "")
	var vida_alvo: int = alvo.vida
	await _ms(180)
	_verificar("depois da pausa começa a escudada", _defesa.estado == _defesa.Estado.ESCUDADA and _jogador._esta_atacando, "estado=%d" % _defesa.estado)
	_verificar("escudada mostra a animação de ataque da espada e esconde o corpo normal",
			_jogador.corpo_espada_escudo_ataque.visible and _jogador.escudo_ataque.visible and _jogador.braco_espada_ataque.visible
			and not _jogador.sprite_corpo.visible and not _jogador.no_reacao.visible, "")
	var quadro_certo: bool = _jogador.corpo_espada_escudo_ataque.frame >= 52 and _jogador.corpo_espada_escudo_ataque.frame <= 55
	_verificar("quadros do shield bash para a direita (52 a 55)", quadro_certo, "quadro=%d" % _jogador.corpo_espada_escudo_ataque.frame)
	_verificar("as camadas ficam sincronizadas no mesmo quadro", _jogador.braco_espada_ataque.frame == _jogador.corpo_espada_escudo_ataque.frame
			and _jogador.escudo_ataque.frame == _jogador.corpo_espada_escudo_ataque.frame and _jogador.roupa_ataque.frame == _jogador.corpo_espada_escudo_ataque.frame
			and _jogador.cabelo_ataque.frame == _jogador.corpo_espada_escudo_ataque.frame, "")
	_verificar("não anda nem ataca durante a escudada", _jogador.velocity.length() < 5.0, "")
	await _ms(500)
	_verificar("a escudada machuca o inimigo e o atordoa", alvo.vida < vida_alvo and alvo.esta_atordoado(), "vida %d -> %d" % [vida_alvo, alvo.vida])
	_verificar("acabou: livre, sprites normais de volta", _defesa.estado == _defesa.Estado.LIVRE and not _jogador._esta_atacando
			and _jogador.sprite_corpo.visible and not _jogador.corpo_espada_escudo_ataque.visible, "estado=%d" % _defesa.estado)
	_soltar_tudo()
	alvo.queue_free()

	# --- escudada em todas as direções: quadros certos por linha
	for dados in [[Vector2.DOWN, 36, 39], [Vector2.UP, 44, 47], [Vector2.LEFT, 60, 63]]:
		_zerar()
		await _limpar_inimigos()
		await _guardar(dados[0])
		_jogador.receber_dano(1, -dados[0] * 150.0)
		await _ms(180)
		var q: int = _jogador.corpo_espada_escudo_ataque.frame
		_verificar("escudada para %s usa os quadros %d a %d" % [dados[0], dados[1], dados[2]], _defesa.estado == _defesa.Estado.ESCUDADA and q >= dados[1] and q <= dados[2], "quadro=%d estado=%d" % [q, _defesa.estado])
		await _ms(500)
	_zerar()

	# --- bloqueio depois da janela do aparo perfeito
	await _guardar(Vector2.RIGHT)
	await _ms(300)
	var stamina_b: float = _jogador.stamina
	hp = _jogador.hp_atual
	_jogador.receber_dano(20, Vector2(-150, 0))
	var perda_bloqueio: int = hp - _jogador.hp_atual
	_verificar("depois da janela o golpe é bloqueado: leva dano, mas pouco", perda_bloqueio >= 1, "perda=%d" % perda_bloqueio)
	_verificar("bloqueio gasta estamina", _jogador.stamina < stamina_b - 5.0, "%.1f -> %.1f" % [stamina_b, _jogador.stamina])
	_verificar("continua em guarda depois de bloquear (sem pose de ferido)", _defesa.estado == _defesa.Estado.GUARDA and _jogador.no_reacao.visible
			and _jogador.no_reacao._sequencia.size() > 0 and int(_jogador.no_reacao._sequencia[0][0]) == 3, "")
	# o mesmo golpe sem guarda
	_zerar()
	hp = _jogador.hp_atual
	_jogador.receber_dano(20, Vector2(-150, 0))
	var perda_livre: int = hp - _jogador.hp_atual
	_verificar("sem guarda o mesmo golpe machuca mais", perda_livre > perda_bloqueio, "livre=%d bloqueio=%d" % [perda_livre, perda_bloqueio])

	# --- golpe pelas costas e pelo lado
	_zerar()
	await _guardar(Vector2.RIGHT)
	hp = _jogador.hp_atual
	_jogador.receber_dano(20, Vector2(150, 0))   # o atacante está à esquerda, a guarda aponta para a direita
	_verificar("pelas costas a guarda não vale: dano inteiro", hp - _jogador.hp_atual == perda_livre, "perda=%d esperado=%d" % [hp - _jogador.hp_atual, perda_livre])
	_verificar("e a guarda cai", _defesa.estado == _defesa.Estado.LIVRE, "estado=%d" % _defesa.estado)
	_zerar()
	await _guardar(Vector2.RIGHT)
	hp = _jogador.hp_atual
	_jogador.receber_dano(20, Vector2(0, 150))   # o atacante está acima
	_verificar("pelo lado (90 graus) também não vale", hp - _jogador.hp_atual == perda_livre, "perda=%d" % (hp - _jogador.hp_atual))

	# --- guarda quebrada
	_zerar()
	_jogador.stamina = 12.0
	await _guardar(Vector2.RIGHT)
	await _ms(300)
	_jogador.stamina = 3.0
	hp = _jogador.hp_atual
	_jogador.receber_dano(40, Vector2(-150, 0))
	_verificar("sem estamina para segurar o golpe a guarda quebra: dano inteiro e guarda baixa", _defesa.estado == _defesa.Estado.LIVRE
			and hp - _jogador.hp_atual > perda_bloqueio, "estado=%d perda=%d" % [_defesa.estado, hp - _jogador.hp_atual])
	_soltar_tudo()
	await _ms(100)
	Input.action_press("aparar")
	await _fisica(3)
	_verificar("logo depois de quebrar não levanta a guarda de novo (recarga)", _defesa.estado == _defesa.Estado.LIVRE, "")
	_soltar_tudo()

	# --- guarda segurada gasta estamina aos poucos e esgota
	_zerar()
	_jogador.stamina = 14.0
	await _guardar(Vector2.RIGHT)
	await _ms(1500)
	_verificar("segurar a guarda sem parar esgota a estamina e baixa a guarda", _defesa.estado == _defesa.Estado.LIVRE and _jogador.stamina < 5.0, "estado=%d stamina=%.1f" % [_defesa.estado, _jogador.stamina])
	_soltar_tudo()

	# --- sem estamina para entrar
	_zerar()
	await _ms(350)
	_jogador.stamina = 3.0
	Input.action_press("aparar")
	await _fisica(3)
	_verificar("sem estamina para entrar não levanta a guarda", _defesa.estado == _defesa.Estado.LIVRE, "")
	_soltar_tudo()

	# --- rolar cancela a guarda
	_zerar()
	await _guardar(Vector2.RIGHT)
	Input.action_press("rolar")
	await _fisica(3)
	Input.action_release("rolar")
	_verificar("rolar com a guarda levantada cancela a guarda e faz o dash", _defesa.estado == _defesa.Estado.LIVRE and _jogador.esta_em_dash, "estado=%d dash=%s" % [_defesa.estado, _jogador.esta_em_dash])
	await _ms(900)
	_soltar_tudo()

	# --- tela aberta cancela
	_zerar()
	await _guardar(Vector2.RIGHT)
	_jogador.movimento_habilitado = false
	await _fisica(3)
	_verificar("com uma tela aberta (movimento desligado) a guarda cai", _defesa.estado == _defesa.Estado.LIVRE and not _jogador.no_reacao.visible, "")
	_jogador.movimento_habilitado = true
	_soltar_tudo()

	# --- na fazenda e sentado não aparece
	_jogador.modo_fazenda = true
	_zerar()
	await _ms(350)
	Input.action_press("aparar")
	await _fisica(3)
	_verificar("em modo fazenda não tem guarda", _defesa.estado == _defesa.Estado.LIVRE, "")
	_soltar_tudo()
	_jogador.modo_fazenda = false

	# --- espada sem escudo: aparo perfeito sem contra-ataque
	_inventario.desequipar("escudo")
	await _quadros(5)
	_verificar("escudo desequipado", not _jogador.usando_escudo, "")
	_zerar()
	await _guardar(Vector2.RIGHT)
	hp = _jogador.hp_atual
	_jogador.receber_dano(10, Vector2(-150, 0))
	_verificar("sem escudo: aparo perfeito anula o dano mas não tem escudada", _jogador.hp_atual == hp and _defesa.estado == _defesa.Estado.GUARDA, "estado=%d" % _defesa.estado)
	_soltar_tudo()

	# --- lança
	_inventario.equipar(_inventario.buscar_por_tipo("lanca_basica"))
	await _quadros(5)
	_verificar("lança equipada", _jogador.usando_lanca and not _jogador.usando_espada, "")
	_zerar()
	await _guardar(Vector2.DOWN)
	_verificar("com a lança também levanta a guarda (pose da lança, linha de baixo, quadro 3)", _defesa.estado == _defesa.Estado.GUARDA and _jogador.no_reacao.visible
			and _jogador.no_reacao._corpo.frame == 3, "quadro=%d" % _jogador.no_reacao._corpo.frame)
	hp = _jogador.hp_atual
	_jogador.receber_dano(10, Vector2(0, -150))
	_verificar("lança: aparo perfeito sem dano e sem escudada", _jogador.hp_atual == hp and _defesa.estado == _defesa.Estado.GUARDA, "estado=%d" % _defesa.estado)
	_soltar_tudo()

	# --- atordoamento dos inimigos
	await _limpar_inimigos()
	_zerar()
	var parado := _inimigo_em(Vector2(-150, 30), true)
	var livre := _inimigo_em(Vector2(-150, -30), true)
	await _fisica(3)
	parado.atordoar(0.6)
	var p0: Vector2 = parado.global_position
	var l0: Vector2 = livre.global_position
	await _ms(300)
	_verificar("inimigo atordoado fica parado", parado.global_position.distance_to(p0) < 2.0, "andou %.1f" % parado.global_position.distance_to(p0))
	_verificar("o inimigo solto continua andando para o jogador", livre.global_position.distance_to(l0) > 4.0, "andou %.1f" % livre.global_position.distance_to(l0))
	_verificar("atordoado ganha o tom amarelado", parado.sprite.modulate.r > 0.9 and parado.sprite.modulate.b < 0.8, str(parado.sprite.modulate))
	await _ms(600)
	_verificar("passada a duração volta a andar", not parado.esta_atordoado() and parado.global_position.distance_to(p0) > 3.0,
			"atordoado=%s andou=%.1f" % [parado.esta_atordoado(), parado.global_position.distance_to(p0)])
	# sem dano de contato enquanto atordoado
	await _limpar_inimigos()
	_zerar()
	var colado := _inimigo_em(Vector2(4, 0), true)
	await _fisica(2)
	colado.atordoar(0.8)
	hp = _jogador.hp_atual
	await _ms(500)
	_verificar("atordoado não dá dano de contato", _jogador.hp_atual == hp, "hp %d -> %d" % [hp, _jogador.hp_atual])
	# chefe não atordoa
	var chefe := _inimigo_em(Vector2(150, 0))
	chefe.eh_chefe = true
	chefe.atordoar(1.0)
	_verificar("chefe não atordoa", not chefe.esta_atordoado(), "")
	var golem: Node2D = load("res://cenas/inimigos/golem.tscn").instantiate()
	_cena.add_child(golem)
	golem.set_physics_process(false)
	golem.atordoar(1.0)
	_verificar("golem não atordoa", not golem.esta_atordoado(), "")
	golem.queue_free()
	await _limpar_inimigos()

	# --- morrer cancela a guarda
	_inventario.equipar(_inventario.buscar_por_tipo("espada_basica"))
	await _quadros(5)
	_zerar()
	await _guardar(Vector2.RIGHT)
	_jogador.hp_atual = 1
	_jogador.receber_dano(999, Vector2(150, 0))
	await _quadros(3)
	_verificar("morrer derruba a guarda", _jogador.estaMorto and _defesa.estado == _defesa.Estado.LIVRE and not _jogador.no_reacao.visible, "")
	_soltar_tudo()

	progresso.apagar()
	fazenda.apagar()
	print("--- teste_defesa: ", "TUDO OK" if _falhas == 0 else "%d FALHAS" % _falhas)
	print("FALHAS: ", _falhas)
	quit(1 if _falhas > 0 else 0)
