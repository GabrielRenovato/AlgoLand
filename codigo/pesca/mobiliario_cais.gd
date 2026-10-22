extends RefCounted

const Cadeira := preload("res://codigo/logica/cadeira.gd")
const Profundidade := preload("res://codigo/globais/profundidade.gd")
const MOVEIS_PESCA := {
	"caixas_peixes": Vector2(56, 12),
	"equipamento_pesca": Vector2(36, 10),
}
const TEXTURAS_PESCA := {
	"caixas_peixes": "res://assets/cenario/praia/mobiliario/bancada_pesca_v2.png",
	"equipamento_pesca": "res://assets/cenario/praia/mobiliario/suporte_varas_v2.png",
}

static func montar(praia: Node2D, itens: Array, interior_detalhado := false) -> void:
	var grupo := Node2D.new()
	grupo.name = "MobiliarioCais"
	grupo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	praia.add_child(grupo)
	for item: Array in itens:
		var tipo: String = item[0]
		var objeto := _montar_movel(tipo)
		objeto.name = "%s_%d_%d" % [tipo, item[1], item[2]]
		objeto.position = Vector2(item[1], item[2])
		objeto.z_index = Profundidade.z_de(item[2])
		grupo.add_child(objeto)
		if not interior_detalhado:
			preload("res://codigo/pesca/arte_praia.gd").aplicar(objeto,tipo,objeto)
		elif MOVEIS_PESCA.has(tipo):
			var dados_movel: Dictionary = preload("res://codigo/cidade/interiores_detalhados.gd").dados("palafita/" + tipo)
			objeto.texture = load(dados_movel.texturas[0])
			preload("res://codigo/cidade/detalhe_ambiente.gd").instalar(objeto, objeto, dados_movel)
		if tipo == "vasos" and interior_detalhado:
			var atualizar := func(_estacao: int):
				objeto.texture = load("res://assets/cenario/praia/vasos/" + ["primavera","verao","outono","inverno"][praia.estacao_visual()] + ".png")
			praia.get_node("/root/Calendario").estacao_mudou.connect(atualizar)
			atualizar.call(praia.estacao_visual())
		var corpo := StaticBody2D.new()
		corpo.name = objeto.name + "_Colisao"
		corpo.collision_layer = 64
		corpo.collision_mask = 0
		grupo.add_child(corpo)
		var forma := CollisionShape2D.new()
		var caixa := RectangleShape2D.new()
		caixa.size = Vector2(12, 6) if tipo == "vasos" else (Vector2(38, 8) if tipo == "banco" else Vector2(14, 8))
		if tipo == "canteiro":
			# A caixa larga bloqueia pela base; as flores continuam permitindo passar por trás.
			caixa.size = Vector2(44,12)
		if MOVEIS_PESCA.has(tipo):
			caixa.size = MOVEIS_PESCA[tipo]
		forma.shape = caixa
		forma.position = objeto.position - Vector2(0, caixa.size.y / 2)
		corpo.add_child(forma)
		if tipo == "banco":
			_montar_assento(objeto)

static func _montar_movel(tipo: String) -> Sprite2D:
	var sprite := Sprite2D.new()
	var caminho := "res://assets/cenario/cidade/decoracao/mobiliario/" + tipo + ".png"
	if tipo == "vasos":
		caminho = "res://assets/cenario/praia/vasos/primavera.png"
	elif tipo == "banco":
		caminho = "res://assets/cenario/cidade/decoracao/mobiliario/topdown/banco.png"
	elif TEXTURAS_PESCA.has(tipo):
		caminho = TEXTURAS_PESCA[tipo]
	sprite.texture = load(caminho)
	sprite.centered = false
	sprite.offset = Vector2(-sprite.texture.get_width() / 2.0, -sprite.texture.get_height())
	if TEXTURAS_PESCA.has(tipo):
		sprite.offset = sprite.offset.floor()
	return sprite

## Mesmo contrato dos bancos da praça: F/Y senta de frente e levanta em área livre.
static func _montar_assento(banco: Sprite2D) -> void:
	var cadeira := Cadeira.new()
	cadeira.name = "Assento"
	cadeira.so_entre_ondas = false
	cadeira.position = Vector2(0, -5)
	cadeira.assento = Vector2(0, -8)
	cadeira.saida = Vector2(-24, 12)
	cadeira.frente = 1
	var forma := CollisionShape2D.new()
	var alcance := CircleShape2D.new()
	alcance.radius = 20.0
	forma.shape = alcance
	cadeira.add_child(forma)
	banco.add_child(cadeira)
