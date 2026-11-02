extends Node2D
## Boneco do treino de Dara: aceita golpes do jogador sem perder vida, sem dar maestria e sem morrer.
## `armando` (0 a 1) mostra o braço subindo antes do golpe de `treino_dara.gd`.
signal golpeado
var vida := 100
var esta_morto := false
var armando := 0.0
var _piscar := 0.0

func _ready() -> void:
	add_to_group("enemy")
	set_meta("sem_maestria", true)
	var area := Area2D.new()
	area.collision_layer = 4
	area.collision_mask = 0
	area.add_to_group("hurtbox_inimigo")
	var forma := CollisionShape2D.new()
	var circulo := CircleShape2D.new()
	circulo.radius = 14.0
	forma.shape = circulo
	forma.position = Vector2(0, -14)
	area.add_child(forma)
	add_child(area)

func receber_dano(_quantidade: int, _empurrao := Vector2.ZERO) -> void:
	_piscar = 0.18
	golpeado.emit()
	queue_redraw()

func receber_dano_efeito(_quantidade: int, _cor: Color) -> void:
	pass

func empurrar(_forca: Vector2) -> void:
	pass

func atordoar(_tempo: float) -> void:
	pass

func _process(delta: float) -> void:
	if _piscar > 0.0:
		_piscar = maxf(_piscar - delta, 0.0)
		queue_redraw()

func definir_armando(valor: float) -> void:
	armando = clampf(valor, 0.0, 1.0)
	queue_redraw()

func _draw() -> void:
	var madeira := Color("8a5a35")
	var palha := Color("d8b36a")
	if _piscar > 0.0:
		madeira = madeira.lightened(0.5)
		palha = palha.lightened(0.5)
	draw_rect(Rect2(-9, -2, 18, 4), Color(0, 0, 0, 0.25))
	draw_rect(Rect2(-3, -28, 6, 28), madeira)
	draw_rect(Rect2(-13, -22, 26, 5), madeira)
	draw_circle(Vector2(0, -33), 7.0, palha)
	var braco := Color("e0e0e0").lerp(Color("e25544"), armando)
	var ponta := Vector2(13, -19).lerp(Vector2(20, -38), armando)
	draw_line(Vector2(13, -19), ponta, braco, 3.0)
