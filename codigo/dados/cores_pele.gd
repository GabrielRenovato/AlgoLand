extends RefCounted
## Os índices antigos continuam válidos; RGB é opcional e sempre opaco.
const TONS := [Color("edb393"), Color("c98a62"), Color("8d5a3d")]

static func normalizar_rgb(valor: Variant) -> Array:
	if not valor is Array or valor.size()!=3: return []
	var resultado: Array=[]
	for canal in valor:
		if not (canal is float or canal is int) or not is_finite(float(canal)): return []
		resultado.append(clampf(float(canal),0.0,1.0))
	return resultado

static func obter(dados: Dictionary) -> Color:
	var rgb:=normalizar_rgb(dados.get("cor_pele"))
	if not rgb.is_empty(): return Color(rgb[0],rgb[1],rgb[2],1.0)
	return TONS[clampi(int(dados.get("pele",0)),0,TONS.size()-1)]
