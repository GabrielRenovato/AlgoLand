extends "res://testes/teste_acoes_fazenda_raven.gd"
const Corrida=preload("res://codigo/dados/corrida_raven.gd")
const PREVIAS="res://arte/previas/personagens/corrida_mana_seed_raven/"
func _initialize():revisar.call_deferred()
func revisar():
 assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
 assert(DisplayServer.get_name()!="headless")
 for p in [[0.0,0],[0.099,0],[0.10,1],[0.159,1],[0.16,2],[0.299,2],[0.30,3],[0.40,4],[0.46,5],[0.599,5],[0.60,0]]:
  conferir(Corrida.quadro(p[0],0.6)==p[1],"Tempo da referência "+str(p))
 var dados=JSON.parse_string(FileAccess.get_file_as_string("res://arte/fontes/personagens/corrida_mana_seed_raven/contrato.json"))
 for d in 4:
  for q in 6:
   var guia=dados.guias[d][q]
   conferir(float(guia.quadril[1])-float(guia.pescoco[1])>=5,"Quadril abaixo do pescoço, sem inverter o tronco %d/%d"%[d,q])
   for lado in ["esquerda","direita"]:
    var origem=Vector2(guia["perna_"+lado][0][0],guia["perna_"+lado][0][1])
    conferir(origem.distance_to(Vector2(guia.quadril[0],guia.quadril[1]))<=3,"Coxas partem do quadril %d/%d/%s"%[d,q,lado])
 for nome in ["corpo_0","corpo_1","corpo_2","camisa_azul","camisa_verde","calca_jeans","calca_marrom","botas","luvas","capa","capa_fecho","aljava","vazio","ferramentas","escudo_tras","escudo_frente"]:
  conferir(Raven.folha(nome,"correr").get_size()==Vector2(480,320),"Camada modular "+nome)
 for cabelo in range(1,29):
  var im=Raven.folha("cabelo_%d"%cabelo,"correr").get_image()
  conferir(im.get_size()==Vector2i(480,320),"Folha de cabelo "+str(cabelo))
  for d in 4:
   for q in 6:
    var r=im.get_region(Rect2i(q*80,d*80,80,80)).get_used_rect()
    conferir(r.has_area() and r.position.x>0 and r.position.y>0 and r.end.x<80 and r.end.y<80,"Cabelo íntegro %d/%d/%d"%[cabelo,d,q])
 # Regressão: pixels da camisa não podem aparecer como pontos na cabeça.
 for nome in ["camisa_azul","camisa_verde"]:
  var camisa=Raven.folha(nome,"correr").get_image()
  for d in 4:
   for q in 6:
    var cabeca=camisa.get_region(Rect2i(q*80,d*80,80,int(dados.guias[d][q].pescoco[1])-1))
    conferir(cabeca.is_invisible(),"Sem tecido solto acima da gola %s/%d/%d"%[nome,d,q])
 var base=Raven.folha("corpo_0","correr").get_image()
 var capa=Raven.folha("capa","correr").get_image()
 var botas=Raven.folha("botas","correr").get_image()
 var fecho=Raven.folha("capa_fecho","correr").get_image()
 # O pano precisa manter o dorso contínuo e revelar a passada para cima.
 for q in 6:
  var guia=dados.guias[2][q]
  var im=capa.get_region(Rect2i(q*80,160,80,80))
  for h in range(4,10):
   var x=roundi(lerpf(float(guia.pescoco[0]),float(guia.quadril[0]),float(h)/14.0))
   conferir(im.get_pixel(x,int(guia.pescoco[1])+h).a>0.99 or botas.get_pixel(q*80+x,160+int(guia.pescoco[1])+h).a>0.99,"Dorso contínuo ou calcanhar à frente da capa")
  var corpo=base.get_region(Rect2i(q*80,160,80,80))
  var pes_visiveis=0
  for y in range(int(guia.quadril[1])+1,80):
   for x in 80:
    if corpo.get_pixel(x,y).a>0.5 and im.get_pixel(x,y).a<0.5:pes_visiveis+=1
  conferir(pes_visiveis>=8,"Pernas legíveis sob a capa para cima, pose %d"%q)
 # Regressão: conferir cada pé, e a ombreira rígida, separadamente.
 var areas_pes=[[[34,42,6,5],[42,37,5,4]],[[34,42,6,4],[40,41,5,3]],[[41,37,5,5],[35,34,4,3]],[[41,42,6,5],[33,37,5,4]],[[41,42,6,4],[35,41,5,3]],[[35,37,5,5],[41,34,4,3]]]
 for q in 6:
  for area in areas_pes[q]:
   var visiveis=0
   for y in range(area[1],area[1]+area[3]):
    for x in range(area[0],area[0]+area[2]):
     if botas.get_pixel(q*80+x,160+y).a>0.5 and capa.get_pixel(q*80+x,160+y).a<0.5:visiveis+=1
   conferir(visiveis>=4,"Cada pé aparece à frente do pano na pose %d"%q)
  var metal=0
  for y in 80:
   for x in 80:
    var cor=fecho.get_pixel(q*80+x,160+y)
    if cor.a>0.5 and cor.to_html(false) in ["696a6a","847e87","9badb7"]:metal+=1
  conferir(metal==12,"Ombreira preserva seus 12 pixels de metal na pose %d"%q)
 for d in 4:
  var altura_inicial=-1
  for q in 6:
   var r=capa.get_region(Rect2i(q*80,d*80,80,80)).get_used_rect()
   var barra=r.end.y-int(dados.guias[d][q].pescoco[1])
   if q==0:altura_inicial=barra
   if d==2:
    conferir(r.has_area() and barra>=11 and barra<=15,"Barra da capa dobrada na corrida para cima %d"%q)
   else:
    conferir(r.has_area() and barra==altura_inicial,"Capa mantém comprimento ao mudar passada %d/%d"%[d,q])
 for d in 4:
  var chao=base.get_region(Rect2i(0,d*80,80,80)).get_used_rect().end.y
  for q in [2,5]:
   conferir(base.get_region(Rect2i(q*80,d*80,80,80)).get_used_rect().end.y<=chao-3,"Fase aérea com pés acima do chão %d/%d"%[d,q])
 for conjunto in ["carrasco","cavaleiro_rubro","cavalheiro"]:
  for peca in ["elmo","peitoral","luvas","botas"]:
   conferir(Raven.folha_arquivo("res://assets/personagens/conjuntos/"+conjunto+"/raven_"+peca+".png","correr").get_size()==Vector2(480,320),"Peça real "+conjunto+peca)
 root.get_node("Introducao").pular_prologo();root.get_node("Fazenda").definir_clima_hoje(0);root.get_node("Transicao").hora_salva=12
 change_scene_to_file("res://cenas/fazenda.tscn");await esperar(30);root.get_node("Transicao").limpar();current_scene.process_mode=Node.PROCESS_MODE_DISABLED
 var jogador=current_scene.get_node("Jogador");var visual=jogador.get_node("HeroiRaven")
 var controle=root.get_node("Controle")
 controle.usando_toque=true
 jogador._esta_atacando=false
 controle.vetor_toque=Vector2(0.3,0)
 for i in 40:jogador.mover()
 var velocidade_leve=jogador.velocity.length()
 visual._process(0.1)
 conferir(visual._animacao=="correr" and visual.hframes==6,"Toque leve usa a corrida nova de seis quadros")
 controle.vetor_toque=Vector2(0.6,0);jogador.mover();visual._process(0)
 conferir(visual._animacao=="correr","Toque intermediário mantém corrida")
 controle.vetor_toque=Vector2(1,0)
 for i in 40:jogador.mover()
 visual._process(0.1)
 conferir(visual._animacao=="correr" and visual.hframes==6,"Toque forte mantém corrida")
 conferir(absf(velocidade_leve/jogador.velocity.length()-1.0)<0.01,"Toque leve tem a mesma velocidade de corrida do toque forte")
 controle.vetor_toque=Vector2(0.58,0);jogador.mover();visual._process(0)
 conferir(visual._animacao=="correr","Reduzir a intensidade mantém corrida")
 controle.vetor_toque=Vector2(0.4,0);jogador.mover();visual._process(0)
 conferir(visual._animacao=="correr" and visual.hframes==6,"Aliviar o joystick continua na corrida nova")
 controle.vetor_toque=Vector2.ZERO
 for i in 40:jogador.mover()
 visual._process(0.1)
 conferir(visual._animacao=="parado","Soltar joystick termina no repouso")
 controle.usando_toque=false
 Input.action_press("move_right")
 for i in 40:jogador.mover()
 visual._process(0.1)
 conferir(visual._animacao=="correr","Teclado continua usando a corrida nova")
 Input.action_release("move_right")
 jogador.velocity=Vector2.ZERO
 var vp=SubViewport.new();vp.size=Vector2i(840,560);vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS;vp.canvas_item_default_texture_filter=Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST;root.add_child(vp)
 var fundo=ColorRect.new();fundo.size=vp.size;fundo.color=Color("6e7563");vp.add_child(fundo)
 DirAccess.make_dir_recursive_absolute(PREVIAS)
 var configs=[{"nome":"base","pele":0,"roupa":0,"cabelo":0,"itens":[]},{"nome":"azul","pele":0,"roupa":1,"cabelo":1,"itens":[]},{"nome":"capa","pele":1,"roupa":8,"cabelo":28,"itens":[]},{"nome":"misturado","pele":2,"roupa":8,"cabelo":14,"itens":["elmo_cavaleiro_rubro","peitoral_carrasco","luvas_cavalheiro","botas_cavaleiro_rubro"]}]
 for config in configs:
  jogador.aparencia_raven={"pele":config.pele,"roupa":config.roupa,"cabelo":config.cabelo,"cor":[1,1,1,1]}
  for slot in ["cabeca","corpo","luvas","botas"]:jogador.inventario.equipados[slot]=null
  for tipo in config.itens:
   var item=Receitas.criar_item(tipo);jogador.inventario.equipados[item.categoria]=item
  var copias=[]
  for d in 4:
   var dir=[Vector2.DOWN,Vector2.RIGHT,Vector2.UP,Vector2.LEFT][d];jogador._direcao_ataque=dir;jogador.velocity=Vector2.ZERO;jogador.cancelar_acao_fazenda();visual._process(0)
   var repouso=copiar(visual);repouso.position=Vector2(60,d*140+125);repouso.scale=Vector2(3,3);vp.add_child(repouso);copias.append(repouso)
   var t=0.0
   for q in 6:
    jogador.velocity=dir*80;visual._animacao="correr";visual._direcao=d;visual._tempo=t+0.001;visual._process(0)
    conferir(visual.hframes==6 and visual.frame==d*6+q,"Controlador real %s/%d/%d"%[config.nome,d,q])
    for camada in visual._camadas:conferir(camada.hframes==6 and camada.frame==visual.frame,"Camada acompanha o corpo")
    var previa=visual.criar_previa()
    conferir(previa.hframes==4 and visual.hframes==6 and visual.frame==d*6+q,"Prévia neutra preserva corrida em andamento")
    previa.free()
    var copia=copiar(visual);copia.scale=Vector2(3,3);copia.position=Vector2((q+1)*120+60,d*140+125);vp.add_child(copia);copias.append(copia)
    t+=Corrida.DURACOES[q]
   jogador.velocity=Vector2.ZERO;visual._process(0)
   conferir(visual.hframes==4 and visual._animacao=="parado","Parar restaura repouso")
   conferir(jogador.acao_fazenda("colher"),"Colheita inicia depois de correr");visual._process(0);conferir(visual.hframes==4 and visual._animacao=="colher","Colheita usa sua própria grade");jogador.cancelar_acao_fazenda()
  await esperar(2);await RenderingServer.frame_post_draw;vp.get_texture().get_image().save_png(PREVIAS+config.nome+".png")
  for copia in copias:copia.queue_free()
  await esperar(2)
 vp.queue_free();current_scene.queue_free();current_scene=null;await esperar(3)
 print("CORRIDA MANA SEED: ",verificacoes," verificações; ",falhas," falhas");quit(1 if falhas else 0)
