extends SceneTree
func _initialize():rodar.call_deferred()
func imagem(caminho):return Image.load_from_file(ProjectSettings.globalize_path('res://'+caminho))
func vetor(im:Image):
 var soma=Vector2.ZERO;var n=0
 for y in im.get_height():
  for x in im.get_width():
   var c=im.get_pixel(x,y)
   if c.a>0.5 and c.r+c.g+c.b>1.8 and c.b>c.r*0.6:soma+=Vector2(x+0.5,y+0.5);n+=1
 assert(n>0)
 return soma/n-Vector2(im.get_used_rect().get_center())
func rodar():
 assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
 var original=load('res://cenas/jogador.tscn').instantiate();var ap=original.get_node('CompositeSprites/Animation/AnimationPlayer')
 var corpo_mana=imagem('assets/personagens/Body/body_1.png').get_region(Rect2i(0,0,64,64)).get_used_rect()
 var corpo_raven=load('res://codigo/dados/aparencia_raven.gd').folha('corpo_0','parado').get_image().get_region(Rect2i(0,0,80,80)).get_used_rect()
 var proporcao=float(corpo_raven.size.y)/corpo_mana.size.y
 var dados={"proporcao_corpo":proporcao,"referencia":"Trilhas de posição/rotação do AnimationPlayer em cenas/jogador.tscn, criação original Mana Seed.","pivo":[40,47],"raiz":"pés do Raven","sequencia_origem":[0,0,1,2,2,3],"armas":{}}
 for tipo in ['espada','espada_dupla','lanca']:
  var nome='Braco' if tipo!='lanca' else 'Lanca'
  var fonte=imagem('assets/personagens/Arms/'+('swords/Sword_1.png' if tipo!='lanca' else 'spears/spear_1.png'));var tam=fonte.get_size()/8
  var nativo=load('res://codigo/dados/aparencia_raven.gd').folha('ferramentas',tipo).get_image().get_region(Rect2i(0,0,80,80));var caixa=nativo.get_used_rect();var angulo_nativo=vetor(nativo).angle()
  var estados={"caixa":[caixa.position.x,caixa.position.y,caixa.size.x,caixa.size.y],"angulo_nativo":angulo_nativo}
  for estado in ['idle','running']:
   var direcoes=[]
   for d in 4:
    var anim=ap.get_animation(estado+'_'+['down','right','up','left'][d]);var poses=[]
    for q in (6 if estado=='running' else 1):
     var t=[0,0,0.1,0.2,0.2,0.3][q] if estado=='running' else 0.0
     var props={'position':Vector2.ZERO,'rotation':0.0,'flip_h':false,'flip_v':false,'frame':0,'z_index':0}
     for i in anim.get_track_count():
      var p=str(anim.track_get_path(i))
      if not p.begins_with('BaseSprites/'+nome+':'):continue
      for k in anim.track_get_key_count(i):
       if anim.track_get_key_time(i,k)<=t+0.00001:props[p.get_slice(':',1)]=anim.track_get_key_value(i,k)
     var f=int(props.frame);var celula=fonte.get_region(Rect2i(Vector2i(f%8,f/8)*tam,tam));var centro=Vector2(celula.get_used_rect().get_center())-Vector2(tam)/2
     var sentido=vetor(celula);var flip=Vector2(-1 if props.flip_h else 1,-1 if props.flip_v else 1)
     centro=props.position+(centro*flip).rotated(props.rotation)
     # Pés Mana Seed em y11; normaliza pela altura real dos corpos em repouso.
     centro=(centro-Vector2(0,11))*proporcao
     var angulo=(sentido*flip).rotated(props.rotation).angle()-angulo_nativo
     poses.append({"posicao":[snappedf(centro.x,1),snappedf(centro.y,1)],"rotacao":angulo,"z":2 if d==2 else -2})
    direcoes.append(poses)
   estados[estado]=direcoes
  dados.armas[tipo]=estados
 var f=FileAccess.open('res://assets/personagens/raven_fantasy/porte_costas.json',FileAccess.WRITE);f.store_string(JSON.stringify(dados,'  '));f.close();original.free();quit()
