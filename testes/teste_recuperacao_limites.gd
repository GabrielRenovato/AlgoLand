extends SceneTree
var Seguranca: GDScript
var falhas := 0
var verificacoes := 0
func _initialize(): rodar.call_deferred()
func quadros(n := 6):
	for i in n:
		await physics_frame
		await process_frame
func conferir(nome: String, ok: bool):
	verificacoes+=1
	print("OK " if ok else "FALHA ",nome)
	if not ok:falhas+=1
func rodar():
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"):quit(1);return
	Seguranca=load("res://codigo/jogador/seguranca_mapa.gd")
	root.get_node("Ranking").conexao_habilitada=false
	root.get_node("Introducao").pular_prologo()
	root.get_node("Controle").usando_toque=true
	root.get_node("Transicao").hora_salva=12.0
	var coop=root.get_node("Cooperativo")
	var saves=root.get_node("Saves")
	var progresso=root.get_node("Progresso")
	saves.trocar("solo")
	root.get_node("Introducao").pular_prologo()
	for caminho in Seguranca.MAPAS:
		change_scene_to_file(caminho)
		await quadros(18)
		var cena=current_scene
		var j=cena.get_node("Jogador")
		j.set_physics_process(false)
		var guarda=j.get_node("SegurancaMapa")
		guarda.set_physics_process(false)
		var inicio: Vector2=j.global_position
		var vida: int=j.hp_atual
		guarda._physics_process(.3)
		conferir("posição válida preservada "+caminho,j.global_position.is_equal_approx(inicio))
		var limites: Rect2=cena.limites
		for ponto in [cena.to_global(Vector2(-600,-500)),cena.to_global(limites.end+Vector2(400,400)),cena.to_global(Vector2(-10,limites.get_center().y)),cena.to_global(Vector2(limites.get_center().x,limites.end.y+10))]:
			j.global_position=ponto
			j.velocity=Vector2(300,0)
			j.esta_em_dash=true
			guarda._physics_process(.16)
			conferir("retorno dentro do mapa "+caminho,Seguranca.dentro(cena,j.global_position))
			conferir("retorno sem colisão "+caminho,Seguranca.livre(cena,j.global_position,j))
			conferir("recuperação cancela impulso sem ferir",j.velocity==Vector2.ZERO and not j.esta_em_dash and j.hp_atual==vida)
			await quadros(2)
		# Continua um save antigo que já estava do lado de fora.
		progresso.local_jogadores={"1":{"cena":caminho,"x":-1000.,"y":-500.}}
		saves._restaurar_pendente=true
		await saves.restaurar_local()
		conferir("save externo antigo volta a local seguro "+caminho,Seguranca.dentro(cena,j.global_position) and Seguranca.livre(cena,j.global_position,j))
		# A recuperação não disputa o personagem com portas/transições.
		var externo=cena.to_global(Vector2(-200,-200))
		j.global_position=externo
		root.get_node("Transicao").ocupada=true
		guarda._physics_process(.5)
		conferir("fade de viagem preservado",j.global_position==externo)
		root.get_node("Transicao").ocupada=false
		coop._viajando[1]=true
		guarda._physics_process(.5)
		conferir("viagem cooperativa preservada",j.global_position==externo)
		coop._viajando[1]=false
		guarda._physics_process(.16)
		await quadros(2)
		var salvo: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(progresso.caminho_save))
		conferir("posição recuperada fica gravada",Seguranca.dentro(cena,Vector2(salvo.local_jogadores["1"].x,salvo.local_jogadores["1"].y)))
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/algoland-recuperado-"+caminho.get_file().get_basename()+".png")
	# Recupera P2 no próprio mundo; P1 não é movido junto.
	saves.trocar("coop")
	root.get_node("Introducao").pular_prologo()
	coop.entrar(97)
	change_scene_to_file("res://cenas/cidade.tscn")
	await quadros(20)
	var p1=coop._jogador1()
	var p2=coop.jogador2()
	await coop.viajar_local(p2,"res://cenas/praia.tscn","cidade")
	await quadros(10)
	p1.set_physics_process(false)
	p2.set_physics_process(false)
	var lugar1: Vector2=p1.global_position
	var destino=coop.cena_de(p2)
	p2.global_position=destino.to_global(Vector2(-400,-400))
	var guarda=p2.get_node("SegurancaMapa")
	guarda._physics_process(.16)
	conferir("P2 recuperado na própria praia",Seguranca.dentro(destino,p2.global_position) and p1.global_position==lugar1)
	conferir("P1 mantém cidade e P2 mantém praia",coop.cena_de(p1).scene_file_path=="res://cenas/cidade.tscn" and coop.cena_de(p2).scene_file_path=="res://cenas/praia.tscn")
	print("RECUPERACAO LIMITES: ",verificacoes," verificações; ",falhas," falhas")
	quit(1 if falhas else 0)
