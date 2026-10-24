extends SceneTree

## Cada andar da fenda tem a sua estação (campo "estacao" da planta) e o clima do andar é só dele; a vila, a fazenda e o
## Calendario seguem a estação e o clima certos do mundo, antes, durante e depois da passagem por um andar de outra estação.
## Exige projeto com `config/custom_user_dir_name` começando por "AlgoLand testes" (carrega cenas com autoloads).

var falhas := 0
var verificacoes := 0

func _initialize() -> void:
	_rodar.call_deferred()

func verificar(nome: String, ok: bool) -> void:
	verificacoes += 1
	print("OK " if ok else "FALHA ", nome)
	if not ok:
		falhas += 1

func quadros(n := 10) -> void:
	for i in n:
		await process_frame
	await physics_frame

func carregar(caminho: String) -> Node:
	if current_scene != null:
		current_scene.queue_free()
		current_scene = null
		await quadros(4)
	var cena: Node = load(caminho).instantiate()
	root.add_child(cena)
	current_scene = cena
	await quadros(30)
	return cena

func _rodar() -> void:
	if not ProjectSettings.get_setting("application/config/use_custom_user_dir", false) or not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AlgoLand testes"):
		push_error("Teste exige save isolado (AlgoLand testes ...)")
		quit(1)
		return
	var Clima: GDScript = load("res://codigo/cenario/clima.gd")
	var calendario := root.get_node("Calendario")
	var fazenda := root.get_node("Fazenda")
	var estacao_mundo: int = calendario.estacao()
	var clima_mundo: int = fazenda.clima_hoje
	# Cada planta define a sua estação (0 a 3)
	var plantas: Array = load("res://codigo/fendas/catalogo_andares.gd").PLANTAS
	verificar("as onze plantas definem a estação do andar", plantas.all(func(p): return p.data.has("estacao") and int(p.data["estacao"]) in [0, 1, 2, 3]))
	verificar("as estações variam entre os andares", plantas.map(func(p): return int(p.data["estacao"])).reduce(func(a, b): return a | (1 << b), 0) == 15)
	# Um andar de estação diferente da do mundo: andar 8 (inverno)
	var alvo := 3 if estacao_mundo != 3 else 0
	var andar := ""
	for numero in range(1, 12):
		if int(plantas[numero - 1].data["estacao"]) == alvo and not str(plantas[numero - 1].data["bioma"]).begins_with("caverna"):
			andar = "res://cenas/fendas/andar_%02d.tscn" % numero
			break
	var cena := await carregar(andar)
	var estacoes: Node = cena.get_node("Terrains/Estacoes")
	verificar("o andar usa a estação da planta (%d, o mundo está em %d)" % [alvo, estacao_mundo], estacoes.estacao_atual == alvo)
	verificar("o Calendario não foi tocado", calendario.estacao() == estacao_mundo)
	var meteorologia: Node = estacoes.meteorologia
	verificar("o clima do andar acompanha a estação dele", Clima.vale_na_estacao(meteorologia.clima_atual, alvo))
	# O calendário virar de estação não muda o andar
	var outra := (estacao_mundo + 1) % 4
	calendario.estacao_mudou.emit(outra)
	await quadros(6)
	verificar("o andar ignora a troca de estação do calendário", estacoes.estacao_atual == alvo)
	# Clima por onda: sorteia dentro do andar e não passa para o mundo
	var gerente := get_first_node_in_group("gerenciador_andar")
	gerente.onda_iniciada.emit(1)
	await quadros(6)
	verificar("o clima da onda não vaza para o mundo", fazenda.clima_hoje == clima_mundo)
	verificar("o clima sorteado combina com a estação do andar", Clima.vale_na_estacao(meteorologia.clima_atual, alvo))
	# Voltar para a vila: estação e clima certos
	var transicao := root.get_node("Transicao")
	transicao.sair_da_arena()
	await transicao.troca_concluida
	await quadros(4)
	var vila := current_scene
	verificar("saída do andar guarda 23h", is_equal_approx(transicao.hora_salva, 23.0))
	verificar("a vila inicia às 23:00, sem voltar para a manhã", vila.get_node("Iluminacao").hora >= 23.0 and vila.get_node("Iluminacao").hora < 23.2)
	var estacoes_vila: Node = vila.get_node("Terrains/Estacoes")
	verificar("a vila volta na estação do calendário", estacoes_vila.estacao_atual == calendario.estacao() and calendario.estacao() == estacao_mundo)
	verificar("a vila volta com o clima do mundo", estacoes_vila.meteorologia.clima_atual == Clima.clima_do_mundo(estacao_mundo) and fazenda.clima_hoje == clima_mundo)
	var campo := await carregar("res://cenas/fazenda.tscn")
	verificar("a fazenda também", campo.get_node("Terrains/Estacoes").estacao_atual == estacao_mundo)
	print("%d verificações, %d falhas" % [verificacoes, falhas])
	quit(1 if falhas > 0 else 0)
