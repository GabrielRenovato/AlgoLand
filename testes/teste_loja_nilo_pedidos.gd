extends SceneTree
var falhas := 0
func _initialize() -> void: _rodar.call_deferred()
func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ",nome)
	if not ok: falhas += 1
func quadros(n := 8) -> void:
	for i in n: await process_frame
func _rodar() -> void:
	if not String(ProjectSettings.get_setting("application/config/custom_user_dir_name","")).begins_with("AlgoLand testes"):
		quit(1)
		return
	root.get_node("Saves").trocar("solo")
	root.get_node("Introducao").pular_prologo()
	var cidade: Node = root.get_node("Cidade")
	var fazenda: Node = root.get_node("Fazenda")
	var calendario: Node = root.get_node("Calendario")
	cidade._limpar_estado()
	fazenda._zerar()
	root.get_node("InventarioJogador").limpar()
	root.get_node("InventarioJogador").criar_itens_iniciais()
	calendario.dia = 1
	var rotina: GDScript = load("res://codigo/pesca/rotina_nilo.gd")
	for hora in [6.0,7.0,7.99]:
		verificar("Nilo fica dentro antes de abrir %.2f" % hora,rotina.agenda(hora,0)["local"]=="palafita")
	for hora in [8.0,12.0,16.99]:
		verificar("Nilo atende durante expediente %.2f" % hora,rotina.agenda(hora,0)["atividade"]=="Atendendo na loja de pesca")
	verificar("Nilo passeia depois de fechar",rotina.agenda(17.5,0)["local"]=="cidade")
	root.get_node("Transicao").hora_salva = 7
	change_scene_to_file("res://cenas/praia.tscn")
	await quadros(35)
	current_scene.get_node("Iluminacao").definir_hora(7)
	current_scene.get_node("Iluminacao").set_process(false)
	current_scene.get_node("Nilo").atualizar_rotina(true)
	var p1: Node2D = current_scene.get_node("Jogador")
	verificar("Nilo não aparece passeando na praia às 7h",not current_scene.get_node("Nilo").visible)
	var porta: Node = current_scene.get_node("PortaPalafita")
	porta._atravessar(p1)
	await quadros(10)
	var ui: Node = current_scene.get_node("Interface")
	verificar("loja não deixa entrar antes das 8h",current_scene.local=="praia" and ui._telas_abertas.has("introducao"))
	ui._fechar_tela("introducao")
	current_scene.get_node("Iluminacao").definir_hora(8)
	porta._atravessar(p1)
	for i in 240:
		await process_frame
		if current_scene != null and current_scene.scene_file_path.ends_with("palafita.tscn"): break
	await quadros(15)
	verificar("loja abre a partir das 8h",current_scene.local=="palafita")
	verificar("balcão e equipamento de pesca integrados",current_scene.has_node("Interior/Balcao128") and current_scene.has_node("Interior/MobiliarioCais"))
	root.get_node("Transicao").hora_salva = 12
	change_scene_to_file("res://cenas/cidade.tscn")
	await quadros(40)
	var bento: Node2D = current_scene.moradores["bento"]
	var indicador: Node2D = bento.get_node("IndicadorPedido")
	verificar("sem pedido aceito não mostra balão",not indicador.visible)
	cidade.aceitar("horta")
	await quadros()
	verificar("pedido aceito mostra interrogação cinza",indicador.visible and not indicador.pronto and indicador._rotulo.text=="?")
	bento.dizer("O mural tem pedidos novos. Passe la quando puder!",10)
	await quadros()
	var fala: Label = bento._balao
	verificar("fala quebra linhas em largura limitada",fala.size.x<=144 and fala.size.y>16)
	verificar("marcador fica ao lado sem sobrepor fala",not Rect2(fala.position,fala.size).intersects(Rect2(indicador.position,Vector2(16,16))))
	verificar("balões usam os sprites do pacote",indicador._sprite.texture!=null and fala.get_theme_stylebox("normal") is StyleBoxTexture)
	bento.calar()
	await quadros()
	var inicio: Vector2 = indicador.global_position
	bento.position += Vector2(20,0)
	verificar("balão acompanha o morador",indicador.global_position==inicio+Vector2(20,0))
	fazenda.colheita = {"cenoura":3}
	fazenda.bolsas_alteradas.emit()
	verificar("objetivo completo muda balão para amarelo",indicador.visible and indicador.pronto and indicador._rotulo.get_theme_color("font_color")==Color("ffe07a"))
	cidade.concluir("horta","bento")
	verificar("entregar todos os pedidos remove o balão",not indicador.visible)
	print("FALHAS: ",falhas)
	quit(1 if falhas else 0)
