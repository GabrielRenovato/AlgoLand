extends RefCounted
## Consulta a máscara real do terreno: não cria água nem libera lançamentos em terra.
static func alvo(terreno: Node2D, origem: Vector2, direcao: Vector2, alcance: float) -> Vector2:
	if not is_instance_valid(terreno) or not terreno.has_method("peso_agua"): return Vector2.INF
	for distancia in range(roundi(alcance),15,-2):
		var p := origem+direcao.normalized()*distancia
		if terreno.limites.has_point(p) and terreno.peso_agua(p)>=0.65:
			return p
	return Vector2.INF

static func margem_proxima(terreno: Node2D, origem: Vector2) -> Vector2:
	if not terreno.has_method("peso_agua"): return Vector2.INF
	var melhor := Vector2.INF
	var distancia := INF
	for y in range(int(terreno.limites.position.y)+16,int(terreno.limites.end.y),32):
		for x in range(int(terreno.limites.position.x)+16,int(terreno.limites.end.x),32):
			var p := Vector2(x,y)
			if p.distance_squared_to(origem)>=distancia or not terreno.ponto_seguro(p): continue
			for d in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]:
				if alvo(terreno,p+Vector2(0,14),d,44).is_finite():
					melhor=p;distancia=p.distance_squared_to(origem);break
	return melhor
