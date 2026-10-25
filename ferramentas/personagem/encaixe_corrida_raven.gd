extends RefCounted
## Compila o ciclo original de seis poses sobre a identidade Raven e suas camadas.
const Encaixe=preload("res://ferramentas/personagem/encaixe_acoes_fazenda_raven.gd")
const CONTRATO="res://arte/fontes/personagens/corrida_mana_seed_raven/contrato.json"
const DESTINO="res://assets/personagens/raven_fantasy/corrida_mana_seed/"
const R=Encaixe.RAIZ
static func contrato() -> Dictionary:return JSON.parse_string(FileAccess.get_file_as_string(CONTRATO))
static func corpo(fonte: Image, cabeca: Image, guia: Dictionary, original: Dictionary) -> Image:
 var saida=Image.create(80,80,false,Image.FORMAT_RGBA8)
 var tintas={"181818":"2e1c2c","885038":"ac5846","d08860":"d8735e","f8d098":"fa947f","f8f0e0":"353a45"}
 var corte=int(guia.cabeca[1])-2+5
 # A sombra destacada dos quadros aéreos não pertence ao corpo nem à roupa.
 for y in range(corte,64):
  for x in 64:
   var c=fonte.get_pixel(x,y)
   if c.a<0.5:continue
   if y>=41 and c.to_html(false)=="181818" and int(guia.cabeca[1])<=20:continue
   var cor=Color(tintas.get(c.to_html(false),c.to_html(false)))
   var id=Encaixe.parte(Vector2(x+8,y+2),guia)
   if cor!=Color("2e1c2c") and (id=="quadril" or (id.begins_with("coxa") and Encaixe.projecao(Vector2(x+8,y+2),Encaixe.ossos(guia)[id][0],Encaixe.ossos(guia)[id][1]).x<0.35)):
    cor=Color("23272f") if c.to_html(false)=="885038" else Color("353a45")
   saida.set_pixel(x+8,y+2,cor)
 var deslocamento=Vector2i((Encaixe.v(guia.cabeca)-Encaixe.v(original.cabeca)).round())
 # Cabeça, rosto e orelhas são os pixels nativos, sem escalar ou redesenhar.
 saida.blend_rect(cabeca,Rect2i(0,0,80,31),deslocamento)
 return saida
static func projecao_nativa(modelo: Image, guia: Dictionary, original: Dictionary, nativo: Image) -> Array:
 var catalogo={}
 for y in 80:
  for x in 80:
   var cor=nativo.get_pixel(x,y)
   if cor.a<0.5:continue
   var id=Encaixe.parte(Vector2(x,y),original)
   var chave=id+str(cor==Color("2e1c2c"))
   if not catalogo.has(chave):catalogo[chave]=[]
   catalogo[chave].append(Vector2i(x,y))
 var pixels=Encaixe.mapa(modelo,guia,original)
 for pixel in pixels:
  if pixel.parte=="cabeca":
   pixel.uv=Vector2i((Vector2(pixel.pos)-Encaixe.v(guia.cabeca)+Encaixe.v(original.cabeca)).round())
   continue
  var lista=catalogo.get(pixel.parte+str(pixel.contorno),[])
  if lista.is_empty():lista=catalogo.get(pixel.parte+str(not pixel.contorno),[])
  assert(not lista.is_empty(),pixel.parte)
  var menor=INF;var uv=Vector2i.ZERO
  for pos in lista:
   var distancia=Vector2(pos).distance_squared_to(pixel.uv)
   if distancia<menor:menor=distancia;uv=pos
  pixel.uv=uv
 return pixels
static func camada_nativa(origem: Image, pixels: Array) -> Image:
 var saida=Image.create(80,80,false,Image.FORMAT_RGBA8)
 for pixel in pixels:
  var uv=Vector2i(pixel.uv)
  if Rect2i(0,0,80,80).has_point(uv):saida.set_pixelv(pixel.pos,origem.get_pixelv(uv))
 return saida

## Na fase aérea, a canela recolhe para o centro. O guia antigo marcava o
## tornozelo do lado de fora e atribuía esse pé ao quadril e às manoplas.
static func guia_pernas_frente(guia: Dictionary, q: int) -> Dictionary:
 var ajustado=guia.duplicate(true)
 if q==2:
  ajustado.perna_esquerda=[[38,34],[37,36],[40,39]]
  ajustado.perna_direita=[[42,34],[44,34],[44,37]]
 elif q==5:
  ajustado.perna_esquerda=[[37,34],[35,34],[36,37]]
  ajustado.perna_direita=[[41,34],[43,36],[40,39]]
 return ajustado

## Reencaixa somente as pernas de frente; conserva desenho, pivô e seis tempos.
static func corrigir_pernas_frente(destino: String) -> void:
 var dados=contrato();var original=Encaixe.carregar_guias().originais[0]
 var modelo=Image.load_from_file(DESTINO+"corpo_0.png")
 var folhas={}
 for peca in Encaixe.PECAS:folhas[peca]=Image.load_from_file(destino+"raven_"+peca+"/correr.png")
 var fonte=Image.load_from_file(destino+"raven_botas.png").get_region(Rect2i(0,320,80,80))
 var paleta=JSON.parse_string(FileAccess.get_file_as_string(destino.replace("res://assets/personagens/conjuntos/","res://ferramentas/armaduras/em_preparacao/")+"manifesto.json")).paleta
 var esquerda: Array[Vector2i]=[];var direita: Array[Vector2i]=[]
 var candidatos={"esquerda":esquerda,"direita":direita}
 for pos in Encaixe.candidatos(fonte):
  candidatos["esquerda" if pos.x<float(original.quadril[0]) else "direita"].append(pos)
 var reparados=0
 for q in 6:
  var guia=guia_pernas_frente(dados.guias[0][q],q)
  var ossos_alvo=Encaixe.ossos(guia)
  for y in range(int(guia.quadril[1])+1,80):
   for x in 80:
    var pos=Vector2i(q*80+x,y);var pele=modelo.get_pixelv(pos)
    if pele.a<0.5:continue
    var p=Vector2(x,y);var menor=INF;var perna=""
    for id in ["coxa_esquerdo","canela_esquerdo","coxa_direito","canela_direito"]:
     var osso=ossos_alvo[id];var dist=Encaixe.projecao(p,osso[0],osso[1]).y/float(osso[2])
     if dist<menor:menor=dist;perna=id
    var mao=INF
    for id in ["braco_esquerdo","antebraco_esquerdo","braco_direito","antebraco_direito"]:
     var osso=ossos_alvo[id];mao=minf(mao,Encaixe.projecao(p,osso[0],osso[1]).y/float(osso[2]))
    if mao<menor:continue
    var lado="esquerda" if perna.ends_with("esquerdo") else "direita"
    var uv=Encaixe.coordenada(p,perna,guia,original)
    var cor=Encaixe.amostrar(fonte,uv,candidatos[lado])
    # Solado e contorno pertencem ao pé; não puxar metal claro para a
    # borda de sombra da outra perna ao procurar a amostra mais próxima.
    if pele==Color("2e1c2c"):
     cor=Color.html(paleta[0])
    folhas.botas.set_pixelv(pos,cor)
    folhas.peitoral.set_pixelv(pos,Color.TRANSPARENT)
    folhas.luvas.set_pixelv(pos,Color.TRANSPARENT)
    reparados+=1
 for peca in ["peitoral","luvas","botas"]:Encaixe.escrever(folhas[peca],destino+"raven_"+peca+"/correr.png")
 print("Corrida de frente: ",reparados," pixels das pernas com pé recolhido e peças separadas em ",destino)
static func capa_corrida(origem: Image, guia: Dictionary, original: Dictionary, modelo: Image, d: int, q: int) -> Dictionary:
 var tras=Image.create(80,80,false,Image.FORMAT_RGBA8);var fecho=Image.create(80,80,false,Image.FORMAT_RGBA8)
 var alvo=Encaixe.v(guia.pescoco);var fonte=Encaixe.v(original.pescoco)
 if d==2:
  # A ombreira é rígida e acompanha a articulação, independente do pano.
  var deslocamento=Vector2i((Encaixe.v(guia.braco_esquerdo[0])-Encaixe.v(original.braco_esquerdo[0])).round())
  fecho.blit_rect(origem,Rect2i(30,28,5,6),Vector2i(30,28)+deslocamento)
  return {"capa":capa_costas(origem,guia,original,modelo,q),"capa_fecho":fecho}
 # Um pano de comprimento constante, preso ao pescoço. A barra acompanha
 # uma ondulação curta e contínua; a fase aérea não estica o tecido.
 var arrasto=[-1.0,-2.0,-3.0,-2.0,-1.0,0.0][q]*(1 if d==1 else -1 if d==3 else 0)
 for y in 80:
  for x in 80:
   var altura=clampf((y-alvo.y)/17.0,0,1)
   var uv=Vector2i(Vector2(x-alvo.x+fonte.x-arrasto*altura,y-alvo.y+fonte.y).round())
   if not Rect2i(0,0,80,80).has_point(uv):continue
   var cor=origem.get_pixelv(uv)
   if cor.a<0.5:continue
   if d==2 and modelo.get_pixel(x,y).a>0.5:
    var id=Encaixe.parte(Vector2(x,y),guia)
    if id=="cabeca" or id.begins_with("braco") or id.begins_with("antebraco"):continue
   tras.set_pixel(x,y,cor)
   if d!=2 and uv.y<=int(fonte.y)+1:fecho.set_pixel(x,y,cor)
 return {"capa":tras,"capa_fecho":fecho}
static func capa_costas(origem: Image, guia: Dictionary, original: Dictionary, modelo: Image, q: int) -> Image:
 var saida=Image.create(80,80,false,Image.FORMAT_RGBA8)
 var alvo=Encaixe.v(guia.pescoco);var fonte=Encaixe.v(original.pescoco)
 # Na corrida para longe da câmera, o pano se dobra e levanta na impulsão.
 # A gola acompanha o pescoço; cintura e barra seguem a inclinação do tronco.
 var comprimento=[14.0,13.0,12.0,14.0,13.0,12.0][q]
 var onda=[0.0,1.0,1.0,0.0,-1.0,-1.0][q]
 var inclinacao=Encaixe.v(guia.quadril).x-alvo.x
 for y in 80:
  var h=float(y)-alvo.y
  var t=clampf(h/comprimento,0.0,1.0)
  var centro=alvo.x+inclinacao*t+onda*t*t
  # As dobras aproximam as laterais; ombros mantêm o encaixe nativo.
  var largura=1.0-0.16*t
  var fonte_y=fonte.y+h if h<=3.0 else fonte.y+3.0+(h-3.0)*14.0/(comprimento-3.0)
  for x in 80:
   var uv=Vector2i(roundi(fonte.x+(x-centro)/largura),roundi(fonte_y))
   if not Rect2i(0,0,80,80).has_point(uv):continue
   # Metal e contorno da ombreira são compostos separadamente, sem dobrar.
   if Rect2i(30,28,5,6).has_point(uv):continue
   var cor=origem.get_pixelv(uv)
   if cor.a<0.5:continue
   # A cabeça cobre a gola. Não recortar o centro do pano pela classificação
   # do osso mais próximo: os braços cruzam o dorso durante a passada.
   if modelo.get_pixel(x,y).a>0.5:
    var id=Encaixe.parte(Vector2(x,y),guia)
    if id=="cabeca":continue
   saida.set_pixel(x,y,cor)
 return saida
static func preparar() -> void:
 var dados=contrato();var origem=Image.load_from_file("res://"+dados.referencia)
 var guias_originais=Encaixe.carregar_guias().originais
 var nomes=["calca_marrom","calca_jeans","camisa_azul","camisa_verde","botas","luvas","capa","aljava"]
 for i in 28:nomes.append("cabelo_%d"%(i+1))
 var fontes={}
 for nome in nomes+ ["corpo_0","corpo_1","corpo_2"]:
  fontes[nome]=Image.load_from_file(R+"camadas/"+nome+".png").get_region(Rect2i(0,320,320,320))
 fontes.capa=Encaixe.capa_inteira()
 var folhas={}
 for nome in nomes+ ["corpo_0","corpo_1","corpo_2","capa_fecho","vazio","ferramentas","escudo_tras","escudo_frente"]:folhas[nome]=Image.create(480,320,false,Image.FORMAT_RGBA8)
 for d in 4:
  for q in 6:
   var guia=dados.guias[d][q];var original=guias_originais[d]
   var fonte=origem.get_region(Rect2i(int(dados.colunas_origem[q])*64,(4+int(dados.linhas_origem[d]))*64,64,64))
   var cabeca=fontes.corpo_0.get_region(Rect2i(0,d*80,80,80))
   var modelo=corpo(fonte,cabeca,guia,original)
   var pontos=projecao_nativa(modelo,guia,original,cabeca)
   for pele in 3:
    var origem_pele=fontes["corpo_%d"%pele].get_region(Rect2i(0,d*80,80,80))
    var imagem=camada_nativa(origem_pele,pontos)
    # Short neutro por baixo das peças, sem reduzir a rampa da pele Raven.
    for pixel in pontos:
     if pixel.parte=="quadril" and not pixel.contorno:imagem.set_pixelv(pixel.pos,Color("353a45"))
    folhas["corpo_%d"%pele].blit_rect(imagem,Rect2i(0,0,80,80),Vector2i(q*80,d*80))
   var pano=capa_corrida(fontes.capa.get_region(Rect2i(0,d*80,80,80)),guia,original,modelo,d,q)
   folhas.capa_fecho.blit_rect(pano.capa_fecho,Rect2i(0,0,80,80),Vector2i(q*80,d*80))
   for nome in nomes:
    var f=fontes[nome].get_region(Rect2i(0,d*80,80,80));var imagem: Image
    if nome.begins_with("cabelo_"):imagem=Encaixe.cabeca(f,guia,original,modelo)
    elif nome=="capa":imagem=pano.capa
    elif nome=="aljava":imagem=Encaixe.capa(f,guia,original,modelo)
    else:
     imagem=Encaixe.tecido(nome,f,pontos)
     # O contorno da cabeça pode cair fora da elipse do guia anatômico.
     # A gola limita a roupa: nunca projetar tecido no rosto ou na testa.
     if nome.begins_with("camisa_"):
      for y in range(int(guia.pescoco[1])-1):
       for x in 80:imagem.set_pixel(x,y,Color.TRANSPARENT)
    folhas[nome].blit_rect(imagem,Rect2i(0,0,80,80),Vector2i(q*80,d*80))
 # O pé dobrado fica junto ao quadril e o osso mais próximo o classificava
 # como coxa. Marcação dos quatro calcanhares levantados na máscara Mana Seed.
 var calcanhares={0:Rect2i(42,37,5,4),2:Rect2i(35,34,4,3),3:Rect2i(33,37,5,4),5:Rect2i(41,34,4,3)}
 for q in calcanhares:
  var regiao: Rect2i=calcanhares[q]
  for y in range(regiao.position.y,regiao.end.y):
   for x in range(regiao.position.x,regiao.end.x):
    var pos=Vector2i(q*80+x,160+y)
    var cor=folhas.corpo_0.get_pixelv(pos)
    if cor.a<0.5:continue
    var tinta=Color("2e1c2c") if cor==Color("2e1c2c") else Color("463329") if cor==Color("ac5846") else Color("614837")
    folhas.botas.set_pixelv(pos,tinta)
 # Os calcanhares sobem para o lado da câmera ao correr para cima.
 # O tecido fica atrás deles; preservar a bota inteira evita apagar a
 # perna dobrada nas poses de apoio e passagem.
 for q in 6:
  for y in 80:
   for x in 80:
    var pos=Vector2i(q*80+x,160+y)
    if folhas.botas.get_pixelv(pos).a>0.5:folhas.capa.set_pixelv(pos,Color.TRANSPARENT)
 for nome in folhas:Encaixe.escrever(folhas[nome],DESTINO+nome+".png")
 print("Corrida: ",folhas.size()," camadas, seis poses, quatro direções")
## Reaplica a revisão exata do PixelLab sem recompor as outras peças.
## A origem da chapa permanece fixa: limpar a base não recentraliza o elmo.
static func corrigir_base_elmos_corrida(destino: String) -> bool:
 var manifesto=destino.replace("res://assets/personagens/conjuntos/","res://ferramentas/armaduras/em_preparacao/")+"manifesto.json"
 if not FileAccess.file_exists(manifesto):return true
 var config=JSON.parse_string(FileAccess.get_file_as_string(manifesto))
 if not config.has("arte_base_elmo"):return true
 var originais=Image.load_from_file(config.arte_elmo)
 var revisados=Image.load_from_file(config.arte_base_elmo)
 var caminho=destino+"raven_elmo/correr.png"
 var folha=Image.load_from_file(caminho)
 var removidos=0
 for vista in [[0,0],[2,1]]:
  var d=int(vista[0]);var coluna=int(vista[1])
  var original=originais.get_region(Rect2i(coluna*24,0,24,24))
  var revisado=revisados.get_region(Rect2i(coluna*24,0,24,24))
  var caixa=original.get_used_rect()
  for q in 6:
   var alvo=folha.get_region(Rect2i(q*80,d*80,80,80)).get_used_rect().position+Vector2i(q*80,d*80)-caixa.position
   for y in 24:
    for x in 24:
     var antes=original.get_pixel(x,y);var depois=revisado.get_pixel(x,y)
     if antes==depois:continue
     if antes.a<0.5 or depois.a>0.0:
      push_error("Revisão da base só pode retirar pixels: "+destino);return false
     var pos=alvo+Vector2i(x,y);var atual=folha.get_pixelv(pos)
     if atual.a==0.0:continue
     if atual!=antes:
      push_error("Base do elmo diverge da fonte: "+destino+"/"+str(d)+"/"+str(q)+"/"+str(pos));return false
     folha.set_pixelv(pos,Color.TRANSPARENT);removidos+=1
 Encaixe.escrever(folha,caminho)
 print("Bases dos elmos na corrida: ",removidos," pixels de pontas retirados em ",destino)
 return true

static func preparar_conjunto(destino: String, somente_elmo: bool=false, sombra: Color=Color.TRANSPARENT, somente_peitoral: bool=false, pernas_frente: bool=false) -> void:
 var dados=contrato();var originais=Encaixe.carregar_guias().originais
 var corpo_0=Image.load_from_file(DESTINO+"corpo_0.png");var fontes={};var folhas={}
 var reparos=0
 for peca in Encaixe.PECAS:
  fontes[peca]=Image.load_from_file(destino+"raven_"+peca+".png").get_region(Rect2i(0,320,320,320));folhas[peca]=Image.create(480,320,false,Image.FORMAT_RGBA8)
 for d in 4:
  for q in 6:
   var guia=dados.guias[d][q];var original=originais[d];var modelo=corpo_0.get_region(Rect2i(q*80,d*80,80,80));var nativo=Image.load_from_file(R+"camadas/corpo_0.png").get_region(Rect2i(0,320+d*80,80,80));var pixels=projecao_nativa(modelo,guia,original,nativo);var partes={}
   for peca in Encaixe.PECAS:
    var f=fontes[peca].get_region(Rect2i(0,d*80,80,80))
    partes[peca]=Encaixe.cabeca(f,guia,original,modelo) if peca=="elmo" else camada_nativa(f,pixels)
   # Pequenos contornos do corpo nativo ficam fora da borda original da
   # armadura. Completar só esses pixels, com a peça anatômica correta,
   # preserva os detalhes já amostrados e não deixa a pele vazar na borda.
   var candidatos={}
   for peca in ["peitoral","luvas","botas"]:candidatos[peca]=Encaixe.candidatos(fontes[peca].get_region(Rect2i(0,d*80,80,80)))
   for pixel in pixels:
    if pixel.parte=="cabeca":continue
    var coberto=false
    for peca in Encaixe.PECAS:
     if partes[peca].get_pixelv(pixel.pos).a>0.5:coberto=true;break
    if coberto:continue
    var peca="botas" if pixel.parte.begins_with("coxa") or pixel.parte.begins_with("canela") else "luvas" if pixel.parte.begins_with("antebraco") else "peitoral"
    partes[peca].set_pixelv(pixel.pos,Encaixe.amostrar(fontes[peca].get_region(Rect2i(0,d*80,80,80)),Vector2(pixel.uv),candidatos[peca]))
    reparos+=1
   for y in 80:
    for x in 80:
     if partes.elmo.get_pixel(x,y).a>0.5:
      for peca in ["peitoral","luvas","botas"]:partes[peca].set_pixel(x,y,Color.TRANSPARENT)
   for peca in Encaixe.PECAS:folhas[peca].blit_rect(partes[peca],Rect2i(0,0,80,80),Vector2i(q*80,d*80))
 if somente_elmo:
  var outras: Array[Image] = []
  for peca in ["peitoral","luvas","botas"]:outras.append(Image.load_from_file(destino+"raven_"+peca+"/correr.png"))
  Encaixe.preservar_outras_pecas(folhas.elmo,outras,corpo_0,sombra)
  Encaixe.escrever(outras[0],destino+"raven_peitoral/correr.png")
 if somente_peitoral:
  folhas.peitoral=Encaixe.preservar_mascara(Image.load_from_file(destino+"raven_peitoral/correr.png"),folhas.peitoral)
 var selecionadas: Array=["peitoral"] if somente_peitoral else (["elmo"] if somente_elmo else Encaixe.PECAS)
 for peca in selecionadas:Encaixe.escrever(folhas[peca],destino+"raven_"+peca+"/correr.png")
 if pernas_frente:corrigir_pernas_frente(destino)
 if not somente_peitoral and not corrigir_base_elmos_corrida(destino):
  push_error("Não foi possível reaplicar a base revisada do elmo: "+destino)
 print("Corrida: peças independentes em ",destino,"; bordas completadas: ",reparos)
