extends SceneTree
## Save antigo (sem roupas_3d) → conversão, aviso, editor e menu de pausa. Save isolado.
const SAIDA := "res://arte/previas/personagens/base_3d/migracao/"
var falhas := 0
func conferir(ok: bool, texto: String) -> void:
	print(("OK   " if ok else "FALHA ") + texto)
	if not ok: falhas += 1
func foto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAIDA))
	root.get_texture().get_image().save_png(SAIDA+nome+".png")
func ler() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("user://configuracao_jogador.json"))
func _initialize(): rodar.call_deferred()
func rodar():
	assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
	assert(DisplayServer.get_name() != "headless")
	# Personagem salvo antes do 3D: roupa 7 (azul/jeans/capa), cabelo Raven 22, pele 2, cabelo vermelho.
	var antigo := {"aparencia_raven":{"cabelo":22,"cor":[0.75,0.25,0.18,1.0],"pele":2,"roupa":7,"versao":1},
		"apelido":"PRIMO","cabelo_atual":0,"cor_cabelo":{"a":1,"b":1,"g":1,"r":1},"roupa_atual":2}
	FileAccess.open("user://configuracao_jogador.json", FileAccess.WRITE).store_string(JSON.stringify(antigo))
	root.get_node("Introducao").pular_prologo()
	change_scene_to_file("res://cenas/cidade.tscn")
	for i in 40: await process_frame
	root.get_node("Transicao").limpar()
	var j = current_scene.get_node("Jogador")
	var h = j.get_node_or_null("HeroiBase3D")
	conferir(h != null, "personagem 3D é o visual padrão")
	conferir(h.roupas_3d.camisa == "camisa_bosque" and h.roupas_3d.calca == "calca_pescador", "roupa azul/jeans virou camisa do bosque + calça de pescador (%s)" % h.roupas_3d)
	var salvo := ler()
	conferir(salvo.has("roupas_3d") and salvo.get("aviso_visual_3d") == true and salvo.apelido == "PRIMO", "save ganhou roupas_3d e o aviso, sem perder o apelido")
	for i in 150: await process_frame
	var aviso = null
	for n in root.get_children():
		if n is CanvasLayer and n.layer == 85: aviso = n
	conferir(aviso != null, "aviso de visual novo aparece")
	await foto("1_aviso")
	if aviso == null: quit(); return
	var ajustar: Button = aviso.find_children("*", "Button", true, false).filter(func(b): return b.text == "AJUSTAR AGORA")[0]
	ajustar.pressed.emit()
	for i in 30: await process_frame
	conferir(not ler().has("aviso_visual_3d"), "aviso não volta depois de respondido")
	var editor = null
	for n in root.get_children():
		if n is CanvasLayer and n.layer == 90: editor = n
	conferir(editor != null, "AJUSTAR AGORA abre o editor")
	var tela = editor._tela
	conferir(tela.pele == 2 and tela.roupas_3d.calca == "calca_pescador" and tela.apelido == "PRIMO", "editor começa com o personagem salvo")
	tela._escolher_peca_3d("camisa", "jaqueta_viajante")
	tela._escolher_peca_3d("cabelo", "cabelo_cacheado")
	tela._escolher_olhos(1)
	for i in 20: await process_frame
	await foto("2_editor")
	tela.confirmar()
	for i in 10: await process_frame
	salvo = ler()
	conferir(salvo.roupas_3d.camisa == "jaqueta_viajante" and salvo.roupas_3d.cabelo == "cabelo_cacheado", "editor salvou as peças 3D")
	conferir(int(salvo.aparencia_raven.cabelo) == 22 and int(salvo.aparencia_raven.roupa) == 7 and int(salvo.aparencia_raven.olhos) == 1, "Raven 2D conservado; olhos gravados")
	conferir(h.roupas_3d.camisa == "jaqueta_viajante" and j.aparencia_raven.olhos == 1, "personagem no mapa já trocou")
	conferir(not is_instance_valid(editor) or editor.is_queued_for_deletion(), "editor fecha ao salvar")
	await foto("3_depois")
	# Menu de pausa → EDITAR VISUAL
	root.get_node("EventosJogo").abrir_tela_de(j, "pausa")
	for i in 20: await process_frame
	var botoes = root.find_children("BotaoEditarVisual", "Button", true, false)
	conferir(botoes.size() > 0 and botoes[0].is_visible_in_tree(), "menu de pausa tem EDITAR VISUAL")
	await foto("4_pausa")
	botoes[0].pressed.emit()
	for i in 30: await process_frame
	await foto("5_editor_pela_pausa")
	var aberto = null
	for n in root.get_children():
		if n is CanvasLayer and n.layer == 90: aberto = n
	conferir(aberto != null, "EDITAR VISUAL abre o editor com o jogo pausado")
	if aberto != null:
		aberto._tela.voltar()
		for i in 10: await process_frame
		conferir(ler().roupas_3d.camisa == "jaqueta_viajante", "CANCELAR não muda nada")
	# Save que nunca existiu (P2 sem personagem) não pode ganhar arquivo.
	conferir(not FileAccess.file_exists("user://configuracao_jogador_p2.json"), "nenhum arquivo de personagem inventado")
	print("MIGRACAO VISUAL 3D: %d falhas" % falhas)
	quit()
