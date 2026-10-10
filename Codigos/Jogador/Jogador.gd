extends CharacterBody2D

# Preload do banco de dados de armas (nome: banco_dados_armas)
var banco_dados_armas = preload("res://Codigos/DadosLocais/Equipamentos.gd")
signal equipamento_alterado
@onready var estatisticas = preload("res://Codigos/Jogador/Status-do-jogador.gd").new()
var eh_arma_duas_maos: bool = false
@export var cor_cabelo: Color = Color(1, 1, 1)  # Branco como padrão
var ataques_bloqueados: bool = false
@export_category("Variáveis")
@export var _friccao: float = 0.3
@export var _aceleracao: float = 0.3
@export var _decaimento_knockback: float = 0.1
var nivel_escudo: int:
	get: return _nivel_no_modelo("escudo_basico")
var esta_forjando: bool = false
var id_escudo_atual: String = "escudo_basico"
var movimento_habilitado: bool = true

# Vitalidade: separando base e bônus
var vitalidade_base: int = 5              # Valor base de vitalidade
var bonus_vitalidade: int = 0             # Soma de todos os bônus de vitalidade
var vitalidade_atual: int = vitalidade_base  # Vitalidade total (base + bônus)

# Defesa: como não há um "base_defense" explícito, assumimos que estatisticas.defesa = soma dos bônus
var bonus_defesa: int = 0               # Soma de todos os bônus de defesa

@export var tipo_item_atual: String = ""  # "espada", "lanca", etc.
# >>> Escudo controlado separadamente <<<
@export var usando_escudo: bool = false
var ataque_enfileirado: bool = false
# Variável que controla o nível da arma (espada)
var nivel_espada: int:
	get: return _nivel_no_modelo("espada_basica")
var id_arma_atual: String = "espada_basica"
@export var usando_espada: bool = false

# Variáveis para controlar a lança
@export var usando_lanca: bool = false
var nivel_lanca: int:
	get: return _nivel_no_modelo("lanca_basica")
var id_lanca_atual: String = "lanca_basica"
var botao_ataque_pressionado: bool = false
const TIPOS_ARMADURA := {
	"cabeca_basica": "usando_cabeca",
	"armadura_basica": "usando_corpo",
	"luvas_basicas": "usando_luvas",
	"botas_basicas": "usando_botas",
}

# Evita eco: mudanças vindas do modelo não podem voltar para ele (e vice-versa)
var _sincronizando: bool = false
# Lido em _unhandled_input para que cliques consumidos pela GUI não ataquem
var _pedido_ataque: bool = false
@export_category("Objetos")
@export var _arvore_animacao: AnimationTree = null
@export var _temporizador: Timer = null  # Timer para controlar a duração de cada golpe

signal forja_finalizada

# ---------------------------
# BaseSprites
# ---------------------------
@onready var sprite_corpo = $CompositeSprites/BaseSprites/Corpo
@onready var sprite_cabelo = $CompositeSprites/BaseSprites/Cabelo
@onready var sprite_roupa = $CompositeSprites/BaseSprites/Roupa
@onready var sprite_espada = $CompositeSprites/BaseSprites/Braco
@onready var sprite_escudo = $CompositeSprites/BaseSprites/Escudo
@onready var sprite_lanca = $CompositeSprites/BaseSprites/Lanca

# Arrays exclusivos da Forja
var array_cabelo_forja: Array[Texture2D] = []
var array_roupa_forja: Array[Texture2D] = []

# ---------------------------
# AttackSwordAnimation (espada)
# ---------------------------
@onready var corpo_espada_escudo_ataque = $CompositeSprites/AttackSwordAnimation/CorpoEspadaEscudo
@onready var braco_espada_ataque = $CompositeSprites/AttackSwordAnimation/BracoEspada
@onready var escudo_ataque = $CompositeSprites/AttackSwordAnimation/Escudo
@onready var cabelo_ataque = $CompositeSprites/AttackSwordAnimation/Cabelo
@onready var roupa_ataque = $CompositeSprites/AttackSwordAnimation/Roupa

# ---------------------------
# AttackSpearAnimation (lança)
# ---------------------------
@onready var corpo_lanca_escudo_ataque = $CompositeSprites/AttackSpearAnimation/Corpo
@onready var braco_lanca_ataque = $CompositeSprites/AttackSpearAnimation/Lanca
@onready var cabelo_lanca_ataque = $CompositeSprites/AttackSpearAnimation/Cabelo
@onready var roupa_lanca_ataque = $CompositeSprites/AttackSpearAnimation/Roupa

@onready var sprites_compostos: Composto = Composto.new()
@onready var camera: Camera2D = $Camera2D

@onready var rotulo_hp = $"/root/cenario/UI/Hp"
@onready var rotulo_moedas: Label = $"/root/cenario/UI/Moedas/contador"

signal personalizacao_finalizada(cabelo: int, roupa: int, cor_cabelo: Color, apelido: String)
signal jogador_morreu

@export var estaMorto = false
@onready var gerenciador_ondas = get_node("/root/cenario/enemySpawner/GerenciadorOndas")

var apelido: String = ""
var inimigos_danificados: Array[Node] = []
var itens_comprados: Array[Dictionary] = []

var cabelo_atual: int = 0
var roupa_atual: int = 0
var _maquina_estados: Object 
var status_armas = preload("res://Codigos/DadosLocais/Equipamentos.gd").new()
var _knockback: Vector2 = Vector2.ZERO
var temporizador_knockback: float = 0.0

var array_ataque_cabelo: Array[Texture2D] = []
var array_ataque_roupa: Array[Texture2D] = []

# >>> Arrays de cabelo para lança <<<
var array_ataque_cabelo_lanca: Array[Texture2D] = []

# >>> Arrays de roupa para lança <<<
var array_ataque_roupa_lanca: Array[Texture2D] = []

var _direcao_ataque: Vector2 = Vector2.DOWN
var hp_atual: int

var invulneravel: bool = false
var tempo_invul: float = 0.6
var temporizador_invul: float = 0.0

@export var duracao_dash: float = 0.15
@export var velocidade_dash: float = 380.0
@export var recarga_dash: float = 0.6
@export var intervalo_rastro_dash: float = 0.025
@export var duracao_rastro_dash: float = 0.25
# Tom azulado das "sombras" deixadas pelo dash
@export var cor_rastro_dash: Color = Color(0.55, 0.8, 1.0, 0.6)
var esta_em_dash: bool = false
var _dash_disponivel: bool = true
var _tempo_proximo_rastro: float = 0.0

@onready var barra_hp_cheia = $"/root/cenario/UI/BarraVidaCheia"
@onready var barra_hp_vazia = $"/root/cenario/UI/BarraVidaVazia"

# ---------------------------
# COMBO
# ---------------------------
var _esta_atacando: bool = false
var _fase_combo: int = 0
var _pode_encadear_combo: bool = false

# Tempos para cada slash da espada
var _tempo_slash_1: float = 0.3
var _tempo_slash_2: float = 0.3
var _tempo_slash_3: float = 0.3

# >>> Tempos para a lança (ordem 2 -> 3 -> 1) <<<
var _tempo_slash_lanca_2: float = 0.35
var _tempo_slash_lanca_3: float = 0.45
var _tempo_slash_lanca_1: float = 0.35

var _temporizador_janela_combo: Timer

# ---------------------------
# FORJA
# ---------------------------
@onready var no_forja: Node2D = $CompositeSprites/Forja
@onready var sprite_corpo_forja: Sprite2D = $CompositeSprites/Forja/Corpo
@onready var sprite_cabelo_forja: Sprite2D = $CompositeSprites/Forja/Cabelo
@onready var sprite_roupa_forja: Sprite2D = $CompositeSprites/Forja/Roupa

@onready var reprodutor_anim: AnimationPlayer = $CompositeSprites/Animation/AnimationPlayer

@onready var sprite_armadura_cabeca  : Sprite2D = $CompositeSprites/Armaduras/cabeca
@onready var sprite_armadura_corpo  : Sprite2D = $CompositeSprites/Armaduras/corpo
@onready var sprite_armadura_luvas: Sprite2D = $CompositeSprites/Armaduras/luvas
@onready var sprite_armadura_botas : Sprite2D = $CompositeSprites/Armaduras/botas

# Níveis atuais de cada peça de armadura (iniciam em 1 por padrão)
@export var nivel_cabeca: int = 1
@export var nivel_corpo: int = 1
@export var nivel_luvas: int = 1
@export var nivel_botas: int = 1

# IDs (chaves no banco de dados `armaduras`)
var id_cabeca_atual: String   = "armadura_cabeca"
var id_corpo_atual: String   = "armadura_corpo"
var id_luvas_atual: String = "armadura_luvas"
var id_botas_atual: String  = "armadura_botas"

# Flags para indicar se cada peça está equipada ou não
@export var usando_cabeca: bool   = false
@export var usando_corpo: bool   = false
@export var usando_luvas: bool = false
@export var usando_botas: bool  = false

func _ready() -> void:
	# Inicializa vitalidade e defesa corretamente
	vitalidade_base = 5
	bonus_vitalidade = 0
	_temporizador = $AttackTimer
	bonus_defesa = 0
	estatisticas.vitalidade = vitalidade_base
	estatisticas.defesa = 0  # Será calculado depois
	vitalidade_atual = vitalidade_base
	_arvore_animacao = $CompositeSprites/Animation/AnimationTree
	# Conecta timer de ataque se existir
	if _temporizador:
		_temporizador.connect("timeout", Callable(self, "_on_temporizador_ataque_timeout"))

	_temporizador_janela_combo = Timer.new()
	_temporizador_janela_combo.one_shot = true
	add_child(_temporizador_janela_combo)
	_temporizador_janela_combo.connect("timeout", Callable(self, "_on_timeout_janela_combo"))

	# Ajusta sprite básico do Corpo
	sprite_corpo.texture = sprites_compostos.folha_sprite_corpo[0]

	# ---------------------------
	# Carrega arrays (espada)
	# ---------------------------
	for i in range(1, 3):
		var caminho_cabelo = "res://CharacterSprites/Hair/Attack/slash_1_sword/hair (%d).png" % i
		var recurso_cabelo = load(caminho_cabelo)
		if recurso_cabelo:
			array_ataque_cabelo.append(recurso_cabelo)

	for i in range(1, 8):
		var caminho_roupa = "res://CharacterSprites/Outfit/Attack/slash_1_sword/outfit(%d).png" % i
		var recurso_roupa = load(caminho_roupa)
		if recurso_roupa:
			array_ataque_roupa.append(recurso_roupa)

	# >>> Arrays de cabelo para lança <<<
	for i in range(1, 3):
		var caminho_cabelo_lanca = "res://CharacterSprites/Hair/Attack/slash_1_spear/hair (%d).png" % i
		var recurso_cabelo_lanca = load(caminho_cabelo_lanca)
		if recurso_cabelo_lanca:
			array_ataque_cabelo_lanca.append(recurso_cabelo_lanca)

	# >>> Arrays de roupa para lança <<<
	for i in range(1, 8):
		var caminho_roupa_lanca = "res://CharacterSprites/Outfit/Attack/slash_1_spear/outfit (%d).png" % i
		var recurso_roupa_lanca = load(caminho_roupa_lanca)
		if recurso_roupa_lanca:
			array_ataque_roupa_lanca.append(recurso_roupa_lanca)

	# Ajusta texturas iniciais
	sprite_cabelo.texture = sprites_compostos.folha_sprite_cabelo[cabelo_atual]
	sprite_roupa.texture = sprites_compostos.folha_sprite_roupa[roupa_atual]
	corpo_espada_escudo_ataque.texture = load("res://CharacterSprites/Body_sword_chield/body_attack_sword.png")

	if array_ataque_cabelo.size() > 0 and cabelo_atual < array_ataque_cabelo.size():
		cabelo_ataque.texture = array_ataque_cabelo[cabelo_atual]
		cabelo_ataque.modulate = cor_cabelo

	if array_ataque_roupa.size() > 0 and roupa_atual < array_ataque_roupa.size():
		roupa_ataque.texture = array_ataque_roupa[roupa_atual]

	# Lança
	if array_ataque_cabelo_lanca.size() > 0 and cabelo_atual < array_ataque_cabelo_lanca.size():
		cabelo_lanca_ataque.texture = array_ataque_cabelo_lanca[cabelo_atual]
		cabelo_lanca_ataque.modulate = cor_cabelo

	if array_ataque_roupa_lanca.size() > 0 and roupa_atual < array_ataque_roupa_lanca.size():
		roupa_lanca_ataque.texture = array_ataque_roupa_lanca[roupa_atual]
		roupa_lanca_ataque.modulate = Color(1, 1, 1)

	if _arvore_animacao:
		_maquina_estados = _arvore_animacao.get("parameters/playback")

	# Configura a área de ataque
	$AreaAtaque.collision_layer = 1 << 1
	$AreaAtaque.collision_mask = 1 << 2
	$AreaAtaque.monitoring = false
	$AreaAtaque.monitorable = false

	conectar_sinal_se_nao_conectado($AreaAtaque, "body_entered", "_on_corpo_entrou_area_ataque")
	conectar_sinal_se_nao_conectado($AreaAtaque, "area_entered", "_on_area_entrou_area_ataque")

	# Carrega dados salvos
	var dados_carregados = carregar_de_json()
	aplicar_dados_carregados(dados_carregados)

	no_forja.visible = false
	gerenciador_ondas.connect("onda_completada", Callable(self, "_on_onda_completada"))
	definir_sprites_visiveis(false)
	atualizar_rotulo_moedas()
	atualizar_barra_hp()

	# Equipa armaduras padrão
	nivel_cabeca   = 1
	nivel_corpo   = 1
	nivel_luvas = 1
	nivel_botas  = 1

	equipar_cabeca()
	equipar_corpo()
	equipar_luvas()
	equipar_botas()

	hp_atual = estatisticas.hp_maximo
	atualizar_barra_hp()

	_iniciar_inventario()

func _iniciar_inventario() -> void:
	if InventarioJogador.esta_vazio() and not InventarioJogador.carregar():
		InventarioJogador.criar_itens_iniciais()
	_aplicar_modelo()
	# As armaduras já foram equipadas acima; alinha o modelo caso o arquivo salvo divirja
	_enviar_estado_ao_modelo()
	equipamento_alterado.connect(_enviar_estado_ao_modelo)
	InventarioJogador.equipamento_alterado.connect(_ao_modelo_equipamento_alterado)
	EventosJogo.tela_fechada.connect(_ao_tela_fechada)

func _nivel_no_modelo(tipo: String) -> int:
	var item: DadosItem = InventarioJogador.buscar_por_tipo(tipo)
	return item.nivel if item != null else 1

func _subir_nivel_no_modelo(tipo: String) -> void:
	var item: DadosItem = InventarioJogador.buscar_por_tipo(tipo)
	if item == null:
		return
	InventarioJogador.subir_nivel(item)
	InventarioJogador.salvar()

func _ao_tela_fechada(_nome: String) -> void:
	InventarioJogador.salvar()

# Desequipa antes de equipar para que a arma de duas mãos não esbarre no escudo ainda equipado
func _enviar_estado_ao_modelo() -> void:
	if _sincronizando:
		return
	_sincronizando = true
	var estados := {"espada_basica": usando_espada, "lanca_basica": usando_lanca, "escudo_basico": usando_escudo}
	for tipo in TIPOS_ARMADURA:
		estados[tipo] = get(TIPOS_ARMADURA[tipo])
	for tipo in estados:
		var item: DadosItem = InventarioJogador.buscar_por_tipo(tipo)
		if item != null and not estados[tipo] and InventarioJogador.slot_de(item) != "":
			InventarioJogador.desequipar(item.categoria)
	for tipo in estados:
		var item: DadosItem = InventarioJogador.buscar_por_tipo(tipo)
		if item != null and estados[tipo] and InventarioJogador.slot_de(item) == "":
			InventarioJogador.equipar(item)
	_sincronizando = false

func _ao_modelo_equipamento_alterado(_slot: String) -> void:
	_aplicar_modelo()

func _aplicar_modelo() -> void:
	if _sincronizando:
		return
	_sincronizando = true
	var arma = InventarioJogador.equipados["arma"]
	var escudo = InventarioJogador.equipados["escudo"]
	var tipo_arma: String = arma.tipo if arma != null else ""

	if escudo == null and usando_escudo:
		desequipar_escudo()
	if tipo_arma != "espada_basica" and usando_espada:
		desequipar_espada()
	if tipo_arma != "lanca_basica" and usando_lanca:
		desequipar_lanca()
	if tipo_arma == "espada_basica" and not usando_espada:
		equipar_espada()
	elif tipo_arma == "lanca_basica" and not usando_lanca:
		equipar_lanca()
	if escudo != null and not usando_escudo:
		equipar_escudo()

	_sincronizando = false

func _on_onda_completada(_onda: int) -> void:
	hp_atual = estatisticas.hp_maximo
	atualizar_barra_hp()
	InventarioJogador.salvar()

func iniciar_dash() -> void:
	var dir = Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)
	if dir == Vector2.ZERO:
		dir = _direcao_ataque
	dir = dir.normalized()

	esta_em_dash = true
	_dash_disponivel = false
	invulneravel = true
	temporizador_invul = duracao_dash
	velocity = dir * velocidade_dash
	_tempo_proximo_rastro = 0.0

	await get_tree().create_timer(duracao_dash).timeout
	# Sai do dash com parte do impulso, para não parar seco
	velocity *= 0.35
	esta_em_dash = false

	await get_tree().create_timer(recarga_dash).timeout
	_dash_disponivel = true

func _atualizar_dash(delta: float) -> void:
	_tempo_proximo_rastro -= delta
	if _tempo_proximo_rastro <= 0.0:
		_tempo_proximo_rastro = intervalo_rastro_dash
		_criar_rastro_dash()
	move_and_slide()
	animar()

# Copia os sprites visíveis do personagem no ponto atual e desvanece a cópia (afterimage)
func _criar_rastro_dash() -> void:
	var cena_atual := get_tree().current_scene
	if cena_atual == null:
		return
	var rastro := Node2D.new()
	rastro.global_position = $CompositeSprites.global_position
	rastro.z_index = z_index - 1
	rastro.modulate = cor_rastro_dash
	for camada in [$CompositeSprites/BaseSprites, $CompositeSprites/Armaduras]:
		if not camada.visible:
			continue
		for sprite in camada.get_children():
			if sprite is Sprite2D and sprite.visible and sprite.texture:
				var copia := Sprite2D.new()
				copia.texture = sprite.texture
				copia.hframes = sprite.hframes
				copia.vframes = sprite.vframes
				copia.frame = sprite.frame
				copia.flip_h = sprite.flip_h
				copia.flip_v = sprite.flip_v
				copia.position = camada.position + sprite.position
				copia.rotation = sprite.rotation
				copia.scale = sprite.scale
				copia.z_index = sprite.z_index
				copia.self_modulate = sprite.self_modulate * sprite.modulate
				rastro.add_child(copia)
	cena_atual.add_child(rastro)
	var tween := rastro.create_tween()
	tween.tween_property(rastro, "modulate:a", 0.0, duracao_rastro_dash)
	tween.tween_callback(rastro.queue_free)

func bloquear_ataques(bloquear: bool) -> void:
	ataques_bloqueados = bloquear

func carregar_conjunto_armadura(id_conjunto: int) -> void:
	var caminho_base := "res://CharacterSprites/Armors/%d" % id_conjunto

	var caminho_cabeca   : String = "%s/head.png"   % caminho_base
	var caminho_corpo   : String = "%s/armor.png"  % caminho_base
	var caminho_luvas : String = "%s/gloves.png" % caminho_base
	var caminho_botas  : String = "%s/boots.png"  % caminho_base

	if ResourceLoader.exists(caminho_cabeca):
		sprite_armadura_cabeca.texture = load(caminho_cabeca)
	else:
		push_warning("[carregar_conjunto_armadura] head.png não encontrado em: " + caminho_cabeca)

	if ResourceLoader.exists(caminho_corpo):
		sprite_armadura_corpo.texture = load(caminho_corpo)
	else:
		push_warning("[carregar_conjunto_armadura] armor.png não encontrado em: " + caminho_corpo)
	if ResourceLoader.exists(caminho_luvas):
		sprite_armadura_luvas.texture = load(caminho_luvas)
	else:
		push_warning("[carregar_conjunto_armadura] gloves.png não encontrado em: " + caminho_luvas)

	if ResourceLoader.exists(caminho_botas):
		sprite_armadura_botas.texture = load(caminho_botas)
	else:
		push_warning("[carregar_conjunto_armadura] boots.png não encontrado em: " + caminho_botas)

func conectar_sinal_se_nao_conectado(no: Node, nome_sinal: String, metodo: String) -> void:
	if not no.is_connected(nome_sinal, Callable(self, metodo)):
		no.connect(nome_sinal, Callable(self, metodo))

func _physics_process(delta: float) -> void:
	if not movimento_habilitado:
		_pedido_ataque = false
		return

	if Input.is_action_just_pressed("debug_damage"):
		receber_dano(1)

	if invulneravel:
		temporizador_invul -= delta
		if temporizador_invul <= 0:
			invulneravel = false

	if esta_em_dash:
		_atualizar_dash(delta)
		return

	if Input.is_action_just_pressed("rolar") and _dash_disponivel and not _esta_atacando and not esta_forjando:
		iniciar_dash()
		return

	if temporizador_knockback > 0:
		temporizador_knockback -= delta
		velocity = _knockback
		_knockback = _knockback.lerp(Vector2.ZERO, _decaimento_knockback)
	else:
		mover()
		logica_combo_ataque()  # Chamado a cada frame

	move_and_slide()
	animar()

func mover() -> void:
	# Se o jogador está no meio de um ataque, não movimenta
	if _esta_atacando:
		velocity.x = lerp(velocity.x, 0.0, _friccao)
		velocity.y = lerp(velocity.y, 0.0, _friccao)
		return

	# Lê o input de movimento (teclas de andar)
	var dir = Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)

	if dir != Vector2.ZERO:
		# Normaliza a direção para não ficar maior que 1 em magnitude
		dir = dir.normalized()

		# **IMPORTANTE**: Atualiza a última direção de ataque
		_direcao_ataque = dir

		# 1) Define a base de velocidade
		#    - Sem arma: base = 64
		#    - Com arma (espada ou lança): base = 114
		var velocidade_base = 64.0
		if usando_espada or usando_lanca:
			velocidade_base = 114.0

		# 2) Soma os bônus que já estão em estatisticas
		#    (quando compra item, incrementa estatisticas.bonus_velocidade_item)
		var bonus_velocidade_item = estatisticas.bonus_velocidade_item

		# 3) Soma também o bônus de agilidade, caso queira
		var bonus_agilidade = float(estatisticas.agilidade) * 1.5

		# 4) Soma tudo para obter a velocidade final
		var velocidade_final = min(velocidade_base + bonus_velocidade_item + bonus_agilidade, estatisticas.VELOCIDADE_MAXIMA)

		# Move interpolando a velocidade atual para a velocidade desejada
		velocity.x = lerp(velocity.x, dir.x * velocidade_final, _aceleracao)
		velocity.y = lerp(velocity.y, dir.y * velocidade_final, _aceleracao)

		# Atualiza a animação dependendo de ter (espada/lança) ou não
		if usando_espada or usando_lanca:
			_arvore_animacao.set("parameters/idle/blend_position", dir)
			_arvore_animacao.set("parameters/running/blend_position", dir)
		else:
			_arvore_animacao.set("parameters/idle/blend_position", dir)
			_arvore_animacao.set("parameters/run/blend_position", dir)
	else:
		# Se não há input (dir == Vector2.ZERO), freia suavemente
		velocity.x = lerp(velocity.x, 0.0, _friccao)
		velocity.y = lerp(velocity.y, 0.0, _friccao)

# ---------------------------
# COMBO / ATAQUE
# ---------------------------
func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_action_pressed("attack"):
		_pedido_ataque = true

func logica_combo_ataque() -> void:
	var atacar := _pedido_ataque
	_pedido_ataque = false
	if ataques_bloqueados or get_viewport().gui_get_focus_owner() != null:
		return

	if atacar:
		if _esta_atacando:
			ataque_enfileirado = true
		else:
			if usando_espada:
				# Aqui usamos os nomes e tempos de ataque da espada
				if _fase_combo == 0:
					_fase_combo = 1
					iniciar_slash_ataque("AtaqueEspadaSlash_1", _tempo_slash_1)
				elif _fase_combo == 1:
					_fase_combo = 2
					iniciar_slash_ataque("AtaqueEspadaSlash_2", _tempo_slash_2)
				elif _fase_combo == 2:
					_fase_combo = 3
					iniciar_slash_ataque("AtaqueEspadaSlash_3", _tempo_slash_3)
			# Caso queira manter a lógica de lança, deixe o bloco abaixo
			elif usando_lanca:
				if _fase_combo == 0:
					_fase_combo = 1
					iniciar_slash_ataque_lanca("AtaqueLancaSlash_2", _tempo_slash_lanca_2)
				elif _fase_combo == 1:
					_fase_combo = 2
					iniciar_slash_ataque_lanca("AtaqueLancaSlash_3", _tempo_slash_lanca_3)
				elif _fase_combo == 2:
					_fase_combo = 3
					iniciar_slash_ataque_lanca("AtaqueLancaSlash_1", _tempo_slash_lanca_1)

func iniciar_slash_ataque_lanca(nome_anim: String, tempo_slash: float) -> void:
	# Ajusta a velocidade da animação se necessário (pode ser removido se não for desejado)
	reprodutor_anim.speed_scale = 0.2
	_esta_atacando = true
	$AreaAtaque.monitoring = true
	$AreaAtaque.monitorable = true
	definir_sprites_visiveis(true)
	_arvore_animacao.set("parameters/%s/blend_position" % nome_anim, _direcao_ataque)
	_maquina_estados.travel(nome_anim)
	_temporizador.start(tempo_slash)
	_pode_encadear_combo = true

func iniciar_slash_ataque(nome_anim: String, tempo_slash: float) -> void:
	_esta_atacando = true
	$AreaAtaque.monitoring = true
	$AreaAtaque.monitorable = true
	definir_sprites_visiveis(true)
	_arvore_animacao.set("parameters/%s/blend_position" % nome_anim, _direcao_ataque)
	_maquina_estados.travel(nome_anim)
	_temporizador.start(tempo_slash)
	_pode_encadear_combo = true

func _on_temporizador_ataque_timeout() -> void:
	_esta_atacando = false
	$AreaAtaque.monitoring = false
	$AreaAtaque.monitorable = false
	definir_sprites_visiveis(false)
	reprodutor_anim.speed_scale = 1.0

	# Se houver um ataque enfileirado, processa-o imediatamente
	if ataque_enfileirado:
		ataque_enfileirado = false
		# Verifica se está usando a espada e continua o combo
		if usando_espada:
			if _fase_combo == 1:
				_fase_combo = 2
				iniciar_slash_ataque("AtaqueEspadaSlash_2", _tempo_slash_2)
			elif _fase_combo == 2:
				_fase_combo = 3
				iniciar_slash_ataque("AtaqueEspadaSlash_3", _tempo_slash_3)
			else:
				_fase_combo = 0  # Caso tenha chegado ao final ou algum erro, reinicia
		elif usando_lanca:
			# Lógica para lança (se necessário)
			if _fase_combo == 1:
				_fase_combo = 2
				iniciar_slash_ataque_lanca("AtaqueLancaSlash_3", _tempo_slash_lanca_3)
			elif _fase_combo == 2:
				_fase_combo = 3
				iniciar_slash_ataque_lanca("AtaqueLancaSlash_1", _tempo_slash_lanca_1)
			else:
				_fase_combo = 0
		return

	# Se não houver ataque enfileirado, reinicia o combo
	_fase_combo = 0

func _on_timeout_janela_combo() -> void:
	_fase_combo = 0  # Reseta o combo independente do estágio
	_pode_encadear_combo = false

# ---------------------------
# Animação
# ---------------------------
func animar() -> void:
	if _esta_atacando:
		return
	if velocity.length() > 2:
		if usando_espada or usando_lanca:
			_maquina_estados.travel("running")
		else:
			_maquina_estados.travel("run")
	else:
		_maquina_estados.travel("idle")

func _on_corpo_entrou_area_ataque(corpo: Node2D) -> void:
	if corpo.is_in_group("enemy"):
		aplicar_golpe(corpo, (corpo.position - position).normalized())

func _on_area_entrou_area_ataque(area: Area2D) -> void:
	if area.is_in_group("enemy"):
		aplicar_golpe(area, (area.global_position - position).normalized())

func aplicar_golpe(alvo: Node, direcao_knockback: Vector2) -> void:
	if not alvo.has_method("receber_dano"):
		return
	if "esta_morto" in alvo and alvo.esta_morto:
		return
	var golpe = estatisticas.calcular_dano_golpe()
	var forca = 225.0 if golpe["critico"] else 150.0
	alvo.receber_dano(golpe["dano"], direcao_knockback * forca)
	if estatisticas.roubo_vida > 0:
		var percentual = min(estatisticas.roubo_vida, estatisticas.ROUBO_VIDA_MAXIMO) / 100.0
		var cura = max(1, int(round(golpe["dano"] * percentual)))
		hp_atual = min(hp_atual + cura, estatisticas.hp_maximo)
		atualizar_barra_hp()

# ---------------------------
# Visibilidade dos sprites
# ---------------------------
func definir_sprites_visiveis(esta_atacando: bool) -> void:
	sprite_corpo.visible = not esta_atacando
	sprite_cabelo.visible = not esta_atacando
	sprite_roupa.visible = not esta_atacando

	sprite_espada.visible = (not esta_atacando) and usando_espada
	sprite_lanca.visible = (not esta_atacando) and usando_lanca

	# Escudo só aparece se usando escudo E NÃO está atacando e NÃO está usando lança
	sprite_escudo.visible = (not esta_atacando) and usando_escudo and not usando_lanca

	# -- Animação de ataque com espada --
	corpo_espada_escudo_ataque.visible = esta_atacando and usando_espada
	braco_espada_ataque.visible = esta_atacando and usando_espada
	escudo_ataque.visible = esta_atacando and usando_escudo and usando_espada  # Ajuste aqui
	cabelo_ataque.visible = esta_atacando and usando_espada
	roupa_ataque.visible = esta_atacando and usando_espada

	# -- Animação de ataque com lança --
	corpo_lanca_escudo_ataque.visible = esta_atacando and usando_lanca
	braco_lanca_ataque.visible = esta_atacando and usando_lanca
	cabelo_lanca_ataque.visible = esta_atacando and usando_lanca
	roupa_lanca_ataque.visible = esta_atacando and usando_lanca

# ---------------------------
# CUSTOMIZAÇÃO
# ---------------------------
func trocar_cabelo_avancar() -> void:
	cabelo_atual = (cabelo_atual + 1) % sprites_compostos.folha_sprite_cabelo.size()
	sprite_cabelo.texture = sprites_compostos.folha_sprite_cabelo[cabelo_atual]
	sprite_cabelo.modulate = cor_cabelo
	if cabelo_atual < array_ataque_cabelo.size():
		cabelo_ataque.texture = array_ataque_cabelo[cabelo_atual]
		cabelo_ataque.modulate = cor_cabelo
	if cabelo_atual < array_ataque_cabelo_lanca.size():
		cabelo_lanca_ataque.texture = array_ataque_cabelo_lanca[cabelo_atual]
		cabelo_lanca_ataque.modulate = cor_cabelo
	if sprite_cabelo_forja and cabelo_atual < sprites_compostos.folha_sprite_cabelo.size():
		sprite_cabelo_forja.texture = sprites_compostos.folha_sprite_cabelo[cabelo_atual]
		sprite_cabelo_forja.modulate = cor_cabelo

func trocar_cabelo_voltar() -> void:
	cabelo_atual = (cabelo_atual - 1) % sprites_compostos.folha_sprite_cabelo.size()
	if cabelo_atual < 0:
		cabelo_atual = sprites_compostos.folha_sprite_cabelo.size() - 1
	sprite_cabelo.texture = sprites_compostos.folha_sprite_cabelo[cabelo_atual]
	sprite_cabelo.modulate = cor_cabelo
	if cabelo_atual < array_ataque_cabelo.size():
		cabelo_ataque.texture = array_ataque_cabelo[cabelo_atual]
		cabelo_ataque.modulate = cor_cabelo
	if cabelo_atual < array_ataque_cabelo_lanca.size():
		cabelo_lanca_ataque.texture = array_ataque_cabelo_lanca[cabelo_atual]
		cabelo_lanca_ataque.modulate = cor_cabelo
	if sprite_cabelo_forja and cabelo_atual < sprites_compostos.folha_sprite_cabelo.size():
		sprite_cabelo_forja.texture = sprites_compostos.folha_sprite_cabelo[cabelo_atual]
		sprite_cabelo_forja.modulate = cor_cabelo

func trocar_roupa_avancar() -> void:
	roupa_atual = (roupa_atual + 1) % sprites_compostos.folha_sprite_roupa.size()
	sprite_roupa.texture = sprites_compostos.folha_sprite_roupa[roupa_atual]
	if roupa_atual < array_ataque_roupa.size():
		roupa_ataque.texture = array_ataque_roupa[roupa_atual]
	if roupa_atual < array_ataque_roupa_lanca.size():
		roupa_lanca_ataque.texture = array_ataque_roupa_lanca[roupa_atual]
		roupa_lanca_ataque.modulate = Color(1, 1, 1)
	if sprite_roupa_forja and roupa_atual < sprites_compostos.folha_sprite_roupa.size():
		sprite_roupa_forja.texture = sprites_compostos.folha_sprite_roupa[roupa_atual]

func trocar_roupa_voltar() -> void:
	roupa_atual = (roupa_atual - 1) % sprites_compostos.folha_sprite_roupa.size()
	if roupa_atual < 0:
		roupa_atual = sprites_compostos.folha_sprite_roupa.size() - 1
	sprite_roupa.texture = sprites_compostos.folha_sprite_roupa[roupa_atual]
	if roupa_atual < array_ataque_roupa.size():
		roupa_ataque.texture = array_ataque_roupa[roupa_atual]
	if roupa_atual < array_ataque_roupa_lanca.size():
		roupa_lanca_ataque.texture = array_ataque_roupa_lanca[roupa_atual]
		roupa_lanca_ataque.modulate = Color(1, 1, 1)
	if sprite_roupa_forja and roupa_atual < sprites_compostos.folha_sprite_roupa.size():
		sprite_roupa_forja.texture = sprites_compostos.folha_sprite_roupa[roupa_atual]

func salvar_personalizacao() -> void:
	emit_signal("personalizacao_finalizada", cabelo_atual, roupa_atual, cor_cabelo, apelido)

func adicionar_moedas(quantidade: int) -> void:
	DadosJogo.moedas += quantidade
	atualizar_rotulo_moedas()

func gastar_moedas(quantidade: int) -> void:
	DadosJogo.moedas = max(DadosJogo.moedas - quantidade, 0)
	atualizar_rotulo_moedas()

func atualizar_rotulo_moedas() -> void:
	if rotulo_moedas:
		rotulo_moedas.text = str(DadosJogo.moedas)

# ---------------------------
# FUNÇÕES DE EQUIPAR/DESEQUIPAR
# ---------------------------
func atualizar_dano_arma() -> void:
	var dados := {}
	if usando_espada:
		dados = status_armas.obter_dados_nivel_arma(id_arma_atual, nivel_espada)
	elif usando_lanca:
		dados = status_armas.obter_dados_nivel_arma(id_lanca_atual, nivel_lanca)
	estatisticas.dano_arma = dados.get("dano", 0)
	estatisticas.calcular_estatisticas_derivadas(usando_espada or usando_lanca)

func equipar_espada() -> void:
	# Se já estiver usando espada, remover
	if usando_espada:
		desequipar_espada()
		return

	# Se estiver usando lança, remover antes
	if usando_lanca:
		desequipar_lanca()

	tipo_item_atual = ""
	usando_espada = true
	eh_arma_duas_maos = false
	atualizar_texturas_espada()
	sprite_espada.visible = true
	atualizar_dano_arma()
	emit_signal("equipamento_alterado")

func desequipar_espada() -> void:
	usando_espada = false
	sprite_espada.visible = false
	atualizar_dano_arma()
	emit_signal("equipamento_alterado")

func equipar_lanca() -> void:
	if usando_lanca:
		desequipar_lanca()
		return

	if usando_espada:
		desequipar_espada()

	if usando_escudo:
		desequipar_escudo()

	tipo_item_atual = "lanca_basica"
	usando_lanca = true
	eh_arma_duas_maos = true
	atualizar_dano_arma()
	atualizar_texturas_lanca()
	sprite_lanca.visible = true
	emit_signal("equipamento_alterado")

func desequipar_lanca() -> void:
	usando_lanca = false
	eh_arma_duas_maos = false
	sprite_lanca.visible = false
	atualizar_dano_arma()
	emit_signal("equipamento_alterado")

func equipar_escudo() -> void:
	if usando_escudo:
		desequipar_escudo()
		return
	if eh_arma_duas_maos:
		print("Não é possível equipar escudo com arma de duas mãos!")
		return

	usando_escudo = true
	sprite_escudo.visible = true
	atualizar_texturas_escudo()

	var instancia_bd_armas = preload("res://Codigos/DadosLocais/Equipamentos.gd").new()
	var dados_escudo = instancia_bd_armas.obter_dados_nivel_arma(id_escudo_atual, nivel_escudo)

	var bonus_hp_escudo = 0
	if dados_escudo.has("bonus_vitalidade"):
		bonus_vitalidade += dados_escudo["bonus_vitalidade"]
		vitalidade_atual = vitalidade_base + bonus_vitalidade
		estatisticas.vitalidade = vitalidade_atual
		bonus_hp_escudo = dados_escudo["bonus_vitalidade"] * 6

	if dados_escudo.has("bonus_defesa"):
		bonus_defesa += dados_escudo["bonus_defesa"]
		estatisticas.defesa = bonus_defesa

	estatisticas.calcular_estatisticas_derivadas(usando_espada or usando_lanca)
	hp_atual = min(hp_atual + bonus_hp_escudo, estatisticas.hp_maximo)
	atualizar_barra_hp()
	emit_signal("equipamento_alterado")

func desequipar_escudo() -> void:
	if not usando_escudo:
		return

	var instancia_bd_armas = preload("res://Codigos/DadosLocais/Equipamentos.gd").new()
	var dados_escudo = instancia_bd_armas.obter_dados_nivel_arma(id_escudo_atual, nivel_escudo)

	if dados_escudo.has("bonus_vitalidade"):
		bonus_vitalidade -= dados_escudo["bonus_vitalidade"]
		vitalidade_atual = vitalidade_base + bonus_vitalidade
		estatisticas.vitalidade = vitalidade_atual

	if dados_escudo.has("bonus_defesa"):
		bonus_defesa -= dados_escudo["bonus_defesa"]
		estatisticas.defesa = bonus_defesa

	estatisticas.calcular_estatisticas_derivadas(usando_espada or usando_lanca)
	hp_atual = min(hp_atual, estatisticas.hp_maximo)
	atualizar_barra_hp()

	usando_escudo = false
	sprite_escudo.visible = false
	emit_signal("equipamento_alterado")

# ---------------------------
# COMPRAS
# ---------------------------
func aplicar_efeitos_item(dados_item: Dictionary) -> void:
	if not dados_item.has("efeitos"):
		return
	var hp_maximo_anterior = estatisticas.hp_maximo
	for chave_efeito in dados_item.efeitos.keys():
		var valor_efeito = dados_item.efeitos[chave_efeito]
		match chave_efeito:
			"forca":
				estatisticas.forca += valor_efeito
			"defesa":
				# Esse bônus se soma a defesa base
				bonus_defesa += valor_efeito
				estatisticas.defesa = bonus_defesa
			"agilidade":
				estatisticas.agilidade += valor_efeito
			"vitalidade":
				# Mesmo caminho do bônus do escudo, senão o próximo equipar/desequipar sobrescreve
				bonus_vitalidade += valor_efeito
				vitalidade_atual = vitalidade_base + bonus_vitalidade
				estatisticas.vitalidade = vitalidade_atual
			"roubo_vida":
				estatisticas.roubo_vida += valor_efeito
			"sorte":
				estatisticas.sorte += valor_efeito
			_:
				pass
	estatisticas.calcular_estatisticas_derivadas(usando_espada or usando_lanca)
	hp_atual = min(hp_atual + max(estatisticas.hp_maximo - hp_maximo_anterior, 0), estatisticas.hp_maximo)
	atualizar_barra_hp()

# ---------------------------
# DANO / MORTE
# ---------------------------
func receber_dano(dano: int, forca_knockback: Vector2 = Vector2.ZERO) -> void:
	if invulneravel or estaMorto:
		return
	var dano_final = max(1, int(round(dano * (1.0 - estatisticas.reducao_dano()))))
	hp_atual = max(hp_atual - dano_final, 0)
	invulneravel = true
	temporizador_invul = tempo_invul
	atualizar_barra_hp()
	if forca_knockback != Vector2.ZERO:
		aplicar_knockback(forca_knockback)
	if hp_atual <= 0:
		morrer()

func atualizar_barra_hp() -> void:
	var fracao = float(hp_atual) / float(estatisticas.hp_maximo)
	if not barra_hp_cheia:
		return
	barra_hp_cheia.scale.x = fracao
	rotulo_hp.text = str(hp_atual) + "/" + str(estatisticas.hp_maximo)

func morrer() -> void:
	estaMorto = true
	emit_signal("jogador_morreu")
	gerenciador_ondas.parar_ondas()
	hp_atual = estatisticas.hp_maximo
	atualizar_barra_hp()
	DadosJogo.moedas = 0
	DadosDosItems.resetar_precos()
	atualizar_rotulo_moedas()

func aplicar_knockback(forca: Vector2) -> void:
	_knockback = forca
	temporizador_knockback = 0.1

	var sprites_para_piscar = [
		$CompositeSprites/BaseSprites/Corpo,
		$CompositeSprites/BaseSprites/Cabelo,
		$CompositeSprites/BaseSprites/Roupa,
		$CompositeSprites/BaseSprites/Braco,
		$CompositeSprites/BaseSprites/Escudo,
		$CompositeSprites/BaseSprites/Lanca,
		$CompositeSprites/AttackSwordAnimation/CorpoEspadaEscudo,
		$CompositeSprites/AttackSwordAnimation/BracoEspada,
		$CompositeSprites/AttackSwordAnimation/Escudo,
		$CompositeSprites/AttackSwordAnimation/Cabelo,
		$CompositeSprites/AttackSwordAnimation/Roupa,
		$CompositeSprites/AttackSpearAnimation/Corpo,
		$CompositeSprites/AttackSpearAnimation/Lanca,
		$CompositeSprites/AttackSpearAnimation/Cabelo,
		$CompositeSprites/AttackSpearAnimation/Roupa
	]

	for i in range(5):
		for sprite in sprites_para_piscar:
			if sprite:
				sprite.modulate.a = 0.2
		await get_tree().create_timer(0.1).timeout

		for sprite in sprites_para_piscar:
			if sprite:
				sprite.modulate.a = 1.0
		await get_tree().create_timer(0.1).timeout

# ---------------------------
# SALVAR / CARREGAR
# ---------------------------
func carregar_de_json() -> Dictionary:
	var diretorio_documentos = OS.get_user_data_dir()
	var caminho_arquivo = diretorio_documentos.path_join("configuracao_jogador.json")
	var arquivo = FileAccess.open(caminho_arquivo, FileAccess.READ)
	if arquivo == null:
		return {}
	var string_json = arquivo.get_as_text()
	arquivo.close()
	var json = JSON.new()
	var erro_parse = json.parse(string_json)
	if erro_parse != OK:
		return {}
	return json.get_data()

func aplicar_dados_carregados(dados: Dictionary) -> void:
	# Antes de aplicar, zera todos os bônus de armadura/escudo
	bonus_vitalidade = 0
	bonus_defesa = 0
	vitalidade_atual = vitalidade_base
	estatisticas.vitalidade = vitalidade_atual
	estatisticas.defesa = bonus_defesa

	if dados.has("cabelo_atual"):
		cabelo_atual = dados["cabelo_atual"]
		sprite_cabelo.texture = sprites_compostos.folha_sprite_cabelo[cabelo_atual]
		if cabelo_atual < array_ataque_cabelo.size():
			cabelo_ataque.texture = array_ataque_cabelo[cabelo_atual]
			cabelo_ataque.modulate = cor_cabelo
		if cabelo_atual < array_ataque_cabelo_lanca.size():
			cabelo_lanca_ataque.texture = array_ataque_cabelo_lanca[cabelo_atual]
			cabelo_lanca_ataque.modulate = cor_cabelo

	if dados.has("roupa_atual"):
		roupa_atual = dados["roupa_atual"]
		sprite_roupa.texture = sprites_compostos.folha_sprite_roupa[roupa_atual]
		if roupa_atual < array_ataque_roupa.size():
			roupa_ataque.texture = array_ataque_roupa[roupa_atual]
		if roupa_atual < array_ataque_roupa_lanca.size():
			roupa_lanca_ataque.texture = array_ataque_roupa_lanca[roupa_atual]
			roupa_lanca_ataque.modulate = Color(1,1,1)

	if dados.has("apelido"):
		apelido = dados["apelido"]

	if dados.has("cor_cabelo"):
		var dict_cor = dados["cor_cabelo"]
		var cor_cabelo_salva = Color(dict_cor["r"], dict_cor["g"], dict_cor["b"], dict_cor["a"])
		cor_cabelo = cor_cabelo_salva
		sprite_cabelo.modulate = cor_cabelo_salva
		cabelo_ataque.modulate = cor_cabelo_salva
		cabelo_lanca_ataque.modulate = cor_cabelo_salva

	atualizar_dano_arma()

func carregar_texturas_forja() -> void:
	if array_cabelo_forja.size() > 0:
		return
	for i in range(1, 3):
		var caminho_cabelo = "res://CharacterSprites/body_smithing/Hair/hair (%d).png" % i
		var textura_cabelo = load(caminho_cabelo)
		if textura_cabelo:
			array_cabelo_forja.append(textura_cabelo)

	for i in range(1, 8):
		var caminho_roupa = "res://CharacterSprites/body_smithing/Outfit/outfit (%d).png" % i
		var textura_roupa = load(caminho_roupa)
		if textura_roupa:
			array_roupa_forja.append(textura_roupa)

func aplicar_dados_forja() -> void:
	if cabelo_atual < array_cabelo_forja.size():
		sprite_cabelo_forja.texture = array_cabelo_forja[cabelo_atual]
		sprite_cabelo_forja.modulate = cor_cabelo

	if roupa_atual < array_roupa_forja.size():
		sprite_roupa_forja.texture = array_roupa_forja[roupa_atual]

func iniciar_forja(tipo_item: String) -> void:
	esta_forjando = true
	carregar_texturas_forja()
	var dados_carregados = carregar_de_json()
	if dados_carregados:
		if dados_carregados.has("cabelo_atual"):
			cabelo_atual = dados_carregados["cabelo_atual"]
		if dados_carregados.has("roupa_atual"):
			roupa_atual = dados_carregados["roupa_atual"]

	aplicar_dados_forja()
	movimento_habilitado = false
	no_forja.visible = true
	$CompositeSprites/BaseSprites.visible = false

	if _arvore_animacao and _maquina_estados:
		_maquina_estados.travel("smithing")

	var temporizador_forja = Timer.new()
	temporizador_forja.wait_time = 5.0
	temporizador_forja.one_shot = true
	add_child(temporizador_forja)
	temporizador_forja.connect("timeout", Callable(self, "_on_forja_finalizada").bind(tipo_item))
	temporizador_forja.start()

func _on_forja_finalizada(tipo_item: String) -> void:
	esta_forjando = false
	no_forja.visible = false
	$CompositeSprites/BaseSprites.visible = true
	if _arvore_animacao and _maquina_estados:
		_maquina_estados.travel("idle")
	movimento_habilitado = true

	var instancia_bd_armas = preload("res://Codigos/DadosLocais/Equipamentos.gd").new()

	match tipo_item:
		"espada_basica":
			_subir_nivel_no_modelo(tipo_item)
			atualizar_texturas_espada()
			atualizar_dano_arma()

		"escudo_basico":
			# Se estava usando o escudo, remove o bônus antigo primeiro
			if usando_escudo:
				var dados_escudo_antigo = instancia_bd_armas.obter_dados_nivel_arma(id_escudo_atual, nivel_escudo)
				if dados_escudo_antigo.has("bonus_vitalidade"):
					bonus_vitalidade -= dados_escudo_antigo["bonus_vitalidade"]
				if dados_escudo_antigo.has("bonus_defesa"):
					bonus_defesa -= dados_escudo_antigo["bonus_defesa"]

			_subir_nivel_no_modelo(tipo_item)
			atualizar_texturas_escudo()

			# Aplica o novo bônus se estiver usando o escudo
			var novos_dados_escudo = instancia_bd_armas.obter_dados_nivel_arma(id_escudo_atual, nivel_escudo)
			if usando_escudo:
				if novos_dados_escudo.has("bonus_vitalidade"):
					bonus_vitalidade += novos_dados_escudo["bonus_vitalidade"]
					vitalidade_atual = vitalidade_base + bonus_vitalidade
					estatisticas.vitalidade = vitalidade_atual
				if novos_dados_escudo.has("bonus_defesa"):
					bonus_defesa += novos_dados_escudo["bonus_defesa"]
					estatisticas.defesa = bonus_defesa

			estatisticas.calcular_estatisticas_derivadas(usando_espada or usando_lanca)
			hp_atual = min(hp_atual, estatisticas.hp_maximo)
			atualizar_barra_hp()

		"lanca_basica":
			_subir_nivel_no_modelo(tipo_item)
			atualizar_texturas_lanca()
			atualizar_dano_arma()

	atualizar_aparencia_arma() # Garante atualização visual correta
	emit_signal("forja_finalizada")

# ---------------------------
# ATUALIZAÇÃO DAS TEXTURAS
# ---------------------------
func atualizar_texturas_espada() -> void:
	var instancia_bd_armas = preload("res://Codigos/DadosLocais/Equipamentos.gd").new()
	var dados_nivel = instancia_bd_armas.obter_dados_nivel_arma(id_arma_atual, nivel_espada)
	if dados_nivel.size() > 0 and dados_nivel.has("textura"):
		sprite_espada.texture = dados_nivel["textura"]
		if dados_nivel.has("textura_ataque"):
			braco_espada_ataque.texture = dados_nivel["textura_ataque"]
	else:
		if nivel_espada == 1:
			var caminho_espada_base = "res://CharacterSprites/Arms/swords/Sword_1.png"
			var caminho_ataque_espada = "res://CharacterSprites/Arms/swords/Attack/slash_1.png"
			if ResourceLoader.exists(caminho_espada_base):
				sprite_espada.texture = load(caminho_espada_base)
			if ResourceLoader.exists(caminho_ataque_espada):
				braco_espada_ataque.texture = load(caminho_ataque_espada)
		else:
			var caminho_espada_base2 = "res://CharacterSprites/Arms/swords/swords_upgraded/%d/Sword_1.png" % nivel_espada
			var caminho_ataque_espada2 = "res://CharacterSprites/Arms/swords/Attack/swords_upgraded/slash_1/%d/slash_1.png" % nivel_espada
			if ResourceLoader.exists(caminho_espada_base2):
				sprite_espada.texture = load(caminho_espada_base2)
			if ResourceLoader.exists(caminho_ataque_espada2):
				braco_espada_ataque.texture = load(caminho_ataque_espada2)

func atualizar_texturas_lanca() -> void:
	var instancia_bd_armas = preload("res://Codigos/DadosLocais/Equipamentos.gd").new()
	var dados_nivel = instancia_bd_armas.obter_dados_nivel_arma(id_lanca_atual, nivel_lanca)
	if dados_nivel.size() > 0:
		if dados_nivel.has("textura") and dados_nivel["textura"] is Texture2D:
			sprite_lanca.texture = dados_nivel["textura"]
		if dados_nivel.has("textura_ataque") and dados_nivel["textura_ataque"] is Texture2D:
			braco_lanca_ataque.texture = dados_nivel["textura_ataque"]
	else:
		var caminho_lanca_base = ""
		var caminho_ataque_lanca = ""

		if nivel_lanca == 1:
			caminho_lanca_base = "res://CharacterSprites/Arms/spears/spear_1.png"
			caminho_ataque_lanca = "res://CharacterSprites/Arms/spears/Attack/slash_1.png"
		else:
			caminho_lanca_base = "res://CharacterSprites/Arms/spears/spears_upgraded/%d/spear_1.png" % nivel_lanca
			caminho_ataque_lanca = "res://CharacterSprites/Arms/spears/Attack/spears_upgraded/%d/slash_1.png" % nivel_lanca

		if ResourceLoader.exists(caminho_lanca_base):
			sprite_lanca.texture = load(caminho_lanca_base)
		else:
			print("Erro: Textura não encontrada:", caminho_lanca_base)

		if ResourceLoader.exists(caminho_ataque_lanca):
			braco_lanca_ataque.texture = load(caminho_ataque_lanca)
		else:
			print("Erro: Textura não encontrada:", caminho_ataque_lanca)

func atualizar_texturas_escudo() -> void:
	var instancia_bd_armas = preload("res://Codigos/DadosLocais/Equipamentos.gd").new()
	var dados_nivel = instancia_bd_armas.obter_dados_nivel_arma(id_escudo_atual, nivel_escudo)
	if dados_nivel.size() > 0 and dados_nivel.has("textura"):
		sprite_escudo.texture = dados_nivel["textura"]
		if dados_nivel.has("textura_ataque"):
			escudo_ataque.texture = dados_nivel["textura_ataque"]
	else:
		if nivel_escudo == 1:
			var caminho_escudo_base = "res://CharacterSprites/Arms/shields/shield_1.png"
			var caminho_ataque_escudo = "res://CharacterSprites/Arms/shields/attack/slash_1.png"
			if ResourceLoader.exists(caminho_escudo_base):
				sprite_escudo.texture = load(caminho_escudo_base)
			if ResourceLoader.exists(caminho_ataque_escudo):
				escudo_ataque.texture = load(caminho_ataque_escudo)
		else:
			var caminho_escudo_base2 = "res://CharacterSprites/Arms/shields/upgraded_shields/%d/shield_1.png" % nivel_escudo
			var caminho_ataque_escudo2 = "res://CharacterSprites/Arms/shields/attack/shields_upgrade/slash_1/%d/slash_1.png" % nivel_escudo
			if ResourceLoader.exists(caminho_escudo_base2):
				sprite_escudo.texture = load(caminho_escudo_base2)
			if ResourceLoader.exists(caminho_ataque_escudo2):
				escudo_ataque.texture = load(caminho_ataque_escudo2)

func atualizar_aparencia_arma() -> void:
	if usando_espada:
		atualizar_texturas_espada()
	elif usando_lanca:
		atualizar_texturas_lanca()
	elif usando_escudo:
		atualizar_texturas_escudo()

func desabilitar_todas_acoes(desabilitar: bool) -> void:
	# Se estiver em forja, não permite reativar as ações
	if esta_forjando:
		ataques_bloqueados = true
		movimento_habilitado = false
		return

	# Código original
	ataques_bloqueados = desabilitar
	movimento_habilitado = !desabilitar

	if desabilitar and _esta_atacando:
		_esta_atacando = false
		$AreaAtaque.monitoring = false
		$AreaAtaque.monitorable = false
		definir_sprites_visiveis(false)
		reprodutor_anim.speed_scale = 1.0
		_fase_combo = 0

# ---------------------------
# FUNÇÕES DE ARMADURA
# ---------------------------
func equipar_cabeca() -> void:
	if not usando_cabeca:
		usando_cabeca = true
		carregar_conjunto_armadura(nivel_cabeca)
		
		var instancia_bd_armaduras = preload("res://Codigos/DadosLocais/Equipamentos.gd").new()
		var dados_cabeca = instancia_bd_armaduras.obter_dados_nivel_armadura(id_cabeca_atual, nivel_cabeca)
		
		if dados_cabeca.has("bonus_vitalidade"):
			bonus_vitalidade += dados_cabeca["bonus_vitalidade"]
			vitalidade_atual = vitalidade_base + bonus_vitalidade
			estatisticas.vitalidade = vitalidade_atual
			estatisticas.calcular_estatisticas_derivadas(usando_espada or usando_lanca)
			hp_atual = min(hp_atual + dados_cabeca["bonus_vitalidade"] * 6, estatisticas.hp_maximo)
		
		if dados_cabeca.has("bonus_defesa"):
			bonus_defesa += dados_cabeca["bonus_defesa"]
			estatisticas.defesa = bonus_defesa
		
		estatisticas.calcular_estatisticas_derivadas(usando_espada or usando_lanca)
		atualizar_barra_hp()
		emit_signal("equipamento_alterado")

func equipar_corpo() -> void:
	if not usando_corpo:
		usando_corpo = true
		carregar_conjunto_armadura(nivel_corpo)
		
		var instancia_bd_armaduras = preload("res://Codigos/DadosLocais/Equipamentos.gd").new()
		var dados_corpo = instancia_bd_armaduras.obter_dados_nivel_armadura(id_corpo_atual, nivel_corpo)
		
		if dados_corpo.has("bonus_vitalidade"):
			bonus_vitalidade += dados_corpo["bonus_vitalidade"]
			vitalidade_atual = vitalidade_base + bonus_vitalidade
			estatisticas.vitalidade = vitalidade_atual
			estatisticas.calcular_estatisticas_derivadas(usando_espada or usando_lanca)
			hp_atual = min(hp_atual + dados_corpo["bonus_vitalidade"] * 6, estatisticas.hp_maximo)
		
		if dados_corpo.has("bonus_defesa"):
			bonus_defesa += dados_corpo["bonus_defesa"]
			estatisticas.defesa = bonus_defesa
		
		estatisticas.calcular_estatisticas_derivadas(usando_espada or usando_lanca)
		atualizar_barra_hp()
		emit_signal("equipamento_alterado")

func equipar_luvas() -> void:
	if not usando_luvas:
		usando_luvas = true
		carregar_conjunto_armadura(nivel_luvas)
		
		var instancia_bd_armaduras = preload("res://Codigos/DadosLocais/Equipamentos.gd").new()
		var dados_luvas = instancia_bd_armaduras.obter_dados_nivel_armadura(id_luvas_atual, nivel_luvas)
		
		if dados_luvas.has("bonus_vitalidade"):
			bonus_vitalidade += dados_luvas["bonus_vitalidade"]
			vitalidade_atual = vitalidade_base + bonus_vitalidade
			estatisticas.vitalidade = vitalidade_atual
			estatisticas.calcular_estatisticas_derivadas(usando_espada or usando_lanca)
			hp_atual = min(hp_atual + dados_luvas["bonus_vitalidade"] * 6, estatisticas.hp_maximo)
		
		if dados_luvas.has("bonus_defesa"):
			bonus_defesa += dados_luvas["bonus_defesa"]
			estatisticas.defesa = bonus_defesa
		
		estatisticas.calcular_estatisticas_derivadas(usando_espada or usando_lanca)
		atualizar_barra_hp()
		emit_signal("equipamento_alterado")

func equipar_botas() -> void:
	if not usando_botas:
		usando_botas = true
		carregar_conjunto_armadura(nivel_botas)
		
		var instancia_bd_armaduras = preload("res://Codigos/DadosLocais/Equipamentos.gd").new()
		var dados_botas = instancia_bd_armaduras.obter_dados_nivel_armadura(id_botas_atual, nivel_botas)
		
		if dados_botas.has("bonus_vitalidade"):
			bonus_vitalidade += dados_botas["bonus_vitalidade"]
			vitalidade_atual = vitalidade_base + bonus_vitalidade
			estatisticas.vitalidade = vitalidade_atual
			estatisticas.calcular_estatisticas_derivadas(usando_espada or usando_lanca)
			hp_atual = min(hp_atual + dados_botas["bonus_vitalidade"] * 6, estatisticas.hp_maximo)
		
		if dados_botas.has("bonus_defesa"):
			bonus_defesa += dados_botas["bonus_defesa"]
			estatisticas.defesa = bonus_defesa
		
		estatisticas.calcular_estatisticas_derivadas(usando_espada or usando_lanca)
		atualizar_barra_hp()
		emit_signal("equipamento_alterado")

func definir_cor_cabelo(nova_cor: Color) -> void:
	cor_cabelo = nova_cor
	sprite_cabelo.modulate = nova_cor
	cabelo_ataque.modulate = nova_cor
	cabelo_lanca_ataque.modulate = nova_cor
	if sprite_cabelo_forja:
		sprite_cabelo_forja.modulate = nova_cor

func definir_apelido(novo_apelido: String) -> void:
	apelido = novo_apelido
