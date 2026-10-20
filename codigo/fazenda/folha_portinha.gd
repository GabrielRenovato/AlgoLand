extends Node2D

## Folha da portinha: recorte nativo da fachada por fora; tábuas por dentro.
var tamanho := Vector2(10,12)
var abertura := 0.0
var textura: Texture2D
var regiao := Rect2()

func _draw() -> void:
	var altura := tamanho.y*(1-abertura)
	if altura <= 0: return
	# Fundo opaco: transparências no atlas nunca deixam frestas na tampa.
	draw_rect(Rect2(Vector2.ZERO,Vector2(tamanho.x,altura)),Color("82502c"))
	if textura != null:
		draw_texture_rect_region(textura,Rect2(Vector2.ZERO,Vector2(tamanho.x,altura)),
			Rect2(regiao.position,Vector2(regiao.size.x,regiao.size.y*(1-abertura))))
		return
	for proporcao in [0.3,0.6,0.9]:
		var x := floorf(tamanho.x*proporcao)
		draw_line(Vector2(x,0),Vector2(x,altura),Color("543721"))
