extends "res://testes/teste_acoes_fazenda_raven.gd"
## Exporta seis quadros reais por conjunto; executar apenas com save isolado.
const Conjuntos=preload("res://codigo/dados/conjuntos_armadura.gd")
const PASTA_COSTAS="res://arte/previas/armaduras/corrida_costas/"

func _initialize():exportar.call_deferred()

func conferir_encaixe_costas(visual: Sprite2D, conjunto, q: int, guias: Array):
 var regiao=Rect2i(q*80,160,80,80)
 var guia=guias[q]
 var elmo=visual._camadas[9].texture.get_image().get_region(regiao).get_used_rect()
 var centro=elmo.get_center().x+visual._camadas[9].position.x+visual._camadas[9].offset.x
 conferir(centro==0.0,"Centro do elmo fixo no eixo do personagem, sem balanço lateral: "+conjunto.ID+"/"+str(q))
 var primeiro=visual._camadas[9].texture.get_image().get_region(Rect2i(0,160,80,80)).get_used_rect()
 conferir(elmo.position.y+visual._camadas[9].position.y-int(guia.quadril[1])==primeiro.position.y-int(guias[0].quadril[1]),"Altura acompanha o tronco nos seis quadros: "+conjunto.ID+"/"+str(q))
 var fontes=[Raven.folha("corpo_0","correr"),Raven.folha_arquivo(conjunto.RAIZ_SPRITES+"raven_peitoral.png","correr"),Raven.folha_arquivo(conjunto.RAIZ_SPRITES+"raven_luvas.png","correr")]
 var texturas=[visual.texture,visual._camadas[10].texture,visual._camadas[11].texture]
 var nuca=Rect2i(int(guia.cabeca[0])-6,0,12,int(guia.pescoco[1]))
 for i in 3:
  var antes=fontes[i].get_image().get_region(regiao)
  var depois=texturas[i].get_image().get_region(regiao)
  var limpo=true;var preservado=true
  for y in 80:
   for x in 80:
    if nuca.has_point(Vector2i(x,y)):
     if depois.get_pixel(x,y).a!=0.0:limpo=false
    elif depois.get_pixel(x,y)!=antes.get_pixel(x,y):preservado=false
  conferir(limpo,"Sem pele ou suporte antigo sob a nuca: "+conjunto.ID+"/"+str(q)+"/"+str(i))
  conferir(preservado,"Mãos erguidas, braços, gola e tronco preservados: "+conjunto.ID+"/"+str(q)+"/"+str(i))
 var posicao=visual._camadas[9].position
 var previa=visual.criar_previa()
 conferir(previa.get_node("Camada9").position==Vector2.ZERO,"Prévia neutra sem compensação das costas")
 previa.free()
 conferir(visual._camadas[9].position==posicao,"Prévia restaura o encaixe da corrida de costas")

func exportar():
 assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
 assert(DisplayServer.get_name()!="headless")
 root.get_node("Ranking").conexao_habilitada=false
 root.get_node("Introducao").pular_prologo()
 root.get_node("Fazenda").definir_clima_hoje(0)
 root.get_node("Transicao").hora_salva=12
 change_scene_to_file("res://cenas/fazenda.tscn");await esperar(35)
 root.get_node("Transicao").limpar()
 var jogador=current_scene.get_node("Jogador")
 var visual=jogador.get_node("HeroiRaven")
 var origem=jogador.global_position
 var guias=JSON.parse_string(FileAccess.get_file_as_string("res://arte/fontes/personagens/corrida_mana_seed_raven/contrato.json")).guias[2]
 jogador.inventario.equipados.arma=null;jogador.inventario.equipados.escudo=null
 jogador.usando_espada=false;jogador.usando_lanca=false;jogador.usando_arco=false
 var vp=SubViewport.new();vp.size=Vector2i(1040,1040)
 vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 vp.canvas_item_default_texture_filter=Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST;root.add_child(vp)
 var fundo=ColorRect.new();fundo.size=vp.size;fundo.color=Color("435047");vp.add_child(fundo)
 var nativo=SubViewport.new();nativo.size=Vector2i(480,560);nativo.transparent_bg=true
 nativo.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 nativo.canvas_item_default_texture_filter=Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST;root.add_child(nativo)
 for q in 6:
  var titulo=Label.new();titulo.text="QUADRO %d\n%d ms"%[q+1,[100,60,140,100,60,140][q]]
  titulo.position=Vector2(200+q*140,10);titulo.size=Vector2(140,42)
  titulo.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;titulo.add_theme_font_size_override("font_size",13);vp.add_child(titulo)
 for linha in 7:
  var conjunto=Conjuntos.CONJUNTOS[linha+3]
  jogador.aparencia_raven={"pele":0,"roupa":8,"cabelo":28,"cor":[1,1,1,1]}
  for tipo in conjunto.TIPOS:
   var item=Receitas.criar_item(tipo);jogador.inventario.equipados[item.categoria]=item
  var nome=Label.new();nome.text=conjunto.NOME.replace(" ","\n");nome.position=Vector2(14,60+linha*140+35);nome.size=Vector2(164,78)
  nome.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;nome.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
  nome.add_theme_font_size_override("font_size",14);vp.add_child(nome)
  var vistos={};Input.action_press("move_up")
  for passo in 150:
   jogador.global_position=origem;await RenderingServer.frame_post_draw
   if visual._animacao!="correr" or visual._direcao!=2:continue
   var q=visual.frame%6
   if vistos.has(q):continue
   vistos[q]=true
   conferir(visual.hframes==6 and visual.frame/6==2,"Costas e seis colunas: "+conjunto.ID+"/"+str(q))
   conferir_encaixe_costas(visual,conjunto,q,guias)
   var copia=visual.criar_rastro();copia.scale=Vector2(3,3);copia.position=Vector2(270+q*140,170+linha*140);vp.add_child(copia)
   var celula=visual.criar_rastro();celula.scale=Vector2.ONE;celula.position=Vector2(q*80+40,linha*80+47);nativo.add_child(celula)
   if vistos.size()==6:break
  Input.action_release("move_up")
  conferir(vistos.size()==6,"Seis quadros reais: "+conjunto.ID)
  print("COSTAS: ",conjunto.ID," ",vistos)
 DirAccess.make_dir_recursive_absolute(PASTA_COSTAS)
 await RenderingServer.frame_post_draw
 vp.get_texture().get_image().save_png(PASTA_COSTAS+"quadros_costas.png")
 nativo.get_texture().get_image().save_png(PASTA_COSTAS+"quadros_costas_nativos.png")
 print("CORRIDA COSTAS: ",verificacoes," verificações; ",falhas," falhas")
 vp.queue_free();nativo.queue_free();current_scene.queue_free();current_scene=null;await esperar(3);quit(1 if falhas else 0)
