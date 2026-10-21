extends SceneTree

const Receitas := preload("res://codigo/dados/forja_armas.gd")
const Icones := preload("res://codigo/ui/icones_itens.gd")
var falhas := 0
func verificar(ok: bool, texto: String) -> void:
	if not ok:
		falhas += 1
		print("FALHA ",texto)
func _initialize() -> void:
	rodar.call_deferred()
func esperar(n := 12) -> void:
	for i in n: await process_frame
func rodar() -> void:
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"):
		quit(1)
		return
	root.get_node("Introducao").pular_prologo()
	root.get_node("Progresso").apagar()
	root.get_node("Transicao").hora_salva=12.0
	root.get_node("Calendario").dia=1
	change_scene_to_file("res://cenas/cidade/forja.tscn")
	await esperar(40)
	var ui=current_scene.get_node("Interface")
	ui._abrir_tela("forja")
	await esperar()
	var tela=ui._telas["forja"]
	for tipo in Icones.ARMAS_RAVEN:
		verificar(tela._botoes.has(tipo),"modelo presente "+tipo)
		var item=Receitas.criar_item(tipo)
		var icone=Icones.obter(item,self)
		verificar(icone.resource_path=="res://assets/personagens/raven_fantasy/icones/%s.png" % tipo,"ícone Raven "+tipo)
		verificar(item.duas_maos == (tipo in ["espada_gemea","machado","lanca_basica","arco_curto"]),"mãos "+tipo)
	for tipo in Receitas.ARMAS_RETIRADAS:
		verificar(not tela._botoes.has(tipo),"modelo antigo oculto "+tipo)
		verificar(root.get_node("Progresso").motivo_fabricar_arma(tipo)=="RECEITA DESCONHECIDA","não fabrica modelo retirado")
	if DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute("/tmp/algoland-forja-raven")
		root.mode=Window.MODE_WINDOWED
		for formato in [Vector2i(576,324),Vector2i(288,216)]:
			root.content_scale_size=formato
			root.size=formato*2
			for tipo in ["espada_gemea","machado","arco_curto"]:
				tela._selecionar(tipo)
				await esperar()
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("/tmp/algoland-forja-raven/%d_%s.png" % [formato.x,tipo])
	print("CATALOGO RAVEN: ",falhas," falhas")
	quit(falhas)
