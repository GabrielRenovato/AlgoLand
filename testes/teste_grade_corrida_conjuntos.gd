extends "res://testes/teste_acoes_fazenda_raven.gd"
## Exercita o controlador ativo e a prévia do inventário; não corrige a grade da cópia.
const Conjuntos=preload("res://codigo/dados/conjuntos_armadura.gd")
const SAIDA_GRADE="res://arte/previas/armaduras/corrida_grade/"
func _initialize():revisar_grade.call_deferred()
func conferir_grade(visual: Sprite2D, contexto: String):
 var sprites=[visual]
 for camada in visual._camadas:sprites.append(camada)
 for sprite in sprites:
  conferir(sprite.hframes==6 and sprite.vframes==4,contexto+" grade "+str(sprite.name))
  conferir(sprite.frame==visual.frame,contexto+" quadro "+str(sprite.name))
  conferir(sprite.texture.get_size()==Vector2(480,320),contexto+" folha "+str(sprite.name)+" "+str(sprite.texture.get_size()))
  conferir(sprite.get_rect().size==Vector2(80,80),contexto+" célula "+str(sprite.name)+" "+str(sprite.get_rect().size))

func conferir_cabeca_substituida(visual: Sprite2D, conjunto, q: int, novo: bool):
 var regiao=Rect2i(q*80,0,80,80)
 var fontes=[Raven.folha("corpo_0","correr"),Raven.folha_arquivo(conjunto.RAIZ_SPRITES+"raven_peitoral.png","correr")]
 var texturas=[visual.texture,visual._camadas[10].texture]
 for i in 2:
  var antes=fontes[i].get_image().get_region(regiao)
  var depois=texturas[i].get_image().get_region(regiao)
  var limpo=true
  var preservado=true
  for y in 80:
   for x in 80:
    if novo and y<[29,28,26,29,28,26][q]:
     if depois.get_pixel(x,y).a!=0:limpo=false
    elif antes.get_pixel(x,y)!=depois.get_pixel(x,y):preservado=false
  conferir(limpo,"Sem rosto ou suporte antigo sob o elmo: "+conjunto.ID+"/"+str(q)+"/"+str(i))
  conferir(preservado,"Gola, tronco e conjuntos antigos preservados: "+conjunto.ID+"/"+str(q)+"/"+str(i))
func revisar_grade():
 assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
 assert(DisplayServer.get_name()!="headless")
 root.get_node("Ranking").conexao_habilitada=false
 root.get_node("Introducao").pular_prologo();root.get_node("Fazenda").definir_clima_hoje(0);root.get_node("Transicao").hora_salva=12
 change_scene_to_file("res://cenas/fazenda.tscn");await esperar(35);root.get_node("Transicao").limpar()
 var jogador=current_scene.get_node("Jogador");var visual=jogador.get_node("HeroiRaven")
 var posicao_inicial=jogador.global_position
 var guias_frente=JSON.parse_string(FileAccess.get_file_as_string("res://arte/fontes/personagens/corrida_mana_seed_raven/contrato.json")).guias[0]
 jogador.inventario.equipados.arma=null;jogador.inventario.equipados.escudo=null
 jogador.usando_espada=false;jogador.usando_lanca=false;jogador.usando_arco=false
 var vp=SubViewport.new();vp.size=Vector2i(1400,840);vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 vp.canvas_item_default_texture_filter=Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST;root.add_child(vp)
 var fundo=ColorRect.new();fundo.size=vp.size;fundo.color=Color("435047");vp.add_child(fundo)
 for c in Conjuntos.CONJUNTOS.size():
  var conjunto=Conjuntos.CONJUNTOS[c]
  jogador.aparencia_raven={"pele":0,"roupa":8,"cabelo":28,"cor":[1,1,1,1]}
  for tipo in conjunto.TIPOS:
   var item=Receitas.criar_item(tipo);jogador.inventario.equipados[item.categoria]=item
  var titulo=Label.new();titulo.text=conjunto.NOME.replace(" ","\n");titulo.position=Vector2(c*140+8,12);titulo.size=Vector2(124,60);titulo.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;titulo.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;titulo.add_theme_font_size_override("font_size",11);vp.add_child(titulo)
  var vistos={}
  Input.action_press("move_down")
  for passo in 150:
   jogador.global_position=posicao_inicial
   await RenderingServer.frame_post_draw
   if visual._animacao!="correr" or visual._direcao!=0:continue
   var q=visual.frame
   if vistos.has(q):continue
   vistos[q]=true;conferir_grade(visual,conjunto.ID+"/"+str(q))
   # Reproduz a regressão: corpo em seis colunas, peças ainda em quatro.
   # _definir_grade não pode encerrar a atualização só pela grade do corpo.
   for i in [9,10,11,12]:
    visual._camadas[i].frame=0;visual._camadas[i].hframes=4
   visual._process(0)
   conferir_grade(visual,conjunto.ID+"/restaurar-pecas/"+str(q))
   var ajuste=2 if c>=3 and q in [1,4] else 0
   var ajuste_x=1 if c>=3 and q in [0,1,5] else 0
   conferir(visual._camadas[9].position==Vector2(ajuste_x,ajuste),"Encaixe do elmo no tronco dos novos conjuntos: "+conjunto.ID+"/"+str(q))
   conferir_cabeca_substituida(visual,conjunto,q,c>=3)
   if c>=3:
    var folha_elmo=visual._camadas[9].texture.get_image()
    var elmo=folha_elmo.get_region(Rect2i(q*80,0,80,80)).get_used_rect()
    var referencia=folha_elmo.get_region(Rect2i(0,0,80,80)).get_used_rect()
    var centro_tronco=(float(guias_frente[q].braco_esquerdo[0][0])+float(guias_frente[q].braco_direito[0][0]))/2.0
    conferir(elmo.get_center().x+visual._camadas[9].position.x==centro_tronco,"Elmo centralizado entre os ombros em cada passada: "+conjunto.ID+"/"+str(q))
    var compressao=1 if q in [1,4] else 0
    conferir(elmo.position.y+ajuste-int(guias_frente[q].quadril[1])==referencia.position.y-int(guias_frente[0].quadril[1])+compressao,"Cabeça acompanha o tronco com recolhimento na passagem: "+conjunto.ID+"/"+str(q))
   var copia=visual.criar_rastro();copia.scale=Vector2(3,3);copia.position=Vector2(c*140+70,q*125+180);vp.add_child(copia)
   var previa=visual.criar_previa()
   conferir(previa.get_node("Camada9").position==Vector2.ZERO,"Prévia de repouso sem compensação da corrida")
   previa.free();conferir_grade(visual,conjunto.ID+"/previa/"+str(q))
   conferir(visual._camadas[9].position==Vector2(ajuste_x,ajuste),"Inventário restaura o encaixe do quadro em andamento")
   if vistos.size()==6:break
  Input.action_release("move_down")
  conferir(vistos.size()==6,"Seis quadros reais de frente em "+conjunto.ID+": "+str(vistos))
  for d in [1,2,3]:
   jogador._direcao_ataque=[Vector2.DOWN,Vector2.RIGHT,Vector2.UP,Vector2.LEFT][d]
   jogador.velocity=jogador._direcao_ataque*80
   visual._process(0)
   var ajuste_costas=Vector2.ZERO
   if c>=3 and d==2:
    var quadro_costas=visual.frame%6
    ajuste_costas=Vector2([0,0,2,2,2,0][quadro_costas],1 if quadro_costas in [1,4] else 0)
   conferir(visual._camadas[9].position==ajuste_costas,"Encaixe de costas; perfis e conjuntos antigos preservados")
  jogador.velocity=Vector2.ZERO;visual._process(0)
  conferir(visual._camadas[9].position==Vector2.ZERO,"Parar restaura o encaixe original")
  print("CORRIDA ATIVA: ",conjunto.ID," quadros ",vistos)
  await esperar(3)
 DirAccess.make_dir_recursive_absolute(SAIDA_GRADE)
 await RenderingServer.frame_post_draw;vp.get_texture().get_image().save_png(SAIDA_GRADE+"controlador_ativo.png")
 root.get_texture().get_image().save_png(SAIDA_GRADE+"no_jogo.png")
 print("GRADE CORRIDA: ",verificacoes," verificações; ",falhas," falhas")
 vp.queue_free();current_scene.queue_free();current_scene=null;await esperar(3);quit(1 if falhas else 0)
