extends RefCounted

## Quem segue a mesma rota espera uma passada: não anda dentro do morador à frente.
## Não muda as colisões nem prende moradores que cruzam em sentidos diferentes.
const DISTANCIA := 18.0
const LARGURA_FILA := 12.0

static func limitar(npc: CharacterBody2D, movimento: Vector2) -> Vector2:
	if npc.vila.local not in ["cidade","praia"]: return movimento
	if movimento.is_zero_approx(): return movimento
	var direcao := movimento.normalized()
	var comprimento := movimento.length()
	for outro in npc.get_tree().get_nodes_in_group("moradores_cidade"):
		if outro == npc or not outro.visible or outro.dormindo or outro.vila != npc.vila or outro.caminho.is_empty():
			continue
		var distancia: Vector2 = outro.global_position-npc.global_position
		if distancia.length_squared() > pow(DISTANCIA+comprimento,2): continue
		var rumo := Vector2.ZERO
		for ponto: Vector2 in outro.caminho:
			if outro.position.distance_to(ponto) > 0.5:
				rumo = (ponto-outro.position).normalized()
				break
		if direcao.dot(rumo) < 0.5: continue
		if absf(distancia.dot(direcao.orthogonal())) >= LARGURA_FILA: continue
		var adiante := distancia.dot(direcao)
		# Desempate estável quando os dois acabam de entrar pela mesma porta.
		if absf(adiante) < 0.01 and npc.get_instance_id() > outro.get_instance_id():
			return Vector2.ZERO
		if adiante > 0:
			comprimento = minf(comprimento,maxf(0,adiante-DISTANCIA))
	return direcao*comprimento
