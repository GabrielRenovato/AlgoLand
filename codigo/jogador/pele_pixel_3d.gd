extends RefCounted
## Pele em pixel art pintada no próprio modelo (modo pixel).
## Cada parte do corpo ganha um cilindro de UV em volta do seu osso, no repouso: u dá a volta
## (frente no meio, emenda nas costas) e v corre ao longo do osso. A textura é pequena
## (1 texel ≈ 1 pixel do personagem na grade 2×) e guarda só a variação de tom: a cor da
## pele continua vindo de pele_base. Não altera posição, normal, pesos nem rig.
const TEXTURA := "res://assets/personagens/base_3d/pele_pixel/pele.png"
const TAMANHO := Vector2i(64, 64)
const NEUTRO := 0.784 # Texel neutro: o shader divide por este valor.
## Malhas com o UV pixel já calculado (gerar_roupas_pixel.gd): no jogo só carregam. O cálculo por
## triângulo em GDScript levava ~0,2 s no PC e segundos no Android a cada troca de mapa.
const PASTA_MALHAS := "res://assets/personagens/base_3d/pele_pixel/malhas/"

static func assinatura(malha: Mesh) -> String:
	if malha == null or malha.get_surface_count() == 0: return "vazia"
	var total := 0
	for s in malha.get_surface_count(): total += malha.surface_get_array_len(s)
	var caixa := malha.get_aabb()
	return "%d|%.4f|%.4f|%.4f|%.4f|%.4f|%.4f" % [total, caixa.position.x, caixa.position.y, caixa.position.z, caixa.size.x, caixa.size.y, caixa.size.z]

static func caminho_malha(nome: String) -> String:
	return PASTA_MALHAS + nome + ".res"

## Malha pronta salva para esta origem; null se não existir ou se a origem mudou (aí recalcula).
static func malha_pronta(nome: String, origem: Mesh) -> ArrayMesh:
	var caminho := caminho_malha(nome)
	if not ResourceLoader.exists(caminho): return null
	var pronta := load(caminho) as ArrayMesh
	if pronta == null or str(pronta.get_meta("origem", "")) != assinatura(origem): return null
	return pronta

static func guardar_malha(nome: String, origem: Mesh, pronta: ArrayMesh) -> void:
	pronta.set_meta("origem", assinatura(origem))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PASTA_MALHAS))
	ResourceSaver.save(pronta, caminho_malha(nome), ResourceSaver.FLAG_COMPRESS)

## UV pixel de uma peça (roupa/cabelo), da malha salva quando houver.
static func com_uv_pixel_salvo(nome: String, malha: ArrayMesh, instancia: MeshInstance3D, esqueleto: Skeleton3D) -> ArrayMesh:
	var pronta := malha_pronta(nome, malha)
	return pronta if pronta != null else com_uv_pixel(malha, instancia, esqueleto)

# Partes: retângulo no atlas, juntas do eixo (sufixo .L/.R quando lateral), faixa de v
# coberta pelos triângulos e referência de "frente" para o ângulo.
const PARTES := {
	"tronco": {"tile": Rect2i(0, 0, 40, 36), "de": "DEF-hips", "ate": "DEF-neck", "v": Vector2(-0.35, 1.25), "frente": Vector3.BACK, "lado": false},
	"braco": {"tile": Rect2i(40, 0, 12, 14), "de": "DEF-upper_arm", "ate": "DEF-forearm", "v": Vector2(-0.2, 1.1), "frente": Vector3.BACK, "lado": true},
	"antebraco": {"tile": Rect2i(52, 0, 12, 14), "de": "DEF-forearm", "ate": "DEF-hand", "v": Vector2(-0.1, 1.1), "frente": Vector3.BACK, "lado": true},
	"mao": {"tile": Rect2i(40, 14, 10, 10), "de": "DEF-hand", "ate": "DEF-f_middle.01", "v": Vector2(-0.2, 2.2), "frente": Vector3.BACK, "lado": true},
	"pe": {"tile": Rect2i(50, 14, 12, 15), "de": "DEF-foot", "ate": "DEF-toe", "v": Vector2(-0.4, 1.8), "frente": Vector3.UP, "lado": true},
	"coxa": {"tile": Rect2i(0, 36, 18, 14), "de": "DEF-thigh", "ate": "DEF-shin", "v": Vector2(-0.15, 1.1), "frente": Vector3.BACK, "lado": true},
	"canela": {"tile": Rect2i(18, 36, 14, 20), "de": "DEF-shin", "ate": "DEF-foot", "v": Vector2(-0.1, 1.1), "frente": Vector3.BACK, "lado": true},
	# Cabelos 3D: cilindro em volta do eixo pescoço→cabeça (o osso da cabeça não tem filho).
	"cabeca": {"tile": Rect2i(32, 36, 32, 28), "de": "DEF-neck", "ate": "DEF-head", "v": Vector2(-3.2, 5.0), "frente": Vector3.BACK, "lado": false},
}

static func parte_do_osso(nome: String) -> String:
	var base := nome.trim_suffix(".L").trim_suffix(".R")
	if base == "DEF-head": return "cabeca"
	if base in ["DEF-hips", "DEF-spine.001", "DEF-spine.002", "DEF-spine.003", "DEF-neck", "DEF-shoulder"]: return "tronco"
	if base == "DEF-upper_arm": return "braco"
	if base == "DEF-forearm": return "antebraco"
	if base == "DEF-hand" or base.begins_with("DEF-f_") or base.begins_with("DEF-thumb"): return "mao"
	if base == "DEF-thigh": return "coxa"
	if base == "DEF-shin": return "canela"
	if base == "DEF-foot" or base == "DEF-toe": return "pe"
	return "tronco"

## u ∈ [0,1] (frente = 0,5) e v ao longo do osso, sem normalizar para o atlas.
static func cilindro(p: Vector3, j0: Vector3, j1: Vector3, frente_ref: Vector3) -> Vector2:
	var eixo := (j1 - j0).normalized()
	var frente := (frente_ref - eixo * frente_ref.dot(eixo)).normalized()
	var lado := eixo.cross(frente)
	var r := p - j0
	var u := atan2(r.dot(lado), r.dot(frente)) / TAU + 0.5
	return Vector2(u, r.dot(eixo) / (j1 - j0).length())

static func no_atlas(parte: String, uv: Vector2) -> Vector2:
	var d: Dictionary = PARTES[parte]
	var tile: Rect2i = d.tile
	var faixa: Vector2 = d.v
	var u := clampf(uv.x, 0.5 / tile.size.x, 1.0 - 0.5 / tile.size.x)
	var vn := clampf((uv.y - faixa.x) / (faixa.y - faixa.x), 0.5 / tile.size.y, 1.0 - 0.5 / tile.size.y)
	return (Vector2(tile.position) + Vector2(u * tile.size.x, (1.0 - vn) * tile.size.y)) / Vector2(TAMANHO)

static func juntas_na_malha(instancia: MeshInstance3D, esqueleto: Skeleton3D) -> Dictionary:
	var para_malha := instancia.global_transform.affine_inverse() * esqueleto.global_transform
	var juntas := {}
	for osso in esqueleto.get_bone_count():
		juntas[esqueleto.get_bone_name(osso)] = para_malha * esqueleto.get_bone_global_rest(osso).origin
	return juntas

static func nomes_dos_binds(instancia: MeshInstance3D, esqueleto: Skeleton3D) -> Array[String]:
	var nomes: Array[String] = []
	for b in instancia.skin.get_bind_count():
		var nome := String(instancia.skin.get_bind_name(b))
		nomes.append(nome if nome != "" else esqueleto.get_bone_name(instancia.skin.get_bind_bone(b)))
	return nomes

## Parte e coordenadas de cilindro (u, v sem normalizar) dos 3 vértices de um triângulo.
static func triangulo(posicoes: Array, ossos: PackedInt32Array, pesos: PackedFloat32Array, indices: Array, nomes: Array[String], juntas: Dictionary) -> Dictionary:
	var soma := {}
	for i in indices:
		for j in 4:
			var b := ossos[i * 4 + j]
			soma[b] = soma.get(b, 0.0) + pesos[i * 4 + j]
	var dominante: int = soma.keys().reduce(func(x, y): return x if soma[x] > soma[y] else y)
	var nome_osso := nomes[dominante]
	var parte := parte_do_osso(nome_osso)
	var d: Dictionary = PARTES[parte]
	var sufixo := ".R" if nome_osso.ends_with(".R") else ".L"
	var de: String = d.de + (sufixo if d.lado else "")
	var ate: String = d.ate + (sufixo if d.lado else "")
	var cil: Array[Vector2] = []
	for p in posicoes:
		var c := cilindro(p, juntas[de], juntas[ate], d.frente)
		if sufixo == ".R" and d.lado: c.x = 1.0 - c.x # Espelha: o lado de fora fica igual nos dois.
		cil.append(c)
	# Triângulo na emenda das costas: leva tudo para o mesmo lado.
	var menor := minf(cil[0].x, minf(cil[1].x, cil[2].x))
	var maior := maxf(cil[0].x, maxf(cil[1].x, cil[2].x))
	if maior - menor > 0.5:
		for k in 3:
			if cil[k].x < 0.5: cil[k].x += 1.0
		for k in 3: cil[k].x = minf(cil[k].x, 1.0)
	return {"parte": parte, "cil": cil}

## Roupas: mesmo atlas e mesmos cilindros da pele, gravados em CUSTOM0 (o UV/UV2 da peça
## continuam com as coordenadas de costura que os cortes e o "esconder pele" usam).
static func com_uv_pixel(malha: ArrayMesh, instancia: MeshInstance3D, esqueleto: Skeleton3D) -> ArrayMesh:
	var juntas := juntas_na_malha(instancia, esqueleto)
	var nomes := nomes_dos_binds(instancia, esqueleto)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_custom_format(0, SurfaceTool.CUSTOM_RG_FLOAT)
	for superficie in malha.get_surface_count():
		var a := malha.surface_get_arrays(superficie)
		var vertices: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var ossos: PackedInt32Array = a[Mesh.ARRAY_BONES]
		var pesos: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
		var indices: PackedInt32Array = a[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			for i in vertices.size(): indices.append(i)
		for t in range(0, indices.size(), 3):
			var tri := [indices[t], indices[t + 1], indices[t + 2]]
			var r := triangulo(tri.map(func(i): return vertices[i]), ossos, pesos, tri, nomes, juntas)
			for k in 3:
				var i: int = tri[k]
				var uv := no_atlas(r.parte, r.cil[k])
				if a[Mesh.ARRAY_NORMAL] != null: st.set_normal(a[Mesh.ARRAY_NORMAL][i])
				if a[Mesh.ARRAY_COLOR] != null: st.set_color(a[Mesh.ARRAY_COLOR][i])
				if a[Mesh.ARRAY_TEX_UV] != null: st.set_uv(a[Mesh.ARRAY_TEX_UV][i])
				if a[Mesh.ARRAY_TEX_UV2] != null: st.set_uv2(a[Mesh.ARRAY_TEX_UV2][i])
				st.set_custom(0, Color(uv.x, uv.y, 0, 0))
				st.set_bones(ossos.slice(i * 4, i * 4 + 4))
				st.set_weights(pesos.slice(i * 4, i * 4 + 4))
				st.add_vertex(vertices[i])
	st.index()
	return st.commit()

## Faixa de v (unidades do cilindro) que a peça ocupa em cada parte: barras e bainhas.
static func extensoes(malha: ArrayMesh, instancia: MeshInstance3D, esqueleto: Skeleton3D) -> Dictionary:
	var juntas := juntas_na_malha(instancia, esqueleto)
	var nomes := nomes_dos_binds(instancia, esqueleto)
	var faixas := {}
	for superficie in malha.get_surface_count():
		var a := malha.surface_get_arrays(superficie)
		var vertices: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = a[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			for i in vertices.size(): indices.append(i)
		for t in range(0, indices.size(), 3):
			var tri := [indices[t], indices[t + 1], indices[t + 2]]
			var r := triangulo(tri.map(func(i): return vertices[i]), a[Mesh.ARRAY_BONES], a[Mesh.ARRAY_WEIGHTS], tri, nomes, juntas)
			var f: Vector2 = faixas.get(r.parte, Vector2(INF, -INF))
			for c in r.cil: f = Vector2(minf(f.x, c.y), maxf(f.y, c.y))
			faixas[r.parte] = f
	return faixas

static func aplicar(corpo: MeshInstance3D, esqueleto: Skeleton3D) -> void:
	var pronta := malha_pronta("corpo", corpo.mesh)
	corpo.mesh = pronta if pronta != null else malha_do_corpo(corpo, esqueleto)
	var m: ShaderMaterial = corpo.material_override
	m.set_shader_parameter("desenho_pixel_corpo", false)
	m.set_shader_parameter("pele_pixel", true)
	m.set_shader_parameter("textura_pele_pixel", load(TEXTURA))

static func malha_do_corpo(corpo: MeshInstance3D, esqueleto: Skeleton3D) -> ArrayMesh:
	var juntas := juntas_na_malha(corpo, esqueleto)
	var nomes := nomes_dos_binds(corpo, esqueleto)
	var base := corpo.mesh as ArrayMesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for superficie in base.get_surface_count():
		var a := base.surface_get_arrays(superficie)
		var vertices: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var cores: PackedColorArray = a[Mesh.ARRAY_COLOR]
		var ossos: PackedInt32Array = a[Mesh.ARRAY_BONES]
		var pesos: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
		var uvs_antigos = a[Mesh.ARRAY_TEX_UV]
		var indices: PackedInt32Array = a[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			for i in vertices.size(): indices.append(i)
		for t in range(0, indices.size(), 3):
			var cor: Color = (cores[indices[t]] + cores[indices[t + 1]] + cores[indices[t + 2]]) / 3.0
			var uvs: Array[Vector2] = []
			if cor.r > .25 and cor.r < .75:
				# Cabeça: mantém o UV original (rosto/cabelo usam outra pintura).
				for k in 3: uvs.append(uvs_antigos[indices[t + k]] if uvs_antigos != null else Vector2.ZERO)
			else:
				var tri := [indices[t], indices[t + 1], indices[t + 2]]
				var r := triangulo(tri.map(func(i): return vertices[i]), ossos, pesos, tri, nomes, juntas)
				for k in 3: uvs.append(no_atlas(r.parte, r.cil[k]))
			for k in 3:
				var i := indices[t + k]
				st.set_normal(a[Mesh.ARRAY_NORMAL][i])
				st.set_color(cores[i])
				st.set_uv(uvs[k])
				st.set_uv2(a[Mesh.ARRAY_TEX_UV2][i])
				st.set_bones(ossos.slice(i * 4, i * 4 + 4))
				st.set_weights(pesos.slice(i * 4, i * 4 + 4))
				st.add_vertex(vertices[i])
	st.index()
	return st.commit()

# --- Pintura (gerada por ferramentas/personagem/base_3d/gerar_pele_pixel.gd; pode ser repintada à mão).

static func _tom(fator: float, quente := false) -> Color:
	var c := Vector3.ONE * NEUTRO * fator
	if quente: c *= Vector3(1.0, 0.9, 0.9) # Vincos puxam para o avermelhado.
	return Color(clampf(c.x, 0, 1), clampf(c.y, 0, 1), clampf(c.z, 0, 1))

## Tom do texel em (u, v) de cada parte. v normalizado pela junta (0 = início do osso, 1 = fim).
static func tom(parte: String, u: float, v: float) -> Color:
	var neutro := _tom(1.0)
	var vinco := _tom(0.86, true)
	var luz := _tom(1.08)
	var perto := func(a: float, b: float, r: float) -> bool: return absf(a - b) <= r
	match parte:
		"tronco":
			# Peitoral: base curva e brilho no alto; esterno no meio.
			if v > 0.64 and v < 0.70 and (u > 0.38 and u < 0.48 or u > 0.52 and u < 0.62): return vinco
			if perto.call(u, 0.5, 0.012) and v > 0.62 and v < 0.84: return vinco
			if v > 0.74 and v < 0.80 and (perto.call(u, 0.43, 0.02) or perto.call(u, 0.57, 0.02)): return luz
			# Abdômen: linha central, duas divisões e oblíquos.
			if perto.call(u, 0.5, 0.012) and v > 0.30 and v < 0.62: return vinco
			if (perto.call(v, 0.43, 0.02) or perto.call(v, 0.53, 0.02)) and u > 0.45 and u < 0.55: return vinco
			if (perto.call(u, 0.40, 0.012) or perto.call(u, 0.60, 0.012)) and v > 0.30 and v < 0.56: return vinco
			if perto.call(u, 0.5, 0.012) and perto.call(v, 0.26, 0.02): return vinco # Umbigo.
			# Costas: coluna na emenda e escápulas.
			if (u < 0.025 or u > 0.975) and v > 0.30 and v < 0.90: return vinco
			if v > 0.70 and v < 0.84 and (perto.call(u, 0.14, 0.015) or perto.call(u, 0.86, 0.015)): return vinco
			return neutro
		"braco":
			if perto.call(v, 0.35, 0.04) and u > 0.15 and u < 0.85: return vinco # Fim do deltoide.
			if perto.call(v, 0.95, 0.05) and perto.call(u, 0.5, 0.1): return vinco # Dobra do cotovelo.
			return neutro
		"antebraco":
			if perto.call(v, 0.97, 0.05): return vinco # Punho.
			return neutro
		"canela":
			if v > 0.02 and v < 0.10 and perto.call(u, 0.5, 0.08): return luz # Patela.
			if perto.call(v, 0.14, 0.03) and perto.call(u, 0.5, 0.1): return vinco
			if (u < 0.05 or u > 0.95) and v > 0.2 and v < 0.55: return vinco # Panturrilha.
			return neutro
		"pe":
			if perto.call(v, 1.25, 0.06) and u > 0.3 and u < 0.7: return vinco # Dedos.
			return neutro
	return neutro

static func pintar() -> Image:
	var imagem := Image.create(TAMANHO.x, TAMANHO.y, false, Image.FORMAT_RGBA8)
	imagem.fill(_tom(1.0))
	for parte in PARTES:
		var d: Dictionary = PARTES[parte]
		var tile: Rect2i = d.tile
		var faixa: Vector2 = d.v
		for y in tile.size.y:
			for x in tile.size.x:
				var u := (x + 0.5) / tile.size.x
				var v := faixa.x + (1.0 - (y + 0.5) / tile.size.y) * (faixa.y - faixa.x)
				imagem.set_pixel(tile.position.x + x, tile.position.y + y, tom(parte, u, v))
	return imagem
