extends Node2D
## Prévia em quadros: ruptura, lançamento, queda e dissipação dos escombros.
## O dano pertence ao evento de contato do boss; as pedras não reaplicam dano.
const TEMPOS := [30,60,90,120,90,120,120,150,120]
var textura_escombros: Texture2D
var tempo := -1.0
var _automatico := false

func iniciar() -> void:
	_automatico=true
	amostrar(0.0)

func _process(delta: float) -> void:
	if not _automatico:return
	amostrar(tempo+delta)
	if tempo>=.9:queue_free()

func amostrar(segundos: float) -> void:
	tempo=segundos
	queue_redraw()

func _draw() -> void:
	if tempo<0.0 or tempo>=.9 or textura_escombros==null:return
	var acumulado:=0
	var indice:=TEMPOS.size()-1
	for i in TEMPOS.size():
		acumulado+=TEMPOS[i]
		if tempo*1000.0<float(acumulado):
			indice=i
			break
	var celula:=Vector2(textura_escombros.get_size())/3.0
	var origem:=Vector2(indice%3,indice/3)*celula
	var alfa:=1.0-smoothstep(.55,.9,tempo)
	# O pivô da ruptura coincide com a pedra no chão, entre as botas.
	draw_texture_rect_region(textura_escombros,Rect2(-280,-401.4,560,560),
		Rect2(origem,celula),Color(1,1,1,alfa))
