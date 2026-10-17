extends RefCounted

const Clima := preload("res://codigo/dados/estados_clima.gd").Estado

static func agenda(hora: float, clima: int) -> Dictionary:
	if hora >= 21 or hora < 6:
		return {"local": "palafita", "ponto": Vector2(272, 105), "atividade": "Dormindo em casa", "dormindo": true}
	if hora < 7:
		return {"local":"palafita", "ponto":Vector2(80,90), "atividade":"Preparando o cafe da manha"}
	if hora < 8:
		return {"local":"palafita", "ponto":Vector2(152,100), "atividade":"Preparando a oficina antes de abrir"}
	if hora < 17:
		return {"local":"palafita", "ponto":Vector2(152,100), "atividade":"Atendendo na loja de pesca"}
	if clima not in [Clima.CHUVA_FORTE,Clima.TEMPESTADE,Clima.NEVE_FORTE] and hora < 19:
		return {"local":"cidade", "ponto":Vector2(392,360), "atividade":"Passeando pela vila"}
	return {"local":"palafita", "ponto":Vector2(232,142), "atividade":"Descansando em casa"}
