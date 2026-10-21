extends Node2D

## A mesma âncora do layout: (676, 298). O piso liga as duas margens;
## os corrimãos ocupam suas bases físicas, independentemente da altura da arte.
const Profundidade := preload("res://codigo/globais/profundidade.gd")
const DetalheAmbiente := preload("res://codigo/cidade/detalhe_ambiente.gd")
const RAIZ := "res://assets/cenario/cidade/ponte_detalhada/"
const ESTACOES := ["primavera", "verao", "outono", "inverno"]
const RESOLUCAO := 4.0
const PISO := Rect2(-40, -46, 80, 40)
const CORRIMAO_NORTE := Rect2(-40, -50, 80, 4)
const CORRIMAO_SUL := Rect2(-40, -6, 80, 4)
const ORIGEM_APOIOS := Vector2(-19.25, -6)

func _ready() -> void:
	_camada("Apoios", "apoios", ORIGEM_APOIOS, -991)
	# Os tufos das margens estão em -990: ficam sob o piso, sem atravessar
	# as cabeceiras de pedra, mas ainda podem esconder apoios atrás da margem.
	_camada("Piso", "piso", PISO.position, -989)
	_camada("CorrimaoNorte", "corrimao", Vector2(-40, -58), Profundidade.z_de(global_position.y + PISO.position.y) + 7)
	_camada("CorrimaoSul", "corrimao", Vector2(-40, -18), Profundidade.z_de(global_position.y + PISO.end.y) + 7)
	var contato := preload("res://codigo/cidade/contato_estacas.gd").new()
	contato.name = "ContatoAgua"
	contato.z_as_relative = false
	contato.z_index = -992
	var manifesto: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RAIZ + "geometria.json"))
	for ponto in manifesto["contatos_apoios"]:
		contato.pontos.append(ORIGEM_APOIOS + Vector2(ponto[0], ponto[1]))
	add_child(contato)
	var corpo := StaticBody2D.new()
	corpo.name = "Obstaculos"
	corpo.collision_layer = 64
	corpo.collision_mask = 0
	add_child(corpo)
	for lado in ["Norte", "Sul"]:
		var area: Rect2 = CORRIMAO_NORTE if lado == "Norte" else CORRIMAO_SUL
		var forma := CollisionShape2D.new()
		forma.name = "Corrimao" + lado
		var retangulo := RectangleShape2D.new()
		retangulo.size = area.size
		forma.shape = retangulo
		forma.position = area.get_center()
		corpo.add_child(forma)

func _camada(nome: String, peca: String, origem: Vector2, profundidade: int) -> void:
	var camada := Node2D.new()
	camada.name = nome
	camada.z_as_relative = false
	camada.z_index = profundidade
	var imagem := Sprite2D.new()
	imagem.name = "Imagem"
	imagem.centered = false
	imagem.offset = origem
	var caminhos: Array[String] = []
	for estacao in ESTACOES:
		caminhos.append(RAIZ + estacao + "/" + peca + ".png")
	imagem.texture = load(caminhos[0])
	camada.add_child(imagem)
	DetalheAmbiente.instalar(camada, imagem, {"texturas": caminhos, "resolucao": RESOLUCAO})
	add_child(camada)
