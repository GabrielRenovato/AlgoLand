extends Node2D

## Adapta a fazenda ao mesmo ator e aos trajetos usados nos interiores e na rua.
## Assim o Osvaldo tem uma só rotina, inclusive com jogadores em mapas diferentes.
var local := "fazenda"
var moradores: Dictionary = {}
var apoio_helena: Node
var _participantes: Array = []
var navegacao := AStarGrid2D.new()
var _espera := 0.0
var _assinatura := ""
var _npc: Node2D

func _ready() -> void:
	name = "ObraCarpinteiro"
	_montar_navegacao()
	_npc = preload("res://codigo/cidade/morador_cidade.gd").new()
	_npc.name = "Osvaldo"
	_npc.id = "osvaldo"
	_npc.vila = self
	add_child(_npc)
	_npc.collision_mask = 96 | 2
	moradores.osvaldo = _npc
	var trabalho := preload("res://codigo/fazenda/trabalho_carpinteiro.gd").new()
	_npc.add_child(trabalho)
	Fazenda.galinheiro_alterado.connect(_ao_obra)

func _ao_obra() -> void:
	var assinatura := "%d:%d" % [Fazenda.galinheiro.nivel,Fazenda.galinheiro.obra]
	if assinatura == _assinatura: return
	_assinatura = assinatura
	_rever_obra.call_deferred()

func _rever_obra() -> void:
	if not is_inside_tree(): return
	await get_tree().physics_frame
	if not is_inside_tree() or not is_instance_valid(_npc): return
	_montar_navegacao()
	_npc.atualizar_rotina()

func _process(delta: float) -> void:
	_espera -= delta
	if _espera <= 0:
		_espera = 0.5
		_npc.atualizar_rotina()

func hora_atual() -> float:
	return get_parent().get_node("Iluminacao").hora_do_mundo()

func clima_atual() -> int:
	return Fazenda.clima_hoje

func porta_do_local(_destino: String) -> Vector2:
	return get_parent().get_node("Terrains/Chegada_cidade").position

func _montar_navegacao() -> void:
	navegacao.cell_size = Vector2(8,8)
	navegacao.offset = Vector2(4,4)
	navegacao.region = Rect2i(Vector2i.ZERO,Vector2i(get_parent().limites.size/8))
	navegacao.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	navegacao.update()
	for corpo in get_parent().find_children("*","StaticBody2D",true,false):
		if corpo.collision_layer & 96 == 0: continue
		for forma in corpo.get_children():
			if forma is CollisionShape2D and (forma.disabled or forma.shape == null): continue
			var area := Rect2()
			var poligono := PackedVector2Array()
			if forma is CollisionShape2D:
				var retangulo: Rect2 = forma.shape.get_rect()
				area = forma.global_transform * retangulo
			elif forma is CollisionPolygon2D:
				for ponto in forma.polygon:
					var global: Vector2 = forma.to_global(ponto)
					poligono.append(global)
					area = Rect2(global,Vector2(0.01,0.01)) if area.size == Vector2.ZERO else area.expand(global)
			else: continue
			area.position.y -= 9
			area = area.grow(7)
			var inicio := Vector2i((area.position/8).floor()).max(Vector2i.ZERO)
			var fim := Vector2i((area.end/8).ceil()).min(navegacao.region.size-Vector2i.ONE)
			for y in range(inicio.y,fim.y+1):
				for x in range(inicio.x,fim.x+1):
					var celula := Vector2i(x,y)
					if poligono.is_empty(): navegacao.set_point_solid(celula)
					else:
						var pe := navegacao.get_point_position(celula)+Vector2(0,9)
						for deslocamento in [Vector2.ZERO,Vector2(7,0),Vector2(-7,0),Vector2(0,7),Vector2(0,-7)]:
							if Geometry2D.is_point_in_polygon(pe+deslocamento,poligono):
								navegacao.set_point_solid(celula)
								break

func _celula_livre(ponto: Vector2) -> Vector2i:
	var celula := Vector2i(ponto/8).clamp(Vector2i.ZERO,navegacao.region.size-Vector2i.ONE)
	if not navegacao.is_point_solid(celula): return celula
	for raio in range(1,30):
		for y in range(-raio,raio+1):
			for x in range(-raio,raio+1):
				if absi(x) != raio and absi(y) != raio: continue
				var candidata := celula+Vector2i(x,y)
				if navegacao.is_in_boundsv(candidata) and not navegacao.is_point_solid(candidata): return candidata
	return celula

func caminho_morador(inicio: Vector2, fim: Vector2, _id: String) -> PackedVector2Array:
	var rota := navegacao.get_point_path(_celula_livre(inicio),_celula_livre(fim))
	if not rota.is_empty():
		rota.insert(0,inicio)
		var celula := Vector2i(fim/8)
		if navegacao.is_in_boundsv(celula) and not navegacao.is_point_solid(celula): rota.append(fim)
	return rota
