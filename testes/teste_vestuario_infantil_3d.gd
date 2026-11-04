extends SceneTree
const GuardaRoupa=preload("res://codigo/npcs/vestuario_infantil_3d.gd")
var falhas:=0
var pasta:="res://capturas-vestuario-infantil/"
func _initialize() -> void:rodar.call_deferred()
func verificar(nome: String,ok: bool) -> void:
	print("OK " if ok else "FALHA ",nome)
	if not ok:falhas+=1
func quadros(n:=3) -> void:
	for i in n:await process_frame
func foto(h: Node,nome: String) -> void:
	await RenderingServer.frame_post_draw
	var im:Image=h._vp.get_texture().get_image()
	var r:=im.get_used_rect()
	verificar("quadro sem cortes "+nome,r.has_area() and r.position.x>0 and r.position.y>0 and r.end.x<im.get_width() and r.end.y<im.get_height())
	if nome.ends_with("_2") or nome.contains("_2_"):
		var conectado:=true
		for y in range(r.position.y,r.end.y):
			var pele_ou_roupa:=false
			for x in range(r.position.x,r.end.x):
				if im.get_pixel(x,y).a>.5:pele_ou_roupa=true;break
			if not pele_ou_roupa:conectado=false
		verificar("nuca e pescoço sem linha transparente "+nome,conectado)
	im.save_png(pasta+nome+".png")
	if nome.ends_with("_0") and not nome.begins_with("andar_"):
		var pele:=0
		for y in range(r.position.y+int(r.size.y*.72),r.end.y):
			for x in range(r.position.x,r.end.x):
				var cor:=im.get_pixel(x,y)
				if cor.a>.5 and cor.g>.58 and cor.r>cor.g*1.14 and cor.g>cor.b*1.13:pele+=1
		verificar("pernas aparecem abaixo da roupa curta "+nome,pele>1)
func rodar() -> void:
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes") or DisplayServer.get_name()=="headless":quit(1);return
	root.get_node("Ranking").conexao_habilitada=false
	DirAccess.make_dir_recursive_absolute(pasta)
	var ficha=load("res://codigo/dados/gerador_npcs.gd").gerar(42,"agricultor")
	ficha.aparencia.cor=[.32,.20,.14,1.]
	ficha.aparencia.cor_pele=[.957,.776,.643]
	var crianca=load("res://codigo/npcs/manequim_infantil_3d.gd").new()
	crianca.aparencia=ficha.aparencia
	crianca.position=Vector2(160,220)
	root.add_child(crianca)
	await quadros(8)
	var h=crianca.heroi
	var corpo:MeshInstance3D=h._modelo.find_child("CorpoBase",true,false)
	var geometria:=hash(corpo.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX])
	var cabelos:=GuardaRoupa.CABELOS.keys()
	for traje in GuardaRoupa.TRAJES:
		for penteado in cabelos:
			crianca.vestir_infantil(traje,penteado)
			verificar("estilo preserva o corpo "+traje+"/"+penteado,hash(corpo.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX])==geometria)
			for i in [0,1,3]:
				var p:MeshInstance3D=h._pecas[i]
				verificar("peça separada %s/%s/%d" % [traje,penteado,i],p!=corpo and p.mesh!=corpo.mesh and p.skin==corpo.skin and p.skeleton==corpo.skeleton)
				var a:=p.mesh.surface_get_arrays(0)
				var pesos:PackedFloat32Array=a[Mesh.ARRAY_WEIGHTS]
				var ok:=true
				for n in a[Mesh.ARRAY_VERTEX].size():
					var soma:=0.0
					for k in 4:soma+=pesos[n*4+k]
					ok=ok and absf(soma-1.0)<.001 and a[Mesh.ARRAY_VERTEX][n].is_finite()
				verificar("pesos íntegros %s/%s/%d" % [traje,penteado,i],ok)
			for d in 4:
				crianca.pose(false,d,0)
				await quadros()
				verificar("cabelo volumétrico mantém rosto e olhos",h._cabeca_referencia.visible and h._cabeca_referencia.material.get_shader_parameter("sem_cabelo") and h._pecas[3].visible)
				await foto(h,"%s_%s_%d" % [traje,penteado,d])
			if cabelos.find(penteado)!=GuardaRoupa.TRAJES.keys().find(traje):continue
			var duracao:float=crianca.duracao_caminhada()
			for d in 4:
				for q in 8:
					crianca.pose_caminhada(true,d,duracao*q/8.)
					await quadros(2)
					await foto(h,"andar_%s_%d_%02d" % [traje,d,q])
		for i in 4:
			h.pecas_visiveis=15 & ~(1<<i)
			verificar("retira só a peça %s/%d" % [traje,i],not h._pecas[i].visible)
			h.pecas_visiveis=15
			verificar("restaura peça %s/%d" % [traje,i],h._pecas[i].visible)
	crianca.mostrar(ficha.aparencia,ficha.aparencia.roupas_3d,0)
	verificar("trocar aparência conserva vestuário infantil",h._pecas[0].material_override.shader.resource_path.ends_with("vestuario_infantil.gdshader") and h._pecas[3].visible)
	crianca.queue_free();await quadros()
	print("FALHAS: ",falhas);quit(falhas)
