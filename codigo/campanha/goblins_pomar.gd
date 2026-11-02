extends RefCounted
## Estágio 4: grupos espalhados pelo pomar, com entrada e interações desobstruídas.
const CENA := preload("res://cenas/inimigos/goblin_pomar.tscn")
const QUANTIDADE := 32
static func povoar(cena: Node2D) -> Array[Node2D]:
	var resultado: Array[Node2D]=[]
	var candidatos: Array[Vector2]=[]
	var entrada:=Vector2(cena.terreno.dados.entrada[0],cena.terreno.dados.entrada[1])
	for y in [-240,-160,-80,0,80,160,240]:
		for x in [-336,-240,-144,-48,48,144,240,336]:
			var deslocamento:=Vector2(sin(float(x+y)*.07)*14.0,cos(float(x-y)*.09)*12.0)
			var ponto:Vector2=cena._livre(Vector2(x,y)+deslocamento)
			if ponto.distance_to(entrada)<155.0:continue
			if candidatos.any(func(p):return p.distance_to(ponto)<48.0):continue
			if cena.alvos.values().any(func(a):return a.no.position.distance_to(ponto)<42.0):continue
			candidatos.append(ponto)
	var quantidade:=mini(QUANTIDADE,candidatos.size())
	for i in quantidade:
		var goblin:=CENA.instantiate() as Node2D
		goblin.position=candidatos[int(float(i)*candidatos.size()/quantidade)]
		cena.add_child(goblin)
		if cena.registro_run!=null:cena.registro_run.registrar_inimigo(goblin)
		resultado.append(goblin)
	return resultado
