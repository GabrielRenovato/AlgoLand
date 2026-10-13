extends SceneTree
# Captura a guarda (aparar) e a escudada do jogador na arena: uma tira por arma/direção com a pose de aparar e os quadros do
# contra-ataque. Precisa de janela. Uso:
#   godot --path . --script res://ferramentas/fazenda/render_defesa.gd -- <pasta_saida>
# Equipa itens pelo inventário (grava user://inventario.json): faça backup do user:// antes. Salva defesa_<arma>_<direcao>.png.

const LADO := 120
const ESCALA := 3

var _cena: Node
var _jogador: Node2D
var _tira: Array[Image] = []

func _initialize() -> void:
	_rodar()

func _foto() -> void:
	var img := root.get_viewport().get_texture().get_image()
	var centro := img.get_size() / 2
	var recorte := img.get_region(Rect2i(centro.x - LADO / 2, centro.y - LADO / 2 - 8, LADO, LADO))
	recorte.resize(LADO * ESCALA, LADO * ESCALA, Image.INTERPOLATE_NEAREST)
	_tira.append(recorte)

func _salvar(caminho: String) -> void:
	var tira := Image.create(LADO * ESCALA * _tira.size(), LADO * ESCALA, false, Image.FORMAT_RGBA8)
	for i in _tira.size():
		tira.blit_rect(_tira[i], Rect2i(0, 0, LADO * ESCALA, LADO * ESCALA), Vector2i(i * LADO * ESCALA, 0))
	tira.save_png(caminho)
	print("salvo: ", caminho)
	_tira.clear()

func _esperar(s: float) -> void:
	await create_timer(s).timeout

func _rodar() -> void:
	var pasta: String = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(pasta)
	await process_frame
	root.get_node("Progresso").caminho_save = "user://render_defesa_progresso.json"
	root.get_node("Fazenda").caminho_save = "user://render_defesa_fazenda.json"
	root.get_node("Progresso").apagar()
	root.get_node("Fazenda").apagar()
	var inventario := root.get_node("InventarioJogador")
	inventario.limpar()
	inventario.criar_itens_iniciais()
	_cena = load("res://cenas/cenario.tscn").instantiate()
	root.add_child(_cena)
	current_scene = _cena
	for i in 20:
		await process_frame
	_jogador = _cena.get_node("Jogador")
	_cena.get_node("enemySpawner/GerenciadorOndas").parar_ondas()
	for inimigo in get_nodes_in_group("enemy"):
		inimigo.queue_free()
	var defesa: Node = _jogador.get_node("Defesa")

	var armas := {"espada": ["espada_basica", "escudo_basico"], "lanca": ["lanca_basica"]}
	for nome in armas:
		for tipo in armas[nome]:
			inventario.equipar(inventario.buscar_por_tipo(tipo))
		for i in 6:
			await process_frame
		for dir in [["direita", Vector2.RIGHT], ["baixo", Vector2.DOWN], ["cima", Vector2.UP], ["esquerda", Vector2.LEFT]]:
			_jogador.invulneravel = false
			_jogador.stamina = _jogador.stamina_maxima
			Input.action_release("aparar")
			await _esperar(0.4)
			_jogador._direcao_ataque = dir[1]
			# parado de pé olhando para a direção, a guarda e depois o aparo perfeito e a escudada
			_jogador.virar_para(dir[1])
			await _esperar(0.2)
			_foto()
			Input.action_press("aparar")
			await _esperar(0.12)
			_foto()
			_jogador.receber_dano(1, -dir[1] * 150.0)
			await _esperar(0.06)
			_foto()
			if nome == "espada":
				await _esperar(0.12)
				_foto()
				await _esperar(0.1)
				_foto()
				await _esperar(0.1)
				_foto()
				await _esperar(0.12)
				_foto()
			Input.action_release("aparar")
			_salvar("%s/defesa_%s_%s.png" % [pasta, nome, dir[0]])
			await _esperar(0.7)
	root.get_node("Progresso").apagar()
	root.get_node("Fazenda").apagar()
	quit()
