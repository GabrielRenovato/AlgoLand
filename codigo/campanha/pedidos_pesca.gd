extends RefCounted
## Cada captura válida cumpre um passo persistido no diário; não depende de contadores da fazenda.
const IDS := ["pesca_primeiras_fisgadas","pesca_carpas_da_vila"]
static func registrar(cena: Node, especie: String) -> void:
	var progresso: RefCounted = cena.controlador.progresso
	for id in IDS:
		if progresso.missao_concluida(id) or not "pedido" in progresso.objetivos_cumpridos(id): continue
		for objetivo in cena.controlador._catalogo.missoes[id].objetivos:
			if objetivo.tipo!="pescar" or objetivo.id in progresso.objetivos_cumpridos(id): continue
			if objetivo.get("especie","") not in ["",especie]: continue
			if progresso.registrar_objetivo(id,objetivo.id)==OK:
				cena._avisar("Pesca registrada: "+cena.controlador._catalogo.missoes[id].nome)
				cena.controlador.alterado.emit()
			break
