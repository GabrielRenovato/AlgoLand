extends RefCounted
## Orçamento por jogador, compartilhado por golpes, flechas, itens e poção.
const PERCENTUAL_MAXIMO := 0.08
const CURA_POR_SEGUNDO := 3.0
const PAUSA_APOS_DANO := 1.2
var _orcamento := CURA_POR_SEGUNDO
var _fracao := 0.0
var _pausa := 0.0
func avancar(delta: float) -> void:
	_pausa = maxf(0,_pausa-delta)
	_orcamento = minf(CURA_POR_SEGUNDO,_orcamento+maxf(delta,0)*CURA_POR_SEGUNDO)
func ferido() -> void:
	_pausa = PAUSA_APOS_DANO
	_fracao = 0
func recuperar(dano_real: int, percentual: float) -> int:
	if dano_real <= 0 or percentual <= 0 or _pausa > 0: return 0
	_fracao += dano_real*minf(percentual,PERCENTUAL_MAXIMO)
	var cura := mini(floori(_fracao),floori(_orcamento))
	_orcamento -= cura
	_fracao = minf(0.999,_fracao-cura)
	return cura
