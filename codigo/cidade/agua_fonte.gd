extends Node2D
## Ondas de superfície nas duas bacias, com bordas refletoras, alimentadas
## por jatos e gotas balísticos. A pedra permanece fora da simulação.
const SHADER := preload("res://codigo/cidade/agua_fonte.gdshader")
const N := 96
const PASSO := 1.0/30.0
const GRAVIDADE := 190.0
const LARGURAS_JATO := [0.7, 0.9, 1.1, 1.3, 1.5, 1.7]
var imagem: Sprite2D
var altura := PackedFloat32Array()
var anterior := PackedFloat32Array()
var proxima := PackedFloat32Array()
var molhado := PackedByteArray()
var ativos: Array[int] = []
var emissores: Array[Dictionary] = []
var gotas: Array[Dictionary] = []
var ondas: Array[Dictionary] = []
var passos := 0
var impactos := 0
var tempo := 0.0
var _acumulado := 0.0
var _emissao := 0.0
var _campo: Image
var _bytes := PackedByteArray()
## Só simula e desenha com a fonte na tela: no celular a simulação em GDScript pesava na cidade inteira
var _aviso: VisibleOnScreenNotifier2D
var _textura: ImageTexture
var _material: ShaderMaterial
var _aleatorio := RandomNumberGenerator.new()
var _trajetos: Array[Dictionary] = []
var _circulo := PackedVector2Array()
## Um lote por espessura mantém as curvas, sem centenas de comandos individuais.
var lotes_desenho := 0

func _ready() -> void:
	_aleatorio.seed=336284
	position=imagem.offset*imagem.scale
	var original:=imagem.texture.get_image()
	if original.is_compressed(): original.decompress()
	var mascara:=Image.create(original.get_width(),original.get_height(),false,Image.FORMAT_RGBA8)
	for y in original.get_height():
		for x in original.get_width():
			var cor:=original.get_pixel(x,y)
			var agua:=cor.a>.3 and cor.b>cor.r*1.045 and cor.g>cor.r*.99
			mascara.set_pixel(x,y,Color.WHITE if agua else Color.BLACK)
	altura.resize(N*N)
	anterior.resize(N*N)
	proxima.resize(N*N)
	molhado.resize(N*N)
	_campo=Image.create(N,N,false,Image.FORMAT_RGBA8)
	_campo.fill(Color(.5,.5,.5,1))
	for y in range(1,N-1):
		for x in range(1,N-1):
			var quantidade:=0
			for dy in 4:
				for dx in 4:
					if mascara.get_pixel(x*4+dx,y*4+dy).r>.5: quantidade+=1
			if quantidade>=3:
				molhado[y*N+x]=1
				ativos.append(y*N+x)
	_bytes=_campo.get_data()
	_textura=ImageTexture.create_from_image(_campo)
	_material=ShaderMaterial.new()
	_material.shader=SHADER
	_material.set_shader_parameter("superficie",ImageTexture.create_from_image(mascara))
	_material.set_shader_parameter("altura",_textura)
	imagem.material=_material
	_emissor(Vector2(31.5,23.5),Vector2(24.75,53.5))
	_emissor(Vector2(63.75,23.5),Vector2(70.75,53.75))
	_emissor(Vector2(47.5,29.5),Vector2(47.5,64.5))
	for lado in [-1,1]:
		var duracao: float=(26.0+sqrt(676.0+2.0*GRAVIDADE*8.5))/GRAVIDADE
		emissores.append({"origem":Vector2(47.5,9),"velocidade":Vector2(lado*8.5,-26),"g":GRAVIDADE,"duracao":duracao,"alvo_y":17.5})
	_preparar_trajetos()
	for i in 29:
		var a := float(i) * TAU / 28.0
		_circulo.append(Vector2(cos(a), sin(a) * .38))
	# O estado inicial já contém ondas nas bacias; os impactos as mantêm.
	_impacto(Vector2(42,17),.30)
	_impacto(Vector2(27,54),.25)
	_impacto(Vector2(67,54),.25)
	for i in 35: _onda()
	_atualizar_textura()
	_aviso=VisibleOnScreenNotifier2D.new()
	_aviso.rect=Rect2(imagem.offset,imagem.texture.get_size()).grow(8.0)
	imagem.add_child(_aviso)

func _emissor(origem: Vector2,alvo: Vector2) -> void:
	var duracao:=sqrt(2.0*(alvo.y-origem.y)/GRAVIDADE)
	emissores.append({"origem":origem,"velocidade":Vector2((alvo.x-origem.x)/duracao,0),"g":GRAVIDADE,"duracao":duracao,"alvo_y":alvo.y})
func _posicao(e: Dictionary,t: float) -> Vector2:
	return e.origem+e.velocidade*t+Vector2(0,.5*e.g*t*t)
func _impacto(p: Vector2,forca: float) -> void:
	var melhor:=-1
	var distancia:=1000.0
	for y in range(maxi(1,int(p.y)-3),mini(N-1,int(p.y)+4)):
		for x in range(maxi(1,int(p.x)-3),mini(N-1,int(p.x)+4)):
			var i:=y*N+x
			var d:=Vector2(x,y).distance_squared_to(p)
			if molhado[i] and d<distancia:
				melhor=i
				distancia=d
	if melhor>=0:
		altura[melhor]=clampf(altura[melhor]+forca,-.9,.9)
		anterior[melhor]=clampf(anterior[melhor]-forca*.5,-.9,.9)
		impactos+=1
		if impactos%2==0:
			ondas.append({"p":Vector2(melhor%N,melhor/N),"t":0.0})
func _onda() -> void:
	for i in ativos:
		var h:=altura[i]
		var vizinhos:=(altura[i-1] if molhado[i-1] else h)+(altura[i+1] if molhado[i+1] else h)+(altura[i-N] if molhado[i-N] else h)+(altura[i+N] if molhado[i+N] else h)
		proxima[i]=clampf((2.0*h-anterior[i]+.19*(vizinhos-4.0*h))*.988,-.95,.95)
	var velha:=anterior
	anterior=altura
	altura=proxima
	proxima=velha
	passos+=1
func _atualizar_textura() -> void:
	for i in ativos:
		var cinza:=int(clampf(.5+altura[i]*.45,0.0,1.0)*255.0+.5)
		var o:=i*4
		_bytes[o]=cinza
		_bytes[o+1]=cinza
		_bytes[o+2]=cinza
	_campo.set_data(N,N,false,Image.FORMAT_RGBA8,_bytes)
	_textura.update(_campo)
func _process(delta: float) -> void:
	if not is_visible_in_tree() or not _aviso.is_on_screen(): return
	var dt:=minf(delta,.10)
	tempo+=dt
	for i in range(ondas.size()-1,-1,-1):
		ondas[i].t+=dt
		if ondas[i].t>.55: ondas.remove_at(i)
	_emissao+=dt
	if _emissao>=.085:
		_emissao=fmod(_emissao,.085)
		for e in emissores:
			gotas.append({"emissor":e,"t":0.0,"p":e.origem,"respingo":false})
	for i in range(gotas.size()-1,-1,-1):
		var gota: Dictionary=gotas[i]
		gota.t+=dt
		if gota.respingo:
			gota.p+=gota.v*dt+Vector2(0,45.0*dt*dt)
			gota.v.y+=90.0*dt
			if gota.t>.28: gotas.remove_at(i)
		else:
			var e: Dictionary=gota.emissor
			gota.p=_posicao(e,gota.t)
			if gota.t>=float(e.duracao):
				var ponto:=_posicao(e,e.duracao)
				var velocidade: float=absf(e.velocidade.y+e.g*e.duracao)
				_impacto(ponto,clampf(velocidade*.0018,.06,.25)*_aleatorio.randf_range(.9,1.1))
				gotas.remove_at(i)
				for lado in [-1,1]:
					gotas.append({"respingo":true,"t":0.0,"p":ponto,"v":Vector2(lado*_aleatorio.randf_range(3,8),-velocidade*_aleatorio.randf_range(.08,.12))})
	_acumulado+=dt
	var atualizou:=false
	while _acumulado>=PASSO:
		_onda()
		_acumulado-=PASSO
		atualizou=true
	if atualizou: _atualizar_textura()
	queue_redraw()
func _preparar_trajetos() -> void:
	for e in emissores:
		var pontos := PackedVector2Array()
		var larguras := PackedFloat32Array()
		for i in 17:
			var a := float(i) / 16.0
			pontos.append(_posicao(e, a * float(e.duracao)))
			var velocidade: float = absf(e.velocidade.y + e.g * a * e.duracao)
			larguras.append(clampf(1.6 / sqrt(1.0 + velocidade * .011), .75, 1.6))
		_trajetos.append({"pontos": pontos, "larguras": larguras})

func _draw() -> void:
	lotes_desenho = 0
	var pontos_jato: Array[PackedVector2Array] = []
	var pontos_brilho: Array[PackedVector2Array] = []
	var cores_brilho: Array[PackedColorArray] = []
	for _i in LARGURAS_JATO.size():
		pontos_jato.append(PackedVector2Array())
		pontos_brilho.append(PackedVector2Array())
		cores_brilho.append(PackedColorArray())
	for trajeto in _trajetos:
		for i in 16:
			var a := float(i) / 16.0
			var b := float(i + 1) / 16.0
			var p0: Vector2 = trajeto.pontos[i]
			var p1: Vector2 = trajeto.pontos[i + 1]
			var largura: float = trajeto.larguras[i] * (1.0 + .10 * sin(a * 24.0 - tempo * 19.0))
			var grupo := clampi(roundi((largura - .7) / .2), 0, LARGURAS_JATO.size() - 1)
			p0.x += .08 * sin(a * 39.0 - tempo * 21.0)
			p1.x += .08 * sin(b * 39.0 - tempo * 21.0)
			var reflexo := .5 + .5 * sin(a * 32.0 - tempo * 22.0)
			pontos_jato[grupo].append(p0)
			pontos_jato[grupo].append(p1)
			pontos_brilho[grupo].append(p0 + Vector2(-.16, 0))
			pontos_brilho[grupo].append(p1 + Vector2(-.16, 0))
			cores_brilho[grupo].append(Color(.87, .97, 1.0, .40 + reflexo * .45))
	for grupo in LARGURAS_JATO.size():
		if pontos_jato[grupo].is_empty(): continue
		draw_multiline(pontos_jato[grupo], Color(.37, .72, .91, .55), LARGURAS_JATO[grupo], true)
		draw_multiline_colors(pontos_brilho[grupo], cores_brilho[grupo], LARGURAS_JATO[grupo] * .40, true)
		lotes_desenho += 2
	var pontos_ondas := PackedVector2Array()
	var cores_ondas := PackedColorArray()
	for onda in ondas:
		var t: float = onda.t / .55
		var raio := .35 + t * 3.0
		var cor := Color(.82, .96, 1.0, (1.0 - t) * .55)
		for i in 28:
			var p0: Vector2 = onda.p + _circulo[i] * raio
			var p1: Vector2 = onda.p + _circulo[i + 1] * raio
			if _na_agua(p0) and _na_agua(p1):
				pontos_ondas.append(p0)
				pontos_ondas.append(p1)
				cores_ondas.append(cor)
	if not pontos_ondas.is_empty():
		draw_multiline_colors(pontos_ondas, cores_ondas, .16, true)
		lotes_desenho += 1
	var pontos_gotas := PackedVector2Array()
	var cores_gotas := PackedColorArray()
	var pontos_respingos := PackedVector2Array()
	var cores_respingos := PackedColorArray()
	for gota in gotas:
		var opacidade: float = 1.0 - float(gota.t) / .28 if gota.respingo else .9
		var cor := Color(.78, .95, 1, opacidade)
		# Segmentos curtos e arredondados mantêm o tamanho subpixel das gotas.
		if gota.respingo:
			pontos_respingos.append(gota.p - Vector2(0, .02))
			pontos_respingos.append(gota.p + Vector2(0, .02))
			cores_respingos.append(cor)
		else:
			pontos_gotas.append(gota.p - Vector2(0, .02))
			pontos_gotas.append(gota.p + Vector2(0, .02))
			cores_gotas.append(cor)
	if not pontos_gotas.is_empty():
		draw_multiline_colors(pontos_gotas, cores_gotas, .40, true)
		lotes_desenho += 1
	if not pontos_respingos.is_empty():
		draw_multiline_colors(pontos_respingos, cores_respingos, .34, true)
		lotes_desenho += 1
func _na_agua(p: Vector2) -> bool:
	var x:=int(p.x)
	var y:=int(p.y)
	return x>=0 and x<N and y>=0 and y<N and molhado[y*N+x]>0
