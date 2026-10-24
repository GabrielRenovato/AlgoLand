extends SceneTree
const Item=preload("res://codigo/modelos/dados_item.gd")
var falhas=0
var verificacoes=0
func _initialize():rodar.call_deferred()
func esperar(n=15):
	for i in n:await process_frame
func conferir(ok:bool,texto:String):
	verificacoes+=1
	if not ok:falhas+=1;push_error(texto)
func toque(ponto:Vector2,soltar:Vector2=Vector2.INF):
	var e=InputEventScreenTouch.new();e.index=0;e.position=ponto;e.pressed=true
	root.push_input(e,true);await esperar(2)
	var f=e.duplicate();f.pressed=false;f.position=ponto if soltar==Vector2.INF else soltar
	root.push_input(f,true);await esperar()
func textos(no:Node)->String:
	var t=""
	for l in no.find_children("*","Label",true,false):t+=l.text+"\n"
	return t
func rodar():
	assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
	assert(DisplayServer.get_name()!="headless")
	await process_frame
	Input.emulate_mouse_from_touch=true
	root.get_node("Controle").usando_toque=true
	root.get_node("Introducao").pular_prologo()
	root.get_node("Progresso").apagar()
	var inv=root.get_node("InventarioJogador");inv.limpar()
	inv.receber(Item.de_coletavel("pocao","vampiro",2));inv.receber(Item.de_coletavel("comida","omelete_horta",2))
	change_scene_to_file("res://cenas/fazenda.tscn");await esperar(40)
	root.get_node("Transicao").limpar()
	var ui=current_scene.get_node("Interface");ui._abrir_tela("inventario");await esperar()
	var tela=ui._telas.inventario
	for medida in [Vector2i(576,324),Vector2i(288,216),Vector2i(288,512)]:
		root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_IGNORE;root.content_scale_size=medida;root.size=medida*2;await esperar()
		var slot=tela._slots_mochila.filter(func(s):return s.item_atual!=null and s.item_atual.tipo=="pocao:vampiro")[0]
		tela._rolagem.ensure_control_visible(slot);await esperar()
		var antes=inv.quantidade_tipo("pocao:vampiro")
		await toque(slot.item_ui().get_global_transform_with_canvas()*Vector2(8,8))
		var dica=ui.get_node_or_null("DicaItemToque")
		conferir(dica!=null,"Toque real abre tooltip: "+str(medida))
		if dica==null:continue
		conferir(Rect2(Vector2.ZERO,Vector2(medida)).grow(-10).encloses(dica.painel.get_global_rect()),"Tooltip respeita bordas")
		var descricao=textos(dica)
		conferir(descricao.contains("6%") and descricao.contains("30S") and descricao.contains("CINTO") and descricao.contains("3 VIDA/S"),"Poção explica efeito, duração, limite e uso")
		conferir(inv.quantidade_tipo("pocao:vampiro")==antes,"Ler não consome item")
		conferir(dica.rolagem.clip_contents,"Descrição longa tem recorte e rolagem")
		for l in dica.find_children("*","Label",true,false):
			conferir(dica.rolagem.get_child(0).get_global_rect().grow(0.1).encloses(l.get_global_rect()),"Texto permanece dentro do conteúdo: %s; %s; %s"%[l.text,dica.rolagem.get_child(0).get_global_rect(),l.get_global_rect()])
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("/tmp/algoland-tooltip-mobile-%dx%d.png"%[medida.x,medida.y])
		await toque(Vector2(2,2));conferir(not ui.has_node("DicaItemToque"),"Toque fora fecha")
		for id in load("res://codigo/dados/pocoes.gd").ORDEM:
			var item_ui=slot.item_ui();var original=item_ui.dados;item_ui.dados=Item.de_coletavel("pocao",id)
			var conteudo=item_ui.tooltip_do_item(220)
			conferir(textos(conteudo).contains(load("res://codigo/dados/pocoes.gd").texto_efeito(id)),"Efeito correto: "+id)
			conteudo.free();item_ui.dados=original
	var comida=tela._slots_mochila.filter(func(s):return s.item_atual!=null and s.item_atual.categoria=="comida")[0]
	tela._rolagem.ensure_control_visible(comida);await esperar()
	var ponto: Vector2=comida.item_ui().get_global_transform_with_canvas()*Vector2(8,8)
	await toque(ponto)
	conferir(ui.has_node("DicaItemToque") and inv.quantidade_tipo("comida:omelete_horta")==2,"Toque na comida apenas consulta")
	var duplo=InputEventMouseButton.new();duplo.button_index=MOUSE_BUTTON_LEFT;duplo.position=ponto;duplo.pressed=true;duplo.double_click=true
	root.push_input(duplo,true);duplo=duplo.duplicate();duplo.pressed=false;root.push_input(duplo,true);await esperar()
	conferir(inv.quantidade_tipo("comida:omelete_horta")==1,"Toque duplo ainda usa comida com tooltip aberto")
	if ui.has_node("DicaItemToque"):ui.get_node("DicaItemToque").free()
	await toque(ponto,ponto+Vector2(0,-35))
	conferir(not ui.has_node("DicaItemToque"),"Deslizar não abre tooltip")
	print("DICAS CONSUMIVEIS: %d verificações; %d falhas"%[verificacoes,falhas])
	quit(1 if falhas else 0)
