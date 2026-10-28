extends SceneTree
## Regressões da cabeça: oito vistas, encaixe, olhos fechados e personalização.
const SAIDA := "res://arte/previas/personagens/base_3d/pintura_corpo/"
var h: Node
var falhas:=0
func _initialize():rodar.call_deferred()
func conferir(ok: bool,texto: String):
	if not ok:
		falhas+=1
		push_error(texto)
func esperar(n: int):
	for i in n:await process_frame
func foto(nome: String) -> Image:
	await esperar(3)
	await RenderingServer.frame_post_draw
	var imagem: Image=h._vp.get_texture().get_image()
	imagem.save_png(SAIDA+nome+".png")
	return imagem
func recorte(imagem: Image) -> Image:
	var f:=imagem.get_width()/640.0
	return imagem.get_region(Rect2i(roundi(245*f),roundi(175*f),roundi(150*f),roundi(125*f)))
func azuis(imagem: Image) -> int:
	var total:=0
	for y in imagem.get_height():
		for x in imagem.get_width():
			var cor:=imagem.get_pixel(x,y)
			if cor.a>.95 and cor.b>cor.r*1.15 and cor.b>cor.g*.95 and cor.b>.25:total+=1
	return total
func componentes(imagem: Image) -> Array[int]:
	var w:=imagem.get_width()
	var h_img:=imagem.get_height()
	var visto:=PackedByteArray()
	visto.resize(w*h_img)
	var tamanhos: Array[int]=[]
	for y in h_img:
		for x in w:
			var i:=y*w+x
			if visto[i] or imagem.get_pixel(x,y).a<.5:continue
			var fila: Array[int]=[i]
			visto[i]=1
			var cursor:=0
			while cursor<fila.size():
				var p:=fila[cursor]
				cursor+=1
				var px:=p%w
				var py:=p/w
				for d in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
					var q: Vector2i=Vector2i(px,py)+d
					if q.x<0 or q.y<0 or q.x>=w or q.y>=h_img:continue
					var indice: int=q.y*w+q.x
					if visto[indice] or imagem.get_pixel(q.x,q.y).a<.5:continue
					visto[indice]=1
					fila.append(indice)
			if fila.size()>16:tamanhos.append(fila.size())
	return tamanhos
func rodar():
	assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
	assert(DisplayServer.get_name()!="headless")
	root.get_node("Ranking").conexao_habilitada=false
	root.get_node("Introducao").pular_prologo()
	root.get_node("Transicao").hora_salva=12.0
	change_scene_to_file("res://cenas/fazenda.tscn")
	await esperar(40)
	root.get_node("Transicao").limpar()
	var j=current_scene.get_node("Jogador")
	j.set_physics_process(false)
	j.no_fazenda.set_process(false)
	h=j.get_node("HeroiBase3D")
	h.set_process(false)
	h._costas.hide()
	h._mao.hide()
	h._mao_esquerda.hide()
	var mochila: Array=j.inventario.fotografar_mochila()
	conferir(h._cabeca_referencia.visible,"Cabeça da referência ativa na base")
	conferir(h._sprite.material==null and not h.acabamento_pixel_art,"Sem filtro de pixelização")
	conferir(not h._pecas[3].visible,"Sem cabelo antigo sobreposto")
	var corpo: MeshInstance3D=h._modelo.find_child("CorpoBase",true,false)
	conferir(corpo.mesh.get_surface_count()>0,"Corpo continua com superfície válida após ajuste cosmético")
	conferir(corpo.material_override.get_shader_parameter("substituir_cabeca")==true,"Cabeça antiga recortada")
	for d in 8:
		h._modelo.rotation.y=d*TAU/8.0
		h._player.play("Idle_Loop",0)
		h._player.pause()
		h._player.seek(0.0,true)
		h._cabeca_referencia.orientar(h._modelo.rotation.y)
		var completa:=await foto("cabeca_validada_%d"%d)
		conferir(completa.get_used_rect().size.y>completa.get_height()*.32,"Corpo inteiro visível, direção %d"%d)
		var imagem:=recorte(completa)
		var faixa_cabeca:=imagem.get_region(Rect2i(0,0,imagem.get_width(),roundi(imagem.get_height()*.55)))
		conferir(faixa_cabeca.get_used_rect().size.x>imagem.get_width()*.25,"Cabeça não fica de quina ao trocar direção %d"%d)
		var partes:=componentes(imagem)
		conferir(partes.size()==1,"Cabeça ligada ao pescoço sem fresta, direção %d; componentes %s"%[d,str(partes)])
		if d==0:conferir(azuis(imagem)>20,"Olhos azuis da referência visíveis")
		if d==4:conferir(azuis(imagem)==0,"Sem olhos na nuca")
	corpo.material_override.set_shader_parameter("olhos_fechados",true)
	h._modelo.rotation.y=0
	h._cabeca_referencia.orientar(0)
	conferir(azuis(recorte(await foto("cabeca_dormindo")))==0,"Dormir fecha os dois olhos")
	corpo.material_override.set_shader_parameter("olhos_fechados",false)
	var original: Dictionary=j.aparencia_raven.duplicate(true)
	j.aparencia_raven["pele"]=1
	h._chave_cores=0
	h._aplicar_cores()
	conferir(h._cabeca_referencia.visible,"Outra pele usa a cabeça nova")
	conferir(h._cabeca_referencia.material.get_shader_parameter("tom_pele").is_equal_approx(h.PELES[1]),"Tom de pele aplicado à pintura")
	j.aparencia_raven=original
	h._chave_cores=0
	h._aplicar_cores()
	conferir(h._cabeca_referencia.visible,"Retorno à cabeça canônica")
	# Reproduz somente a aparência dos saves, nunca carrega nem grava a partida real.
	for argumento in OS.get_cmdline_user_args():
		if not argumento.begins_with("--aparencias="):continue
		var casos: Array=JSON.parse_string(FileAccess.get_file_as_string(argumento.trim_prefix("--aparencias=")))
		for i in casos.size():
			j.aparencia_raven=casos[i].aparencia_raven.duplicate(true)
			h.definir_roupas_3d(casos[i].roupas_3d)
			h._chave_cores=0
			h._aplicar_cores()
			conferir(h._cabeca_referencia.visible,"Save %d usa o rosto novo"%i)
			conferir(not h._pecas[3].visible,"Save %d sem cabelo antigo sobreposto"%i)
			for d in [0,2,6]:
				h._modelo.rotation.y=d*TAU/8.0
				h._cabeca_referencia.orientar(h._modelo.rotation.y)
				await foto("save_real_%d_direcao_%d"%[i,d])
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(SAIDA+"save_real_%d_no_mapa.png"%i)
	j.aparencia_raven=original
	h._chave_cores=0
	h._aplicar_cores()
	conferir(j.inventario.fotografar_mochila()==mochila,"Inventário preservado")
	print("CABEÇA REFERÊNCIA: oito vistas, união do pescoço, sono, cores de personalização e inventário; ",falhas," falhas")
	quit(1 if falhas else 0)
