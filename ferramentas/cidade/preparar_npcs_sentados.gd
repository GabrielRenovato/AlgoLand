extends SceneTree

## Monta as transições PixelLab preservadas em arte/fontes/npcs/pixellab/<nome>/Idle/animations/sentar_banco/.
## A última célula é a pose sentada; a sequência invertida é usada ao levantar.
const NOMES := ["tomas", "rosa", "estela", "lia", "bento"]
func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/npcs/cidade/sentados"))
	var falhas := 0
	for nome in NOMES:
		var pasta: String = "res://arte/fontes/npcs/pixellab/" + nome + "/Idle/animations/sentar_banco/south/"
		var folha := Image.create(64 * 9, 64, false, Image.FORMAT_RGBA8)
		var pronto := true
		for i in 9:
			var caminho := ProjectSettings.globalize_path(pasta + "frame_%03d.png" % i)
			if not FileAccess.file_exists(caminho):
				pronto = false
				break
			var quadro := Image.load_from_file(caminho)
			quadro.convert(Image.FORMAT_RGBA8)
			var destino := Vector2i((64 - quadro.get_width()) / 2, (64 - quadro.get_height()) / 2)
			var area := Rect2i(Vector2i.ZERO, quadro.get_size())
			var recorte := Rect2i(destino, quadro.get_size()).intersection(Rect2i(0, 0, 64, 64))
			area.position = recorte.position - destino
			area.size = recorte.size
			folha.blit_rect(quadro, area, Vector2i(i * 64, 0) + recorte.position)
		if not pronto:
			push_error("Transicao incompleta: " + nome)
			falhas += 1
			continue
		_retirar_moveis(folha, nome)
		folha.save_png(ProjectSettings.globalize_path("res://assets/npcs/cidade/sentados/" + nome + ".png"))
		print("OK sentar/levantar: ", nome)
	for nome in ["tomas", "rosa", "estela", "lia", "bento", "caio"]:
		_articular(nome, true)
	_articular("caio", false)
	quit(1 if falhas else 0)

## Máscaras autoradas após inspecionar os quadros: preservam rosto, roupa, mãos e pernas.
## A animação só fornece o personagem; bancos e banquetas são exclusivamente do mapa.
func _retirar_moveis(folha: Image, nome: String) -> void:
	for quadro in range(1, 9):
		var cortes: Array[Rect2i] = []
		match nome:
			"tomas":
				if quadro in [2, 3]:
					cortes = [Rect2i(24, 33, 16, 31)]
				elif quadro >= 4:
					cortes = [Rect2i(27, 34, 12, 30)]
			"rosa":
				cortes = [Rect2i(27, 39, 11, 25)]
			"estela":
				if quadro in [2, 3]:
					cortes = [Rect2i(24, 25, 17, 39)]
				elif quadro >= 4:
					cortes = [Rect2i(26, 38, 13, 26)]
			"bento":
				if quadro >= 2:
					cortes = [Rect2i(25, 32, 15, 32), Rect2i(27, 38, 11, 26)]
		for corte in cortes:
			for y in range(corte.position.y, 64):
				for x in 64:
					if x < corte.position.x or x >= corte.end.x:
						folha.set_pixel(quadro * 64 + x, y, Color(0, 0, 0, 0))

## Poses de costas articuladas sobre a arte original: cabeça e tronco descem, quadril e pernas dobram.
## Cada pixel vem da própria folha do morador; nenhum móvel é desenhado na animação.
func _articular(nome: String, costas: bool) -> void:
	var original := Image.load_from_file(ProjectSettings.globalize_path("res://assets/npcs/cidade/" + nome + ".png"))
	var quadro := original.get_region(Rect2i(0, 128 if costas else 0, 64, 64))
	var folha := Image.create(64 * 9, 64, false, Image.FORMAT_RGBA8)
	for i in 9:
		var p := float(i) / 8.0
		var descida := roundi(4.0 * p)
		var escala_pernas := 1.0 - 0.48 * p
		for y in 64:
			var origem_y := y - descida if y < 34 + descida else 34 + int((y - 34 - descida) / escala_pernas)
			if origem_y < 0 or origem_y >= 64:
				continue
			for x in 64:
				folha.set_pixel(i * 64 + x, y, quadro.get_pixel(x, origem_y))
	folha.save_png(ProjectSettings.globalize_path("res://assets/npcs/cidade/sentados/" + nome + ("_costas" if costas else "") + ".png"))
