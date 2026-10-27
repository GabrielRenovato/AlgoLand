extends SceneTree
## Estudo reversível de albedo sobre o rig; capturas com save isolado.
const FONTES := "res://arte/fontes/personagens/base_3d/rosto_cabelo_pixel/"
const ASSETS := "res://assets/personagens/base_3d/rosto_cabelo_pixel/"
const SAIDA := "res://arte/previas/personagens/base_3d/rosto_cabelo_pixel/"
func _initialize(): rodar.call_deferred()

func preparar_texturas():
	# O rosto conserva todos os pixels da imagem de referência. Apenas o
	# cabelo passa pelo preparo de grade/paleta da variante simplificada.
	for tipo in ["rosto","cabelo"]:
		var img := Image.load_from_file(FONTES+tipo+"_original.png")
		if tipo=="rosto":
			img.save_png(ASSETS+tipo+".png")
			continue
		var tamanho := 32
		img.resize(tamanho,tamanho,Image.INTERPOLATE_NEAREST)
		img.convert(Image.FORMAT_RGBA8)
		var paleta: Array[Color] = []
		for hex in ["47302c","654333","835b42"]:
			paleta.append(Color(hex))
		for y in tamanho:
			for x in tamanho:
				var pixel := img.get_pixel(x,y)
				var melhor := 100.0
				var escolhida := paleta[0]
				for cor in paleta:
					var distancia := Vector3(pixel.r-cor.r,pixel.g-cor.g,pixel.b-cor.b).length_squared()
					if distancia<melhor:
						melhor=distancia
						escolhida=cor
				img.set_pixel(x,y,escolhida)
		img.save_png(ASSETS+tipo+".png")
		img.resize(tamanho*8,tamanho*8,Image.INTERPOLATE_NEAREST)
		img.save_png(FONTES+tipo+"_grade.png")
	print("TEXTURAS: rosto na resolução original, sem quantização; cabelo 32x32, três cores")

func quadro(h: Node) -> Image:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	return h._vp.get_texture().get_image()

func conferir_malha(h: Node):
	var alterados := 0
	var corpo_preservado := 0
	for s in h._molde_rosto.get_surface_count():
		var antes: Array=h._molde_rosto.surface_get_arrays(s)
		var depois: Array=h._rosto_arredondado.surface_get_arrays(s)
		for atributo in [Mesh.ARRAY_BONES,Mesh.ARRAY_WEIGHTS,Mesh.ARRAY_TEX_UV,Mesh.ARRAY_TEX_UV2,Mesh.ARRAY_COLOR,Mesh.ARRAY_INDEX]:
			assert(antes[atributo]==depois[atributo],"Rig, UVs e topologia preservados")
		for i in antes[Mesh.ARRAY_VERTEX].size():
			var cor: Color=antes[Mesh.ARRAY_COLOR][i]
			if cor.r<0.25 or cor.r>0.75:
				assert(antes[Mesh.ARRAY_VERTEX][i]==depois[Mesh.ARRAY_VERTEX][i],"Corpo preservado")
				corpo_preservado+=1
			elif antes[Mesh.ARRAY_VERTEX][i]!=depois[Mesh.ARRAY_VERTEX][i]:
				alterados+=1
				assert(is_equal_approx(depois[Mesh.ARRAY_NORMAL][i].length(),1.0),"Normal da face válida")
	assert(alterados>0)
	print("MALHA: ",alterados," vértices da cabeça ajustados; ",corpo_preservado," do corpo preservados; rig, UVs e índices preservados")

func rodar():
	assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
	if "--preparar" in OS.get_cmdline_user_args():
		preparar_texturas()
		quit()
		return
	assert(DisplayServer.get_name()!="headless")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAIDA))
	root.get_node("Ranking").conexao_habilitada=false
	root.get_node("Introducao").pular_prologo()
	root.get_node("Transicao").hora_salva=12.0
	change_scene_to_file("res://cenas/fazenda.tscn")
	for i in 40: await process_frame
	root.get_node("Transicao").limpar()
	var j=current_scene.get_node("Jogador")
	j.aparencia_raven={"pele":0,"cor":[1.0,1.0,1.0,1.0],"olhos":0}
	j.set_physics_process(false)
	j.no_fazenda.set_process(false)
	var h=j.get_node("HeroiBase3D")
	h.acabamento_pixel_art=false
	h.pecas_visiveis=15
	h.definir_roupas_3d({"cabelo":"cabelo_curto"})
	h._aplicar_cores()
	h.set_process(false)
	h._player.play(h._nome_animacao("parado"),0)
	h._player.pause()
	h._player.seek(0,true)
	var recorte := Rect2i(244,160,152,152)
	var contato := Image.create(152*4,152*4,false,Image.FORMAT_RGBA8)
	contato.fill(Color("52624f"))
	for modo in 2:
		h.rosto_cabelo_pixel_art=modo==1
		if modo==1:conferir_malha(h)
		for d in 8:
			h._modelo.rotation.y=d*TAU/8.0
			var img: Image=await quadro(h)
			img.save_png(SAIDA+"%s_%d.png"%["depois" if modo else "antes",d])
			var parte:=img.get_region(recorte)
			contato.blend_rect(parte,Rect2i(Vector2i.ZERO,parte.get_size()),Vector2i((d%4)*152,(modo*2+d/4)*152))
	contato.resize(contato.get_width()*2,contato.get_height()*2,Image.INTERPOLATE_NEAREST)
	contato.save_png(SAIDA+"comparacao.png")
	if "--somente-retrato" in OS.get_cmdline_user_args():
		print("RETRATO: oito direções antes/depois no Godot, save isolado")
		quit()
		return
	# Três tons de pele e tintura; sem gravar aparência do jogador.
	var cores := Image.create(152*4,152*3,false,Image.FORMAT_RGBA8)
	cores.fill(Color("52624f"))
	for pele in 3:
		for coluna in 4:
			j.aparencia_raven={"pele":pele,"cor":[.40,.22,.55,1.0] if coluna==3 else [1.0,1.0,1.0,1.0],"olhos":2}
			h._aplicar_cores()
			h._modelo.rotation.y=[0.0,PI/2,PI,0.0][coluna]
			var img: Image=await quadro(h)
			cores.blend_rect(img.get_region(recorte),Rect2i(0,0,152,152),Vector2i(coluna*152,pele*152))
	cores.resize(1216,912,Image.INTERPOLATE_NEAREST)
	cores.save_png(SAIDA+"tons_e_tintura.png")
	j.aparencia_raven={"pele":0,"cor":[1.0,1.0,1.0,1.0],"olhos":0}
	h._aplicar_cores()
	# Os mesmos tempos viram folha e GIF; amostram animações reais do motor.
	for acao in ["correr","espada"]:
		var nome: String=h._nome_animacao(acao)
		var anim: Animation=h._player.get_animation(nome)
		h._player.play(nome,0)
		h._player.pause()
		for d in [0,1,2,4]:
			h._modelo.rotation.y=d*TAU/8.0
			for q in 12:
				h._player.seek(anim.length*q/12.0,true)
				var img: Image=await quadro(h)
				img.save_png(SAIDA+"%s_%d_%02d.png"%[acao,d,q])
		print("MOVIMENTO ",acao," duracao=",anim.length," quadros=12 direcoes=4")
	# Olhos fechados sobre o rosto pintado e recuperação do material original.
	h._player.play(h._nome_animacao("parado"),0)
	h._player.pause()
	h._player.seek(0,true)
	h._modelo.rotation.y=0
	var material: ShaderMaterial=h._modelo.find_child("CorpoBase",true,false).material_override
	material.set_shader_parameter("olhos_fechados",true)
	var fechado: Image=await quadro(h)
	fechado.save_png(SAIDA+"olhos_fechados.png")
	material.set_shader_parameter("olhos_fechados",false)
	h.rosto_cabelo_pixel_art=false
	var restaurado: Image=await quadro(h)
	restaurado.save_png(SAIDA+"restaurado.png")
	print("ROSTO/CABELO: 8 direções, corrida e ataque, três peles, tintura, olhos fechados e restauração; save isolado")
	quit()
