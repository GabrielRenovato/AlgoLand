extends SceneTree
## Compara a precipitação econômica com os mesmos sprites e fades do PC.
class EstacoesTeste extends Node:
	var _calendario_ligado := false
	var ambiente_interno := false

var falhas := 0
func _initialize() -> void:
	rodar.call_deferred()
func verificar(nome: String, certo: bool) -> void:
	print("OK " if certo else "FALHA ", nome)
	if not certo: falhas += 1
func capturar(vp: SubViewport) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return vp.get_texture().get_image()
func rodar() -> void:
	if not OS.get_user_data_dir().contains("AlgoLand testes") or DisplayServer.get_name() == "headless":
		quit(1)
		return
	var vp := SubViewport.new()
	vp.size = Vector2i(576, 324)
	vp.world_2d = World2D.new()
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var terreno := Node2D.new()
	vp.add_child(terreno)
	var fundo := ColorRect.new()
	fundo.color = Color("5a7851")
	fundo.size = vp.size
	terreno.add_child(fundo)
	var estacoes := EstacoesTeste.new()
	terreno.add_child(estacoes)
	var clima: Node = load("res://codigo/cenario/clima.gd").new()
	estacoes.add_child(clima)
	clima.set_process(false)
	for nuvem in clima._nuvens: nuvem.hide()
	var modulador := CanvasModulate.new()
	terreno.add_child(modulador)
	var visivel := Rect2(Vector2(-37, -23), Vector2(700, 450))
	DirAccess.make_dir_recursive_absolute("/tmp/algoland-clima-android-previas")
	for noite in [false, true]:
		modulador.color = Color("737394") if noite else Color.WHITE
		for estado in [2, 3, 4, 5, 6]:
			for fase in [0, 1]:
				for i in clima._camadas.size():
					var camada = clima._camadas[i]
					camada.alfa = float(camada.alvos.get(estado, 0)) * (0.45 if fase == 0 else 1.0)
					camada.indice = (estado + i * 3) % 8
					camada.no.texture = camada.quadros[camada.indice]
				clima.clima_atual = estado
				clima.modo_economico = false
				clima._atualizar_camadas(0, visivel)
				var antes := await capturar(vp)
				var chamadas_antes := vp.get_render_info(Viewport.RENDER_INFO_TYPE_CANVAS, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
				clima.modo_economico = true
				# Recriar a associação aos quadros escolhidos sem avançar o relógio.
				clima._atualizar_camadas(0, visivel)
				for i in clima._camadas.size():
					clima._material_queda.set_shader_parameter(clima.UNIFORMES_QUEDA[i], clima._camadas[i].no.texture)
				var depois := await capturar(vp)
				var chamadas_depois := vp.get_render_info(Viewport.RENDER_INFO_TYPE_CANVAS, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
				if estado in [3,4,6]:
					verificar("Menos chamadas de desenho %d -> %d" % [chamadas_antes,chamadas_depois], chamadas_depois < chamadas_antes)
				var maior := 0.0
				for y in vp.size.y:
					for x in vp.size.x:
						var a := antes.get_pixel(x, y)
						var b := depois.get_pixel(x, y)
						maior = maxf(maior, maxf(absf(a.r-b.r), maxf(absf(a.g-b.g),absf(a.b-b.b))))
				verificar("Sprites/fade/noite %d %d %s diferença %.4f" % [estado,fase,noite,maior], maior <= 3.1/255.0)
				verificar("Uma camada sem luzes extras", clima._queda_compacta.visible and clima._queda_compacta.light_mask == 0 and clima._camadas.all(func(c): return not c.no.visible))
				if fase == 1 and not noite:
					depois.save_png("/tmp/algoland-clima-android-previas/estado_%d.png" % estado)
	clima.clima_atual = 3
	var forte = clima._camadas[0]
	forte.tempo = 0
	forte.indice = 0
	clima._atualizar_camadas(600.25, visivel)
	verificar("Retomar app salta quadros perdidos com a fase correta", forte.indice == 2 and absf(forte.tempo - 0.05) < 0.00001)
	clima.clima_atual = 0
	for i in 100: clima._atualizar_camadas(0.02, visivel)
	verificar("Limpo desliga a passagem extra", not clima._queda_compacta.visible)
	vp.queue_free()
	await process_frame
	print("Falhas: ",falhas)
	quit(falhas)
