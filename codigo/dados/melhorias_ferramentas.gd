extends RefCounted

const TIPOS := ["enxada","regador","machadinha","picareta"]
const POR_ACAO := {"enxada":"enxada","regar":"regador","machado":"machadinha","picareta":"picareta"}
const NOMES := ["MADEIRA","REFORCADA","FERRO"]
const CUSTOS := {2:{"madeira":8,"pedra":6,"ferro":2},3:{"madeira":6,"ferro":8,"fibra":2}}

static func nivel(inventario: Node, tipo: String) -> int:
	var item = inventario.buscar_por_tipo(tipo) if inventario!=null else null
	return clampi(item.nivel,1,3) if item!=null else 1

static func motivo(inventario: Node, tipo: String) -> String:
	if not tipo in TIPOS: return "FERRAMENTA INVALIDA"
	if inventario.buscar_por_tipo(tipo)==null: return "TRAGA A FERRAMENTA NA MOCHILA"
	var atual := nivel(inventario,tipo)
	if atual>=3: return "NIVEL MAXIMO"
	for material in CUSTOS[atual+1]:
		if inventario.quantidade_tipo("material:"+material)<int(CUSTOS[atual+1][material]): return "MATERIAIS INSUFICIENTES"
	return ""

static func melhorar(inventario: Node, tipo: String) -> String:
	var erro := motivo(inventario,tipo)
	if not erro.is_empty(): return erro
	var antes: Array=inventario.fotografar_mochila()
	var item = inventario.buscar_por_tipo(tipo)
	var proximo: int=item.nivel+1
	for material in CUSTOS[proximo]: inventario.gastar_tipo("material:"+material,int(CUSTOS[proximo][material]))
	item.nivel=proximo
	if not inventario.salvar():
		inventario.restaurar_mochila(antes)
		return "NAO FOI POSSIVEL SALVAR. TENTE NOVAMENTE."
	inventario._avisar_item(item)
	inventario._avisar_mochila()
	return ""

static func descricao(tipo: String, grau: int) -> String:
	var n := clampi(grau,1,3)
	if tipo in ["machadinha","picareta"]:
		return "FORCA: %d POR GOLPE\nENERGIA: %d POR USO" % [n,maxi(1,3-n)]
	return "AREA: %d SOLO%s\nENERGIA: %d POR USO" % [1 if n==1 else 3 if n==2 else 9,"" if n==1 else "S",maxi(1,3-n)]
