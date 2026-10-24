extends RefCounted

## Barras no acabamento de madeira da interface; cores e proporções de vida/energia preservadas.
const ATLAS := preload("res://assets/ui/inicio_detalhado/atlas.png")
const LARGURA_PECA := 16
const ALTURA := 8
const BORDA := 2.0
const COR_FUNDO := Color("30241b")
const COR_VIDA := Color("ba5945")
const COR_RASTRO := Color("f4dfae")

static func desenhar(item: CanvasItem, origem: Vector2, largura: int, fracao: float, fracao_rastro: float, cor := Color.WHITE) -> void:
	var total := maxi(floori(largura/float(LARGURA_PECA)),2)*LARGURA_PECA
	_moldura(item,origem,Vector2(total,ALTURA))
	var interior := Rect2(origem+Vector2.ONE*BORDA,Vector2(total-2*BORDA,ALTURA-2*BORDA))
	item.draw_rect(interior,COR_FUNDO)
	var vida := roundf(interior.size.x*clampf(fracao,0,1))
	var rastro := roundf(interior.size.x*clampf(fracao_rastro,0,1))
	var tom := COR_VIDA if cor == Color.WHITE else cor
	if vida > 0:
		for y in int(interior.size.y):
			var luz := 1.18-0.3*y/maxf(1,interior.size.y-1)
			item.draw_rect(Rect2(interior.position+Vector2(0,y),Vector2(vida,1)),tom*Color(luz,luz,luz,1))
	if rastro > vida:
		item.draw_rect(Rect2(interior.position+Vector2(vida,0),Vector2(rastro-vida,interior.size.y)),COR_RASTRO)

static func _moldura(item: CanvasItem, origem: Vector2, tamanho: Vector2) -> void:
	var lado := ATLAS.get_width()/2.0
	var fonte := [0.0,64.0,lado-64.0,lado]
	var destino_x := [0.0,BORDA,tamanho.x-BORDA,tamanho.x]
	var destino_y := [0.0,BORDA,tamanho.y-BORDA,tamanho.y]
	for y in 3:
		for x in 3:
			if x == 1 and y == 1: continue
			item.draw_texture_rect_region(ATLAS,Rect2(origem+Vector2(destino_x[x],destino_y[y]),Vector2(destino_x[x+1]-destino_x[x],destino_y[y+1]-destino_y[y])),Rect2(Vector2(fonte[x],fonte[y]),Vector2(fonte[x+1]-fonte[x],fonte[y+1]-fonte[y])))
