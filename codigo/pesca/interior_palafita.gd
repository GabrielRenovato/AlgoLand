extends Node2D

## Piso, paredes e móveis da mesma biblioteca pintada usada nas casas da vila.
const Sala := preload("res://codigo/cidade/sala_topdown.gd")
const Profundidade := preload("res://codigo/globais/profundidade.gd")
const Biblioteca := preload("res://codigo/cidade/interiores_detalhados.gd")
const Detalhe := preload("res://codigo/cidade/detalhe_ambiente.gd")

func _ready() -> void:
	var sala := Sala.new()
	sala.name = "Sala"
	add_child(sala)
	sala.configurar({"recorte": [0, 0, 320, 224], "areas": [
		{"retangulo": [24, 56, 272, 136], "piso": "claro"},
		{"retangulo": [128, 192, 64, 32], "piso": "claro"}]}, "palafita")
	var manifesto: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/cenario/cidade/ambientes/manifesto.json"))
	for dado in [["cama", 272, 105], ["mesa", 272, 158], ["lareira", 50, 75]]:
		var item: Dictionary = Biblioteca.preparar(manifesto["interior/casa_bento/" + dado[0]])
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
		Detalhe.instalar(sprite, sprite, item)

	# Um balcão contínuo, sem emenda; os dois corredores e a base130×12 ficam iguais.
	for dado in [["loja_balcao","BalcaoLoja",160,128], ["loja_reparos","BancadaReparos",58,145],
			["loja_varas","ExpositorVaras",164,52], ["loja_tapete","TapeteLoja",160,183]]:
		var item: Dictionary=Biblioteca.dados("palafita/"+dado[0])
		var sprite:=Sprite2D.new()
		sprite.name=dado[1]
		sprite.texture=load(item.texturas[0])
		sprite.centered=false
		sprite.position=Vector2(dado[2],dado[3])
		var tela: Array=item.canvas_logico
		sprite.offset=Vector2(-float(tela[0])/2,-float(tela[1]))
		sprite.z_index=-996 if dado[0]=="loja_tapete" else Profundidade.z_de(dado[3])
		add_child(sprite)
		Detalhe.instalar(sprite,sprite,item)
	preload("res://codigo/pesca/mobiliario_cais.gd").montar(self,[["caixas_peixes",64,174],["equipamento_pesca",224,174]], true)

	load("res://codigo/cidade/atendimento_cidade.gd").montar(self,"palafita")
