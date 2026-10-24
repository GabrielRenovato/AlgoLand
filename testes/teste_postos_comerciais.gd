extends SceneTree

const Postos:=preload("res://codigo/cidade/postos_comerciais.gd")
var Dados: GDScript
var falhas:=0

func _initialize() -> void:
	rodar.call_deferred()

func quadros(n:=12) -> void:
	for i in n:
		await process_frame
		await physics_frame

func verificar(ok: bool,texto: String) -> void:
	if not ok:
		falhas+=1
		push_error(texto)

func rodar() -> void:
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"):
		push_error("Use saves isolados.")
		quit(1)
		return
	Dados=load("res://codigo/cidade/dados_cidade.gd")
	root.get_node("Introducao").pular_prologo()
	root.get_node("Fazenda").galinheiro.obra=0
	root.get_node("Progresso").encomenda_forja={}
	var capturar:=OS.get_cmdline_user_args().has("--capturar")
	var pasta:="res://arte/previas/cidade/postos_comerciais/"
	if capturar:DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(pasta))
	for id: String in Postos.POSTOS:
		var filtros := Array(OS.get_cmdline_user_args()).filter(func(arg): return arg.begins_with("--morador="))
		if not filtros.is_empty() and not filtros.has("--morador="+id): continue
		var posto: Array=Postos.POSTOS[id]
		var hora:=19.0 if id=="bardo" else 12.0
		for e in 4:
			for dia_semana in 7:
				var agenda: Dictionary=Dados.agenda(id,hora,e,0,dia_semana)
				var aberto: bool=id in ["bardo","osvaldo","nilo"] or not Dados.de_folga(id,dia_semana)
				if aberto:
					verificar(agenda.get("comercial",false) and agenda.local==posto[0] and agenda.ponto==posto[1],"Posto no horário aberto: "+id)
				else:
					verificar(not agenda.get("comercial",false),"Folga preservada: "+id)
			var fechado: Dictionary=Dados.agenda(id,3.0,e,0,0)
			verificar(not fechado.get("comercial",false),"Madrugada fora do balcão: "+id)
		root.get_node("Calendario").dia=1
		root.get_node("Transicao").hora_salva=hora
		var caminho: String="res://cenas/palafita.tscn" if posto[0]=="palafita" else "res://cenas/cidade/"+posto[0]+".tscn"
		change_scene_to_file(caminho)
		await quadros(32)
		var cena:=current_scene
		if id == "lia":
			verificar(cena.has_node("Interior/BalcaoAtendimento"),"Lia atende em um balcão real")
			var vela: Node2D = cena.get_node("Interior/BalcaoAtendimento/Candelabro")
			verificar(Rect2(-44,-38,88,13).has_point(vela.position),"Base da vela apoiada dentro do tampo do balcão")
			var itens: Array = load("res://codigo/cidade/interior_casa.gd").dados().casas.sede.itens
			verificar(not itens.any(func(item): return item.p in ["mesa_reuniao","banco_reuniao"]),"Recepção livre da mesa e dos bancos")
		cena.set_process(false)
		cena.get_node("Iluminacao").set_process(false)
		cena.get_node("Iluminacao").definir_hora(hora)
		var jogador: Node2D=cena.get_node("Jogador")
		jogador.set_physics_process(false)
		jogador.position=Vector2(-200,-200)
		jogador.hide()
		var npc: Node2D=cena.get_node("Nilo") if id=="nilo" else cena.moradores[id]
		for outro in cena.moradores.values():
			outro.set_physics_process(false)
			if outro!=npc:
				outro.hide()
				outro.collision_layer=0
		for filho in cena.get_children():
			if filho.get_script()==load("res://codigo/cidade/rotina_taverna.gd"):
				filho.set_physics_process(false)
		npc.set_physics_process(false)
		npc.agenda=Dados.agenda(id,hora,0,0,0)
		npc._agenda_base=npc.agenda.duplicate(true)
		npc.visible=true
		npc._saindo=false
		npc.position=cena.get_node("Chegada_entrada").position
		npc._ir_ate(posto[1])
		verificar(not npc.caminho.is_empty() and npc.caminho[-1].distance_to(posto[1])<6,"Balcão acessível pela navegação: "+id)
		for i in 500:
			npc._physics_process(0.2)
			await process_frame
			if npc.caminho.is_empty():break
		verificar(npc.position.distance_to(posto[1])<6,"Chega atrás do móvel sem atravessar colisão: "+id+" em "+str(npc.position))
		npc._physics_process(0.05)
		verificar(npc.sprite.frame==0,"Atendente olha para o cliente ao parar: "+id)
		# Percurso de saída também precisa existir: posto não é uma prisão.
		verificar(not cena.caminho_entre(npc.position,cena.get_node("Chegada_entrada").position).is_empty(),"Pode sair ao fechar: "+id)
		if capturar:
			var vp:=SubViewport.new()
			vp.size=Vector2i(384,288)
			vp.world_2d=cena.get_world_2d()
			vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS
			root.add_child(vp)
			var camera:=Camera2D.new()
			camera.position=posto[1]+Vector2(0,24)
			camera.zoom=Vector2(3,3)
			vp.add_child(camera)
			camera.make_current()
			for e in 4:
				root.get_node("Calendario").dia=1+e*30
				cena._atualizar_ambiente()
				await quadros(5)
				await RenderingServer.frame_post_draw
				vp.get_texture().get_image().save_png(pasta+"%s_%d.png" % [id,e])
			vp.queue_free()
		print("POSTO VALIDADO: ",id)
		cena.queue_free()
		current_scene=null
		await quadros(4)
	print("POSTOS COMERCIAIS: ",falhas," falhas")
	quit(1 if falhas else 0)
