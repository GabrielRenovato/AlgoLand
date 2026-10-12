extends SceneTree
# Captura a fazenda com a mecanica de plantio (Etapa B) como o jogador a ve: solo arado e molhado, plantas em varios estagios,
# barra de ferramentas e a tela do caldeirao. Precisa de janela (nao headless). Uso:
#   godot --path . --script res://ferramentas/fazenda/render_plantio.gd -- <tomadas.json> <pasta_saida>
# Usa arquivos de teste para Fazenda, Calendario e Progresso (nao toca nos saves reais).
# Tomada: {"nome": "x", "estacao": 0..3, "dia": N, "jogador": [x, y], "hora": 12.0, "quadros": 40, "clima": "limpo",
#          "campo": "vazio" | "estagios" | "arado" | "murcho", "ferramenta": "enxada" | "regador" | "mao" | "semente:<id>",
#          "zoom": 1.0 (camera), "debug": true (abre o painel F3), "sementes": {"id": n}, "colheita": {"id": n}, "pocoes": {"id": n}, "ouro": N, "tela": "caldeirao", "aviso": "TEXTO"}
# "estagios": uma fileira por planta da estacao (y 23, 25, 27, 29), cada coluna num dia de crescimento diferente (de 0 ate madura),
# colunas alternadas secas e molhadas; entre as fileiras fica solo arado; a primeira e a ultima fileira da area ficam sem arar.
# "arado": so solo arado (3 colunas secas, 3 molhadas). "murcho": as plantas da estacao anterior, secas, no inicio da estacao.

var _tomadas: Array = []
var _pasta := ""

func _initialize() -> void:
	_rodar()

func _foto(nome: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	var caminho := "%s/%s.png" % [_pasta, nome]
	img.save_png(caminho)
	print("salvo: ", caminho, " ", img.get_size())

func _rodar() -> void:
	var args := OS.get_cmdline_user_args()
	_tomadas = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	_pasta = args[1]
	DirAccess.make_dir_recursive_absolute(_pasta)
	await process_frame
	var fazenda_dados := root.get_node("Fazenda")
	var calendario := root.get_node("Calendario")
	var progresso := root.get_node("Progresso")
	fazenda_dados.caminho_save = "user://render_plantio_fazenda.json"
	calendario.caminho_save = "user://render_plantio_calendario.json"
	progresso.caminho_save = "user://render_plantio_progresso.json"
	fazenda_dados.apagar()
	calendario.apagar()
	progresso.apagar()
	var cena: Node = load("res://cenas/fazenda.tscn").instantiate()
	root.add_child(cena)
	current_scene = cena
	for i in 20:
		await process_frame
	var jogador := cena.get_node("Jogador")
	var estacoes := cena.find_child("Estacoes", true, false)
	var luz := cena.get_node("Iluminacao")
	for t in _tomadas:
		await _tomada(t, fazenda_dados, calendario, jogador, estacoes, luz, cena)
	fazenda_dados.apagar()
	calendario.apagar()
	progresso.apagar()
	for caminho in ["user://render_plantio_fazenda.json", "user://render_plantio_calendario.json", "user://render_plantio_progresso.json"]:
		if FileAccess.file_exists(caminho):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(caminho))
	quit()

func _tomada(t: Dictionary, fd: Node, calendario: Node, jogador: Node, estacoes: Node, luz: Node, cena: Node) -> void:
	var estacao := int(t.get("estacao", 0))
	calendario.dia = int(t.get("dia", 1 + estacao * 7))
	estacoes.definir_estacao(estacao, true)
	for hud in get_nodes_in_group("hud"):
		hud.atualizar_data()
	fd.solo = {}
	fd.sementes = {}
	fd.colheita = {}
	fd.pocoes = {}
	fd.clima_hoje = -1
	_montar_campo(fd, String(t.get("campo", "vazio")), estacao)
	for id in t.get("sementes", {}):
		fd.sementes[id] = int(t["sementes"][id])
	for id in t.get("colheita", {}):
		fd.colheita[id] = int(t["colheita"][id])
	for id in t.get("pocoes", {}):
		fd.pocoes[id] = int(t["pocoes"][id])
	root.get_node("DadosJogo").moedas = int(t.get("ouro", 120))
	root.get_node("DadosJogo").atualizar_ui_moedas()
	fd.ferramenta = "enxada"
	fd.definir_ferramenta(String(t.get("ferramenta", "enxada")))
	fd.solo_recarregado.emit()
	fd.bolsas_alteradas.emit()
	var p: Array = t.get("jogador", [392, 338])
	jogador.global_position = Vector2(float(p[0]), float(p[1]))
	jogador._direcao_ataque = Vector2.DOWN
	if jogador.camera != null:
		var zoom := float(t.get("zoom", 1.0))
		jogador.camera.zoom = Vector2(zoom, zoom)
		jogador.camera.reset_smoothing()
	luz.hora = float(t.get("hora", 12.0))
	luz.set_process(false)
	luz._aplicar()
	var meteoro: Node = estacoes.meteorologia
	var estado: int = meteoro.clima_padrao(estacao)
	if t.has("clima"):
		estado = int(meteoro.Estado[String(t["clima"]).to_upper()])
	meteoro.definir_clima(estado, true)
	luz.definir_tom_clima(meteoro.TONS[estado], 0.0)
	luz._aplicar()
	if t.has("aviso"):
		for hud in get_nodes_in_group("hud"):
			hud.avisar_ferramenta(String(t["aviso"]))
	if t.has("tela"):
		root.get_node("EventosJogo").abrir_tela.emit(String(t["tela"]))
	var painel_debug := root.get_node_or_null("PainelDebug")
	if painel_debug != null:
		painel_debug._painel.visible = bool(t.get("debug", false))
	for i in int(t.get("quadros", 40)):
		await process_frame
	_foto(String(t["nome"]))
	if t.has("tela"):
		root.get_node("EventosJogo").fechar_tela.emit(String(t["tela"]))
		for i in 4:
			await process_frame

func _montar_campo(fd: Node, campo: String, estacao: int) -> void:
	var area: Rect2i = fd.AREA_PLANTIO
	match campo:
		"arado":
			for y in range(area.position.y + 1, area.end.y - 1):
				for x in range(area.position.x + 1, area.end.x - 1):
					fd.solo[Vector2i(x, y)] = {"molhado": x >= area.position.x + 8, "planta": "", "dias": 0, "murcha": false}
		"estagios":
			var ids: Array = fd.plantas_da_estacao(estacao)
			for y in range(area.position.y + 1, area.end.y - 1):
				for x in range(area.position.x, area.end.x):
					fd.solo[Vector2i(x, y)] = {"molhado": (x % 2) == 0, "planta": "", "dias": 0, "murcha": false}
			for r in ids.size():
				var id: String = ids[r]
				var total: int = fd.PLANTAS[id]["dias"]
				var y := area.position.y + 1 + r * 2
				for x in range(area.position.x + 1, area.end.x - 1):
					var celula := Vector2i(x, y)
					fd.solo[celula]["planta"] = id
					fd.solo[celula]["dias"] = (x - area.position.x - 1) % (total + 1)
		"murcho":
			# plantas da estacao anterior (a que acabou de terminar), secas
			var anterior := posmod(estacao - 1, 3)
			var ids: Array = fd.plantas_da_estacao(anterior)
			for y in range(area.position.y + 1, area.end.y - 1):
				for x in range(area.position.x, area.end.x):
					fd.solo[Vector2i(x, y)] = {"molhado": false, "planta": "", "dias": 0, "murcha": false}
			for r in ids.size():
				var id: String = ids[r]
				var y := area.position.y + 1 + r * 2
				for x in range(area.position.x + 1, area.end.x - 1):
					fd.solo[Vector2i(x, y)]["planta"] = id
					fd.solo[Vector2i(x, y)]["dias"] = 1 + (x % 3)
					fd.solo[Vector2i(x, y)]["murcha"] = true
