extends SceneTree
const Escala=preload("res://codigo/ui/escala_interface.gd")
var falhas=0
var verificacoes=0
func _initialize():rodar.call_deferred()
func esperar(n=15):
 for i in n:await process_frame
func conferir(ok:bool,texto:String):
 verificacoes+=1
 if not ok:falhas+=1;push_error(texto)
func botoes(tela:Node):return tela.find_children("*","Button",true,false).filter(func(b):return b.has_meta("fechar_circular"))
func checar(botao:Button):
 conferir(botao.is_set_as_top_level(),"Fechar flutua sobre a moldura")
 conferir(botao.get_theme_stylebox("normal") is StyleBoxFlat,"Fechar usa círculo")
 conferir(is_equal_approx(botao.size.x,botao.size.y),"Círculo não vira elipse")
 conferir(Rect2(Vector2.ZERO,Escala.tamanho_logico(botao)).grow(0.1).encloses(botao.get_global_rect()),"Fechar respeita a tela e o viewport do jogador")
 conferir(botao.text=="X","X preservado")
func clicar(botao: Button):
 var ponto=botao.get_global_transform_with_canvas()*(botao.size*0.5)
 var press=InputEventMouseButton.new();press.button_index=MOUSE_BUTTON_LEFT;press.position=ponto;press.pressed=true
 botao.get_viewport().push_input(press,true)
 var soltar=press.duplicate();soltar.pressed=false;botao.get_viewport().push_input(soltar,true)
func rodar():
 assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
 root.mode=Window.MODE_WINDOWED;root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_IGNORE
 root.get_node("Saves").trocar("solo");root.get_node("Introducao").pular_prologo()
 change_scene_to_file("res://cenas/cidade/forja.tscn");await esperar(40)
 var ui=current_scene.get_node("Interface")
 for medida in [Vector2i(640,360),Vector2i(288,216),Vector2i(288,512)]:
  root.content_scale_size=medida;root.size=medida*2;await esperar()
  for nome in ["inventario","mercante","acampamento","mistica","caldeirao","pausa","mapa_mundi","forja","carpintaria","bau","guia_pesca","oficina_vara","mural_cidade","desafio_arena"]:
   if nome=="acampamento":
    root.get_node("Progresso").apagar();root.get_node("Progresso").brasas=100;root.get_node("Progresso").melhorias.vigor=1
   ui._abrir_tela(nome);await esperar()
   var tela=ui._telas[nome];var fechadores=botoes(tela).filter(func(b):return b.is_visible_in_tree())
   conferir(not fechadores.is_empty(),"Janela tem X circular: "+nome)
   for b in fechadores:checar(b)
   if nome=="acampamento":
    conferir(ui._paineis[nome].get_global_rect().get_center().distance_to(tela.get_global_rect().get_center())<1,"Brasas no centro da tela")
    conferir(Rect2(Vector2.ZERO,tela.size).grow(0.1).encloses(ui._paineis[nome].get_global_rect()),"Janela de Brasas cabe na tela")
   if DisplayServer.get_name()!="headless" and nome in ["inventario","forja","carpintaria","pausa","acampamento"]:
    await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("/tmp/algoland-fechar-%s-%dx%d.png"%[nome,medida.x,medida.y])
   if not fechadores.is_empty():clicar(fechadores[0]);await esperar()
   conferir(not ui._telas_abertas.has(nome),"X continua fechando a janela: "+nome)
   for outra in ui._telas_abertas.duplicate():ui._fechar_tela(outra)
   await esperar()
 root.get_node("Saves").trocar("coop");root.get_node("Introducao").pular_prologo()
 root.content_scale_size=Vector2i(768,432);root.size=Vector2i(1536,864)
 change_scene_to_file("res://cenas/fazenda.tscn");await esperar(50)
 var ui1=get_nodes_in_group("interface").filter(func(n):return not root.get_node("EventosJogo").eh_do_p2(n))[0];var ui2=root.get_node("Cooperativo").interface_p2()
 conferir(ui2!=null,"Cooperativo cria interface separada")
 if ui2!=null:
  root.get_node("Introducao").pular_prologo()
  ui1._abrir_tela("inventario");ui2._abrir_tela("inventario");await esperar(30)
  for interface in [ui1,ui2]:
   for b in botoes(interface._telas.inventario).filter(func(x):return x.is_visible_in_tree()):checar(b)
  if DisplayServer.get_name()!="headless":
   await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("/tmp/algoland-fechar-coop.png")
  botoes(ui2._telas.inventario)[0].pressed.emit();await esperar()
  conferir(not ui2._telas_abertas.has("inventario") and ui1._telas_abertas.has("inventario"),"X do P2 fecha só a janela do P2")
 print("FECHAR JANELAS: ",verificacoes," verificações; ",falhas," falhas")
 quit(1 if falhas else 0)
