extends SceneTree
# Capturas da raridade dos equipamentos: hotbar com uma arma de cada raridade, drops no chão, inventário e aba de venda do mercador.
# Precisa de janela. Uso:
#   godot --path . --resolution 1440x648 --script res://ferramentas/itens/render_raridade.gd -- <pasta_saida>
# Grava user://inventario.json (faça backup do user:// antes).

const Raridades := preload("res://Codigos/DadosLocais/raridades.gd")
const DadosItemScript := preload("res://Codigos/Modelos/dados_item.gd")
var EquipamentoDrop: GDScript

func _initialize() -> void:
	_rodar()

func _novo(tipo: String, categoria: String, raridade: String, nivel: int, afixos: Dictionary):
	var item = DadosItemScript.new()
	item.id = StringName(tipo)
	item.tipo = tipo
	item.categoria = categoria
	item.raridade = raridade
	item.nivel = nivel
	item.afixos = afixos
	item.duas_maos = tipo in ["lanca_basica", "arco_curto", "arco_curvo", "arco_longo"]
	return item

func _salvar(nome: String, regiao: Rect2i, escala: int) -> void:
	var img := root.get_viewport().get_texture().get_image()
	var r := img.get_region(regiao)
	r.resize(r.get_width() * escala, r.get_height() * escala, Image.INTERPOLATE_NEAREST)
	r.save_png(nome)
	print("salvo ", nome)

func _rodar() -> void:
	var pasta: String = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(pasta)
	await process_frame
	EquipamentoDrop = load("res://Codigos/Logicas/equipamento_drop.gd")
	root.get_node("Progresso").caminho_save = "user://render_raridade_progresso.json"
	root.get_node("Fazenda").caminho_save = "user://render_raridade_fazenda.json"
	root.get_node("Progresso").apagar()
	root.get_node("Fazenda").apagar()
	var inv := root.get_node("InventarioJogador")
	inv.limpar()
	inv.criar_itens_iniciais()
	var arena: Node = load("res://cenas/cenario.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	for i in 30:
		await process_frame
	arena.get_node("enemySpawner/GerenciadorOndas").parar_ondas()
	var jogador: Node2D = arena.get_node("Jogador")
	# uma arma de cada raridade
	inv.adicionar(_novo("espada_gemea", "arma", "incomum", 2, {}))
	inv.adicionar(_novo("machado", "arma", "raro", 3, {"critico": 0.03}))
	inv.adicionar(_novo("arco_curvo", "arma", "epico", 3, {"critico": 0.04, "roubo_vida": 2.0}))
	var lend = _novo("arco_longo", "arma", "lendario", 4, {"velocidade": 5.0, "vitalidade": 2.0})
	lend.encantamento = "raio"
	lend.nivel_encantamento = 1
	inv.adicionar(lend)
	inv.adicionar(_novo("escudo_basico", "escudo", "epico", 2, {"defesa": 3.0}))
	for i in 20:
		await process_frame
	var barra: Control = arena.get_node("UI/BarraArmas")
	barra.escolher(3)
	await create_timer(0.6).timeout
	# a captura tem o tamanho da janela (1440x648), não o da tela do jogo (576x324)
	var tela := Vector2(root.get_viewport().get_texture().get_image().get_size())
	print("tela ", tela)
	_salvar(pasta + "/hotbar.png", Rect2i(int(tela.x / 2) - 300, int(tela.y) - 130, 600, 130), 2)
	# drops no chão em volta do jogador (quietos: o jogador está parado e longe do ímã)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var rar := ["comum", "incomum", "raro", "epico", "lendario"]
	var tipos := ["espada_basica", "lanca_basica", "maca", "arco_curto", "arco_longo"]
	for i in 5:
		var drop: Node2D = EquipamentoDrop.soltar_item(_novo(tipos[i], "arma", rar[i], 1, {}), jogador.global_position + Vector2(-90 + i * 45, 60), arena, rng)
		drop._tempo = 0.0
	await create_timer(1.0).timeout
	var c := Vector2i(int(tela.x / 2), int(tela.y / 2))
	_salvar(pasta + "/drops.png", Rect2i(c.x - 330, c.y - 20, 660, 330), 2)
	# inventário
	root.get_node("EventosJogo").abrir_tela.emit("inventario")
	await create_timer(0.6).timeout
	root.get_viewport().get_texture().get_image().save_png(pasta + "/inventario_tela.png")
	print("salvo inventario_tela")
	# mercador, aba de venda
	root.get_node("EventosJogo").fechar_tela.emit("inventario")
	await create_timer(0.3).timeout
	root.get_node("EventosJogo").abrir_tela.emit("mercante")
	await create_timer(0.6).timeout
	var mercante: Control = get_first_node_in_group("tela_mercante")
	if mercante != null:
		mercante._aba_vender.button_pressed = true
		mercante._mostrar_aba(mercante._painel_vender)
		await create_timer(0.3).timeout
		root.get_viewport().get_texture().get_image().save_png(pasta + "/vender_vazio.png")
		var casa: Control = load("res://cenas/ui/componentes/item_ui.tscn").instantiate()
		mercante.add_child(casa)
		casa.exibir(lend)
		inv.remover_da_mochila(lend)
		inv.adicionar(lend)
		mercante._slot_venda.colocar_item(casa)
		await create_timer(0.4).timeout
		root.get_viewport().get_texture().get_image().save_png(pasta + "/vender_item.png")
		print("salvo vender")
	quit()
