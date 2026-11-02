extends RefCounted
## Estado individual, validado e gravado por substituição atômica. Não reinicia o mundo.
signal alterado
const Catalogo := preload("res://codigo/dados/catalogo_maestria.gd")
const VERSAO := 1
var experiencia: Dictionary = {}
var aprendidos: Array[String] = []
var equipados: Dictionary = {}
var recebidos: Array[String] = []
var legado := false
var caminho := ""
var pronto := false

func iniciar(arquivo: String, preservar_combo := false) -> Error:
	pronto = false
	if not arquivo.begins_with("user://") or ".." in arquivo: return ERR_INVALID_PARAMETER
	caminho = arquivo
	experiencia = {}; aprendidos.clear(); equipados = {}; recebidos.clear(); legado = preservar_combo
	for f in Catalogo.FAMILIAS:
		experiencia[f] = 0
		equipados[f] = {"tecnicas":[], "finalizador":""}
	if FileAccess.file_exists(caminho):
		var json := JSON.new()
		if json.parse(FileAccess.get_file_as_string(caminho)) != OK: return ERR_FILE_CORRUPT
		var erro := importar(json.data)
		if erro != OK: return erro
	pronto = true
	return OK

func nivel(f: String) -> int:
	return Catalogo.nivel(int(experiencia.get(f, 0)))

func disponiveis(f: String) -> int:
	return Catalogo.pontos(nivel(f)) - aprendidos.filter(func(id): return Catalogo.no(id).familia == f).size()

func adicionar_xp(f: String, quantidade: int, ticket := "") -> Error:
	if not pronto: return ERR_UNCONFIGURED
	if not f in Catalogo.FAMILIAS or quantidade <= 0 or quantidade > 10000: return ERR_INVALID_PARAMETER
	if not ticket.is_empty() and ticket in recebidos: return ERR_ALREADY_EXISTS
	if ticket.length()>128: return ERR_INVALID_PARAMETER
	var recibos_antes := recebidos.duplicate()
	if not ticket.is_empty():
		recebidos.append(ticket)
		if recebidos.size()>256:recebidos.remove_at(0)
	var antes: int = experiencia[f]
	experiencia[f] = mini(Catalogo.xp_para_nivel(100), antes + quantidade)
	var erro := salvar()
	if erro != OK:
		experiencia[f] = antes
		recebidos.assign(recibos_antes)
	else: alterado.emit()
	return erro

func motivo_aprender(id: String) -> String:
	var dado := Catalogo.no(id)
	if not pronto: return "PROGRESSO INDISPONIVEL"
	if dado.is_empty(): return "HABILIDADE DESCONHECIDA"
	if id in aprendidos: return "JA APRENDIDA"
	if nivel(dado.familia) < dado.nivel: return "REQUER MAESTRIA %d" % dado.nivel
	if not dado.requisito.is_empty() and not dado.requisito in aprendidos: return "APRENDA O NO ANTERIOR"
	if disponiveis(dado.familia) <= 0: return "SEM PONTOS DISPONIVEIS"
	return ""

func aprender(id: String) -> Error:
	if not motivo_aprender(id).is_empty(): return ERR_UNAUTHORIZED
	aprendidos.append(id)
	var erro := salvar()
	if erro != OK: aprendidos.erase(id)
	else: alterado.emit()
	return erro

func equipar(id: String) -> Error:
	if not pronto or not id in aprendidos: return ERR_UNAUTHORIZED
	var dado := Catalogo.no(id)
	if dado.tipo == "passiva": return ERR_INVALID_PARAMETER
	var antes := equipados.duplicate(true)
	var selecao: Dictionary = equipados[dado.familia]
	if dado.tipo == "finalizador":
		selecao.finalizador = "" if selecao.finalizador == id else id
	elif id in selecao.tecnicas:
		selecao.tecnicas.erase(id)
	else:
		if selecao.tecnicas.size() >= 2: return ERR_OUT_OF_MEMORY
		selecao.tecnicas.append(id)
	var erro := salvar()
	if erro != OK: equipados = antes
	else: alterado.emit()
	return erro

func redistribuir(f: String) -> Error:
	if not pronto or not f in Catalogo.FAMILIAS: return ERR_INVALID_PARAMETER
	var antes := exportar()
	aprendidos.assign(aprendidos.filter(func(id): return Catalogo.no(id).familia != f))
	equipados[f] = {"tecnicas":[], "finalizador":""}
	var erro := salvar()
	if erro != OK: importar(antes)
	else: alterado.emit()
	return erro

func bonus(f: String, efeito: String) -> float:
	var total := 0.0
	for id in aprendidos:
		var dado := Catalogo.no(id)
		if dado.familia == f and dado.efeito == efeito: total += float(dado.valor)
	return total

func exportar() -> Dictionary:
	return {"versao":VERSAO,"experiencia":experiencia.duplicate(),"aprendidos":aprendidos.duplicate(),"equipados":equipados.duplicate(true),"combo_legado":legado,"recebidos":recebidos.duplicate()}

func importar(dados: Variant) -> Error:
	if not dados is Dictionary or dados.get("versao") != VERSAO: return ERR_FILE_CORRUPT
	if not dados.get("experiencia") is Dictionary or not dados.get("aprendidos") is Array or not dados.get("equipados") is Dictionary or not dados.get("combo_legado",false) is bool: return ERR_FILE_CORRUPT
	var recibos: Variant = dados.get("recebidos",[])
	if not recibos is Array or recibos.size()>256:return ERR_FILE_CORRUPT
	var recibos_vistos:Dictionary={}
	for ticket in recibos:
		if not ticket is String or ticket.is_empty() or ticket.length()>128 or recibos_vistos.has(ticket):return ERR_FILE_CORRUPT
		recibos_vistos[ticket]=true
	var vistos := {}
	for f in Catalogo.FAMILIAS:
		var xp: Variant = dados.experiencia.get(f)
		if not (xp is int or xp is float) or not is_finite(float(xp)) or float(xp) != int(xp) or xp < 0 or xp > Catalogo.xp_para_nivel(100): return ERR_FILE_CORRUPT
		var selecao: Variant = dados.equipados.get(f)
		if not selecao is Dictionary or not selecao.get("tecnicas") is Array or selecao.tecnicas.size() > 2 or not selecao.get("finalizador") is String: return ERR_FILE_CORRUPT
	for id in dados.aprendidos:
		if not id is String or vistos.has(id): return ERR_FILE_CORRUPT
		var dado := Catalogo.no(id)
		if dado.is_empty() or Catalogo.nivel(dados.experiencia[dado.familia]) < dado.nivel: return ERR_FILE_CORRUPT
		if not dado.requisito.is_empty() and not dado.requisito in dados.aprendidos: return ERR_FILE_CORRUPT
		vistos[id] = true
	for f in Catalogo.FAMILIAS:
		if dados.aprendidos.filter(func(id): return Catalogo.no(id).familia == f).size() > Catalogo.pontos(Catalogo.nivel(dados.experiencia[f])): return ERR_FILE_CORRUPT
		var selecionados: Array = dados.equipados[f].tecnicas.duplicate()
		if not dados.equipados[f].finalizador.is_empty(): selecionados.append(dados.equipados[f].finalizador)
		var repetidos := {}
		for id in selecionados:
			if not id is String or not id in dados.aprendidos or repetidos.has(id): return ERR_FILE_CORRUPT
			var dado := Catalogo.no(id)
			if dado.familia != f or dado.tipo != ("finalizador" if id == dados.equipados[f].finalizador else "tecnica"): return ERR_FILE_CORRUPT
			repetidos[id] = true
	experiencia = dados.experiencia.duplicate(); aprendidos.assign(dados.aprendidos)
	equipados = dados.equipados.duplicate(true); legado = dados.get("combo_legado",false)
	recebidos.assign(recibos)
	return OK

func salvar() -> Error:
	if not pronto: return ERR_UNCONFIGURED
	var erro := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(caminho.get_base_dir()))
	if erro != OK: return erro
	var arquivo := FileAccess.open(caminho + ".tmp", FileAccess.WRITE)
	if arquivo == null: return FileAccess.get_open_error()
	arquivo.store_string(JSON.stringify(exportar()))
	arquivo.flush(); erro = arquivo.get_error(); arquivo.close()
	if erro != OK: return erro
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(caminho + ".tmp"), ProjectSettings.globalize_path(caminho))
