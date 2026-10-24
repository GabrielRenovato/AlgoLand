extends "res://testes/teste_acoes_fazenda_raven.gd"
const SAIDA_PORTE="res://arte/previas/personagens/porte_armas_raven/"
func _initialize():revisar.call_deferred()
func revisar():
 assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
 root.get_node("Introducao").pular_prologo();root.get_node("Fazenda").definir_clima_hoje(0);root.get_node("Transicao").hora_salva=12
 change_scene_to_file("res://cenas/fazenda.tscn");await esperar(30);root.get_node("Transicao").limpar();current_scene.process_mode=Node.PROCESS_MODE_DISABLED
 var jogador=current_scene.get_node("Jogador");var visual=jogador.get_node("HeroiRaven")
 var vp=SubViewport.new();vp.size=Vector2i(600,440);vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS;vp.canvas_item_default_texture_filter=Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST;root.add_child(vp)
 var fundo=ColorRect.new();fundo.color=Color("515e47");fundo.size=vp.size;vp.add_child(fundo)
 var fonte=preload("res://assets/ui/Planes_ValMore.ttf").duplicate() as FontFile;fonte.antialiasing=TextServer.FONT_ANTIALIASING_NONE
 for coluna in 3:
  for linha in 2:
   var label=Label.new();label.text=["ESPADA","LANCA","ALJAVA"][coluna]+(" / CAPA" if linha==1 else "");label.position=Vector2(coluna*200+12,linha*220+12);label.add_theme_font_override("font",fonte);label.add_theme_font_size_override("font_size",12);vp.add_child(label)
 DirAccess.make_dir_recursive_absolute(SAIDA_PORTE+"quadros/")
 var numero=0
 for d in 4:
  for passo in 80:
   var tempo=passo*0.02;var copias=[]
   for linha in 2:
    jogador.aparencia_raven={"pele":0,"roupa":1 if linha==0 else 8,"cabelo":1,"cor":[1,1,1,1]}
    for coluna in 3:
     var id=["espada_basica","lanca_basica","arco_curvo"][coluna];jogador.inventario.equipados.arma=Receitas.criar_item(id)
     jogador.usando_espada=coluna==0;jogador.usando_lanca=coluna==1;jogador.usando_arco=coluna==2;jogador.id_arma_atual="espada_basica";jogador.id_lanca_atual="lanca_basica"
     jogador._direcao_ataque=[Vector2.DOWN,Vector2.RIGHT,Vector2.UP,Vector2.LEFT][d]
     jogador.velocity=Vector2.ZERO if tempo<0.2 or tempo>=1.4 else jogador._direcao_ataque*80
     visual._animacao="parado" if jogador.velocity==Vector2.ZERO else "correr";visual._direcao=d;visual._tempo=maxf(0,tempo-0.2);visual._process(0)
     var copia=visual.criar_rastro();copia.position=Vector2(coluna*200+100,linha*220+205);copia.scale=Vector2(3,3);vp.add_child(copia);copias.append(copia)
   await RenderingServer.frame_post_draw;vp.get_texture().get_image().save_png(SAIDA_PORTE+"quadros/%03d.png"%numero);numero+=1
   for copia in copias:copia.queue_free()
   await process_frame
 print("PORTE: ",numero," quadros de 20ms, quatro direções, repouso e corrida real.")
 vp.queue_free();current_scene.queue_free();current_scene=null;await esperar(3);quit()
