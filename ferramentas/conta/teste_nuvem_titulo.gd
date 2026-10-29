extends SceneTree
## Nuvem no menu inicial real (aparelho novo baixa; conflito abre o diálogo). Mesmo uso do teste_nuvem_local.gd.
var falhas := 0
func conferir(ok: bool, nome: String) -> void:
	print(("OK    " if ok else "FALHA ") + nome)
	if not ok: falhas += 1
func _initialize(): rodar.call_deferred()
func gravar(nome: String, dados: Dictionary) -> void:
	var f := FileAccess.open("user://" + nome, FileAccess.WRITE)
	f.store_string(JSON.stringify(dados))
	f.close()
func montar_save(dia: int) -> void:
	gravar("configuracao_jogador.json", {"apelido": "T"})
	gravar("calendario.json", {"dia": dia})
	gravar("progresso.json", {"recorde_onda": 2, "brasas": 7})
	gravar("versao_save.json", {"versao": 2})
func apagar_save() -> void:
	for nome in load("res://codigo/globais/transferencia_save.gd").ARQUIVOS:
		if FileAccess.file_exists("user://" + nome): DirAccess.remove_absolute(ProjectSettings.globalize_path("user://" + nome))
func rodar() -> void:
	assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
	root.mode = Window.MODE_WINDOWED
	root.content_scale_size = Vector2i(576, 324)
	root.size = Vector2i(1152, 648)
	var conta = load("res://codigo/conta/cliente_conta.gd").obter(self)
	conta._limpar_sessao()
	apagar_save()
	montar_save(5)
	await conta.criar("titulo@teste.com", "12345678", "TITULO")
	conferir(await conta.nuvem.sincronizar("login") == "ok", "aparelho A sobe o save (dia 5)")
	# Aparelho B: sem save e sem revisão conhecida, abre o menu inicial
	apagar_save()
	conta.nuvem._rev = 0
	conta.nuvem._hash = ""
	var titulo: Node = load("res://cenas/inicio_do_jogo.tscn").instantiate()
	root.add_child(titulo)
	current_scene = titulo
	for i in 90: await process_frame
	conferir(FileAccess.file_exists("user://configuracao_jogador.json"), "aparelho novo recebeu o save da nuvem no menu")
	conferir(titulo.tem_save() and titulo.botao_continuar.visible, "botao CONTINUAR aparece depois da nuvem")
	conferir(conta.nuvem.estado == "baixado", "estado baixado")
	# Conflito: o aparelho tem outro progresso e não conhece a revisão da nuvem
	titulo.queue_free()
	await process_frame
	montar_save(11)
	conta.nuvem._rev = 0
	conta.nuvem._hash = ""
	titulo = load("res://cenas/inicio_do_jogo.tscn").instantiate()
	root.add_child(titulo)
	current_scene = titulo
	for i in 90: await process_frame
	var dialogo = titulo.get_node_or_null("ConflitoNuvem")
	conferir(dialogo != null and conta.nuvem.estado == "conflito", "conflito abre o dialogo no menu")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/algoland-coop-online/conflito.png")
	if dialogo:
		await dialogo._escolher(true)
		for i in 20: await process_frame
		conferir(JSON.parse_string(FileAccess.get_file_as_string("user://calendario.json")).dia == 5, "usar a nuvem troca o save local pelo da conta")
		conferir(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("user://backups")), "copia do save substituido guardada em backups")
	var painel = load("res://codigo/conta/painel_conta.gd").new()
	root.add_child(painel)
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/algoland-coop-online/painel_logado.png")
	painel.queue_free()
	await conta.sair()
	painel = load("res://codigo/conta/painel_conta.gd").new()
	root.add_child(painel)
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/algoland-coop-online/painel_offline.png")
	conta._limpar_sessao()
	print("NUVEM TITULO: ", falhas, " falhas")
	quit(1 if falhas else 0)
