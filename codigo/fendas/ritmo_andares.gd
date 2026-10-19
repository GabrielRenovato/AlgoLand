extends RefCounted

## A barra exige encontros suficientes para preparar o guardião sem obrigar a limpar becos.
static func fracao(andar: int) -> float:
	return lerpf(0.60, 0.72, clampf(float(andar - 1) / 9.0, 0.0, 1.0))

static func meta(planta: Dictionary, andar: int) -> int:
	var estoque := float(planta.combate.meta) / float(planta.combate.fracao_exigida)
	return maxi(3, ceili(estoque * fracao(andar)))

static func fragmentos_tesouro(andar: int) -> int:
	return clampi(1 + andar / 10, 1, 5)

## Espécies antigas de arena não devem virar esponjas de vida na primeira expedição.
static func teto_vida_comum(andar: int) -> int:
	return 18 + 2 * maxi(andar - 1,0)
