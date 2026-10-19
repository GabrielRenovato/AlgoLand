extends SceneTree

var falhas := 0
func _initialize() -> void: rodar.call_deferred()
func quadros(n := 10) -> void:
	for i in n:
		await process_frame
		await physics_frame
func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ",nome)
	if not ok: falhas += 1
func rodar() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AlgoLand testes"):
		quit(1)
		return
	await process_frame
	var saves := root.get_node("Saves")
	var faz := root.get_node("Fazenda")
	if "--fechar-energia" in OS.get_cmdline_user_args():
		saves.trocar("solo")
		faz._definir_energia(1,8)
		faz.salvar()
		faz._definir_energia(1,177)
		faz._definir_energia(2,93)
		saves.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
		return
	var cal := root.get_node("Calendario")
	var inv := root.get_node("InventarioJogador")
	for mundo in ["solo","coop"]:
		saves.trocar(mundo)
		root.get_node("Introducao").pular_prologo()
		cal.dia = 7
		cal.salvar()
		faz.solo = {Vector2i(10,24):{"planta":"", "dias":0, "molhado":true, "murcha":false}}
		faz.clima_hoje = 0
		faz._definir_energia(1,218)
		faz._definir_energia(2,163)
		faz.salvar()
		inv.limpar()
		inv.criar_itens_iniciais()
		inv.adicionar_coletavel("material","madeira",3)
		inv.salvar()
		var solo: Dictionary = faz.solo.duplicate(true)
		for segundo in [false,true]:
			var personagem := FileAccess.open(saves.caminho_personagem(segundo),FileAccess.WRITE)
			personagem.store_string("{}")
			personagem.close()
		change_scene_to_file("res://cenas/inicio_do_jogo.tscn")
		await quadros(30)
		var inicio: Node = current_scene
		if mundo == "coop": inicio._ao_continuar_coop()
		else: inicio._ao_continuar()
		for tentativa in 180:
			await quadros(1)
			if current_scene != null and current_scene != inicio: break
		await quadros(20)
		verificar("continuar carrega a partida " + mundo,current_scene!=inicio and current_scene.scene_file_path=="res://cenas/cidade.tscn")
		verificar("continuar preserva energia dos dois jogadores " + mundo,faz.energia_de(1)==218 and faz.energia_de(2)==163)
		verificar("continuar nao passa dia nem altera terreno " + mundo,cal.dia==7 and faz.solo==solo)
		verificar("continuar conserva materiais " + mundo,inv.quantidade_tipo("material:madeira")==3)
		faz.carregar()
		verificar("saldo parcial permanece salvo " + mundo,faz.energia_de(1)==218 and faz.energia_de(2)==163)
		faz.gastar_energia("enxada")
		await quadros(2)
		faz._definir_energia(1,0)
		faz.carregar()
		verificar("gasto e salvo e recarga comum conserva saldo " + mundo,faz.energia_de(1)==216)
		change_scene_to_file("res://cenas/fazenda.tscn")
		await quadros(20)
		verificar("viajar nao recarrega energia " + mundo,faz.energia_de(1)==216)
		var hud: Node = get_first_node_in_group("hud_p1")
		faz._definir_energia(1,0)
		faz.carregar()
		verificar("barra acompanha energia recarregada " + mundo,hud.barra_energia!=null and is_equal_approx(hud.barra_energia._fracao,216.0/270.0))
	# Simula o app indo para o fundo antes de a gravação adiada acontecer.
	faz._definir_energia(1,201)
	faz._definir_energia(2,137)
	saves.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	faz._definir_energia(1,0)
	faz._definir_energia(2,0)
	faz.carregar()
	verificar("suspender app grava os saldos exatos",faz.energia_de(1)==201 and faz.energia_de(2)==137)
	var saida: Array = []
	var codigo := OS.execute(OS.get_executable_path(),["--headless","--path",ProjectSettings.globalize_path("res://"),"--script","res://testes/teste_energia_continuar.gd","--","--fechar-energia"],saida,true)
	var gravado = JSON.parse_string(FileAccess.get_file_as_string("user://fazenda.json"))
	verificar("fechar janela grava energia antes de encerrar o processo",codigo==0 and gravado is Dictionary and gravado.get("energia_p1")==177 and gravado.get("energia_p2")==93)
	current_scene.queue_free()
	await quadros()
	print("Energia continuar: %d falhas" % falhas)
	quit(1 if falhas else 0)
