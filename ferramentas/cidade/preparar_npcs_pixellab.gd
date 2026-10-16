extends SceneTree

## Monta as folhas dos moradores a partir dos quadros baixados do PixelLab (arte/fontes/npcs/pixellab/<id>/).
## Folha: 7 colunas x 4 linhas de quadros 64x64. Coluna 0 = parado (rotação do personagem), colunas 1 a 6 = andar.
## Linhas: baixo (south), direita (east), cima (north), esquerda (west = east espelhado). Os quadros do PixelLab vêm
## em telas de tamanhos diferentes, centradas no pivô do personagem, então cada quadro é centrado na célula.
## Também atualiza assets/npcs/cidade/manifesto.json (altura do desenho parado e linha dos pés) e grava uma prévia.
## Uso: godot --headless --path . --script ferramentas/cidade/preparar_npcs_pixellab.gd -- tomas rosa caio estela lia bento
const FONTES := "res://arte/fontes/npcs/pixellab/"
const SAIDA := "res://assets/npcs/cidade/"
const PREVIAS := "res://arte/previas/cenario/"
const CELULA := 64
const COLUNAS := 7
const ANDAR := 6

func _init() -> void:
	var manifesto_caminho := ProjectSettings.globalize_path(SAIDA + "manifesto.json")
	var manifesto: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(manifesto_caminho))
	var ids := Array(OS.get_cmdline_user_args())
	# "previa" como primeiro argumento só grava a imagem ampliada, sem tocar no jogo
	var so_previa: bool = ids.size() > 0 and ids[0] == "previa"
	if so_previa:
		ids.remove_at(0)
	for id in ids:
		var pasta := ProjectSettings.globalize_path(FONTES + id + "/Idle/")
		var folha := Image.create(CELULA * COLUNAS, CELULA * 4, false, Image.FORMAT_RGBA8)
		var direcoes := ["south", "east", "north", "west"]
		var baixo_parado := 0
		var topo_parado := CELULA
		for linha in 4:
			var d: String = direcoes[linha]
			var espelhar := d == "west"
			var origem := "east" if espelhar else d
			_colar(folha, _carregar(pasta + "rotations/" + origem + ".png", espelhar), 0, linha)
			for i in ANDAR:
				_colar(folha, _carregar(pasta + "animations/andar/%s/frame_%03d.png" % [origem, i], espelhar), 1 + i, linha)
		# Medidas do desenho parado de frente (célula 0, linha 0)
		var parado := folha.get_region(Rect2i(0, 0, CELULA, CELULA))
		var usado := parado.get_used_rect()
		topo_parado = usado.position.y
		baixo_parado = usado.end.y
		var altura := baixo_parado - topo_parado
		var ampliada := folha.duplicate() as Image
		ampliada.resize(folha.get_width() * 3, folha.get_height() * 3, Image.INTERPOLATE_NEAREST)
		ampliada.save_png(ProjectSettings.globalize_path(PREVIAS + "npc_pixellab_" + id + ".png"))
		if so_previa:
			print(id, ": altura ", altura, " pes_y ", baixo_parado)
			continue
		folha.save_png(ProjectSettings.globalize_path(SAIDA + id + ".png"))
		var dados: Dictionary = manifesto.get(id, {})
		dados["altura_parado"] = altura
		# Os quadros já nascem na escala do jogador (Mana Seed, ~31 px de altura): sem redimensionar
		dados["altura_mapa"] = altura
		dados["escala_mapa"] = 1.0
		dados["direcoes"] = ["baixo", "direita", "cima", "esquerda"]
		dados["folha"] = SAIDA + id + ".png"
		dados["fonte"] = "res://arte/fontes/npcs/pixellab/" + id
		dados["grade"] = [COLUNAS, 4]
		dados["pes_y"] = baixo_parado
		dados["quadro"] = [CELULA, CELULA]
		dados["quadros_andar"] = ANDAR
		manifesto[id] = dados
		print(id, ": altura ", altura, " pes_y ", baixo_parado)
	if so_previa:
		quit()
		return
	var arq := FileAccess.open(manifesto_caminho, FileAccess.WRITE)
	arq.store_string(JSON.stringify(manifesto, "\t") + "\n")
	arq.close()
	quit()

func _carregar(caminho: String, espelhar: bool) -> Image:
	var img := Image.load_from_file(caminho)
	img.convert(Image.FORMAT_RGBA8)
	if espelhar:
		img.flip_x()
	return img

## Centra o quadro na célula (recortando o que passa de 64 px)
func _colar(folha: Image, img: Image, coluna: int, linha: int) -> void:
	var destino := Vector2i(coluna * CELULA + (CELULA - img.get_width()) / 2, linha * CELULA + (CELULA - img.get_height()) / 2)
	var fonte := Rect2i(Vector2i.ZERO, img.get_size())
	# Recorte quando a tela do quadro é maior que a célula
	var limite := Rect2i(coluna * CELULA, linha * CELULA, CELULA, CELULA)
	var alvo := Rect2i(destino, img.get_size()).intersection(limite)
	if alvo.size == Vector2i.ZERO:
		return
	fonte = Rect2i(alvo.position - destino, alvo.size)
	folha.blit_rect(img, fonte, alvo.position)
