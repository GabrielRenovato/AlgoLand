extends Node2D
## Objeto independente: sprite sazonal, estado do mecanismo e colisão apenas na base.
const RAIZ := "res://assets/cenario/campanha/dungeon_comporta/"
const Profundidade := preload("res://codigo/globais/profundidade.gd")
var tipo := "suprimentos"
var estado := "fechada"
var base := Vector2(36,16)
var estacao := 0
var sprite: Sprite2D
var _tempo:=0.0

func _ready() -> void:
	sprite=Sprite2D.new();sprite.name="Sprite";sprite.centered=false
	sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.z_as_relative=false;sprite.z_index=Profundidade.z_de(global_position.y)
	var lado:=128 if tipo=="comporta" else 32 if tipo=="cadeira" else 64
	sprite.offset=Vector2(-lado*.5,-lado*.875)
	if tipo=="fogueira_panela":sprite.hframes=4
	add_child(sprite)
	var corpo:=StaticBody2D.new();corpo.name="BaseFisica";corpo.collision_layer=64;corpo.collision_mask=0
	var forma:=CollisionShape2D.new();var ret:=RectangleShape2D.new();ret.size=base
	forma.shape=ret;corpo.add_child(forma);add_child(corpo)
	_atualizar()
	if tipo=="fogueira_panela":_luz_fogueira()
	else:set_process(false)

func _process(delta:float) -> void:
	_tempo+=delta
	sprite.frame=int(_tempo*6.0)%4

func _luz_fogueira() -> void:
	var gradiente:=Gradient.new()
	gradiente.colors=PackedColorArray([Color(1,.45,.1,.65),Color(1,.25,.04,0)])
	var textura:=GradientTexture2D.new();textura.gradient=gradiente
	textura.width=128;textura.height=128;textura.fill=GradientTexture2D.FILL_RADIAL
	textura.fill_from=Vector2(.5,.5);textura.fill_to=Vector2(1,.5)
	var luz:=PointLight2D.new();luz.texture=textura;luz.color=Color(1,.65,.3);luz.energy=.35
	luz.position=Vector2(0,-10);add_child(luz)

func definir_estacao(indice:int) -> void:
	estacao=clampi(indice,0,3)
	if is_instance_valid(sprite):_atualizar()

func definir_aberta(aberta:bool) -> void:
	estado="aberta" if aberta else "fechada"
	if is_instance_valid(sprite):_atualizar()

func _atualizar() -> void:
	var variante:="_"+estado if tipo in ["alavanca","comporta"] else ""
	sprite.texture=load(RAIZ+tipo+variante+"_%d.png" % estacao)
