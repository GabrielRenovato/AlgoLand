extends SceneTree
const Item := preload("res://codigo/modelos/dados_item.gd")
var falhas := 0
func _initialize(): rodar.call_deferred()
func conferir(ok: bool, texto: String):
	if not ok: falhas+=1;push_error(texto)
func esperar(n=20):
	for i in n: await process_frame
func rodar():
	assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
	await process_frame
	root.get_node("Introducao").pular_prologo()
	var p = root.get_node("Progresso");p.apagar()
	var inv = root.get_node("InventarioJogador");inv.limpar()
	var comida := Item.de_coletavel("comida","omelete_horta",2)
	conferir(inv.receber(comida)>=0 and comida.empilhavel(),"Comida ocupa casa e empilha")
	conferir(inv.salvar() and inv.carregar(),"Comida persiste no save")
	comida=inv.buscar_por_tipo("comida:omelete_horta")
	conferir(comida!=null and comida.quantidade==2 and comida.nome()=="OMELETE DA HORTA","Nome e quantidade restaurados")
	conferir(inv.usar_comida(comida)=="" and inv.quantidade_tipo(comida.tipo)==1 and p.refeicao=="omelete_horta","Comer consome uma unidade e ativa bônus")
	conferir(inv.usar_comida(comida)!="" and inv.quantidade_tipo(comida.tipo)==1,"Segunda comida não acumula bônus nem é gasta")
	conferir(p.carregar() and p.refeicao=="omelete_horta","Bônus sobrevive à reabertura")
	var guardado=inv.guardar_para_nova_partida()
	conferir(guardado.pecas.any(func(r):return r.item.categoria=="comida"),"Comida guardada não some ao encerrar partida")
	p._acabar_refeicao()
	change_scene_to_file("res://cenas/fazenda.tscn");await esperar(40)
	root.get_node("Transicao").limpar()
	var ui=current_scene.get_node("Interface")
	# Usa os mesmos slots e ações de mochila presentes no celular e no controle.
	ui._abrir_tela("inventario");await esperar()
	var tela=ui._telas.inventario
	var slot = tela._slots_mochila.filter(func(s):return s.item_atual!=null and s.item_atual.categoria=="comida")[0]
	conferir(tela._verbo_do_item(slot)=="COMER","Controle informa ação COMER")
	for medida in [Vector2i(576,324),Vector2i(288,216)]:
		root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_IGNORE;root.content_scale_size=medida;root.size=medida*2;await esperar()
		var papel := PanelContainer.new();papel.position=Vector2(18,18);papel.z_index=100
		papel.add_theme_stylebox_override("panel",preload("res://codigo/ui/estilo_interface.gd").painel(false,8))
		papel.add_child(slot.item_ui().tooltip_do_item(220));tela.add_child(papel);await esperar()
		conferir(Rect2(Vector2.ZERO,tela.size).encloses(papel.get_global_rect()),"Descrição da comida cabe: "+str(medida))
		for l in papel.find_children("*","Label",true,false):
			conferir(papel.get_global_rect().grow(-7).encloses(l.get_global_rect()),"Texto da comida respeita margem: %s papel=%s texto=%s minimo=%s"%[l.text,papel.get_global_rect(),l.get_global_rect(),l.get_combined_minimum_size()])
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("/tmp/algoland-comida-tesouro-%dx%d.png"%[medida.x,medida.y])
		papel.free()
	slot._equipar_ou_desequipar();await esperar()
	conferir(p.refeicao=="omelete_horta" and inv.quantidade_tipo("comida:omelete_horta")==0,"Ação da interface come última unidade")
	ui._fechar_tela("inventario");await esperar()
	p._acabar_refeicao()
	inv.receber(Item.de_coletavel("comida","sopa_raizes"));await esperar()
	var barra = get_nodes_in_group("hud_p1")[0].barra_armas
	barra._fileira=0;barra._pagina_barra=0;barra._atualizar()
	var foco = root.gui_get_focus_owner()
	if foco!=null: foco.release_focus()
	conferir(barra.escolher(0) and p.refeicao=="sopa_raizes" and inv.quantidade_tipo("comida:sopa_raizes")==0,"Barra do celular também come sem abrir mochila")
	conferir(load("res://codigo/dados/equipamentos.gd").dados_melhoria_conjunto(1).moedas_forja==1,"Moeda tem custo real nas melhorias de conjuntos")
	print("COMIDA TESOURO: %d falhas"%falhas)
	quit(1 if falhas else 0)
