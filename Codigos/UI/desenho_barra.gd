extends RefCounted

# Barra montada com as peças de 16x8 do pack de plataforma: ponta esquerda, meio repetido, ponta direita
const PASTA := "res://UI/craftpix-net-420010-pixel-game-user-interface-for-platformer/4 Bars/"
const CHEIA: Array[Texture2D] = [preload(PASTA + "7.png"), preload(PASTA + "8.png"), preload(PASTA + "9.png")]
const VAZIA: Array[Texture2D] = [preload(PASTA + "10.png"), preload(PASTA + "11.png"), preload(PASTA + "12.png")]
const LARGURA_PECA := 16
const ALTURA := 8
const COR_RASTRO := Color(1.0, 0.92, 0.8)
# O pack só tem a barra vermelha; as outras cores saem de uma cópia em tons de cinza tingida
const BRILHO_CINZA := 2.4

static var _cheia_cinza: Array[Texture2D] = []

## largura em múltiplos de 16 (mínimo 32: as duas pontas). cor branca = vermelho original
static func desenhar(item: CanvasItem, origem: Vector2, largura: int, fracao: float, fracao_rastro: float, cor := Color.WHITE) -> void:
	var pecas := maxi(floori(largura / float(LARGURA_PECA)), 2)
	var total := pecas * LARGURA_PECA
	var px_vida := roundi(total * clampf(fracao, 0.0, 1.0))
	var px_rastro := roundi(total * clampf(fracao_rastro, 0.0, 1.0))
	var cheia := CHEIA if cor == Color.WHITE else _pecas_cinza()
	for i in pecas:
		var tipo := 0 if i == 0 else (2 if i == pecas - 1 else 1)
		var x := i * LARGURA_PECA
		var pos := origem + Vector2(x, 0)
		item.draw_texture(VAZIA[tipo], pos)
		_desenhar_corte(item, cheia[tipo], pos, px_vida - x, cor)
	# Modulate só escurece a peça vermelha, então o rastro claro é um retângulo no miolo (sem a borda de 1px)
	if px_rastro > px_vida:
		var inicio := maxi(px_vida, 1)
		var fim := mini(px_rastro, total - 1)
		if fim > inicio:
			item.draw_rect(Rect2(origem + Vector2(inicio, 1), Vector2(fim - inicio, ALTURA - 2)), COR_RASTRO)

static func _desenhar_corte(item: CanvasItem, textura: Texture2D, pos: Vector2, largura: int, cor: Color) -> void:
	if largura <= 0:
		return
	var w := mini(largura, LARGURA_PECA)
	item.draw_texture_rect_region(textura, Rect2(pos, Vector2(w, ALTURA)), Rect2(0, 0, w, ALTURA), cor)

static func _pecas_cinza() -> Array[Texture2D]:
	if _cheia_cinza.is_empty():
		for textura in CHEIA:
			var imagem := textura.get_image()
			imagem.convert(Image.FORMAT_RGBA8)
			for y in imagem.get_height():
				for x in imagem.get_width():
					var c := imagem.get_pixel(x, y)
					var v := minf(c.get_luminance() * BRILHO_CINZA, 1.0)
					imagem.set_pixel(x, y, Color(v, v, v, c.a))
			_cheia_cinza.append(ImageTexture.create_from_image(imagem))
	return _cheia_cinza
