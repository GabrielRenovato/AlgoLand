extends SceneTree
# Importa os cabelos e as roupas novas dos pacotes Mana Seed para CharacterSprites/Aparencia/.
# Nas páginas de combate (golpes de espada, lança e arco, esquiva, ferido, aparar) os pacotes só trazem os cabelos bob1/dap1 e as roupas antigas:
#  - CABELOS NOVOS: a folha de combate é SINTETIZADA aqui: em cada quadro, o cabelo de pé do estilo novo (mesma direção) é posto na cabeça,
#    na posição que o cabelo bob1 tem naquele quadro de combate (alinhamento pelo centro do cabelo). Quadros em que a cabeça muda demais
#    (deitado, girando) ficam com o bob1 original. Assim o personagem não "troca de cabelo" ao golpear.
#  - ROUPAS NOVAS: não dá para sintetizar (o corpo muda de forma): entra a roupa antiga mais parecida, com uma tinta que aproxima a cor.
#
# Uso (sem janela): godot --headless --path . --script res://ferramentas/personagem/importar_aparencia.gd
# Depois rode `godot --headless --path . --import` para o Godot importar os PNGs novos.
#
# O que sai:
#   CharacterSprites/Aparencia/cabelos/<estilo>_p<1|2|4>.png     cabelos do Hairstyle Pack (versão v00; a cor vem do modulate, como nos antigos)
#   CharacterSprites/Aparencia/roupas/<id>_p<1|2|4>.png          roupas (só a camada 1out; sem chapéus); as capas saem prontas por cima da cueca
#   Codigos/DadosLocais/aparencia_combate.gd                     tabelas geradas: peça nova -> índice da peça antiga usada nas páginas de combate
#
# Páginas: p1 = andar/correr, p2 = fazenda, p4 = ferreiro e sentado. As páginas de ataque/reação (espada, lança, arco) só existem para
# as peças antigas (bob1/dap1, undi, boxr, pfpn, fstr): as novas usam a antiga mais parecida (silhueta e cor), calculada aqui.

const RAIZ_PACOTES := "res://SPRITES GERAL/Jogador/"
const DESTINO := "res://CharacterSprites/Aparencia/"
const PAGINAS := [1, 2, 4]

const ESTILOS_CABELO := ["bob2", "flat", "fro1", "pon1", "spk2"]
# Folhas de combate do cabelo bob1 (referência de onde a cabeça está em cada quadro) por página nossa de animação
const COMBATE_BOB1 := {
	"espada": "res://CharacterSprites/Hair/Attack/slash_1_sword/hair (1).png",
	"lanca": "res://CharacterSprites/Hair/Attack/slash_1_spear/hair (1).png",
	"reacao_um_mao": "res://CharacterSprites/Reacao/um_mao/cabelo_1.png",
	"reacao_lanca": "res://CharacterSprites/Reacao/lanca/cabelo_1.png",
	"reacao_arco": "res://CharacterSprites/Reacao/arco/cabelo_1.png",
	"arco_p2": "res://CharacterSprites/Arco/cabelo_1_p2.png",
	"arco_p3": "res://CharacterSprites/Arco/cabelo_1_p3.png",
}
const QUADRO := 64
## Abaixo desta sobreposição (depois de alinhar) o quadro de combate é parecido demais com o de pé: mantém o cabelo bob1 original
const SOBREPOSICAO_MINIMA := 0.5
const PACOTE_CABELOS := "Cabelos/21.01a - Hairstyle Pack v0.5.3/"

# id da roupa -> pasta do pacote (a camada 1out de cada um)
const PACOTES_ROUPA := {
	"pfdr": "Roupas/20.01d - Peasant Farmer Dress & Bonnet 2.1 (comp. v01)/",
	"angl": "Roupas/20.04a - Angler Pants and Rain Hat 2.1 (comp. v01)/",
	"bksm": "Roupas/20.04b - Blacksmith Apron and Bandana 2.1 (comp. v01)/",
	"alch": "Roupas/20.11a - Alchemist's Coat 2.1 (comp. v01)/",
}
const VARIANTES_ROUPA := ["v01", "v02", "v03", "v04", "v05"]

# Capas: camada 2clo do pacote Cloak & Hood por cima da cueca (a camada 0bot, atrás do corpo, fica de fora)
const PACOTE_CAPA := "Roupas/20.05d - Cloak & Hood 1.3 (comp. v01)/"
const MODELOS_CAPA := {"lnpl": "capal", "mnpl": "capam"}
const VARIANTES_CAPA := ["v01", "v03", "v05", "v07", "v09"]

# Cueca (boxr) de cada página: base das capas (as roupas antigas, na ordem do jogo)
const CUECA_POR_PAGINA := {
	1: "res://CharacterSprites/Outfit/outfit (2).png",
	2: "res://CharacterSprites/Fazenda/roupa_2.png",
	4: "res://CharacterSprites/Sentado/roupa_2.png",
}

# Roupas antigas que existem em todas as páginas de combate e servem de substituta (de roupa íntima não: ficaria pelado no golpe)
# Compara 1 pixel a cada PASSO_AMOSTRA em x e y (basta para escolher a peça parecida e é 16 vezes mais rápido)
const PASSO_AMOSTRA := 4

const SUBSTITUTAS_ROUPA := [2, 3, 4, 5, 6, 7, 8, 9, 10, 11]

# Páginas de combate (onde os pacotes não trazem as roupas novas): a roupa antiga que serve de molde é RECOLORIDA com as cores da nova
const PAGINAS_COMBATE := ["espada", "lanca", "reacao_um_mao", "reacao_lanca", "reacao_arco", "arco_p2", "arco_p3"]
const Aparencia := preload("res://Codigos/DadosLocais/aparencia.gd")
## Cores da paleta da roupa nova por posição de luminosidade (a mais escura ao contorno, a mais clara ao brilho)
const DEGRAUS_PALETA := 256

func _initialize() -> void:
	_rodar()

func _rodar() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DESTINO + "cabelos"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DESTINO + "roupas"))
	var combate_roupas := {}

	# --- cabelos: copia p1, p2 e p4 e sintetiza as páginas de combate
	var referencia_andar := _imagem("res://CharacterSprites/Hair/hair (1).png")
	var referencias_combate := {}
	for pagina in COMBATE_BOB1:
		referencias_combate[pagina] = _imagem(COMBATE_BOB1[pagina])
	for estilo in ESTILOS_CABELO:
		for p in PAGINAS:
			var origem := "%s%schar_a_p%d/4har/char_a_p%d_4har_%s_v00.png" % [RAIZ_PACOTES, PACOTE_CABELOS, p, p, estilo]
			_copiar(origem, "%scabelos/%s_p%d.png" % [DESTINO, estilo, p])
		var nova := _imagem("%scabelos/%s_p1.png" % [DESTINO, estilo])
		for pagina in COMBATE_BOB1:
			var folha := _sintetizar_cabelo(nova, referencia_andar, referencias_combate[pagina])
			folha.save_png(ProjectSettings.globalize_path("%scabelos/%s_%s.png" % [DESTINO, estilo, pagina]))
		print("cabelo %s: p1, p2, p4 e %d paginas de combate sintetizadas" % [estilo, COMBATE_BOB1.size()])

	# --- roupas
	var legadas: Array = []
	for i in range(1, 13):
		legadas.append(_imagem("res://CharacterSprites/Outfit/outfit (%d).png" % i))
	for id in PACOTES_ROUPA:
		for variante in VARIANTES_ROUPA:
			for p in PAGINAS:
				var origem := "%s%schar_a_p%d/1out/char_a_p%d_1out_%s_%s.png" % [RAIZ_PACOTES, PACOTES_ROUPA[id], p, p, id, variante]
				_copiar(origem, "%sroupas/%s_%s_p%d.png" % [DESTINO, id, variante, p])
			var nova_roupa := _imagem("%sroupas/%s_%s_p1.png" % [DESTINO, id, variante])
			combate_roupas["%s_%s" % [id, variante]] = _melhor_roupa(nova_roupa, legadas)
			_gerar_roupa_de_combate("%s_%s" % [id, variante], nova_roupa, combate_roupas["%s_%s" % [id, variante]])
	for modelo in MODELOS_CAPA:
		for variante in VARIANTES_CAPA:
			var id: String = "%s_%s" % [MODELOS_CAPA[modelo], variante]
			for p in PAGINAS:
				var capa := _imagem("%s%schar_a_p%d/2clo/char_a_p%d_2clo_%s_%s.png" % [RAIZ_PACOTES, PACOTE_CAPA, p, p, modelo, variante])
				var pronta := _imagem(CUECA_POR_PAGINA[p])
				pronta.convert(Image.FORMAT_RGBA8)
				capa.convert(Image.FORMAT_RGBA8)
				pronta.blend_rect(capa, Rect2i(Vector2i.ZERO, capa.get_size()), Vector2i.ZERO)
				pronta.save_png(ProjectSettings.globalize_path("%sroupas/%s_p%d.png" % [DESTINO, id, p]))
			var nova_capa := _imagem("%sroupas/%s_p1.png" % [DESTINO, id])
			combate_roupas[id] = _melhor_roupa(nova_capa, legadas)
			_gerar_roupa_de_combate(id, nova_capa, combate_roupas[id])

	_gravar_tabela(combate_roupas)
	print("pronto: %d cabelos e %d roupas novas" % [ESTILOS_CABELO.size(), combate_roupas.size()])
	quit()

func _imagem(caminho: String) -> Image:
	var imagem := Image.load_from_file(ProjectSettings.globalize_path(caminho))
	if imagem == null:
		push_error("não achei " + caminho)
		quit(1)
	imagem.convert(Image.FORMAT_RGBA8)
	return imagem

func _copiar(origem: String, destino: String) -> void:
	var bytes := FileAccess.get_file_as_bytes(origem)
	if bytes.is_empty():
		push_error("não achei " + origem)
		quit(1)
		return
	var arquivo := FileAccess.open(destino, FileAccess.WRITE)
	arquivo.store_buffer(bytes)
	arquivo.close()

# Folha de combate de um cabelo novo: em cada quadro, o cabelo de pé do estilo novo (mesma direção, coluna 0 das linhas 0 a 3 da página 1) vai
# para onde o cabelo bob1 está naquele quadro, alinhado pelo centro do cabelo; se a cabeça mudou demais, fica o quadro original do bob1
func _sintetizar_cabelo(nova_andar: Image, bob_andar: Image, bob_combate: Image) -> Image:
	var folha := Image.create(bob_combate.get_width(), bob_combate.get_height(), false, Image.FORMAT_RGBA8)
	for linha in 8:
		var direcao := linha % 4
		var bob_parado := bob_andar.get_region(Rect2i(0, direcao * QUADRO, QUADRO, QUADRO))
		var novo_parado := nova_andar.get_region(Rect2i(0, direcao * QUADRO, QUADRO, QUADRO))
		var centro_parado := _centro(bob_parado)
		for coluna in 8:
			var regiao := Rect2i(coluna * QUADRO, linha * QUADRO, QUADRO, QUADRO)
			var bob_quadro := bob_combate.get_region(regiao)
			var centro_quadro := _centro(bob_quadro)
			if centro_quadro == Vector2.INF:
				continue   # quadro vazio da folha
			var deslocamento := Vector2i((centro_quadro - centro_parado).round())
			var saida := Image.create(QUADRO, QUADRO, false, Image.FORMAT_RGBA8)
			if _sobreposicao(bob_quadro, bob_parado, deslocamento) >= SOBREPOSICAO_MINIMA:
				saida.blend_rect(novo_parado, Rect2i(0, 0, QUADRO, QUADRO), deslocamento)
			else:
				saida.blend_rect(bob_quadro, Rect2i(0, 0, QUADRO, QUADRO), Vector2i.ZERO)
			folha.blit_rect(saida, Rect2i(0, 0, QUADRO, QUADRO), regiao.position)
	return folha

# Centro (média das posições) dos pixels não transparentes do quadro; Vector2.INF se estiver vazio
func _centro(quadro: Image) -> Vector2:
	var soma := Vector2.ZERO
	var n := 0
	for y in quadro.get_height():
		for x in quadro.get_width():
			if quadro.get_pixel(x, y).a > 0.5:
				soma += Vector2(x, y)
				n += 1
	return soma / n if n > 0 else Vector2.INF

# Interseção sobre união entre `a` e `b` deslocado de `deslocamento`
func _sobreposicao(a: Image, b: Image, deslocamento: Vector2i) -> float:
	var dentro := 0
	var uniao := 0
	for y in a.get_height():
		for x in a.get_width():
			var pa := a.get_pixel(x, y).a > 0.5
			var bx := x - deslocamento.x
			var by := y - deslocamento.y
			var pb := bx >= 0 and by >= 0 and bx < b.get_width() and by < b.get_height() and b.get_pixel(bx, by).a > 0.5
			if pa or pb:
				uniao += 1
				if pa and pb:
					dentro += 1
	return float(dentro) / maxf(uniao, 1.0)

# Silhueta: interseção sobre união dos pixels não transparentes (todos os 64 quadros da folha)
func _iou(a: Image, b: Image) -> float:
	var dentro := 0
	var uniao := 0
	for y in range(0, a.get_height(), PASSO_AMOSTRA):
		for x in range(0, a.get_width(), PASSO_AMOSTRA):
			var pa := a.get_pixel(x, y).a > 0.5
			var pb := b.get_pixel(x, y).a > 0.5
			if pa or pb:
				uniao += 1
				if pa and pb:
					dentro += 1
	return float(dentro) / maxf(uniao, 1.0)

func _cor_media(imagem: Image) -> Color:
	var r := 0.0
	var g := 0.0
	var b := 0.0
	var n := 0
	for y in range(0, imagem.get_height(), PASSO_AMOSTRA):
		for x in range(0, imagem.get_width(), PASSO_AMOSTRA):
			var c := imagem.get_pixel(x, y)
			if c.a > 0.5:
				r += c.r
				g += c.g
				b += c.b
				n += 1
	return Color(r / maxf(n, 1.0), g / maxf(n, 1.0), b / maxf(n, 1.0))

# Entre as roupas antigas que existem nas páginas de combate, a de silhueta e cor mais parecidas com a nova (índice 0-based)
func _melhor_roupa(nova: Image, legadas: Array) -> int:
	var cor_nova := _cor_media(nova)
	var melhor := SUBSTITUTAS_ROUPA[0]
	var menor := INF
	for indice in SUBSTITUTAS_ROUPA:
		var antiga: Image = legadas[indice]
		var cor := _cor_media(antiga)
		var distancia_cor := sqrt(pow(cor.r - cor_nova.r, 2.0) + pow(cor.g - cor_nova.g, 2.0) + pow(cor.b - cor_nova.b, 2.0))
		var custo := 0.6 * distancia_cor + 0.4 * (1.0 - _iou(nova, antiga))
		if custo < menor:
			menor = custo
			melhor = indice
	return melhor

## Recolore a roupa antiga de molde (`base`, 0-based) em cada página de combate com as cores da roupa nova. A forma, a pose e as sombras são as
## do molde (a única arte de golpe que existe); as cores vêm da nova: cada pixel do molde troca para o tom da paleta da nova que está na mesma
## posição de luminosidade (o contorno escuro fica com o tom mais escuro da nova, o brilho com o mais claro). Grava roupas/<id>_<pagina>.png
func _gerar_roupa_de_combate(id: String, nova: Image, base: int) -> void:
	var paleta := _paleta_por_luminosidade(nova)
	for pagina in PAGINAS_COMBATE:
		var molde := _imagem(Aparencia._caminho_legado_roupa(base + 1, pagina))
		molde.convert(Image.FORMAT_RGBA8)
		var dados := molde.get_data()
		var quantis := _quantis_do_molde(dados)
		for i in range(0, dados.size(), 4):
			if dados[i + 3] == 0:
				continue
			var cor: Color = paleta[quantis[i / 4]]
			dados[i] = int(cor.r8)
			dados[i + 1] = int(cor.g8)
			dados[i + 2] = int(cor.b8)
		var pronta := Image.create_from_data(molde.get_width(), molde.get_height(), false, Image.FORMAT_RGBA8, dados)
		pronta.save_png(ProjectSettings.globalize_path("%sroupas/%s_%s.png" % [DESTINO, id, pagina]))

## Para cada pixel opaco do molde, a posição (0 a DEGRAUS_PALETA-1) que a luminosidade dele ocupa entre todos os pixels opacos do molde
func _quantis_do_molde(dados: PackedByteArray) -> Dictionary:
	var luminosidades: Array = []
	var indices: Array = []
	for i in range(0, dados.size(), 4):
		if dados[i + 3] == 0:
			continue
		luminosidades.append(0.299 * dados[i] + 0.587 * dados[i + 1] + 0.114 * dados[i + 2])
		indices.append(i / 4)
	var ordem: Array = range(luminosidades.size())
	ordem.sort_custom(func(a, b): return luminosidades[a] < luminosidades[b])
	var quantis := {}
	var total := maxf(ordem.size(), 1.0)
	for posicao in ordem.size():
		quantis[indices[ordem[posicao]]] = mini(int(float(posicao) / total * DEGRAUS_PALETA), DEGRAUS_PALETA - 1)
	return quantis

## DEGRAUS_PALETA cores da roupa nova, da mais escura à mais clara (média dos pixels de cada faixa de luminosidade)
func _paleta_por_luminosidade(nova: Image) -> Array:
	var copia := nova.duplicate() as Image
	copia.convert(Image.FORMAT_RGBA8)
	var dados := copia.get_data()
	var pixels: Array = []
	for i in range(0, dados.size(), 4):
		if dados[i + 3] == 0:
			continue
		pixels.append([0.299 * dados[i] + 0.587 * dados[i + 1] + 0.114 * dados[i + 2], Color8(dados[i], dados[i + 1], dados[i + 2])])
	pixels.sort_custom(func(a, b): return a[0] < b[0])
	var paleta: Array = []
	var total := pixels.size()
	for degrau in DEGRAUS_PALETA:
		var de := int(float(degrau) / DEGRAUS_PALETA * total)
		var ate := maxi(int(float(degrau + 1) / DEGRAUS_PALETA * total), de + 1)
		var r := 0.0
		var g := 0.0
		var b := 0.0
		var n := 0
		for k in range(de, mini(ate, total)):
			var c: Color = pixels[k][1]
			r += c.r
			g += c.g
			b += c.b
			n += 1
		paleta.append(Color(r / maxf(n, 1.0), g / maxf(n, 1.0), b / maxf(n, 1.0)) if n > 0 else (paleta[paleta.size() - 1] if not paleta.is_empty() else Color.WHITE))
	return paleta

func _gravar_tabela(roupas: Dictionary) -> void:
	var texto := "## GERADO por ferramentas/personagem/importar_aparencia.gd (não editar à mão): qual roupa antiga serve de molde (forma e pose) de cada roupa\n"
	texto += "## nova nas páginas de combate (golpes de espada e lança, arco, esquiva, ferido e aparar), onde os pacotes só trazem as roupas antigas; as\n"
	texto += "## folhas recoloridas ficam em CharacterSprites/Aparencia/roupas/<id>_<pagina>.png. Índices 0-based. (Os cabelos novos têm folhas de\n"
	texto += "## combate próprias, sintetizadas pelo mesmo programa.)\n"
	texto += "extends RefCounted\n\n"
	texto += "const ROUPAS := {\n"
	for chave in roupas:
		texto += "\t\"%s\": %d,\n" % [chave, roupas[chave]]
	texto += "}\n"
	var arquivo := FileAccess.open("res://Codigos/DadosLocais/aparencia_combate.gd", FileAccess.WRITE)
	arquivo.store_string(texto)
	arquivo.close()
