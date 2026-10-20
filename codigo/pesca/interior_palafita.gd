extends Node2D

## Piso, paredes e móveis da mesma biblioteca nativa usada nas casas da vila.
const Sala := preload("res://codigo/cidade/sala_topdown.gd")
const Profundidade := preload("res://codigo/globais/profundidade.gd")

func _ready() -> void:
	var sala := Sala.new()
	add_child(sala)
	sala.configurar({"recorte": [0, 0, 320, 224], "areas": [
		{"retangulo": [24, 56, 272, 136], "piso": "claro"},
		{"retangulo": [128, 192, 64, 32], "piso": "claro"}]}, "palafita")
	var manifesto: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/cenario/cidade/ambientes/manifesto.json"))
	for dado in [["cama", 272, 105], ["mesa", 272, 158], ["lareira", 50, 75], ["bancada", 58, 145], ["ferramentas", 164, 52]]:
		var item: Dictionary = manifesto["interior/casa_bento/" + dado[0]]
		var sprite := Sprite2D.new()
		sprite.name = dado[0].capitalize()
		sprite.texture = load(item["texturas"][0])
		sprite.hframes = int(item["quadros"])
		sprite.centered = false
		sprite.position = Vector2(dado[1], dado[2])
		sprite.offset = Vector2(-float(item["usado"][2]) / 2.0, -float(item["usado"][3]))
		sprite.z_index = Profundidade.z_de(dado[2])
		sprite.texture_filter = TEXTURE_FILTER_NEAREST
		add_child(sprite)

	# Balcão frontal; corredor lateral livre para a rotina até o quarto.
	for x in [128,192]:
		var item: Dictionary = manifesto["interior/venda/balcao"]
		var balcao := Sprite2D.new()
		balcao.name = "Balcao%d" % x
		balcao.texture = load(item["texturas"][0])
		balcao.hframes = int(item["quadros"])
		balcao.centered = false
		balcao.position = Vector2(x,128)
		balcao.offset = Vector2(-33,-41)
		balcao.z_index = Profundidade.z_de(128)
		balcao.texture_filter = TEXTURE_FILTER_NEAREST
		add_child(balcao)
	preload("res://codigo/pesca/mobiliario_cais.gd").montar(self,[["caixas_peixes",64,174],["equipamento_pesca",224,174]])

	load("res://codigo/cidade/atendimento_cidade.gd").montar(self,"palafita")
