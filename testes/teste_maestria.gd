extends SceneTree
var falhas := 0
func _initialize() -> void: rodar.call_deferred()
func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ", nome)
	if not ok: falhas += 1
func rodar() -> void:
	var acoes_p2: Array = root.get_node("Cooperativo").get_script().get_script_constant_map().ACOES_P2
	verificar("tecnicas no controle do P2", "tecnica_1" in acoes_p2 and "tecnica_2" in acoes_p2)
	for acao in ["tecnica_1","tecnica_2"]:
		for evento in InputMap.action_get_events(acao):
			if evento is InputEventJoypadButton:
				verificar("tecnica nao usa direcional " + acao, evento.button_index not in [JOY_BUTTON_DPAD_UP,JOY_BUTTON_DPAD_DOWN,JOY_BUTTON_DPAD_LEFT,JOY_BUTTON_DPAD_RIGHT])
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"): quit(1); return
	DirAccess.remove_absolute("user://teste/maestria.json")
	var catalogo=load("res://codigo/dados/catalogo_maestria.gd")
	var classe=load("res://codigo/modelos/modelo_maestria.gd")
	if catalogo == null or classe == null: quit(1); return
	var modelo=classe.new()
	verificar("save isolado",OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
	verificar("inicia maestria nova",modelo.iniciar("user://teste/maestria.json")==OK)
	for f in catalogo.FAMILIAS:
		verificar("18 nos com identidade propria "+f,catalogo.nos(f).size()==18)
		for no in catalogo.nos(f): verificar("no registrado "+no.id,catalogo.no(no.id)==no)
		verificar("sem pontos iniciais "+f,modelo.nivel(f)==0 and modelo.disponiveis(f)==0)
	verificar("ferramenta nao conta",catalogo.familia("machadinha").is_empty())
	verificar("montantes compartilham dominio",catalogo.familia("montante_geada")=="montante" and catalogo.familia("espada_gemea")=="montante")
	verificar("bloqueio por nivel",modelo.aprender("espada_0_0")==ERR_UNAUTHORIZED)
	verificar("ganho real persistido",modelo.adicionar_xp("espada",catalogo.xp_para_nivel(10))==OK and modelo.nivel("espada")==10)
	verificar("outro armamento independente",modelo.nivel("lanca")==0)
	verificar("requisito anterior exigido",modelo.aprender("espada_0_1")==ERR_UNAUTHORIZED)
	verificar("primeira passiva",modelo.aprender("espada_0_0")==OK and is_equal_approx(modelo.bonus("espada","esquiva"),0.08))
	verificar("aprende tecnica",modelo.aprender("espada_0_1")==OK)
	verificar("equipamento aprendido",modelo.equipar("espada_0_1")==OK)
	verificar("passiva nao ocupa tecnica",modelo.equipar("espada_0_0")==ERR_INVALID_PARAMETER)
	var reaberto=classe.new()
	verificar("reabertura preserva escolhas",reaberto.iniciar("user://teste/maestria.json")==OK and reaberto.aprendidos==modelo.aprendidos and reaberto.equipados==modelo.equipados)
	var antes:Dictionary=modelo.exportar()
	var invalido:Dictionary=antes.duplicate(true)
	invalido.aprendidos.append("espada_0_0")
	verificar("save duplicado recusado sem mudar memoria",modelo.importar(invalido)==ERR_FILE_CORRUPT and modelo.exportar()==antes)
	invalido=antes.duplicate(true);invalido.experiencia.espada=-2
	verificar("xp negativo recusado",modelo.importar(invalido)==ERR_FILE_CORRUPT)
	verificar("redistribuir preserva experiencia",modelo.redistribuir("espada")==OK and modelo.nivel("espada")==10 and modelo.aprendidos.is_empty() and modelo.disponiveis("espada")==3)
	for n in range(101):verificar("curva monotona e reversivel %d" % n,catalogo.nivel(catalogo.xp_para_nivel(n))==n)
	for f in catalogo.FAMILIAS:
		while modelo.nivel(f)<100:
			modelo.adicionar_xp(f,mini(10000,catalogo.xp_para_nivel(100)-int(modelo.experiencia[f])))
		for ramo in 2:
			for degrau in 6:verificar("caminho completo "+f+str(ramo)+str(degrau),modelo.aprender("%s_%d_%d" % [f,ramo,degrau])==OK)
		verificar("doze pontos limitam escolhas "+f,modelo.disponiveis(f)==0 and modelo.aprender(f+"_2_0")==ERR_UNAUTHORIZED)
	verificar("cap no cem",modelo.adicionar_xp("espada",999)==OK and modelo.nivel("espada")==100)
	print("FALHAS: ",falhas)
	quit(1 if falhas else 0)
