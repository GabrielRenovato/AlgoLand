extends RefCounted
## Roupas em pixel art pintadas no modelo (modo pixel), no mesmo atlas e cilindros da pele
## (pele_pixel_3d.gd). Um PNG por modelo do catálogo; pode ser repintado à mão.
## Convenção dos texels: alfa 255 = tom relativo à cor do catálogo (rgb / NEUTRO);
## alfa 128 = cor própria (botão, fivela, sola), que não muda com a cor da peça.
const PELE := preload("res://codigo/jogador/pele_pixel_3d.gd")
const PASTA := "res://assets/personagens/base_3d/roupas_pixel_3d/"
const NEUTRO := PELE.NEUTRO
const OURO := Color(0.73, 0.57, 0.34)
const COURO_ESCURO := Color(0.24, 0.17, 0.15)
const SOLA := Color(0.20, 0.15, 0.16)
const CREME := Color(0.90, 0.80, 0.62)

static func caminho(id: String) -> String:
	return PASTA + id + ".png"

static func _tecido(fator: float) -> Color:
	var c := NEUTRO * fator
	return Color(clampf(c, 0, 1), clampf(c, 0, 1), clampf(c, 0, 1), 1.0)

static func _propria(cor: Color) -> Color:
	return Color(cor.r, cor.g, cor.b, 128.0 / 255.0)

## v do tronco a partir da altura de repouso (y da malha): quadril = 0, pescoço = 1.
static func v_tronco(y: float) -> float:
	return (y - 0.9167) / 0.571

## Tom de um texel. faixas: Vector2(v mínimo, v máximo) que a peça cobre em cada parte;
## passo: tamanho de 1 texel em v naquela parte (para bainhas de 1 texel).
static func tom(categoria: String, estilo: int, parte: String, u: float, v: float, faixas: Dictionary, passo: float) -> Color:
	var base := _tecido(1.0)
	var vinco := _tecido(0.80)
	var luz := _tecido(1.10)
	var perto := func(a: float, b: float, r: float) -> bool: return absf(a - b) <= r
	var frente := absf(u - 0.5) < 0.25
	if not faixas.has(parte): return base
	var f: Vector2 = faixas[parte]
	match categoria:
		"camisa":
			if parte == "tronco":
				if v < f.x + passo * 1.5: return vinco # Bainha.
				if v > f.y - passo * 1.5: return vinco # Gola.
				match estilo:
					0, 1:
						if perto.call(u, 0.5, 0.013) and v > v_tronco(1.335) and v < v_tronco(1.494): return vinco # Carcela.
						if perto.call(u, 0.5, 0.025) and (perto.call(v, v_tronco(1.445), passo * 0.6) or perto.call(v, v_tronco(1.385), passo * 0.6)): return _propria(OURO)
						if estilo == 1 and u > 0.36 and u < 0.45 and v > v_tronco(1.24) and v < v_tronco(1.34):
							return vinco if (perto.call(v, v_tronco(1.34), passo * 0.6) or perto.call(u, 0.36, 0.012) or perto.call(u, 0.45, 0.012)) else base # Bolso do peito.
					2:
						if v > v_tronco(1.055) and v < v_tronco(1.095):
							return _propria(OURO) if perto.call(u, 0.5, 0.03) else _propria(COURO_ESCURO) # Cinto e fivela.
					3:
						if perto.call(u, 0.5, 0.02): return _tecido(0.6) # Abertura da jaqueta.
						if v > v_tronco(1.05) and v < v_tronco(1.17) and (perto.call(absf(u - 0.5), 0.12, 0.05)):
							return vinco if perto.call(v, v_tronco(1.17), passo * 0.6) else base # Bolsos.
					4:
						if v > v_tronco(1.075) and v < v_tronco(1.11): return _propria(OURO) # Fita.
						if perto.call(absf(u - 0.5), 0.03, 0.025) and perto.call(v, v_tronco(1.43), passo): return _propria(CREME) # Laço.
					5:
						if perto.call(u, 0.5, 0.015): return _tecido(0.7) # Abertura.
						if perto.call(u, 0.53, 0.012) and fmod(v - v_tronco(1.13), 0.15) < passo: return _propria(CREME) # Botões.
				# Dobras curtas perto da barra.
				if frente and (perto.call(u, 0.40, 0.01) or perto.call(u, 0.60, 0.01)) and v < f.x + passo * 4 and v > f.x + passo * 2: return vinco
				return base
			if parte in ["braco", "antebraco"]:
				var ponta := f.y if not (faixas.has("antebraco") and parte == "braco") else INF
				if v > ponta - passo * 1.5: return vinco # Punho / fim da manga.
				if parte == "braco" and estilo == 4 and v < f.x + (f.y - f.x) * 0.5 and perto.call(fmod(u, 0.25), 0.0, 0.03): return vinco # Mangas bufantes: franzido.
				return base
			return base
		"calca":
			if parte == "tronco":
				if v > f.y - passo * 1.5: return _tecido(0.72) # Cós.
				if frente and perto.call(u, 0.5, 0.012) and v > f.y - passo * 5: return vinco # Braguilha.
				if estilo == 3 and fmod(u, 0.08) < 0.012: return vinco # Pregas.
				return base
			if parte in ["coxa", "canela"]:
				var ultima := "canela" if faixas.has("canela") else "coxa"
				if parte == ultima and v > f.y - passo * 1.5:
					return luz if estilo == 2 else vinco # Bainha (pescador: barra dobrada clara).
				if parte == ultima and estilo == 2 and v > f.y - passo * 3: return luz
				if (u < 0.03 or u > 0.97): return vinco # Costura de trás.
				if estilo == 1 and parte == "coxa" and u > 0.15 and u < 0.3 and v > 0.35 and v < 0.7:
					return vinco if (perto.call(u, 0.15, 0.02) or perto.call(u, 0.3, 0.02) or perto.call(v, 0.7, passo * 0.6) or perto.call(v, 0.35, passo * 0.6)) else base # Bolso cargo.
				if estilo == 3 and fmod(u, 0.08) < 0.012: return vinco # Pregas da saia.
				if parte == "canela" and frente and perto.call(v, 0.05, passo) and perto.call(u, 0.5, 0.08): return vinco # Dobra do joelho.
				return base
			return base
		"cabelo":
			if parte != "cabeca": return base
			# Mechas: faixas verticais de 1 texel alternando, mais escuras embaixo e na nuca;
			# brilho em arco no alto da cabeça, como na pintura à mão.
			var coluna := int(floor(u * 32.0))
			var altura := (v - f.x) / maxf(f.y - f.x, 0.001) # 0 = ponta de baixo, 1 = topo.
			if altura < 0.12: return _tecido(0.70) # Pontas.
			if altura > 0.70 and altura < 0.80 and frente and coluna % 3 != 0: return luz # Brilho.
			if coluna % 4 == 0 and altura < 0.85: return vinco # Separação das mechas.
			if coluna % 4 == 2 and altura < 0.45: return _tecido(0.88)
			if not frente and altura < 0.35: return _tecido(0.86) # Nuca mais escura.
			return base
		"calcado":
			if parte == "canela":
				if v < f.x + passo * 1.5: return _tecido(0.72) # Borda do cano.
				return base
			if parte == "pe":
				if u < 0.16 or u > 0.84: return _propria(SOLA) # Sola (o "frente" do pé é o peito do pé).
				if v > f.y - passo * 2.5: return luz # Biqueira.
				if estilo == 1 and perto.call(u, 0.5, 0.06) and v < 0.7 and fmod(v, passo * 2.0) < passo: return _propria(CREME) # Cadarço.
				if estilo == 3 and perto.call(v, 0.55, passo) and perto.call(u, 0.5, 0.1): return _propria(CREME) # Laço da sapatilha.
				return base
			return base
	return base

static func pintar(categoria: String, estilo: int, faixas: Dictionary) -> Image:
	var imagem := Image.create(PELE.TAMANHO.x, PELE.TAMANHO.y, false, Image.FORMAT_RGBA8)
	imagem.fill(_tecido(1.0))
	for parte in PELE.PARTES:
		var d: Dictionary = PELE.PARTES[parte]
		var tile: Rect2i = d.tile
		var faixa: Vector2 = d.v
		var passo := (faixa.y - faixa.x) / tile.size.y
		for y in tile.size.y:
			for x in tile.size.x:
				var u := (x + 0.5) / tile.size.x
				var v := faixa.x + (1.0 - (y + 0.5) / tile.size.y) * (faixa.y - faixa.x)
				imagem.set_pixel(tile.position.x + x, tile.position.y + y, tom(categoria, estilo, parte, u, v, faixas, passo))
	return imagem
