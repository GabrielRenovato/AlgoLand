extends RefCounted
const NOMES := ["NORMAL","PRATA","OURO","IRIDIO"]
const CORES := [Color.WHITE,Color("c8d5df"),Color("ffd264"),Color("c398f3")]
const MULTIPLICADORES := [1.0,1.25,1.5,2.0]

static func da_captura(perfeita: bool, nivel_vara: int, otimos: int, tentativas: int) -> int:
	if perfeita: return 3 if nivel_vara>=4 else (2 if nivel_vara>=2 else 1)
	return 1 if nivel_vara>=3 and tentativas>0 and float(otimos)/tentativas>=0.5 else 0

static func valor(base: int, qualidade: int) -> int:
	return ceili(base*MULTIPLICADORES[clampi(qualidade,0,3)])
