extends RefCounted
## Converte o Raven 2D em 3D: fotografa a aparência real do jogador nas quatro
## direções (repouso), cruza as silhuetas frontal e lateral para obter o volume,
## gera uma superfície lisa e projeta nela os próprios sprites.
## Eixos do modelo: +X direita da tela (vista de frente), +Y para cima, +Z frente.
const CELULA := 80
const PIVO := Vector2i(40, 47)
const CELULA_ARMA := 40
# Linhas do corpo base Raven (células 80×80, repouso de frente).
const PESCOCO := 32 # Última linha da cabeça.
const COTOVELO := 37
const QUADRIL := 40
const JOELHO := 44
const FIM_BRACO := 41
const BRACO_ESQ_MAX := 35 # Colunas ≤ isto, entre ombro e fim do braço: braço da esquerda.
const BRACO_DIR_MIN := 45
const PROFUNDIDADE_BRACO := 2.5
const SUBDIVISAO := 1 # Cubos por pixel do sprite (2 = Scale2x, contorno mais redondo).
# Cubos: cada vista reta reproduz o sprite pixel a pixel. Lisa: Surface Nets.
const SUPERFICIE_LISA := false
const EXPOENTE := 4.0 # Arredonda os cantos do corte (superelipse).
const PROFUNDIDADE := 1.0 # Fração da profundidade lateral mantida.

## Articulações em unidades de voxel (y=0 é a sola).
const ARTICULACOES := {
	"tronco": Vector3(0, 7, 0), "cabeca": Vector3(0, 14, 0),
	"braco_e": Vector3(-5, 14, 0), "antebraco_e": Vector3(-5.5, 10, 0),
	"braco_d": Vector3(5.5, 14, 0), "antebraco_d": Vector3(6, 10, 0),
	"perna_e": Vector3(-2.5, 7, 0), "canela_e": Vector3(-2.5, 3, 0),
	"perna_d": Vector3(2.5, 7, 0), "canela_d": Vector3(2.5, 3, 0),
}
const DIRECOES_FACE := [Vector3i(1,0,0), Vector3i(-1,0,0), Vector3i(0,1,0),
	Vector3i(0,-1,0), Vector3i(0,0,1), Vector3i(0,0,-1)]

const CAMADAS_CABELO := ["Camada6", "Camada9"] # Cabelo e elmo do compositor Raven.

## Devolve {"corpo": [...], "cabelo": [...]}, cada um com [baixo, direita, cima,
## esquerda] em 80×80 RGBA. O cabelo vira uma casca separada sobre a cabeça.
static func capturar(raven: Node, pai: Node) -> Dictionary:
	var fotos := {"corpo": [], "cabelo": []}
	for direcao in 4:
		for tipo in ["corpo", "cabelo"]:
			var previa: Sprite2D = raven.criar_previa(direcao)
			previa.position = Vector2(PIVO)
			for filho in previa.get_children():
				var cabelo: bool = filho.name in CAMADAS_CABELO
				filho.visible = cabelo if tipo == "cabelo" else not cabelo
			if tipo == "cabelo":
				previa.self_modulate.a = 0.0
			fotos[tipo].append(await _fotografar(previa, Vector2i(CELULA, CELULA), pai))
	return fotos

## Fotografa a arma do porte (textura e material de nível) sem rotação.
static func capturar_arma(textura: Texture2D, material: Material, pai: Node) -> Image:
	var sprite := Sprite2D.new()
	sprite.texture = textura
	sprite.material = material
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position = Vector2(CELULA_ARMA, CELULA_ARMA)/2.0
	return await _fotografar(sprite, Vector2i(CELULA_ARMA, CELULA_ARMA), pai)

static func _fotografar(no: CanvasItem, tamanho: Vector2i, pai: Node) -> Image:
	var vp := SubViewport.new()
	vp.size = tamanho
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	pai.add_child(vp)
	vp.add_child(no)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	vp.queue_free()
	return img

	# --- Volume -------------------------------------------------------------------

## Remove o contorno escuro externo (o shader 2D devolve um contorno limpo depois).
static func _sem_contorno(img: Image) -> Image:
	var limpa := img.duplicate() as Image
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a < 0.5 or c.get_luminance() > 0.2:
				continue
			for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
				if not _opaco(img, x+d.x, y+d.y):
					limpa.set_pixel(x, y, Color.TRANSPARENT)
					break
	return limpa

static func _opaco(img: Image, x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height() and img.get_pixel(x, y).a >= 0.5

static func _parte(px: int, py: int) -> String:
	if py <= PESCOCO:
		return "cabeca"
	var lado := ""
	if py <= FIM_BRACO and px <= BRACO_ESQ_MAX:
		lado = "e"
	elif py <= FIM_BRACO and px >= BRACO_DIR_MIN:
		lado = "d"
	if not lado.is_empty():
		return ("antebraco_" if py >= COTOVELO else "braco_")+lado
	if py < QUADRIL:
		return "tronco"
	lado = "e" if px < PIVO.x else "d"
	return ("canela_" if py >= JOELHO else "perna_")+lado

## Monta as malhas por parte: {parte: [[ArrayMesh, Material], ...]}, com vértices
## relativos à articulação da parte (ARTICULACOES). O volume vem do corte por
## silhuetas; a superfície é lisa (Surface Nets) e recebe os próprios sprites
## projetados, pixel a pixel, conforme o lado para onde aponta.
static func montar(fotos: Dictionary) -> Dictionary:
	var f := SUBDIVISAO
	var silhuetas := {}
	var materiais := {}
	for camada in ["corpo", "cabelo"]:
		var ampliadas: Array[Image] = []
		var texturas: Array[Image] = []
		for foto in fotos[camada]:
			var limpa := _sem_contorno(foto)
			var vazada := _sangrar(limpa)
			ampliadas.append(_ampliar(limpa) if SUBDIVISAO == 2 else limpa)
			texturas.append(_ampliar(vazada) if SUBDIVISAO == 2 else vazada)
		silhuetas[camada] = ampliadas
		materiais[camada] = _material(texturas)
	var corpo := {}
	var cabelo := {}
	_volume(silhuetas.corpo, "", corpo)
	# Cabelo: casca própria, presa à cabeça; a cabeça careca some por baixo dele.
	_volume(silhuetas.cabelo, "cabeca", cabelo, silhuetas.corpo)
	for v in cabelo:
		corpo.erase(v)
	var resultado := {}
	for camada in ["corpo", "cabelo"]:
		var ocupacao: Dictionary = corpo if camada == "corpo" else cabelo
		var por_parte := {}
		for v in ocupacao:
			var parte: String = ocupacao[v]
			if not por_parte.has(parte):
				por_parte[parte] = {}
			por_parte[parte][v] = true
		for parte in por_parte:
			var malha := _superficie(por_parte[parte], ARTICULACOES[parte]*f, 1.0/f) if SUPERFICIE_LISA \
				else _cubos(por_parte[parte], ARTICULACOES[parte]*f, 1.0/f)
			if malha == null:
				continue
			if not resultado.has(parte):
				resultado[parte] = []
			resultado[parte].append([malha, materiais[camada]])
	return resultado

## Material que projeta as quatro fotos (ampliadas e com cor vazada nas bordas).
static func _material(texturas: Array[Image]) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://codigo/jogador/projecao_raven.gdshader")
	for i in 4:
		var img := texturas[i]
		m.set_shader_parameter(["frente", "direita", "costas", "esquerda"][i], ImageTexture.create_from_image(img))
	m.set_shader_parameter("celula", float(CELULA*SUBDIVISAO))
	m.set_shader_parameter("pivo", Vector2(PIVO*SUBDIVISAO))
	return m

## Estende as cores das bordas para fora da silhueta: a superfície lisa passa
## um pouco além dos pixels e não pode buscar transparente.
static func _sangrar(img: Image) -> Image:
	var atual := img
	for passo in 2:
		var proxima := atual.duplicate() as Image
		for y in atual.get_height():
			for x in atual.get_width():
				if atual.get_pixel(x, y).a >= 0.5:
					continue
				for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
					if _opaco(atual, x+d.x, y+d.y):
						proxima.set_pixel(x, y, atual.get_pixel(x+d.x, y+d.y))
						break
		atual = proxima
	return atual

## Cubos com as mesmas coordenadas de projeção da superfície lisa: de frente,
## de costas e de lado, sem inclinação, a imagem é o próprio sprite.
static func _cubos(dentro: Dictionary, pivo: Vector3, escala: float) -> ArrayMesh:
	if dentro.is_empty():
		return null
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for v in dentro:
		for d in DIRECOES_FACE:
			if dentro.has(v+d):
				continue
			var n := Vector3(d)
			var eixo := 0 if d.x != 0 else (1 if d.y != 0 else 2)
			var u := Vector3.ZERO
			u[(eixo+1) % 3] = 1.0
			var w := Vector3.ZERO
			w[(eixo+2) % 3] = 1.0
			var origem := Vector3(v)
			if n[eixo] > 0.0:
				origem[eixo] += 1.0
			for canto in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 0), Vector2(1, 1), Vector2(0, 1)]:
				var p: Vector3 = origem+u*canto.x+w*canto.y
				st.set_normal(n)
				st.set_uv(Vector2(p.x, p.y))
				st.set_uv2(Vector2(p.z, 0.0))
				st.add_vertex((p-pivo)*escala)
	return st.commit()

## Surface Nets: um vértice por célula cortada pela superfície, no centro médio
## dos cruzamentos; uma face por aresta entre dentro e fora. Normais pelo
## gradiente da ocupação suavizada; vértices também guardam a posição do modelo
## (UV = x,y e UV2.x = z, em unidades ampliadas) para a projeção dos sprites.
static func _superficie(dentro: Dictionary, pivo: Vector3, escala: float) -> ArrayMesh:
	if dentro.is_empty():
		return null
	# Só as células vizinhas de voxels da borda podem ser cortadas pela superfície.
	var candidatas := {}
	for v in dentro:
		var borda := false
		for d in DIRECOES_FACE:
			if not dentro.has(v+d):
				borda = true
				break
		if borda:
			for i in 8:
				candidatas[v-Vector3i(i & 1, (i >> 1) & 1, (i >> 2) & 1)] = true
	var vertices := {} # célula -> índice
	var posicoes := PackedVector3Array()
	var normais := PackedVector3Array()
	for c in candidatas:
		var soma := Vector3.ZERO
		var cruzamentos := 0
		var gradiente := Vector3.ZERO
		var cantos := 0
		for i in 8:
			var o := Vector3i(i & 1, (i >> 1) & 1, (i >> 2) & 1)
			if dentro.has(c+o):
				cantos += 1
				gradiente += Vector3(o)-Vector3(0.5, 0.5, 0.5)
		if cantos == 0 or cantos == 8:
			continue
		for eixo in 3:
			for i in 4:
				var a := Vector3i.ZERO
				a[(eixo+1) % 3] = i & 1
				a[(eixo+2) % 3] = (i >> 1) & 1
				var b := a
				b[eixo] = 1
				if dentro.has(c+a) != dentro.has(c+b):
					soma += (Vector3(a)+Vector3(b))*0.5
					cruzamentos += 1
		vertices[c] = posicoes.size()
		# Centros de voxel ficam em v+0,5 (mesma convenção do corte).
		posicoes.append(Vector3(c)+soma/cruzamentos+Vector3(0.5, 0.5, 0.5))
		normais.append(-gradiente.normalized() if gradiente.length() > 0.01 else Vector3.UP)
	# Suaviza as normais com as vizinhas (3×3×3) para a luz não marcar degraus.
	var suaves := PackedVector3Array()
	suaves.resize(normais.size())
	for c in vertices:
		var n := Vector3.ZERO
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				for dz in [-1, 0, 1]:
					var vizinho = vertices.get(c+Vector3i(dx, dy, dz))
					if vizinho != null:
						n += normais[vizinho]
		suaves[vertices[c]] = n.normalized()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for v in dentro:
		for eixo in 3:
			var passo := Vector3i.ZERO
			passo[eixo] = 1
			var fora_frente := not dentro.has(v+passo)
			var fora_tras := not dentro.has(v-passo)
			for lado in [1, -1]:
				if (lado == 1 and not fora_frente) or (lado == -1 and not fora_tras):
					continue
				# Aresta entre v e v+lado*passo: as quatro células que a tocam.
				var base: Vector3i = v if lado == 1 else v-passo
				var u := Vector3i.ZERO
				u[(eixo+1) % 3] = 1
				var w := Vector3i.ZERO
				w[(eixo+2) % 3] = 1
				var celulas := [base-u-w, base-w, base, base-u]
				var ids := []
				for cel in celulas:
					var indice = vertices.get(cel)
					if indice == null:
						break
					ids.append(indice)
				if ids.size() < 4:
					continue
				if lado == -1:
					ids.reverse()
				for k in [0, 1, 2, 0, 2, 3]:
					var p: Vector3 = posicoes[ids[k]]
					st.set_normal(suaves[ids[k]])
					st.set_uv(Vector2(p.x, p.y))
					st.set_uv2(Vector2(p.z, 0.0))
					st.add_vertex((p-pivo)*escala)
	return st.commit()

## Corta o volume de um conjunto de fotos e grava voxels/cores (sobrescreve).
## reserva: fotos do corpo; dão a profundidade das linhas em que o perfil não
## mostra a casca (cabelo comprido que desce pelas costas).
static func _volume(fotos: Array, parte_fixa: String, voxels: Dictionary, reserva: Array = []) -> void:
	var f := SUBDIVISAO
	var frente: Image = fotos[0]
	var direita: Image = fotos[1]
	var costas: Image = fotos[2]
	var esquerda: Image = fotos[3]
	var n := CELULA*f
	var pivo := PIVO*f
	for py in range(0, n):
		var iy := pivo.y-1-py
		# Silhuetas desta linha.
		var em_x := PackedByteArray()
		em_x.resize(n)
		var em_z := PackedByteArray()
		em_z.resize(n)
		var tem := false
		for i in n:
			em_x[i] = 1 if (_opaco(frente, i, py) or _opaco(costas, n-1-i, py)) else 0
			em_z[i] = 1 if (_opaco(direita, i, py) or _opaco(esquerda, n-1-i, py)) else 0
			tem = tem or em_x[i] == 1
		if not tem:
			continue
		var z_min := n
		var z_max := -1
		for i in n:
			if em_z[i] == 1:
				z_min = mini(z_min, i)
				z_max = maxi(z_max, i)
		var sem_perfil := false
		if not reserva.is_empty() and (z_max < 0 or py/f > PESCOCO):
			sem_perfil = true
			z_min = n
			z_max = -1
			for i in n:
				em_z[i] = 1 if (_opaco(reserva[1], i, py) or _opaco(reserva[3], n-1-i, py)) else 0
				if em_z[i] == 1:
					z_min = mini(z_min, i)
					z_max = maxi(z_max, i)
		if z_max < 0:
			continue
		var zc := (z_min+z_max+1)/2.0
		var rz := (z_max-z_min+1)/2.0
		for i in n:
			if em_x[i] == 0:
				continue
			var parte := _parte(i/f, py/f)
			if not parte_fixa.is_empty():
				# Abaixo do pescoço a casca acompanha o tronco, não a cabeça.
				parte = parte_fixa if py/f <= PESCOCO else "tronco"
			# Trecho contínuo da mesma parte na silhueta frontal.
			var a := i
			while a > 0 and em_x[a-1] == 1 and (not parte_fixa.is_empty() or _parte((a-1)/f, py/f) == parte):
				a -= 1
			var b := i
			while b < n-1 and em_x[b+1] == 1 and (not parte_fixa.is_empty() or _parte((b+1)/f, py/f) == parte):
				b += 1
			var xc := (a+b+1)/2.0
			var rx := (b-a+1)/2.0
			var braco := parte.contains("braco")
			for k in range(z_min, z_max+1):
				if em_z[k] == 0:
					continue
				var zf := k+0.5
				var dz := (zf-zc)/(rz*PROFUNDIDADE)
				if braco:
					dz = (zf-pivo.x)/(PROFUNDIDADE_BRACO*f)
					if absf(dz) > 1.0:
						continue
				var dx := (i+0.5-xc)/rx
				if pow(absf(dx), EXPOENTE)+pow(absf(dz), EXPOENTE) > 1.05:
					continue
				# Casca (cabelo/elmo): cada metade obedece só à vista que a mostra,
				# senão a nuca, toda de cabelo, tampa o rosto na frente.
				if not parte_fixa.is_empty():
					var vista_z := _opaco(frente, i, py) if zf >= zc else _opaco(costas, n-1-i, py)
					var vista_x := sem_perfil or (_opaco(direita, k, py) if i+0.5 < pivo.x else _opaco(esquerda, n-1-k, py))
					if not (vista_z and vista_x):
						continue
				var v := Vector3i(i-pivo.x, iy, k-pivo.x)
				voxels[v] = parte

## Scale2x (EPX): dobra a imagem preservando bordas de pixel art.
static func _ampliar(img: Image) -> Image:
	var l := img.get_width()
	var h := img.get_height()
	var saida := Image.create(l*2, h*2, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in l:
			var p := img.get_pixel(x, y)
			var a := img.get_pixel(x, maxi(y-1, 0))
			var b := img.get_pixel(mini(x+1, l-1), y)
			var c := img.get_pixel(maxi(x-1, 0), y)
			var d := img.get_pixel(x, mini(y+1, h-1))
			saida.set_pixel(x*2, y*2, a if (c == a and c != d and a != b) else p)
			saida.set_pixel(x*2+1, y*2, b if (a == b and a != c and b != d) else p)
			saida.set_pixel(x*2, y*2+1, c if (d == c and d != b and c != a) else p)
			saida.set_pixel(x*2+1, y*2+1, d if (b == d and b != a and d != c) else p)
	return saida

## Cor do pixel ou do vizinho opaco mais próximo na mesma linha.
static func _cor(img: Image, x: int, y: int) -> Color:
	for d in [0, 1, -1, 2, -2, 3, -3, 4, -4, 5, -5]:
		if _opaco(img, x+d, y):
			return img.get_pixel(x+d, y)
	return Color(0, 0, 0, 0)

static func _faces(st: SurfaceTool, v: Vector3i, voxels: Dictionary, c: Array, pivo: Vector3, escala := 1.0) -> void:
	var parte: String = voxels[v]
	for d in DIRECOES_FACE:
		var vizinho: Vector3i = v+d
		if voxels.get(vizinho, "") == parte:
			continue
		var cor: Color
		if d.z == 1: cor = c[0]
		elif d.z == -1: cor = c[1]
		elif d.x == -1: cor = c[2]
		elif d.x == 1: cor = c[3]
		else:
			# Topo/base: a vista mais próxima da superfície (frente ou costas).
			cor = c[0] if c[4] <= c[5] else c[1]
		if cor.a < 0.5:
			for alternativa in [c[0], c[1], c[2], c[3]]:
				if alternativa.a >= 0.5:
					cor = alternativa
					break
		cor.a = 1.0
		_quad(st, Vector3(v)-pivo, d, cor, escala)

static func _quad(st: SurfaceTool, base: Vector3, d: Vector3i, cor: Color, escala := 1.0) -> void:
	var n := Vector3(d)
	# Quatro cantos da face do cubo [base, base+1], em ordem anti-horária vista de fora.
	var u: Vector3
	var w: Vector3
	var origem := base
	if d.x != 0:
		u = Vector3(0, 0, 1); w = Vector3(0, 1, 0)
		origem.x += 1.0 if d.x > 0 else 0.0
		if d.x < 0: u = Vector3(0, 1, 0); w = Vector3(0, 0, 1)
	elif d.y != 0:
		u = Vector3(1, 0, 0); w = Vector3(0, 0, 1)
		origem.y += 1.0 if d.y > 0 else 0.0
		if d.y < 0: u = Vector3(0, 0, 1); w = Vector3(1, 0, 0)
	else:
		u = Vector3(0, 1, 0); w = Vector3(1, 0, 0)
		origem.z += 1.0 if d.z > 0 else 0.0
		if d.z < 0: u = Vector3(1, 0, 0); w = Vector3(0, 1, 0)
	var p0 := origem
	var p1 := origem+u
	var p2 := origem+u+w
	var p3 := origem+w
	st.set_normal(n)
	st.set_color(cor)
	for p in [p0, p1, p2, p0, p2, p3]:
		st.add_vertex(p*escala)

## Placa de voxels (1 de espessura) a partir da foto da arma, centrada na célula.
static func montar_arma(img: Image) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var voxels := {}
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a >= 0.5:
				voxels[Vector3i(x-CELULA_ARMA/2, CELULA_ARMA/2-1-y, 0)] = "arma"
	for v in voxels:
		var c := img.get_pixel(v.x+CELULA_ARMA/2, CELULA_ARMA/2-1-v.y)
		_faces(st, v, voxels, [c, c, c.darkened(0.15), c.darkened(0.15), 0.0, 1.0], Vector3(0, 0, 0.5))
	return st.commit()
