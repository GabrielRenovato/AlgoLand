extends SceneTree
var falhas:=0
var pasta:="res://capturas-casas-familias/"
func _initialize():rodar.call_deferred()
func conferir(nome: String,ok: bool):
	print("OK " if ok else "FALHA ",nome)
	if not ok:falhas+=1
func ponto_bloqueado(cena: Node2D,ponto: Vector2) -> bool:
	var consulta:=PhysicsPointQueryParameters2D.new()
	consulta.position=ponto
	consulta.collision_mask=64
	return not cena.get_world_2d().direct_space_state.intersect_point(consulta).is_empty()
func quadros(n:=4):
	for i in n:await process_frame
func rodar():
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes") or DisplayServer.get_name()=="headless":quit(1);return
	root.get_node("Ranking").conexao_habilitada=false
	DirAccess.make_dir_recursive_absolute(pasta)
	root.mode=Window.MODE_WINDOWED
	root.content_scale_size=Vector2i(800,656)
	root.size=Vector2i(1200,984)
	change_scene_to_file("res://cenas/cidade/familias/previa_casas.tscn")
	await quadros(10)
	var previa=current_scene
	var paredes_vistas:Dictionary={}
	var pisos_vistos:Dictionary={}
	var plantas_vistas:Array[String]=[]
	for id in ["mara","cora","rosa"]:
		previa.abrir(id)
		await quadros(6)
		var casa=previa.casa
		var g:Dictionary=casa.planta.geometria
		conferir("planta identifica família "+id,casa.planta.familia.size()==2 and casa.planta.familia[0]==id)
		var publicos:Array[Rect2]=[]
		var quartos:Array[Rect2]=[]
		var formato:Array=[]
		for area in g.areas:
			var r:Array=area.retangulo
			var ret:=Rect2(r[0],r[1],r[2],r[3])
			formato.append(area.retangulo)
			if area.nome in casa.planta.areas_publicas:publicos.append(ret)
			if area.nome in casa.planta.quartos:quartos.append(ret)
		var assinatura:=JSON.stringify(formato)
		conferir("planta própria, sem repetir a distribuição",not plantas_vistas.has(assinatura))
		plantas_vistas.append(assinatura)
		var chegada:=Vector2(g.chegada[0],g.chegada[1])
		conferir("entrada chega diretamente ao comércio",publicos.any(func(r):return r.has_point(chegada)))
		for quarto in quartos:
			for publico in publicos:conferir("quartos ficam atrás do comércio",quarto.end.y<=publico.position.y)
		for item in casa.planta.itens:
			var pos:=Vector2(item.x,item.y)
			if str(item.get("id","")).begins_with("Cama"):
				conferir("cama pertence a um quarto reservado",quartos.any(func(r):return r.has_point(pos)))
			if item.chave=="interior/enfermaria/lavatorio":
				conferir("pia fora da área de clientes",not publicos.any(func(r):return r.has_point(pos)))
				var junto_da_bancada:=false
				for bancada in casa.planta.itens:
					if str(bancada.get("id","")).begins_with("Bancada") and absf(bancada.y-item.y)<=8 and absf(bancada.x-item.x)<=56:junto_da_bancada=true
				conferir("pia integrada à bancada, sem ficar isolada",junto_da_bancada)
		var grade:=AStarGrid2D.new()
		grade.region=Rect2i(0,0,int(g.recorte[2]/8),int(g.recorte[3]/8))
		grade.cell_size=Vector2(8,8)
		grade.offset=Vector2(4,4)
		grade.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_NEVER
		grade.update()
		for y in grade.region.size.y:
			for x in grade.region.size.x:grade.set_point_solid(Vector2i(x,y),not casa.ponto_livre(grade.get_point_position(Vector2i(x,y))))
		var inicio:=Vector2i(Vector2(g.chegada[0],g.chegada[1])/8)
		conferir("entrada desobstruída "+id,not grade.is_point_solid(inicio))
		for area in g.areas:
			if area.nome in ["Passagem","Corredor","Saída"]:continue
			var r:Array=area.retangulo
			var ret:=Rect2(r[0],r[1],r[2],r[3])
			var chegou:=false
			for y in range(int(r[1]/8)+2,int((r[1]+r[3])/8)-2):
				for x in range(int(r[0]/8)+2,int((r[0]+r[2])/8)-2):
					var alvo:=Vector2i(x,y)
					if not grade.is_point_solid(alvo) and not grade.get_id_path(inicio,alvo).is_empty():chegou=true;break
				if chegou:break
			conferir("acesso com raio do personagem "+id+"/"+area.nome,chegou)
		for movel in casa.moveis:
			conferir("móvel tem quatro estações "+str(movel.item.chave),movel.ficha.texturas.size()==4)
			if movel.item.get("no_chao",false):
				conferir("tapete não cobre os móveis e personagens",movel.sprite.z_index<load("res://codigo/globais/profundidade.gd").z_de(movel.item.y))
			else:
				conferir("colisão acompanha base "+str(movel.item.chave),movel.sprite.z_index==load("res://codigo/globais/profundidade.gd").z_de(movel.item.y))
		for recurso in casa.recursos_usados:conferir("recurso próprio",recurso.begins_with("res://assets/cenario/cidade/interiores_detalhados/") and not recurso.to_lower().contains("mana_seed") and not recurso.to_lower().contains("tiny"))
		for estacao in 4:
			casa.definir_estacao(estacao)
			previa.exterior.definir_estacao(estacao)
			await quadros(4)
			conferir("troca material do piso "+id+str(estacao),casa.get_node("Sala")._estacao==estacao)
			for uso in ["medio","claro","escuro"]:
				var piso:Texture2D=casa.get_node("Sala")._pisos[uso]
				var caminho:String="/arquitetura/"+id+"/"+["primavera","verao","outono","inverno"][estacao]+"/piso_"+uso+".png"
				conferir("piso próprio por família, uso e estação "+id+"/"+uso,piso.resource_path.ends_with(caminho))
				conferir("piso conserva período lógico de 128 pixels",piso.get_size()==Vector2(512,512))
				var hash_piso:=piso.get_image().get_data().hex_encode().sha256_text()
				conferir("pisos não reutilizam a mesma textura",not pisos_vistos.get(estacao,[]).has(hash_piso))
				if not pisos_vistos.has(estacao):pisos_vistos[estacao]=[]
				pisos_vistos[estacao].append(hash_piso)
			var parede:Texture2D=casa.get_node("Sala")._materiais.parede
			var hash_parede:=parede.get_image().get_data().hex_encode().sha256_text()
			conferir("parede própria da família "+id,parede.resource_path.contains("/arquitetura/"+id+"/"))
			conferir("paredes realmente diferentes entre famílias",not paredes_vistas.get(estacao,[]).has(hash_parede))
			if not paredes_vistas.has(estacao):paredes_vistas[estacao]=[]
			paredes_vistas[estacao].append(hash_parede)
			for movel in casa.moveis:
				var t:Texture2D=movel.sprite.texture
				if t is AtlasTexture:t=t.atlas
				conferir("móvel usa estação atual",t.resource_path==movel.ficha.texturas[estacao])
			for movel in casa.moveis:
				if not movel.ficha.has("variantes"):continue
				var variante:Dictionary=movel.ficha.variantes[estacao]
				conferir("móvel exclusivo pertence à família",movel.ficha.casa==id)
				var b:Array=variante.usado
				var largura:float=(b[2]-b[0])*movel.sprite.scale.x
				var base:Vector2=(Vector2(variante.pivo[0],variante.pivo[1])+movel.sprite.offset)*movel.sprite.scale
				conferir("pivô e tamanho estáveis por estação",base.is_equal_approx(Vector2.ZERO) and is_equal_approx(largura,float(movel.ficha.canvas_logico[0])))
				# Close real do mesmo Sprite2D, sem remontar/editar o bitmap.
				previa.camera.position=movel.sprite.position-Vector2(0,32)
				previa.camera.zoom=Vector2.ONE*3
				await quadros(3)
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(pasta+id+"_movel_%d.png" % estacao)
				previa._enquadrar()
			await quadros(3)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(pasta+id+"_%d.png" % estacao)
			previa.por_fora=true;previa._atualizar_vista()
			await quadros(3)
			conferir("fachada sazonal da família "+id,previa.exterior.sprite.texture.resource_path==previa.exterior.ficha.texturas[estacao])
			conferir("fachada mantém pivô e escala",previa.exterior.sprite.offset==-Vector2(previa.exterior.ficha.pivo[0],previa.exterior.ficha.pivo[1]) and is_equal_approx(previa.exterior.sprite.scale.x,previa.exterior.largura/float(previa.exterior.ficha.largura_fonte)))
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(pasta+id+"_exterior_%d.png" % estacao)
			previa.por_fora=false;previa._atualizar_vista()
	# Título e instruções dentro da tela, inclusive no celular e na divisão.
	for tamanho in [Vector2i(576,324),Vector2i(288,512),Vector2i(320,324)]:
		root.content_scale_size=tamanho;root.size=tamanho*2
		await quadros(5)
		conferir("texto da bancada cabe "+str(tamanho),Rect2(Vector2.ZERO,Vector2(tamanho)).encloses(previa.titulo.get_global_rect()))
		var topo_casa:Vector2=previa.casa.get_canvas_transform()*Vector2(0,24)
		conferir("texto não sobrepõe o interior "+str(tamanho),topo_casa.y>=previa.titulo.get_global_rect().end.y+8)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(pasta+"previa_%dx%d.png" % [tamanho.x,tamanho.y])
		previa.por_fora=true;previa._atualizar_vista()
		await quadros(4)
		conferir("texto exterior cabe "+str(tamanho),Rect2(Vector2.ZERO,Vector2(tamanho)).encloses(previa.titulo.get_global_rect()))
		var topo_exterior:Vector2=previa.exterior.get_canvas_transform()*previa.exterior.limites_visuais().position
		conferir("texto não sobrepõe a fachada "+str(tamanho),topo_exterior.y>=previa.titulo.get_global_rect().end.y+8)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(pasta+"exterior_%dx%d.png" % [tamanho.x,tamanho.y])
		previa.por_fora=false;previa._atualizar_vista()
	# Confere as mesmas fachadas no terreno real da vila, em save isolado.
	root.content_scale_size=Vector2i(1536,1024);root.size=root.content_scale_size
	change_scene_to_file("res://cenas/campanha/terreno_vila.tscn")
	await quadros(12)
	var vila=current_scene
	var camera:=Camera2D.new()
	vila.add_child(camera)
	conferir("vila usa as três fachadas familiares",vila._fachadas_familias.size()==3)
	conferir("mureta frontal da árvore central bloqueia o jogador",ponto_bloqueado(vila,Vector2(-7,-45)))
	conferir("lateral externa da praça continua livre",not ponto_bloqueado(vila,Vector2(142,-65)))
	var forma_arvore:CollisionPolygon2D=vila.find_child("ColisaoPoligono",true,false).get_node("Forma")
	var contorno:=Line2D.new()
	contorno.name="ConferenciaColisaoArvore"
	contorno.points=forma_arvore.polygon.duplicate()
	contorno.add_point(contorno.points[0])
	contorno.width=2.0
	contorno.default_color=Color(1.0,0.15,0.1,0.95)
	contorno.z_as_relative=false
	contorno.z_index=4096
	vila.add_child(contorno)
	camera.position=Vector2(-7,-65)
	camera.zoom=Vector2.ONE*2.0
	await quadros(3)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(pasta+"arvore_praca_colisao.png")
	contorno.queue_free()
	camera.position=Vector2.ZERO
	camera.zoom=Vector2.ONE
	var obstaculos:Array=vila.obstaculos.duplicate()
	for estacao in 4:
		vila.definir_estacao(estacao)
		await quadros(5)
		for fachada in vila._fachadas_familias:
			conferir("fachada acompanha estação da vila",fachada.estacao_atual==estacao)
		conferir("troca visual preserva colisões",vila.obstaculos==obstaculos)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(pasta+"vila_%d.png" % estacao)
	print("FALHAS: ",falhas)
	quit(falhas)
