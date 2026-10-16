extends SceneTree
# Captura a cena de jogo de verdade (cenario.tscn ou inicio_do_jogo.tscn) como o jogador a ve: HUD, luz, clima, camera.
# Precisa de janela (nao headless). Uso:
#   godot --path . --script res://ferramentas/arena/render_jogo.gd -- <cena.tscn> <tomadas.json> <pasta_saida>
# Tomadas: {"nome":"x","estacao":0..3,"jogador":[x,y],"quadros":40,"hora":12.0}
# "jogador" em coordenadas do terreno (cenario: soma (-4, 14); fazenda e casa: coordenadas da propria cena);
# "hora" fixa a hora do ciclo dia/noite (0..24); "dia" poe o Calendario nesse dia (so a data do HUD; a estacao visual
# continua vindo de "estacao"). Ex.: estacao 2 + dia 15 = "OUTONO - DIA 1".
# Etapa 3 (so cenario.tscn): "chefe" (indice em GerenciadorOndas.CHEFES) com "onda", "dx"/"dy" (distancia do jogador),
# "acoes" (metodos da habilidade a chamar: invocar_cogumelos, iniciar_esporos, iniciar_investida), "vida_pct" (0..1);
# "evento" (id de GerenciadorOndas.EVENTOS) acende o evento da onda e o banner.
# Clima (codigo/cenario/clima.gd): "clima" = nome do estado em minusculas (limpo, nublado, chuva_leve, chuva_forte,
# tempestade, neve_leve, neve_forte), aplicado sem fade; sem "clima" vale o padrao da estacao. "raio": {"dx","dy","aviso"}
# cria um raio a (dx,dy) dos pes do jogador (aviso em s: 5 = so o indicador no chao; 0 = o raio ja cai).
# Com "clima" as tomadas esperam o fade do tom; use "quadros" altos nas que dependem das animacoes.
# Pocoes (cinto do HUD): "pocoes" = {"id": n} poe o estoque da Fazenda; "beber" = [ids] bebe na ordem (sem a espera entre
# goles); "selecionar" = id escolhe a pocao do cinto; "sementes_chao" = n saquinhos de semente espalhados a ~70 px do jogador
# (ou "sementes_chao" = ["id", ...] para escolher as sementes, ex.: ver o brilho das raras).
# ATENCAO: beber grava o estoque no user://fazenda.json real (faça backup do user://).

var _tomadas: Array = []
var _pasta := ""
var _cena: Node
var _i := 0
var _espera := -1

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_tomadas = JSON.parse_string(FileAccess.get_file_as_string(args[1]))
	_pasta = args[2]
	DirAccess.make_dir_recursive_absolute(_pasta)
	_cena = load(args[0]).instantiate()
	root.add_child(_cena)
	current_scene = _cena

func _process(_delta: float) -> bool:
	if _i >= _tomadas.size():
		quit()
		return false
	var t: Dictionary = _tomadas[_i]
	if _espera < 0:
		var est := _cena.find_child("Estacoes", true, false)
		if est and t.has("estacao"):
			est.definir_estacao(int(t["estacao"]), true)
		if t.has("dia"):
			root.get_node("Calendario").dia = int(t["dia"])
			for hud in get_nodes_in_group("hud"):
				hud.atualizar_data()
		var jogador := _cena.get_node_or_null("Jogador")
		if jogador and t.has("jogador"):
			var desloc := Vector2(-4.0, 14.0) if _cena.name == "cenario" else Vector2.ZERO
			jogador.global_position = Vector2(float(t["jogador"][0]), float(t["jogador"][1])) + desloc
			if jogador.camera != null:
				jogador.camera.reset_smoothing()
		var luz := _cena.get_node_or_null("Iluminacao")
		if luz and t.has("hora"):
			luz.hora = float(t["hora"])
			luz.set_process(false)
			luz._aplicar()
		_montar_etapa3(t)
		_montar_clima(t)
		_montar_pocoes(t)
		_montar_painel_titulo(t)
		_espera = int(t.get("quadros", 40))
	else:
		_espera -= 1
		if _espera <= 0:
			var img := root.get_viewport().get_texture().get_image()
			var caminho := "%s/%s.png" % [_pasta, t["nome"]]
			img.save_png(caminho)
			print("salvo: ", caminho, " ", img.get_size())
			_i += 1
			_espera = -1
	return false

# So inicio_do_jogo.tscn: "abrir" = "creditos" | "opcoes" aperta o botao do menu; "rolar" = pixels de rolagem dos creditos;
# "menu" = true fecha o painel aberto (volta ao menu)
func _montar_painel_titulo(t: Dictionary) -> void:
	if _cena.name != "InicioDoJogo":
		return
	if t.get("menu", false) and _cena._painel_aberto != null:
		_cena._fechar_painel()
	match String(t.get("abrir", "")):
		"creditos":
			_cena.botao_creditos.pressed.emit()
		"opcoes":
			_cena.botao_opcoes.pressed.emit()
	if t.has("rolar"):
		_cena.rolagem_creditos.scroll_vertical = int(t["rolar"])

func _montar_pocoes(t: Dictionary) -> void:
	var fazenda := root.get_node("Fazenda")
	var jogador := _cena.get_node_or_null("Jogador")
	if t.has("pocoes"):
		fazenda.pocoes = {}
		for id in t["pocoes"]:
			fazenda.pocoes[id] = int(t["pocoes"][id])
		fazenda.bolsas_alteradas.emit()
	if jogador != null and jogador.get("efeitos_pocao") != null:
		var efeitos: Node = jogador.efeitos_pocao
		for id in t.get("beber", []):
			efeitos._espera = 0.0
			efeitos.beber(String(id))
		if t.has("selecionar"):
			while efeitos.selecionada != String(t["selecionar"]) and not fazenda.pocoes_que_tem().is_empty():
				efeitos.trocar(1)
	var chao = t.get("sementes_chao", 0)
	var qtd_chao: int = chao.size() if chao is Array else int(chao)
	if jogador != null and qtd_chao > 0:
		var drop_gd: GDScript = load("res://codigo/logica/semente_drop.gd")
		var rng := RandomNumberGenerator.new()
		rng.seed = 3
		for i in qtd_chao:
			var drop: Node2D = drop_gd.new()
			drop.semente = String(chao[i]) if chao is Array else drop_gd.sortear_planta(root.get_node("Calendario").estacao(), rng)
			var ponto: Vector2 = jogador.global_position + Vector2.from_angle(TAU * i / float(qtd_chao)) * 70.0
			drop.preparar_pulo(ponto, ponto)
			_cena.add_child(drop)

# Clima e raio da tomada: o clima entra na hora (sem fade) e o tom escuro da luz e reaplicado no ciclo parado
func _montar_clima(t: Dictionary) -> void:
	var est := _cena.find_child("Estacoes", true, false)
	if est == null or est.get("meteorologia") == null:
		return
	var meteoro: Node = est.meteorologia
	meteoro.limpar_raios()
	var estado: int = meteoro.clima_padrao(est.estacao_atual)
	if t.has("clima"):
		estado = int(meteoro.Estado[String(t["clima"]).to_upper()])
	meteoro.tempestade_ativa = estado == meteoro.Estado.TEMPESTADE
	meteoro.definir_clima(estado, true)
	var luz := _cena.get_node_or_null("Iluminacao")
	if luz:
		luz.definir_tom_clima(meteoro.TONS[estado], 0.0)
		luz._aplicar()
	var jogador := _cena.get_node_or_null("Jogador")
	if t.has("raio") and jogador:
		var r: Dictionary = t["raio"]
		var pes: Vector2 = jogador.global_position + Vector2(0, 11)
		meteoro.criar_raio(pes + Vector2(float(r.get("dx", 40)), float(r.get("dy", -20))), float(r.get("aviso", 5.0)))

# Chefe e evento da Etapa 3, colocados sem passar pela onda de verdade (a luta fica parada para a captura)
func _montar_etapa3(t: Dictionary) -> void:
	var gerenciador := _cena.get_node_or_null("enemySpawner/GerenciadorOndas")
	var jogador := _cena.get_node_or_null("Jogador")
	if gerenciador == null or jogador == null:
		return
	# Cada tomada parte de uma arena limpa
	for antigo in get_nodes_in_group("enemy"):
		antigo.free()
	gerenciador._encerrar_evento()
	var luz := _cena.get_node_or_null("Iluminacao")
	if luz:
		luz.definir_tom_evento(Color.WHITE, 0.0)
	get_nodes_in_group("hud")[0].painel_chefe.hide()
	if t.has("chefe"):
		var onda := int(t.get("onda", 20))
		gerenciador.onda_atual = onda
		gerenciador.multiplicador_vida_inimigo = 1.0 + 0.15 * (onda - 1)
		gerenciador.multiplicador_dano_inimigo = 1.0 + 0.08 * (onda - 1)
		var dados: Dictionary = gerenciador.CHEFES[int(t["chefe"])]
		var inimigo: Node2D = dados["cena"].instantiate()
		if dados.has("escala"):
			inimigo.tornar_chefe(dados["nome"], dados["escala"], dados["mult_vida"], dados.get("mult_dano", 1.0), dados.get("habilidade", ""), dados.get("altura_coroa", -1.0))
		inimigo.position = jogador.global_position + Vector2(float(t.get("dx", 70)), float(t.get("dy", 0)))
		_cena.get_node("enemySpawner").aplicar_atributos(inimigo, gerenciador.multiplicador_vida_inimigo, gerenciador.multiplicador_dano_inimigo)
		_cena.add_child(inimigo)
		inimigo.velocidade = 0
		for acao in t.get("acoes", []):
			if inimigo.get("habilidade_chefe") != null:
				inimigo.habilidade_chefe.call(acao) if acao != "iniciar_investida" else inimigo.habilidade_chefe.iniciar_investida(Vector2.LEFT)
		if t.has("vida_pct") and inimigo.get("eh_chefe") == true:
			inimigo.vida = int(inimigo.vida_maxima * float(t["vida_pct"]))
			inimigo._avisar_vida_chefe()
		jogador.hp_atual = jogador.estatisticas.hp_maximo
		jogador.invulneravel = true
		# O banner de abertura dura alguns segundos e cobre a luta: some, a menos que a tomada peca "banner"
		if not t.get("banner", false):
			get_nodes_in_group("hud")[0].faixa_banner.hide()
	if t.has("evento"):
		for e in gerenciador.EVENTOS:
			if e["id"] == t["evento"]:
				gerenciador.onda_atual = int(t.get("onda", 6))
				gerenciador._definir_evento(e)
				if luz:
					luz.definir_tom_evento(e.get("tom", Color.WHITE), 0.0)
					luz._aplicar()
				get_nodes_in_group("hud")[0]._ao_onda_iniciada(gerenciador.onda_atual)
