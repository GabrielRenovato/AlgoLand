extends SceneTree
const RAIZ = "res://"
const ORIGEM = RAIZ+"arte/fontes/personagens/raven_plantio/geracao_perfil.png"
const SAIDA = RAIZ+"assets/personagens/raven_fantasy/estudo_plantio/"
func _initialize():
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"):
		quit(1)
		return
	var fonte=Image.load_from_file(ORIGEM)
	assert(fonte.get_size()==Vector2i(1536,1024))
	var atlas=Image.create(480,80,false,Image.FORMAT_RGBA8)
	for q in 6:
		var pose=fonte.get_region(Rect2i(q%3*512,q/3*512,512,512))
		pose.resize(64,64,Image.INTERPOLATE_NEAREST)
		atlas.blit_rect(pose,Rect2i(0,0,64,64),Vector2i(q*80+8,8))
	DirAccess.make_dir_recursive_absolute(SAIDA)
	atlas.save_png(SAIDA+"plantio_perfil.png")
	var contato=Image.create(960,160,false,Image.FORMAT_RGBA8)
	contato.fill(Color("607044"))
	var maior=atlas.duplicate()
	maior.resize(960,160,Image.INTERPOLATE_NEAREST)
	contato.blend_rect(maior,Rect2i(0,0,960,160),Vector2i.ZERO)
	contato.save_png(RAIZ+"arte/previas/personagens/raven_plantio/quadros_perfil.png")
	print("OK seis quadros de perfil, células80, extração uniforme da grade8x")
	quit()
