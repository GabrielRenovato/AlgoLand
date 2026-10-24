extends RefCounted

const CHANCE_PORTAL := 0.02
const CHANCE_PREMIO_RARO := 0.05
const MULT_OURO_MIMICO := 5
const Conjuntos := preload("res://codigo/dados/conjuntos_armadura.gd")
const Receitas := preload("res://codigo/logica/drops_forja.gd")
const POCOES := ["cura","folego","velocidade","pedra","forca","vampiro"]
const COMIDAS := ["omelete_horta","peixe_assado","sopa_raizes"]

static func sortear_premio(rng: RandomNumberGenerator, andar: int) -> DadosItem:
	var sorteio := rng.randf()
	if sorteio < CHANCE_PREMIO_RARO:
		var tipos := Receitas.receitas_pendentes(andar,Engine.get_main_loop() as SceneTree).filter(func(tipo): return Conjuntos.de_tipo(tipo)!=null)
		if not tipos.is_empty():
			return DadosItem.de_coletavel("receita",tipos[rng.randi_range(0,tipos.size()-1)])
		return DadosItem.de_coletavel("material","moeda_forja")
	if sorteio < 0.40:
		return DadosItem.de_coletavel("pocao",POCOES[rng.randi_range(0,POCOES.size()-1)])
	if sorteio < 0.70:
		return DadosItem.de_coletavel("comida",COMIDAS[rng.randi_range(0,COMIDAS.size()-1)])
	return DadosItem.de_coletavel("material","moeda_forja")
