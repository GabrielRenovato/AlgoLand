extends "res://testes/teste_acoes_fazenda_raven.gd"
const SAIDA_MOVIMENTO="res://arte/previas/personagens/corrida_mana_seed_raven/motor/"
func nativo(copia: Sprite2D, d: int, t: float) -> void:
 var sprites=[copia]
 for filho in copia.get_children():
  if filho is Sprite2D:sprites.append(filho)
 for i in sprites.size():
  var sprite: Sprite2D=sprites[i]
  var caminho: String=sprite.texture.resource_path
  var original: String
  if caminho.contains("/conjuntos/"):
   original=caminho.get_base_dir()+".png"
  else:
   var nome=caminho.get_file()
   if nome=="capa_fecho.png":nome="vazio.png"
   original="res://assets/personagens/raven_fantasy/camadas/"+nome
  var atlas=AtlasTexture.new();atlas.atlas=load(original);atlas.region=Rect2(0,640,320,320);atlas.filter_clip=true
  sprite.frame=0;sprite.hframes=4;sprite.texture=atlas;sprite.frame=d*4+mini(3,int(fposmod(t,0.6)/0.15))
  if i==5:sprite.z_index=0
func _initialize():previa.call_deferred()
func previa():
 assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
 var somente_corrida="--somente-corrida" in OS.get_cmdline_user_args()
 var comparar="--comparar-raven" in OS.get_cmdline_user_args()
 if comparar:somente_corrida=true
 var saida=SAIDA_MOVIMENTO.replace("/motor/","/motor_corrida/") if somente_corrida else SAIDA_MOVIMENTO
 if comparar:saida=SAIDA_MOVIMENTO.replace("/motor/","/comparacao_raven/")
 root.get_node("Introducao").pular_prologo();root.get_node("Fazenda").definir_clima_hoje(0);root.get_node("Transicao").hora_salva=12
 change_scene_to_file("res://cenas/fazenda.tscn");await esperar(25);root.get_node("Transicao").limpar();current_scene.process_mode=Node.PROCESS_MODE_DISABLED
 var jogador=current_scene.get_node("Jogador");var visual=jogador.get_node("HeroiRaven")
 if "--sem-armas" in OS.get_cmdline_user_args():
  jogador.usando_espada=false;jogador.usando_lanca=false;jogador.usando_arco=false

 var vp=SubViewport.new();vp.size=Vector2i(640,180 if somente_corrida and not comparar else 360);vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS;vp.canvas_item_default_texture_filter=Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST;root.add_child(vp)
 var fundo=ColorRect.new();fundo.size=vp.size;fundo.color=Color("777f6c");vp.add_child(fundo)
 var configuracoes=[{"nome":"BASE","pele":0,"cabelo":0,"roupa":0,"itens":[]},{"nome":"ROUPA","pele":0,"cabelo":1,"roupa":1,"itens":[]},{"nome":"CAPA","pele":1,"cabelo":28,"roupa":8,"itens":[]},{"nome":"PECAS REAIS","pele":2,"cabelo":14,"roupa":8,"itens":["elmo_cavaleiro_rubro","peitoral_carrasco","luvas_cavalheiro","botas_cavaleiro_rubro"]}]
 # Legendas sem suavização não gastam centenas de cores da paleta GIF,
 # que precisa preservar integralmente os tons dos sprites.
 var fonte=preload("res://assets/ui/Planes_ValMore.ttf").duplicate() as FontFile
 fonte.antialiasing=TextServer.FONT_ANTIALIASING_NONE
 for i in 4:
  var titulo=Label.new();titulo.text=configuracoes[i].nome;titulo.position=Vector2(i*160+8,3);titulo.add_theme_font_override("font",fonte);titulo.add_theme_font_size_override("font_size",12);vp.add_child(titulo)
 if comparar:
  for linha in 2:
   var titulo=Label.new();titulo.text="RAVEN ORIGINAL" if linha==0 else "CORRIDA REVISADA";titulo.position=Vector2(8,24+linha*180);titulo.add_theme_font_override("font",fonte);titulo.add_theme_font_size_override("font_size",11);vp.add_child(titulo)
 DirAccess.make_dir_recursive_absolute(saida)
 var numero=0
 for d in 4:
  var direcao=[Vector2.DOWN,Vector2.RIGHT,Vector2.UP,Vector2.LEFT][d]
  for passo in (60 if somente_corrida else 96):
   var t=passo*0.02;var copias=[]
   for linha in (1 if somente_corrida and not comparar else 2):
    for c in configuracoes.size():
     var config=configuracoes[c];jogador.aparencia_raven={"pele":config.pele,"cabelo":config.cabelo,"roupa":config.roupa,"cor":[1,1,1,1]}
     for slot in ["cabeca","corpo","luvas","botas"]:jogador.inventario.equipados[slot]=null
     for tipo in config.itens:
      var item=Receitas.criar_item(tipo);jogador.inventario.equipados[item.categoria]=item
     jogador.cancelar_acao_fazenda();jogador.velocity=Vector2.ZERO;jogador._direcao_ataque=direcao
     if (comparar or linha==0) and (somente_corrida or (t>=0.2 and t<1.4)):
      jogador.velocity=direcao*80;visual._animacao="correr";visual._direcao=d;visual._tempo=t if somente_corrida else t-0.2
     elif linha==1 and t>=0.2:
      jogador.esta_em_acao_fazenda=true;jogador.no_fazenda.tocar("colher",direcao);jogador.no_fazenda._process(t-0.2)
     visual._process(0)
     var copia=copiar(visual)
     if comparar and linha==0:nativo(copia,d,t)
     copia.scale=Vector2(3,3);copia.position=Vector2(c*160+80,linha*180+155);vp.add_child(copia);copias.append(copia)
   await RenderingServer.frame_post_draw;vp.get_texture().get_image().save_png(saida+"%03d.png"%numero);numero+=1
   for copia in copias:copia.queue_free()
   await process_frame
 print("Prévia real: ",numero," quadros,20ms,quatro direções; ","somente corrida" if somente_corrida else "corrida e colheita com repouso")
 vp.queue_free();current_scene.queue_free();current_scene=null;await esperar(3);quit()
