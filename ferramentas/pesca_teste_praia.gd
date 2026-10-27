extends SceneTree
## Reproduz pesca na praia: em cada ponto, vara na mão e lançar. -- --3d usa o personagem base 3D. Save isolado.
var avisos: Array = []
func _initialize(): rodar.call_deferred()
func rodar():
	assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
	root.get_node("Introducao").pular_prologo()
	if "--3d" in OS.get_cmdline_user_args(): set_meta("visual_base_3d_p1", true)
	change_scene_to_file("res://cenas/praia.tscn")
	for i in 60: await process_frame
	root.get_node("Transicao").limpar()
	var j = current_scene.get_node("Jogador")
	print("PESCA base3d=", j.has_node("HeroiBase3D"))
	var inv = root.get_node("EventosJogo").inventario_de(j)
	inv.sincronizar_vara()
	inv.definir_vara_na_mao(true)
	var ok := 0
	var falhas := []
	var pontos := get_nodes_in_group("pontos_pesca")
	print("PESCA pontos=", pontos.size(), " espaco_mochila=", inv.tem_espaco(), " vara_na_mao=", inv.vara_na_mao)
	for ponto in pontos:
		if ponto.get_world_2d() != j.get_world_2d(): continue
		j.global_position = ponto.global_position
		j._direcao_ataque = ponto.direcao
		for i in 4: await physics_frame
		var pode: bool = ponto.pode_interagir_para(j)
		var lancou: bool = ponto.get_script().tentar_lancar(j)
		for i in 10: await process_frame
		var sessao: bool = j.has_node("SessaoPesca")
		if sessao:
			ok += 1
			j.get_node("SessaoPesca").call("encerrar") if j.get_node("SessaoPesca").has_method("encerrar") else j.get_node("SessaoPesca").queue_free()
			for i in 10: await process_frame
			if j.has_node("SessaoPesca"):
				j.get_node("SessaoPesca").free()
			j.movimento_habilitado = true
		else:
			falhas.append("%s %s pode=%s amb=%s mov=%s" % [ponto.name, ponto.global_position, pode, ponto.ambiente, j.movimento_habilitado])
	print("PESCA lancou em %d de %d pontos" % [ok, pontos.size()])
	for f in falhas.slice(0, 12): print("PESCA FALHOU ", f)
	quit()
