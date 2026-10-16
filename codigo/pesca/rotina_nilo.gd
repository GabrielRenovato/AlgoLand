extends RefCounted

const Clima := preload("res://codigo/dados/estados_clima.gd").Estado

static func agenda(hora: float, clima: int) -> Dictionary:
	if hora >= 21 or hora < 6:
		return {"local": "palafita", "ponto": Vector2(272, 105), "atividade": "Dormindo em casa", "dormindo": true}
	if clima in [Clima.CHUVA_FORTE, Clima.TEMPESTADE, Clima.NEVE_FORTE]:
		return {"local": "palafita", "ponto": Vector2(232, 142), "atividade": "Consertando as redes em casa"}
	if hora < 7:
		return {"local": "palafita", "ponto": Vector2(80, 90), "atividade": "Preparando o cafe da manha"}
	if hora < 10:
		return {"local": "praia", "ponto": Vector2(252, 256), "atividade": "Separando as iscas e cuidando das redes"}
	if hora < 16:
		return {"local": "praia", "ponto": Vector2(342, 404), "atividade": "Pescando no pier"}
	if hora < 18:
		return {"local": "praia", "ponto": Vector2(426, 240), "atividade": "Recolhendo o equipamento na praia"}
	return {"local": "palafita", "ponto": Vector2(232, 142), "atividade": "Jantando e descansando em casa"}
