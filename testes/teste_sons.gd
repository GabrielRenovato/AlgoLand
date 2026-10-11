extends SceneTree

# Rodar: godot --headless --path . --script res://testes/teste_sons.gd
# Confere o autoload Sons: todos os efeitos carregam, tocar não falha (nem sem saída de áudio),
# o limite por quadro barra repetições e botões ganham os sons de menu.

const NOMES := ["golpe_espada", "golpe_lanca", "flecha", "acerto", "inimigo_morre", "jogador_dano", "jogador_morre",
	"dash", "reviver", "moeda", "compra", "melhoria", "erro", "onda_inicio", "onda_fim", "chefe_aparece",
	"chefe_morre", "estacao", "trovao", "menu_mover", "menu_confirmar"]

var _falhas: int = 0

func _initialize() -> void:
	_rodar()

func _verificar(nome: String, condicao: bool, detalhe: String = "") -> void:
	if condicao:
		print("OK ", nome)
	else:
		_falhas += 1
		print("FALHA ", nome, ": ", detalhe)

func _rodar() -> void:
	await process_frame
	var sons = root.get_node("Sons")

	# --- todos os arquivos existem e carregam como áudio com duração
	var todos_carregam := true
	var duracoes_ok := true
	for nome in NOMES:
		var stream = load("res://sons/%s.wav" % nome)
		if not (stream is AudioStreamWAV):
			todos_carregam = false
			print("  nao carregou: ", nome)
		elif stream.get_length() <= 0.02 or stream.get_length() > 1.5:
			duracoes_ok = false
			print("  duracao estranha: ", nome, " ", stream.get_length())
	_verificar("os %d wavs carregam como AudioStreamWAV" % NOMES.size(), todos_carregam)
	_verificar("duracoes entre 0,02 e 1,5 s", duracoes_ok)

	# --- o autoload conhece todos os nomes
	var todos_existem := true
	for nome in NOMES:
		if not sons.existe(nome):
			todos_existem = false
			print("  Sons nao conhece: ", nome)
	_verificar("Sons.existe() para todos os nomes", todos_existem)
	_verificar("Sons.STREAMS tem exatamente os nomes esperados", sons.STREAMS.size() == NOMES.size())
	_verificar("pool com 8 players", sons.get_child_count() == 8)

	# --- tocar: cada som toca (em quadros diferentes, para o limite por quadro não interferir)
	var todos_tocam := true
	for nome in NOMES:
		await process_frame
		sons._ultimo_uso.clear()
		if not sons.tocar(nome, 0.1, -6.0):
			todos_tocam = false
			print("  nao tocou: ", nome)
	_verificar("tocar() devolve true para todos os sons", todos_tocam)
	_verificar("nome inexistente nao falha e devolve false", sons.tocar("nao_existe") == false)

	# --- limite por quadro: no mesmo quadro só a primeira repetição passa
	await process_frame
	sons._ultimo_uso.clear()
	var primeira: bool = sons.tocar("acerto")
	var segunda: bool = sons.tocar("acerto")
	var terceira: bool = sons.tocar("acerto")
	_verificar("limite por quadro: 1a toca, 2a e 3a sao barradas", primeira and not segunda and not terceira,
		"%s %s %s" % [primeira, segunda, terceira])
	var outro: bool = sons.tocar("moeda")
	_verificar("limite e por som: outro som no mesmo quadro toca", outro)
	await process_frame
	sons._ultimo_uso.clear()
	_verificar("no quadro seguinte o mesmo som volta a tocar", sons.tocar("acerto"))

	# --- intervalo mínimo entre repetições (moeda: 45 ms)
	await process_frame
	sons._ultimo_uso.clear()
	var inicio_moeda := Time.get_ticks_msec()
	var moeda_a: bool = sons.tocar("moeda")
	await process_frame
	var moeda_b: bool = sons.tocar("moeda")
	# Se o quadro demorou mais que o intervalo (máquina lenta) a repetição é legitimamente liberada
	var rapido: bool = Time.get_ticks_msec() - inicio_moeda < 40
	_verificar("intervalo minimo: moeda repetida logo em seguida e barrada", moeda_a and (not moeda_b or not rapido),
		"%s %s" % [moeda_a, moeda_b])

	# --- pool cheio: continua tocando (reaproveita um player) e o número de players não cresce
	for i in 20:
		await process_frame
		sons._ultimo_uso.clear()
		sons.tocar("chefe_aparece")
		sons.tocar("jogador_morre")
		sons.tocar("onda_fim")
	_verificar("pool cheio nao cria players nem falha", sons.get_child_count() == 8)

	# --- pitch e volume aplicados
	await process_frame
	sons._ultimo_uso.clear()
	sons.tocar("flecha", 0.0, -9.0)
	var jogador_pitch: AudioStreamPlayer = null
	for j in sons._jogadores:
		if j.stream == sons.STREAMS["flecha"] and j.playing:
			jogador_pitch = j
	_verificar("variacao 0 mantem o pitch 1.0 e aplica o volume", jogador_pitch != null
		and is_equal_approx(jogador_pitch.pitch_scale, 1.0) and is_equal_approx(jogador_pitch.volume_db, -9.0))

	# --- botões: foco e clique ligam sons; meta som_proprio tira só o "confirmar"
	var raiz := Control.new()
	var botao_normal := Button.new()
	var botao_proprio := Button.new()
	botao_proprio.set_meta(sons.META_SOM_PROPRIO, true)
	raiz.add_child(botao_normal)
	raiz.add_child(botao_proprio)
	root.add_child(raiz)
	sons.ligar_botoes(raiz)
	sons.ligar_botoes(raiz)  # idempotente
	_verificar("ligar_botoes liga foco e clique uma vez so", botao_normal.pressed.get_connections().size() == 1
		and botao_normal.focus_entered.get_connections().size() == 1)
	await process_frame
	sons._ultimo_uso.clear()
	botao_normal.pressed.emit()
	var tocou_confirmar := false
	for j in sons._jogadores:
		if j.stream == sons.STREAMS["menu_confirmar"] and j.playing:
			tocou_confirmar = true
	_verificar("botao normal toca menu_confirmar ao ser pressionado", tocou_confirmar)
	await process_frame
	for j in sons._jogadores:
		j.stop()
	sons._ultimo_uso.clear()
	botao_proprio.pressed.emit()
	var tocou_algo := false
	for j in sons._jogadores:
		if j.playing:
			tocou_algo = true
	_verificar("botao com som_proprio nao toca o confirmar generico", not tocou_algo)
	raiz.queue_free()

	print("--- teste_sons: ", "TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas)
	quit(0 if _falhas == 0 else 1)
