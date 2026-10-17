extends SceneTree

const Desafios := preload("res://codigo/pesca/desafios_pesca.gd")
const Peixes := preload("res://codigo/pesca/peixes.gd")
const Refeicoes := preload("res://codigo/dados/refeicoes.gd")
var Sessao: GDScript
const Aparencia := preload("res://codigo/dados/aparencia.gd")
var falhas := 0

func _initialize() -> void:
	_rodar.call_deferred()

func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ",nome)
	if not ok:
		falhas += 1

func quadros(n := 4) -> void:
	for i in n:
		await process_frame

func _rodar() -> void:
	if not String(ProjectSettings.get_setting("application/config/custom_user_dir_name","")).begins_with("AlgoLand testes"):
		quit(1)
		return
	Sessao = load("res://codigo/pesca/sessao_pesca.gd")
	var fazenda: Node = root.get_node("Fazenda")
	var progresso: Node = root.get_node("Progresso")
	var calendario: Node = root.get_node("Calendario")
	root.get_node("Saves").trocar("solo")
	root.get_node("Introducao").pular_prologo()
	fazenda._zerar()
	root.get_node("InventarioJogador").limpar()
	root.get_node("InventarioJogador").definir_linhas_extras(99)
	root.get_node("InventarioJogador").criar_itens_iniciais()
	progresso.brasas = 0
	progresso.refeicao = ""
	calendario.dia = 1
	verificar("não resgata meta sem progresso",fazenda.resgatar_desafio_pesca("primeira_captura") == 0)
	fazenda.pescar("sardinha",true)
	verificar("primeira captura paga uma vez",fazenda.resgatar_desafio_pesca("primeira_captura") == 10 and fazenda.resgatar_desafio_pesca("primeira_captura") == 0)
	verificar("captura perfeita registrada",fazenda.pesca_perfeitas == 1)
	var pedido: Dictionary = fazenda.pedidos_pesca()[0]
	verificar("pedido estável ao reabrir",pedido == fazenda.pedidos_pesca()[0])
	verificar("não entrega sem quantidade",fazenda.entregar_pedido_pesca(pedido["id"]) == 0)
	fazenda.pescar("sardinha")
	verificar("entrega paga 3x e consome somente a quantidade",fazenda.entregar_pedido_pesca(pedido["id"]) == 18 and fazenda.quantidade_peixes("sardinha") == 0)
	verificar("não entrega duas vezes",fazenda.entregar_pedido_pesca(pedido["id"]) == 0)
	verificar("não entrega pedido inventado",fazenda.entregar_pedido_pesca("999_mar") == 0)
	fazenda.salvar()
	fazenda.carregar()
	verificar("salva resgates, entregas e perfeitas",fazenda.pesca_perfeitas == 1 and fazenda.resgatar_desafio_pesca("primeira_captura") == 0 and fazenda.pesca_pedidos_entregues.has(pedido["id"]))
	calendario.dia = 2
	verificar("pedido anterior vence ao dormir",fazenda.entregar_pedido_pesca(pedido["id"]) == 0 and fazenda.pedidos_pesca()[0]["id"] != pedido["id"])
	for estacao in 4:
		for dia in range(1,31):
			for p in Desafios.pedidos_do_dia(estacao*30+dia,estacao):
				var epocas: Array = Peixes.DADOS[p["peixe"]]["estacoes"]
				if not epocas.is_empty() and not epocas.has(estacao):
					verificar("pedido respeita estação",false)
	verificar("240 pedidos sazonais conferidos",true)
	fazenda.colheita = {"batata":2,"cenoura":1,"abobora":1}
	for i in root.get_node("InventarioJogador").mochila.size():
		var item = root.get_node("InventarioJogador").mochila[i]
		if item != null and item.categoria=="peixe": root.get_node("InventarioJogador").mochila[i]=null
	fazenda.pescar("sardinha")
	verificar("receita incompleta não consome nenhum estoque",fazenda.cozinhar("peixe_assado") != "" and fazenda.quantidade_colhida("batata") == 2 and fazenda.quantidade_peixes("sardinha") == 1)
	fazenda.pescar("sardinha")
	verificar("cozinha sardinhas e aplica bônus na arena",fazenda.cozinhar("peixe_assado") == "" and fazenda.quantidade_peixes("sardinha") == 0 and fazenda.quantidade_colhida("batata") == 1 and progresso.refeicao == "peixe_assado" and Refeicoes.bonus(progresso.refeicao,"folego") == 0.30)
	verificar("um prato por partida",fazenda.cozinhar("sopa_raizes") != "")
	verificar("receita exibe nomes dos peixes",Refeicoes.texto_receita("caldo_rio",fazenda.PLANTAS).contains(Peixes.nome("carpa")))
	for prato in ["caldo_rio","salmao_grelhado"]:
		progresso.refeicao = ""
		for peixe in Refeicoes.dados(prato)["peixes"]:
			fazenda.pescar(peixe)
		verificar("cozinha "+prato,fazenda.cozinhar(prato) == "" and progresso.refeicao == prato)
	progresso.refeicao = ""
	for peixe in Peixes.DADOS:
		fazenda.pescar(peixe)
	var historico: Dictionary = fazenda.peixes_pescados.duplicate()
	fazenda.vender_peixes()
	verificar("vender e cozinhar preservam coleção",fazenda.peixes_pescados == historico and fazenda.progresso_desafio_pesca("colecao_12") == Peixes.DADOS.size())
	for meta in Desafios.COLECAO:
		verificar("coleção paga uma vez: "+meta,fazenda.resgatar_desafio_pesca(meta) > 0 and fazenda.resgatar_desafio_pesca(meta) == 0)
	fazenda.salvar()
	fazenda.carregar()
	verificar("coleção resgatada permanece após carregar",fazenda.resgatar_desafio_pesca("colecao_12") == 0)

	for roupa in Aparencia.roupas().size():
		verificar("roupa disponível na pesca: "+Aparencia.roupas()[roupa]["id"],Aparencia.roupa(roupa,"pesca",0) != null)
	# A progressão pertence ao mundo: cooperativo não herda a coleção do solo.
	var caminho_anterior: String = fazenda.caminho_save
	fazenda.caminho_save = "user://teste_outro_mundo_pesca.json"
	fazenda._zerar()
	fazenda.salvar()
	fazenda.carregar()
	verificar("outro arquivo de mundo começa sem recompensas",fazenda.peixes_pescados.is_empty() and fazenda.pesca_recompensas.is_empty() and fazenda.pesca_pedidos_entregues.is_empty())
	fazenda.caminho_save = caminho_anterior
	fazenda.carregar()
	verificar("voltar ao mundo restaura coleção",fazenda.progresso_desafio_pesca("colecao_12") == Peixes.DADOS.size())

	# Cena real, poses nas quatro direções, composição das roupas e dos conjuntos.
	change_scene_to_file("res://cenas/praia.tscn")
	await quadros(40)
	var jogador: CharacterBody2D = current_scene.get_node("Jogador")
	jogador.global_position = current_scene.get_node("PescaPierLeste").global_position
	jogador.definir_aparencia(0,2)
	await quadros(6)
	for direcao in [Vector2.DOWN,Vector2.UP,Vector2.RIGHT,Vector2.LEFT]:
		var sessao: Node = Sessao.new()
		sessao.iniciar(jogador,direcao,"mar")
		sessao._esperar()
		sessao._espera = 999
		await quadros(3)
		verificar("pose de pesca alinhada: "+str(direcao),not jogador.get_node("CompositeSprites").visible and jogador.get_node("AnimacaoPesca").vara.frame == sessao._animacao._linha*8+2)
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/algoland-pesca-direcao-%d.png" % sessao._animacao._linha)
			if direcao == Vector2.RIGHT:
				root.get_texture().get_image().save_png("res://arte/previas/pesca/mana_seed.png")
		sessao._terminar()
		await quadros(3)
		verificar("cancelar restaura árvore e visual",jogador.movimento_habilitado and jogador._arvore_animacao.active and jogador.get_node("CompositeSprites").visible and not jogador.has_node("AnimacaoPesca"))
	for id in ["armadura_teste","armadura_cavaleiro","armadura_cavaleiro_rubro","traje_cavalheiro"]:
		var indice := -1
		for i in Aparencia.roupas().size():
			if Aparencia.roupas()[i]["id"] == id:
				indice = i
		jogador.definir_aparencia(0,indice)
		var sessao: Node = Sessao.new()
		sessao.iniciar(jogador,Vector2.RIGHT,"mar")
		sessao._esperar()
		sessao._espera = 999
		await quadros(3)
		verificar("conjunto usa página adicional: "+id,sessao._animacao._camadas[1].texture != null)
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/algoland-pesca-%s.png" % id)
		sessao._terminar()
		await quadros(3)
	jogador.definir_aparencia(0,2)
	var eventos: Node = root.get_node("EventosJogo")
	var interface: Node = eventos.interface_de(jogador)
	eventos.abrir_tela_para(jogador,"guia_pesca")
	var guia: Control = interface.get_node("GuiaPesca")
	await quadros(4)
	for aba in ["PEIXES","PEDIDOS","DESAFIOS","COLECAO"]:
		guia._trocar_aba(aba)
		await quadros(3)
		verificar("aba acessível: "+aba,guia._grade.get_child_count() > 0)
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/algoland-pesca-aba-%s.png" % aba)
	guia.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	guia.size = Vector2(240,270)
	guia._trocar_aba("PEDIDOS")
	await quadros(4)
	verificar("painel cabe em vista estreita",guia.painel.size.x <= 240 and guia._abas.columns == 2)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/algoland-pesca-estreita.png")
	eventos.fechar_tela_de(interface,"guia_pesca")
	change_scene_to_file("res://cenas/fazenda.tscn")
	await quadros(40)
	jogador = current_scene.get_node("Jogador")
	var lago: Area2D = current_scene.get_node("PescaLago")
	jogador.global_position = lago.global_position
	await quadros(10)
	verificar("ponto do lago alcançável",lago.jogador_perto and lago.pode_interagir_para(jogador))
	lago.abrir_tela()
	await quadros(3)
	var sessao: Node = jogador.get_node_or_null("SessaoPesca")
	verificar("lago inicia pesca de água doce",sessao != null and sessao.ambiente == "rio")
	if sessao != null:
		sessao._esperar()
		sessao._espera = 999
		if DisplayServer.get_name() != "headless":
			await quadros(3)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/algoland-pesca-lago.png")
		sessao._terminar()
	await quadros(3)
	print("FALHAS: ",falhas)
	quit(1 if falhas else 0)
