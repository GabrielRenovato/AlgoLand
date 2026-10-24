extends SceneTree
var falhas=0
func _initialize():rodar.call_deferred()
func esperar(n=20):
 for i in n:await process_frame
func conferir(ok:bool,texto:String):
 if not ok:falhas+=1;push_error(texto)
func rodar():
 assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
 assert(DisplayServer.get_name()!="headless")
 root.mode=Window.MODE_WINDOWED;root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_IGNORE
 root.get_node("Introducao").pular_prologo();root.get_node("Fazenda").galinheiro=load("res://codigo/fazenda/criacao_galinhas.gd").inicial()
 root.get_node("Calendario").dia=2
 change_scene_to_file("res://cenas/cidade/carpintaria.tscn");await esperar(40)
 var ui=current_scene.get_node("Interface");ui._abrir_tela("carpintaria");await esperar();var tela=ui._telas["carpintaria"]
 for medida in [Vector2i(576,324),Vector2i(288,216),Vector2i(288,512)]:
  root.content_scale_size=medida;root.size=medida*2;await esperar()
  for id in ["galinheiro_1","galinheiro_2","galinheiro_3"]:
   tela._abrir_item(id);await esperar()
   conferir(Rect2(Vector2.ZERO,tela.size).encloses(tela.painel.get_global_rect()),"Painel da carpintaria cabe: "+str(medida))
   conferir(Rect2(Vector2.ZERO,tela.size).encloses(tela._encomendar.get_global_rect()),"Construir permanece acessível")
   conferir(tela._custos.get_child_count()==(3 if id=="galinheiro_1" else 4),"Todos os custos da obra estão presentes")
   for linha in tela._custos.get_children():
    conferir(tela._papel.get_global_rect().grow(-6).encloses(linha.get_global_rect()),"Todos os materiais ficam visíveis dentro do papel: "+str(medida))
    for filho in linha.get_children():conferir(linha.get_global_rect().encloses(filho.get_global_rect()),"Material e quantidade cabem na linha")
  await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("/tmp/algoland-carpintaria-custos-%dx%d.png"%[medida.x,medida.y])
  tela._abrir_item("galinha");await esperar()
  conferir(tela._dados.text.contains("250 BRASAS"),"Preço novo aparece na compra de aves")
  await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("/tmp/algoland-carpintaria-ave-%dx%d.png"%[medida.x,medida.y])
 print("CUSTOS CARPINTARIA: ",falhas," falhas")
 quit(1 if falhas else 0)
