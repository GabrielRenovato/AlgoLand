extends RefCounted

## Manifestos compartilhados com a ferramenta de plantas. Recursos dos mapas carregam sob demanda.
const PLANTAS: Array[JSON] = [
	preload("res://codigo/fendas/plantas/andar_01.json"),
	preload("res://codigo/fendas/plantas/andar_02.json"),
	preload("res://codigo/fendas/plantas/andar_03.json"),
	preload("res://codigo/fendas/plantas/andar_04.json"),
	preload("res://codigo/fendas/plantas/andar_05.json"),
	preload("res://codigo/fendas/plantas/andar_06.json"),
	preload("res://codigo/fendas/plantas/andar_07.json"),
	preload("res://codigo/fendas/plantas/andar_08.json"),
	preload("res://codigo/fendas/plantas/andar_09.json"),
	preload("res://codigo/fendas/plantas/andar_10.json"),
	preload("res://codigo/fendas/plantas/andar_11.json"),
	preload("res://codigo/fendas/plantas/andar_12.json"),
	preload("res://codigo/fendas/plantas/andar_13.json"),
	preload("res://codigo/fendas/plantas/andar_14.json"),
	preload("res://codigo/fendas/plantas/andar_15.json"),
	preload("res://codigo/fendas/plantas/andar_16.json"),
	preload("res://codigo/fendas/plantas/andar_17.json"),
	preload("res://codigo/fendas/plantas/andar_18.json"),
	preload("res://codigo/fendas/plantas/andar_19.json"),
	preload("res://codigo/fendas/plantas/andar_20.json"),
	preload("res://codigo/fendas/plantas/andar_21.json"),
]

static func indice(andar: int) -> int:
	# Depois dos vinte e um mapas, o circuito avançado repete 2–21 com a dificuldade da partida.
	return andar if andar <= PLANTAS.size() else 2 + posmod(andar - PLANTAS.size() - 1, PLANTAS.size() - 1)

static func dados(andar: int) -> Dictionary:
	return PLANTAS[clampi(indice(andar)-1,0,PLANTAS.size()-1)].data

static func meta(andar: int) -> int:
	return preload("res://codigo/fendas/ritmo_andares.gd").meta(dados(andar), andar)

static func cena(andar: int) -> String:
	return "res://cenas/fendas/andar_%02d.tscn" % indice(andar)

static func chefe(andar: int) -> Dictionary:
	var id: String = dados(andar).guardiao_id
	for guardiao in preload("res://codigo/logica/gerenciador_de_ondas.gd").CHEFES:
		if guardiao.id == id: return guardiao
	return preload("res://codigo/logica/gerenciador_de_ondas.gd").CHEFES[0]
