extends SceneTree
const RAIZ="res://"
const PALETA=[Color8(46,28,44),Color8(172,88,70),Color8(216,115,94),Color8(250,148,127),Color8(255,186,172),Color.WHITE,Color8(35,39,47),Color8(53,58,69),Color8(76,83,96)]
func _initialize():
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"):
		quit(1)
		return
	var fonte=Image.load_from_file(RAIZ+"arte/fontes/personagens/raven_colheita/geracao_base_short.png")
	var contrato=JSON.parse_string(FileAccess.get_file_as_string(RAIZ+"arte/fontes/personagens/raven_colheita/contrato_base.json"))
	var transformacao=contrato.normalizacao
	assert(fonte.get_size()==Vector2i(transformacao.tela[0],transformacao.tela[1]),"Rever a transformação comum se a geração mudar")
	var escala: float=transformacao.pixel_fonte
	var chaos: Array=transformacao.chao_fonte
	var atlas=Image.create(320,320,false,Image.FORMAT_RGBA8)
	for d in 4:
		for q in 4:
			var coluna=mini(q,2)
			for y in 80:
				for x in 80:
					var sx=int((coluna+0.5)*fonte.get_width()/4.0+(x-40)*escala)
					var sy=int(d*fonte.get_height()/4.0+float(chaos[d])+(y-47)*escala)
					if sx<int(coluna*fonte.get_width()/4.0) or sx>=int((coluna+1)*fonte.get_width()/4.0) or sy<int(d*fonte.get_height()/4.0) or sy>=int((d+1)*fonte.get_height()/4.0):continue
					var cor=fonte.get_pixel(sx,sy)
					if cor.a<0.5:continue
					var melhor=PALETA[0]
					var distancia=INF
					for p in PALETA:
						var v=Vector3(cor.r-p.r,cor.g-p.g,cor.b-p.b).length_squared()
						if v<distancia:melhor=p;distancia=v
					atlas.set_pixel(q*80+x,d*80+y,melhor)
	DirAccess.make_dir_recursive_absolute(RAIZ+"assets/personagens/raven_fantasy/estudo_colheita/base")
	atlas.save_png(RAIZ+"assets/personagens/raven_fantasy/estudo_colheita/base/corpo_0.png")
	var rampas=[
		[Color8(46,28,44),Color8(103,47,47),Color8(126,68,61),Color8(159,97,82),Color8(185,129,105),Color.WHITE,Color8(35,39,47),Color8(53,58,69),Color8(76,83,96)],
		[Color8(46,28,44),Color8(175,115,102),Color8(227,145,128),Color8(250,180,166),Color8(253,210,202),Color.WHITE,Color8(35,39,47),Color8(53,58,69),Color8(76,83,96)]]
	for i in 2:
		var variante=atlas.duplicate()
		for y in 320:
			for x in 320:
				var cor=atlas.get_pixel(x,y)
				if cor.a==0:continue
				var indice=PALETA.find(cor)
				assert(indice>=0)
				variante.set_pixel(x,y,rampas[i][indice])
		variante.save_png(RAIZ+"assets/personagens/raven_fantasy/estudo_colheita/base/corpo_%d.png"%(i+1))
	var efeito_fonte=Image.load_from_file(RAIZ+"arte/pacotes/Jogador/Base/20.01a - Character Base 2.5c/char_a_p2/6tla/char_a_p2_6tla_farm_v01.png")
	var efeitos=Image.create(320,320,false,Image.FORMAT_RGBA8)
	var referencia=Image.create(320,320,false,Image.FORMAT_RGBA8)
	var mana=Image.load_from_file(RAIZ+"arte/fontes/personagens/raven_colheita/mana_seed_colheita_original.png")
	for d in 4:
		for q in 4:
			efeitos.blit_rect(efeito_fonte,Rect2i((q+4)*64,([0,2,1,3][d]+4)*64,64,64),Vector2i(q*80+8,d*80-2))
			var pose=mana.get_region(Rect2i(q*384,d*384,384,384))
			pose.resize(64,64,Image.INTERPOLATE_NEAREST)
			referencia.blit_rect(pose,Rect2i(0,0,64,64),Vector2i(q*80+8,d*80-2))
	efeitos.save_png(RAIZ+"assets/personagens/raven_fantasy/estudo_colheita/base/efeitos.png")
	referencia.save_png(RAIZ+"arte/fontes/personagens/raven_colheita/mana_seed_nativo.png")
	print("OK base modular: três peles, quatro direções, quatro quadros; short neutro e efeitos separados")
	var contato=Image.create(960,960,false,Image.FORMAT_RGBA8)
	contato.fill(Color("515d4c"))
	atlas.resize(960,960,Image.INTERPOLATE_NEAREST)
	contato.blend_rect(atlas,Rect2i(0,0,960,960),Vector2i.ZERO)
	contato.save_png(RAIZ+"arte/previas/personagens/raven_colheita/quadros_base.png")
	quit()
