extends "res://codigo/jogador/representacao_heroi_3d.gd"
## Corpo infantil com vestuário separado e movimentos retargetados próprios.
const ProporcaoInfantil=preload("res://codigo/npcs/proporcao_infantil_3d.gd")
const ProporcaoAdulta=preload("res://codigo/jogador/proporcao_chibi.gd")
var traje_infantil:String=""
var cabelo_infantil:String="franjinha"
var _vestuario:RefCounted

func _ready() -> void:
	super._ready()
	heroi._player.add_animation_library("infantis",load("res://assets/personagens/base_3d/movimentos_infantis.res"))
	for m in heroi._esqueleto.get_children():
		if m is ProporcaoAdulta:
			m.active=false
			m.queue_free()
	var proporcao:=ProporcaoInfantil.new()
	heroi._esqueleto.add_child(proporcao)
	var cena:Node3D=heroi._esqueleto
	while cena.get_parent()!=heroi._modelo:cena=cena.get_parent()
	cena.scale=Vector3.ONE*ProporcaoInfantil.ESCALA_GERAL
	cena.position.y=-ProporcaoInfantil.DESCIDA_INFANTIL
	# O rosto pintado é um billboard: seu tamanho não herda a escala dos ossos.
	var rosto:QuadMesh=heroi._cabeca_referencia.malha.mesh.duplicate()
	rosto.size*=.83
	heroi._cabeca_referencia.malha.mesh=rosto
	var corpo:MeshInstance3D=heroi._modelo.find_child("CorpoBase",true,false)
	corpo.material_override.set_shader_parameter("preservar_nuca",true)
	proporcao._aplicar()
	pose(false,0,0)
	if not traje_infantil.is_empty():vestir_infantil(traje_infantil,cabelo_infantil)

func vestir_infantil(traje: String,penteado: String) -> void:
	if _vestuario==null:_vestuario=preload("res://codigo/npcs/vestuario_infantil_3d.gd").new(heroi)
	traje_infantil=traje
	cabelo_infantil=penteado
	_vestuario.aplicar(traje,penteado)

func mostrar(aparencia_nova: Dictionary,roupas: Dictionary,direcao: int) -> void:
	super.mostrar(aparencia_nova,roupas,direcao)
	if _vestuario!=null:_vestuario.aplicar(traje_infantil,cabelo_infantil)

func duracao_caminhada() -> float:
	return heroi._player.get_animation("infantis/Caminhada_Infantil").length

func passada_caminhada() -> float:
	return float(heroi._player.get_animation_library("infantis").get_meta("passada_infantil_px"))

func pose_caminhada(andando: bool,direcao: int,tempo: float) -> void:
	var clipe:="infantis/Caminhada_Infantil" if andando else "infantis/Descanso_Infantil"
	_posar("andar" if andando else "parado",clipe,direcao,fposmod(tempo,heroi._player.get_animation(clipe).length))

func pose_conversa(direcao: int,tempo: float) -> void:
	pose_caminhada(false,direcao,tempo)
