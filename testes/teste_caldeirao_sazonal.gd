extends SceneTree
## Tela real em save isolado: a lista mostrada precisa ser a mesma que a fabricação consome.
const Pocoes = preload("res://codigo/dados/pocoes.gd")
var falhas := 0
func _initialize(): rodar.call_deferred()
func verificar(ok: bool, nome: String):
 if not ok:falhas+=1;push_error(nome)
func esperar():
 for i in 5:await process_frame
func rodar():
 assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
 root.get_node("Ranking").conexao_habilitada=false
 root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_IGNORE
 root.mode=Window.MODE_WINDOWED
 var tela=load("res://cenas/ui/tela_caldeirao.tscn").instantiate()
 root.add_child(tela);current_scene=tela
 var cal=root.get_node("Calendario");var inv=root.get_node("InventarioJogador")
 await esperar()
 for medida in [Vector2i(576,324),Vector2i(288,216)]:
  root.content_scale_size=medida;root.size=medida*2
  await esperar()
  for estacao in 4:
   cal.dia=1+cal.DIAS_POR_ESTACAO*estacao
   for id in Pocoes.ORDEM:
    inv.limpar()
    var formula=Pocoes.receita_da_estacao(id,estacao)
    for planta in formula.receita:inv.adicionar_coletavel("colheita",planta,formula.receita[planta])
    for peixe in formula.peixes:inv.adicionar_peixe(peixe,0,formula.peixes[peixe])
    tela.selecionar(id)
    await esperar()
    verificar(not tela.botao_fazer.disabled,"Fazer habilitado: %s / %d"%[id,estacao])
    verificar(tela._info.text.ends_with(cal.NOMES[estacao]),"Legenda da estação atual")
    var largura_texto=tela._info.get_theme_font("font").get_string_size(tela._info.text,HORIZONTAL_ALIGNMENT_LEFT,-1,tela._info.get_theme_font_size("font_size")).x
    verificar(largura_texto <= tela._info.size.x,"Legenda cabe sem invadir a moldura")
    verificar(tela._ingredientes.get_child_count()==2,"Dois ingredientes na tela")
    for ingrediente in formula.receita.keys()+formula.peixes.keys():
     verificar(tela._ingredientes.has_node("Ingrediente_"+ingrediente),"Ingrediente sazonal exibido: "+ingrediente)
    var painel=tela.get_node("Painel") as Control
    verificar(Rect2(Vector2.ZERO,tela.size).grow(1).encloses(painel.get_global_rect()),"Painel cabe no viewport")
    if id=="cura" and DisplayServer.get_name()!="headless":
     await RenderingServer.frame_post_draw
     root.get_texture().get_image().save_png("/tmp/algoland-cura-%d-%dx%d.png"%[estacao,medida.x,medida.y])
     var rolagem=tela.get_node("Painel/Linhas/Rolagem") as ScrollContainer
     rolagem.ensure_control_visible(tela.botao_fazer)
     await esperar()
     await RenderingServer.frame_post_draw
     root.get_texture().get_image().save_png("/tmp/algoland-cura-ingredientes-%d-%dx%d.png"%[estacao,medida.x,medida.y])
     verificar(rolagem.get_global_rect().grow(1).encloses(tela.botao_fazer.get_global_rect()),"Botão fazer acessível pela rolagem")
     rolagem.scroll_vertical=0
 print("CALDEIRAO SAZONAL: ",falhas," falhas; oito poções, quatro estações, PC e compacto")
 tela.queue_free();current_scene=null;await esperar();quit(falhas)
