extends SceneTree
var falhas:=0
var pasta:="res://capturas-manequim-infantil/"
func _initialize() -> void:rodar.call_deferred()
func verificar(nome: String,ok: bool) -> void:
	print("OK " if ok else "FALHA ",nome)
	if not ok:falhas+=1
func quadros(n:=4) -> void:
	for i in n:await process_frame
func foto(visual: Node,nome: String) -> Rect2i:
	await RenderingServer.frame_post_draw
	var im:Image=visual.heroi._vp.get_texture().get_image()
	var r:=im.get_used_rect()
	verificar("sem cortes "+nome,r.has_area() and r.position.x>0 and r.position.y>0 and r.end.x<im.get_width() and r.end.y<im.get_height())
	im.save_png(pasta+nome+".png")
	return r
func rodar() -> void:
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes") or DisplayServer.get_name()=="headless":quit(1);return
	root.get_node("Ranking").conexao_habilitada=false
	DirAccess.make_dir_recursive_absolute(pasta)
	var ficha=load("res://codigo/dados/gerador_npcs.gd").gerar(42,"agricultor")
	ficha.aparencia.roupas_3d={"camisa":"camisa_bosque","calca":"calca_sarja","calcado":"sapatos_viagem","cabelo":"cabelo_curto"}
	ficha.aparencia.cor=[.32,.20,.14,1.0]
	ficha.aparencia.cor_pele=[.957,.776,.643]
	var adulto=load("res://codigo/jogador/representacao_heroi_3d.gd").new()
	var crianca=load("res://codigo/npcs/manequim_infantil_3d.gd").new()
	for visual in [adulto,crianca]:
		visual.aparencia=ficha.aparencia.duplicate(true)
		visual.position=Vector2(160,240)
		root.add_child(visual)
	await quadros(10)
	var corpo:MeshInstance3D=crianca.heroi._modelo.find_child("CorpoBase",true,false)
	for p in crianca.heroi._pecas:verificar("roupa/cabelo separados",p!=corpo and p.mesh!=corpo.mesh and p.skin==corpo.skin and p.skeleton==corpo.skeleton)
	for d in 4:
		for visual in [adulto,crianca]:visual.pose(false,d,0)
		await quadros()
		var a:=await foto(adulto,"adulto_%d" % d)
		var c:=await foto(crianca,"crianca_%d" % d)
		verificar("altura infantil própria %d" % d,c.size.y<a.size.y*.88 and c.size.y>a.size.y*.55)
		verificar("mesma linha de chão %d" % d,absf(c.end.y-a.end.y)<=3)
		var duracao:float=crianca.duracao_caminhada()
		for q in 8:
			crianca.pose_caminhada(true,d,duracao*q/8.0)
			await quadros(2)
			await foto(crianca,"andar_%d_%02d" % [d,q])
	var cabeca_c:Vector3=crianca.heroi._esqueleto.get_bone_pose_scale(crianca.heroi._esqueleto.find_bone("DEF-head"))
	var cabeca_a:Vector3=adulto.heroi._esqueleto.get_bone_pose_scale(adulto.heroi._esqueleto.find_bone("DEF-head"))
	verificar("cabeça cresce em relação ao corpo",cabeca_c.x>cabeca_a.x and cabeca_c.y>cabeca_a.y)
	verificar("adulto preserva proporção original",cabeca_a.is_equal_approx(Vector3(2.38,1.75,2.3)))
	var corpo_adulto:MeshInstance3D=adulto.heroi._modelo.find_child("CorpoBase",true,false)
	verificar("nuca infantil preservada sob cabelo separado",crianca.heroi._modelo.find_child("CorpoBase",true,false).material_override.get_shader_parameter("preservar_nuca")==true)
	verificar("recorte adulto preservado",corpo_adulto.material_override.get_shader_parameter("preservar_nuca")==false)
	verificar("barra da calça adulta preservada",is_equal_approx(corpo_adulto.material_override.get_shader_parameter("altura_barra_calca"),.24))
	crianca.queue_free();adulto.queue_free();await quadros()
	print("FALHAS: ",falhas);quit(falhas)
