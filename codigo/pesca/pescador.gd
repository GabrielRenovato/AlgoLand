extends CharacterBody2D

## O mesmo Nilo é representado em casa e na praia, com trajetos coordenados entre ambientes.
const Profundidade := preload("res://codigo/globais/profundidade.gd")
const Rotina := preload("res://codigo/pesca/rotina_nilo.gd")
const Trajeto := preload("res://codigo/cidade/trajeto_morador.gd")
const PARADO := preload("res://assets/npcs/cidade/nilo.png")
const ANDANDO := preload("res://assets/npcs/cidade/nilo_andar.png")
var id := "nilo"
var vila: Node2D
var sprite: Sprite2D
var interacao: Area2D
var agenda: Dictionary = {}
var caminho := PackedVector2Array()
var _saindo := false
var dormindo := false
var _tempo := 0.0
var _rotina_em := 0.0
var _alvo := Vector2.ZERO
var _direcao := 0
var _cabeca: Sprite2D
var _zzz: Label
var _pesca: Node2D

func _ready() -> void:
	vila = get_parent()
	add_to_group("moradores_cidade")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	collision_mask = 64 | 2
	sprite = Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = PARADO
	sprite.hframes = 4
	sprite.position.y = -4
	add_child(sprite)
	_pesca = preload("res://codigo/pesca/pose_pesca.gd").new()
	_pesca.visible = false
	add_child(_pesca)
	preload("res://codigo/cidade/sombra_cidade.gd").contato(self, 15, 3, Vector2(0, 10))
	var forma := CollisionShape2D.new()
	var circulo := CircleShape2D.new()
	circulo.radius = 5
	forma.shape = circulo
	forma.position.y = 9
	add_child(forma)
	interacao = preload("res://codigo/pesca/interacao_pescador.gd").new()
	interacao.name = "Interacao"
	interacao.position.y = 8
	var zona := CollisionShape2D.new()
	var alcance := CircleShape2D.new()
	alcance.radius = 48
	zona.shape = alcance
	interacao.add_child(zona)
	add_child(interacao)
	_cabeca = Sprite2D.new()
	var recorte := AtlasTexture.new()
	recorte.atlas = PARADO
	recorte.region = Rect2(24, 24, 16, 8)
	_cabeca.texture = recorte
	_cabeca.position = Vector2(0, -57)
	_cabeca.visible = false
	add_child(_cabeca)
	_zzz = Label.new()
	_zzz.text = "z z"
	_zzz.position = Vector2(12, -65)
	_zzz.add_theme_font_size_override("font_size", 8)
	_zzz.visible = false
	add_child(_zzz)
	visible = false
	# A iluminação restaura a hora depois dos filhos anteriores; a agenda nasce só com a cena pronta.
	vila.ready.connect(atualizar_rotina.bind(true), CONNECT_ONE_SHOT)

func atualizar_rotina(inicial := false) -> void:
	var nova := Rotina.agenda(vila.hora_atual(), vila.clima_atual())
	if nova == agenda:
		return
	var anterior := agenda
	agenda = nova
	if inicial:
		visible = agenda["local"] == vila.local and not Trajeto.aguardar(self)
		position = agenda["ponto"] if visible else Vector2.ZERO
		if visible:
			_definir_sono(agenda.get("dormindo", false))
	elif agenda["local"] == vila.local:
		Trajeto.preparar_chegada(self, str(anterior.get("local", "")))
		if not visible and Trajeto.aguardar(self):
			return
		if not visible:
			position = vila.porta_do_local(str(anterior.get("local", "")))
		visible = true
		_saindo = false
		_definir_sono(false)
		_ir_ate(agenda["ponto"])
	elif visible:
		_definir_sono(false)
		_saindo = true
		_ir_ate(vila.porta_do_local(agenda["local"]))
		Trajeto.registrar(self)
	_atualizar_colisao()

func _definir_sono(usar: bool) -> void:
	_pesca.visible = false
	if usar:
		position = agenda["ponto"]
	elif dormindo:
		position = Vector2(236, 116)
	dormindo = usar
	sprite.visible = not usar
	_cabeca.visible = usar
	_zzz.visible = usar
	_atualizar_colisao()

func _atualizar_colisao() -> void:
	collision_layer = 32 if visible and not dormindo else 0
	if interacao != null:
		interacao.set_deferred("monitoring", visible and not dormindo)

func _ir_ate(ponto: Vector2) -> void:
	_alvo = ponto
	caminho = vila.caminho_entre(position, ponto)

func _physics_process(delta: float) -> void:
	_tempo += delta
	_rotina_em -= delta
	if _rotina_em <= 0:
		_rotina_em = 0.5
		atualizar_rotina()
	Trajeto.sincronizar(self)
	if not visible or dormindo:
		_pesca.visible = false
		return
	var jogador := Cooperativo.jogador_no_ambiente(self)
	var perto := jogador != null and (position.distance_to(jogador.position) < 32 or Cidade.em_conversa(id))
	var andando := false
	if perto and (not _saindo or not jogador.movimento_habilitado):
		_olhar(jogador.position - position)
	elif not caminho.is_empty():
		var diferenca := caminho[0] - position
		if diferenca.length() < 1:
			caminho.remove_at(0)
		else:
			_olhar(diferenca)
			var colisao := move_and_collide(diferenca.normalized() * minf(26 * delta, diferenca.length()))
			andando = colisao == null
			if colisao != null and int(_tempo * 2) % 2 == 0:
				_ir_ate(_alvo)
	elif _saindo:
		Trajeto.concluir(self)
		visible = false
		_saindo = false
		_atualizar_colisao()
	elif agenda.get("dormindo", false):
		_definir_sono(true)
	z_index = Profundidade.z_de(position.y + 9)
	_pesca.visible = visible and not dormindo and not _saindo and caminho.is_empty() and not perto and agenda.get("atividade", "") == "Pescando no pier"
	if andando:
		if sprite.texture != ANDANDO:
			sprite.frame = 0
		sprite.texture = ANDANDO
		sprite.hframes = 6
		sprite.vframes = 4
		sprite.frame = _direcao * 6 + int(_tempo * 8) % 6
	else:
		if sprite.texture != PARADO:
			sprite.frame = 0
		sprite.texture = PARADO
		sprite.hframes = 4
		sprite.vframes = 1
		sprite.frame = _direcao

func _olhar(direcao: Vector2) -> void:
	_direcao = (1 if direcao.x > 0 else 3) if absf(direcao.x) > absf(direcao.y) else (0 if direcao.y > 0 else 2)
