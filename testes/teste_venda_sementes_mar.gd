extends SceneTree

const Loja := preload("res://codigo/dados/loja_sementes.gd")
var Sessao: GDScript
var falhas := 0
func _initialize() -> void: rodar.call_deferred()
func quadros(n := 8) -> void:
	for i in n:
		await process_frame
		await physics_frame
func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ", nome)
	if not ok: falhas += 1
func capturar(nome: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/algoland-sementes-mar-%s.png" % nome)
func rodar() -> void:
	await process_frame
	Sessao = load("res://codigo/pesca/sessao_pesca.gd")
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"): quit(1); return
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1152,648)
	root.content_scale_size = Vector2i(576,324)
	root.get_node("Saves").trocar("coop")
	root.get_node("Introducao").pular_prologo()
	preload("res://codigo/globais/opcoes_jogo.gd").fechar_mini_tutorial()
	var prog = root.get_node("Progresso")
	prog.apagar()
	var cal = root.get_node("Calendario")
	cal.dia = 1
	var inv = root.get_node("InventarioJogador")
	var inv2 = root.get_node("InventarioJogador2")
	for mochila in [inv, inv2]:
		mochila.limpar()
		mochila.criar_itens_iniciais()
	change_scene_to_file("res://cenas/cidade.tscn")
	await quadros(30)
	root.get_node("Transicao").limpar()
	var ui = root.get_node("Cooperativo").interface_p2()
	ui._abrir_tela("mercante")
	await quadros()
	var loja = ui._telas["mercante"]
	var tela = ui._telas["inventario"]
	verificar("aba vender habilitada na cidade", loja._aba_vender.visible and not loja._aba_vender.disabled)
	inv2.adicionar_sementes("cenoura", 7)
	inv2.adicionar_sementes("girassol", 3)
	await quadros()
	loja._aba_vender.button_pressed = true
	loja._aba_vender.pressed.emit()
	var dados = inv2.buscar_por_tipo("semente:cenoura")
	var origem = tela._slots_mochila[inv2.indice_de(dados)].item_ui()
	verificar("arrasto aceita sementes e rejeita armas", loja._slot_venda.aceita_item(origem) and not loja._slot_venda.aceita_tipo_item("espada_basica"))
	verificar("confirmar no controle coloca semente para vender", loja.receber_item_do_controle(origem))
	verificar("previa considera a pilha e mostra Brasas", loja._valor_do_item_venda() == 7 and loja._valor_venda.text == "VALE 7 BRASAS")
	for tamanho in [Vector2i(576,324), Vector2i(288,512), Vector2i(320,324)]:
		root.content_scale_size = tamanho
		root.size = tamanho * 2
		await quadros()
		var troca: Button = ui._troca_companheira
		if troca.visible:
			var largura_texto := troca.get_theme_font("font").get_string_size(troca.text,HORIZONTAL_ALIGNMENT_LEFT,-1,troca.get_theme_font_size("font_size")).x
			verificar("mochila cabe sem quebrar palavra %s" % str(tamanho), largura_texto <= troca.size.x - troca.get_theme_stylebox("normal").get_minimum_size().x - 4)
		await capturar("venda-%dx%d" % [tamanho.x,tamanho.y])
		for texto in [loja._titulo_venda, loja._detalhe_venda, loja._valor_venda]:
			verificar("texto cabe na venda %s" % str(tamanho), texto.get_minimum_size().x <= texto.size.x + 1)
	var saldo: int = prog.brasas
	var ouro: int = root.get_node("DadosJogo").moedas
	loja._botao_vender.pressed.emit()
	await quadros()
	verificar("venda paga Brasas e retira apenas a pilha de P2", prog.brasas == saldo + 7 and inv2.quantidade_sementes("cenoura") == 0 and inv.quantidade_sementes("cenoura") == 0)
	verificar("venda nao paga ouro nem duplica ao clicar de novo", root.get_node("DadosJogo").moedas == ouro and Loja.vender(dados,inv2,prog) == 0)
	var fora = inv2.buscar_por_tipo("semente:girassol")
	verificar("semente fora da estacao tambem pode ser vendida", Loja.vender(fora,inv2,prog) > 0)
	var recebido: int = prog.brasas
	inv2.carregar()
	prog.carregar()
	verificar("venda persiste mochila e saldo", prog.brasas == recebido and inv2.quantidade_sementes("cenoura") == 0 and inv2.quantidade_sementes("girassol") == 0)
	ui._fechar_tela("mercante")
	root.get_node("Saves").trocar("solo")
	root.content_scale_size = Vector2i(576,324)
	root.size = Vector2i(1152,648)
	change_scene_to_file("res://cenas/praia.tscn")
	await quadros(30)
	root.get_node("Transicao").limpar()
	var praia = current_scene
	var jogador = praia.get_node("Jogador")
	jogador.set_physics_process(false)
	inv.definir_vara_na_mao(true)
	verificar("areia e piso do cais nao sao agua", not praia.agua_mar_no_ponto(Vector2(128,280)) and not praia.agua_mar_no_ponto(Vector2(352,400)))
	verificar("mar aberto e agua", praia.agua_mar_no_ponto(Vector2(400,440)))
	verificar("fora do mapa nao e agua", not praia.agua_mar_no_ponto(Vector2(800,500)))
	# Direção norte sobre o píer não alcança água em nenhum nível de força.
	jogador.global_position = Vector2(372,416)
	verificar("direcao sem agua rejeitada", not Sessao.alvo_mar(jogador,Vector2.UP,44).is_finite())
	var total := 0
	var invalidos := 0
	for ponto in get_nodes_in_group("pontos_pesca"):
		if ponto.get_world_2d() != jogador.get_world_2d(): continue
		jogador.global_position = ponto.global_position
		for deslocamento in [Vector2.ZERO, Vector2(-9,-9), Vector2(9,9)]:
			jogador.global_position = ponto.global_position + deslocamento
			for alcance in [28.0,44.0,120.0]:
				var alvo: Vector2 = Sessao.alvo_mar(jogador,ponto.direcao,alcance)
				if not alvo.is_finite(): continue
				total += 1
				if not praia.agua_mar_no_ponto(alvo): invalidos += 1
	verificar("todos os alvos aceitos ficam em agua visivel (%d)" % total, total > 100 and invalidos == 0)
	# PescaPalafita ficava 12 px para dentro da madeira: até a força mínima precisa sair do piso.
	jogador.global_position = praia.get_node("PescaPalafita").global_position + Vector2(0,-9)
	var sessao: Node2D = Sessao.new()
	sessao.iniciar(jogador,Vector2.DOWN,"mar",true)
	for forca in [0.0,0.5,1.0]:
		sessao.forca_lancamento = forca
		sessao._lancar()
		verificar("boia fora do piso com forca %.1f" % forca, praia.agua_mar_no_ponto(jogador.to_global(sessao._alvo)))
	sessao.estado = Sessao.Estado.ESPERANDO
	sessao._espera = 1000
	praia.get_node("Iluminacao").definir_hora(12)
	praia.get_node("Iluminacao").set_process(false)
	await quadros()
	await capturar("boia")
	sessao._terminar()
	await quadros()
	verificar("encerrar pesca restaura jogador", jogador.movimento_habilitado and not jogador.ataques_bloqueados)
	print("FALHAS: ",falhas)
	quit(1 if falhas else 0)
