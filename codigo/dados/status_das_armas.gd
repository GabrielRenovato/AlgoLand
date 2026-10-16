extends Resource
# Se preferir, pode usar "extends Script" ou até fazer um autoload.

var mapa_forca_espada: Dictionary = {
	1: 5,
	2: 10,
	3: 20,
	4: 30,
	5: 50
}

func obter_forca_para_nivel(nivel: int) -> int:
	if mapa_forca_espada.has(nivel):
		return mapa_forca_espada[nivel]
	return 0
