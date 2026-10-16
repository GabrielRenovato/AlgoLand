extends SceneTree
# Gera assets/ui/fazenda/icones_ferramentas.png (16x16 lado a lado: enxada, regador, mão, machadinha, picareta) a partir da arte Mana Seed do próprio personagem:
#   enxada  : hoe_and_axe.png do pacote Character Base (lida direto do zip original), a enxada inclinada
#   regador : o regador de lado (sem água) da folha de animação de regar (assets/personagens/Fazenda/ferramenta_fazenda.png)
#   mão     : a cesta que já estava na folha (mantida)
#   machadinha e picareta: o quadro da ferramenta erguida (virada para a direita) das folhas de golpe do personagem
# Uso: godot --headless --path . --script res://ferramentas/fazenda/gerar_icones_ferramentas.gd  e depois  --import

const ZIP_BASE := "res://arte/pacotes/_zips_originais/20.01a - Character Base 2.5c.zip"
const RECORTE_ENXADA := Rect2i(112, 6, 9, 13)
const FOLHA_REGAR := "res://assets/personagens/Fazenda/ferramenta_fazenda.png"
const RECORTE_REGADOR := Rect2i(22, 413, 13, 12)
const SAIDA := "res://assets/ui/fazenda/icones_ferramentas.png"
## Quadro de 64 px com a ferramenta sozinha, sem poeira (linha da direita, primeiro quadro do golpe)
const QUADRO_ERGUIDA := Rect2i(0, 128, 64, 64)
const FOLHAS_GOLPE := {3: "res://assets/personagens/Fazenda/ferramenta_machado.png", 4: "res://assets/personagens/Fazenda/ferramenta_picareta.png"}
const LADO := 16

func _initialize() -> void:
	var leitor := ZIPReader.new()
	if leitor.open(ProjectSettings.globalize_path(ZIP_BASE)) != OK:
		push_error("nao abriu o zip do Character Base")
		quit(1)
		return
	var enxada := Image.new()
	enxada.load_png_from_buffer(leitor.read_file("hoe_and_axe.png"))
	leitor.close()
	enxada.convert(Image.FORMAT_RGBA8)
	var regar := Image.load_from_file(ProjectSettings.globalize_path(FOLHA_REGAR))
	regar.convert(Image.FORMAT_RGBA8)
	var antiga := Image.load_from_file(ProjectSettings.globalize_path(SAIDA))
	antiga.convert(Image.FORMAT_RGBA8)
	var folha := Image.create(LADO * 5, LADO, false, Image.FORMAT_RGBA8)
	_centralizar(folha, enxada.get_region(RECORTE_ENXADA), 0)
	_centralizar(folha, regar.get_region(RECORTE_REGADOR), 1)
	# a mão (cesta) continua a mesma
	folha.blit_rect(antiga, Rect2i(LADO * 2, 0, LADO, LADO), Vector2i(LADO * 2, 0))
	for coluna in FOLHAS_GOLPE:
		var golpe := Image.load_from_file(ProjectSettings.globalize_path(FOLHAS_GOLPE[coluna]))
		golpe.convert(Image.FORMAT_RGBA8)
		var quadro := golpe.get_region(QUADRO_ERGUIDA)
		_centralizar(folha, quadro.get_region(quadro.get_used_rect()), coluna)
	folha.save_png(ProjectSettings.globalize_path(SAIDA))
	print("gerado ", SAIDA)
	quit()

func _centralizar(folha: Image, recorte: Image, coluna: int) -> void:
	var destino := Vector2i(coluna * LADO + (LADO - recorte.get_width()) / 2, (LADO - recorte.get_height()) / 2)
	folha.blit_rect(recorte, Rect2i(Vector2i.ZERO, recorte.get_size()), destino)
