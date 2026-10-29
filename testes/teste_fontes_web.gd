extends SceneTree
## Confere o atlas e a imagem dos glifos, além do layout após girar a tela.
const Fontes := preload("res://codigo/dados/fontes_interface.gd")
const PRINCIPAIS: Array[FontFile] = [
	preload("res://assets/ui/Planes_ValMore.ttf"),
	preload("res://assets/ui/craftpix-net-775352-game-user-interface-pixel-art/6 Font/CraftPixNet Survival Kit.otf"),
	preload("res://assets/ui/craftpix-net-420010-pixel-game-user-interface-for-platformer/TinyFontCraftpixPixel.otf"),
]
var falhas := 0
func _initialize() -> void: rodar.call_deferred()
func conferir(ok: bool, mensagem: String) -> void:
	if not ok:
		falhas += 1
		push_error(mensagem)
func esperar(n := 10) -> void:
	for i in n: await process_frame
func rodar() -> void:
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"):
		quit(1)
		return
	await process_frame
	if not OS.has_feature("web"):
		for fonte in PRINCIPAIS:
			conferir(not fonte.multichannel_signed_distance_field,"Renderização nativa preservada")
	Fontes.preparar(true)
	var fontes: Array[FontFile] = PRINCIPAIS.duplicate()
	fontes.append(load("res://assets/ui/fontes/NotoSans-Regular.ttf"))
	fontes.append(load("res://assets/ui/fontes/NotoSansSymbols2-Regular.ttf"))
	fontes.append(ThemeDB.fallback_font)
	for fonte in fontes:
		conferir(fonte.multichannel_signed_distance_field,"Atlas multicanal: " + fonte.resource_path)
	for fonte in PRINCIPAIS:
		for caractere in "áãçÇÃ·▲▼":
			conferir(fonte.has_char(caractere.unicode_at(0)),"Acento/símbolo disponível: " + caractere)
	if DisplayServer.get_name() == "headless":
		push_error("Este teste exige renderização real")
		quit(1)
		return
	# Um O sólido detecta a regressão de retângulos, mesmo com métricas corretas.
	var vista := SubViewport.new()
	vista.size = Vector2i(128,128)
	vista.transparent_bg = true
	vista.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vista)
	var rotulo := Label.new()
	rotulo.position = Vector2(16,8)
	rotulo.add_theme_font_size_override("font_size",64)
	rotulo.text = "O"
	vista.add_child(rotulo)
	for i in fontes.size():
		var fonte := fontes[i]
		if not fonte.has_char(79): continue
		rotulo.add_theme_font_override("font",fonte)
		await esperar(3)
		await RenderingServer.frame_post_draw
		var imagem := vista.get_texture().get_image()
		var area := imagem.get_used_rect()
		var preenchidos := 0
		for y in range(area.position.y,area.end.y):
			for x in range(area.position.x,area.end.x):
				if imagem.get_pixel(x,y).a > 0.5: preenchidos += 1
		conferir(area.has_area() and preenchidos > 0 and imagem.get_pixelv(area.get_center()).a < 0.5,"O visível e vazado, sem bloco sólido: " + fonte.resource_path)
		imagem.save_png("/tmp/algoland-fontes-web-glifo-%d.png" % i)
	vista.queue_free()
	change_scene_to_file("res://cenas/inicio_do_jogo.tscn")
	await esperar(40)
	root.mode = Window.MODE_WINDOWED
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	var inicio = current_scene
	var raiz: Control = inicio.get_node("Interface/Raiz")
	var conta_tela = inicio.get_node("TelaConta")
	for tamanho in [Vector2i(640,288),Vector2i(288,512),Vector2i(576,324),Vector2i(480,270),Vector2i(640,288)]:
		root.content_scale_size = tamanho
		root.size = tamanho * 2
		await esperar(15)
		for botao: Button in inicio.menu.get_children():
			if not botao.visible: continue
			var texto := botao.get_theme_font("font").get_string_size(botao.text,HORIZONTAL_ALIGNMENT_LEFT,-1,botao.get_theme_font_size("font_size"))
			var margens := botao.get_theme_stylebox("normal").get_minimum_size()
			conferir(texto.x + margens.x <= botao.size.x+1 and texto.y + margens.y <= botao.size.y+1,"Texto e margens: %s em %s" % [botao.text,tamanho])
		conta_tela._trocar(conta_tela.Modo.ENTRAR)
		await esperar()
		conferir(Rect2(Vector2.ZERO,raiz.size).grow(-8).encloses(conta_tela._painel.get_global_rect()),"Painel da conta dentro da tela: %s" % tamanho)
		for modo in [conta_tela.Modo.CRIAR,conta_tela.Modo.RECUPERAR,conta_tela.Modo.ENTRAR]:
			conta_tela._trocar(modo)
			await esperar(5)
			conferir(Rect2(Vector2.ZERO,raiz.size).grow(-8).encloses(conta_tela._painel.get_global_rect()),"Conta modo %s dentro da tela: %s" % [modo,tamanho])
			for filho in conta_tela._caixa.get_children():
				if filho is Label:
					conferir(filho.size.x <= conta_tela._rolagem.size.x,"Texto da conta respeita largura da rolagem")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/algoland-fontes-web-conta-%dx%d.png" % [tamanho.x,tamanho.y])

	current_scene.queue_free()
	current_scene = null
	await esperar(3)
	print("FONTES WEB: ",falhas," falhas")
	quit(1 if falhas else 0)
