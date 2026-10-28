extends SceneTree
const Desafios = preload("res://codigo/pesca/desafios_pesca.gd")
var falhas := 0
func _initialize(): rodar.call_deferred()
func conferir(nome: String, ok: bool):
	print("OK " if ok else "FALHA ",nome)
	if not ok: falhas+=1
func rodar():
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"):quit(1);return
	var f=root.get_node("Fazenda")
	f._zerar()
	var inv=root.get_node("InventarioJogador")
	inv.limpar()
	inv.criar_itens_iniciais()
	var dados=Desafios.dados("especie_linguado")
	conferir("mesmo ID oferece três sardinhas por cinquenta Brasas",dados.nome=="PESCAR 3 SARDINHAS" and dados.peixe=="sardinha" and dados.meta==3 and dados.brasas==50)
	conferir("capturas de linguado anteriores continuam contando",Desafios.progresso("especie_linguado",{"linguado":2,"sardinha":1},0,0)==3)
	conferir("capturas antigas de sardinha já contam",Desafios.progresso("especie_linguado",{"sardinha":3},0,0)==3)
	f.peixes_pescados={"linguado":2,"sardinha":1}
	f.salvar()
	f.carregar()
	conferir("save anterior adota a meta sem perder progresso",f.progresso_desafio_pesca("especie_linguado")==3)
	conferir("meta substituída paga a recompensa original",f.resgatar_desafio_pesca("especie_linguado")==50)
	conferir("recompensa não pode ser resgatada duas vezes",f.resgatar_desafio_pesca("especie_linguado")==0)
	f.carregar()
	conferir("conclusão fica preservada ao reabrir",f.resgatar_desafio_pesca("especie_linguado")==0)
	# Um jogador que já havia terminado a missão antiga não recebe prêmio duplicado.
	f.peixes_pescados={"linguado":5}
	f.pesca_recompensas={"especie_linguado":true}
	f.salvar()
	f.carregar()
	conferir("conclusão da missão antiga continua recebida",f.pesca_recompensas.has("especie_linguado") and f.resgatar_desafio_pesca("especie_linguado")==0)
	if DisplayServer.get_name()!="headless":
		root.mode=Window.MODE_WINDOWED
		root.size=Vector2i(1152,648)
		root.content_scale_size=Vector2i(576,324)
		var guia=load("res://codigo/pesca/guia_pesca.gd").new()
		root.add_child(guia)
		guia._trocar_aba("DESAFIOS")
		for i in 8:await process_frame
		for no in guia._grade.get_children():
			if no is Label and no.text.begins_with("PESCAR 3 SARDINHAS"):
				var rolagem=no.get_parent().get_parent().get_parent().get_parent()
				rolagem.ensure_control_visible(no)
		for i in 8:await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/algoland-meta-sardinhas.png")
	print("META SARDINHAS: ",falhas," falhas")
	quit(1 if falhas else 0)
