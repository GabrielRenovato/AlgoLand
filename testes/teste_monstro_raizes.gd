extends SceneTree

class Alvo:
	extends Node2D
	var estaMorto := false
	var caido := false
	var invulneravel := false
	var acertos := 0
	func receber_dano(_dano: int,_forca := Vector2.ZERO) -> void: acertos+=1

var falhas := 0
var cena: Node2D
var mob: Node2D
var alvo: Alvo
var capturas := "res://capturas-monstro-raizes"
func _initialize() -> void: rodar.call_deferred()
func verificar(nome: String,ok: bool) -> void:
	print("OK " if ok else "FALHA ",nome)
	if not ok: falhas+=1
func quadros(n := 4) -> void:
	for i in n:
		await process_frame
		await physics_frame
func avancar(tempo: float) -> void:
	for i in int(round(tempo*100)): mob._physics_process(.01)
func foto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	verificar("captura "+nome,root.get_texture().get_image().save_png(capturas.path_join(nome+".png"))==OK)
func rodar() -> void:
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes") or DisplayServer.get_name()=="headless": quit(1);return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capturas="):capturas=arg.trim_prefix("--capturas=")
	DirAccess.make_dir_recursive_absolute(capturas)
	root.content_scale_size=Vector2i(576,324);root.size=Vector2i(1152,648)
	change_scene_to_file("res://cenas/campanha/percurso_prototipo.tscn")
	await quadros(30)
	cena=current_scene
	mob=load("res://cenas/inimigos/rebento_raizes.tscn").instantiate()
	mob.ia_habilitada=false
	mob.position=Vector2(82,-220)
	cena.add_child(mob)
	mob.set_physics_process(false)
	mob.raio_percepcao=125
	cena.jogador.position=mob.position+Vector2(250,0)
	verificar("percepção local ignora jogador distante",mob.obter_jogador()==null)
	cena.jogador.position=mob.position+Vector2(100,0)
	verificar("aproximação desperta perseguição",mob.obter_jogador()==cena.jogador)
	cena.jogador.position=mob.position+Vector2(150,0)
	verificar("margem mantém perseguição sem oscilar",mob.obter_jogador()==cena.jogador)
	cena.jogador.position=mob.position+Vector2(200,0)
	verificar("afastamento encerra perseguição",mob.obter_jogador()==null)
	mob.raio_percepcao=0
	alvo=Alvo.new();alvo.add_to_group("jogadores");cena.add_child(alvo)
	alvo.position=mob.position+Vector2(0,25)
	cena.jogador.position=mob.position+Vector2(-60,10)
	cena.jogador.get_node("Camera2D").reset_smoothing()
	await quadros()
	verificar("não causa dano por simples contato",alvo.acertos==0)
	verificar("inicia combo e trava reentrada",mob.iniciar_combo(Vector2.DOWN)==OK and mob.iniciar_combo(Vector2.DOWN)==ERR_BUSY)
	avancar(.49)
	verificar("preparação não causa dano",alvo.acertos==0)
	await foto("00-varrida-aviso")
	avancar(.02)
	verificar("primeira janela acerta uma vez",alvo.acertos==1)
	await foto("00-varrida-impacto")
	avancar(.35)
	verificar("segurar janela não repete dano",alvo.acertos==1)
	avancar(.57)
	verificar("segundo golpe tem janela própria",alvo.acertos==2)
	await foto("00-pancada-impacto")
	avancar(.6)
	verificar("recuperação encerra combo",mob.estado==mob.Estado.LIVRE and alvo.acertos==2)
	mob.iniciar_combo(Vector2.DOWN)
	alvo.position+=Vector2(100,0)
	avancar(2)
	verificar("esquivar sai das duas áreas anunciadas",alvo.acertos==2)
	alvo.position=mob.position+Vector2(-90,-15)
	verificar("inicia conjuração com três áreas",mob.iniciar_raizes(alvo.position)==OK and mob._zonas.size()==3)
	var zonas: Array=mob._zonas.duplicate()
	alvo.position+=Vector2(100,0)
	avancar(.79)
	verificar("aviso longo precede raízes e alvo não é perseguido",alvo.acertos==2 and mob._zonas==zonas)
	await foto("00-raizes-aviso")
	avancar(.4)
	verificar("três erupções não atingem quem esquivou",mob._impactos.size()==3 and alvo.acertos==2)
	await create_timer(.25).timeout
	await foto("00-raizes-erupcao")
	avancar(.6)
	alvo.position=mob.position+Vector2(0,25)
	mob.iniciar_combo(Vector2.DOWN)
	mob.receber_dano(1,Vector2(1,0))
	avancar(2)
	verificar("reação interrompe golpes e remove avisos",alvo.acertos==2 and not mob.esta_atacando and mob._avisos.is_empty())
	# Cancelamento e colisão de mundo, sem criar progresso de missão artificial.
	var parede:=StaticBody2D.new();parede.collision_layer=64
	var forma:=CollisionShape2D.new();var caixa:=RectangleShape2D.new();caixa.size=Vector2(100,10);forma.shape=caixa;parede.add_child(forma)
	parede.position=mob.position+Vector2(0,45);cena.add_child(parede)
	await physics_frame
	verificar("raízes não atravessam parede",mob.iniciar_raizes(mob.position+Vector2(0,90))==ERR_UNAVAILABLE)
	parede.queue_free()
	alvo.remove_from_group("jogadores");alvo.queue_free()
	cena.jogador.position=mob.position+Vector2(-60,10)
	cena.jogador.get_node("Camera2D").reset_smoothing()
	await quadros()
	var ficha: Dictionary=mob.FICHA.data
	verificar("três vistas autorais mais espelhamento lateral",ficha.animacoes.has("andar_baixo") and ficha.animacoes.has("andar_lado") and ficha.animacoes.has("andar_cima"))
	for nome in ficha.animacoes:
		if nome=="reagir": continue
		mob._tocar(nome,true)
		var dados: Dictionary=ficha.animacoes[nome]
		verificar("tempos e quadros correspondem "+nome,dados.quadros.size()==dados.duracoes.size() and not dados.quadros.is_empty())
		for i in dados.quadros.size():
			mob.tempo_animacao=0
			for anterior in i:mob.tempo_animacao+=float(dados.duracoes[anterior])
			mob.tempo_animacao+=.001
			mob._aplicar_quadro()
			await quadros(2)
			await foto("01-"+nome+"-"+str(i))
	# Reproduzir com os tempos reais no motor, além da folha de contato.
	for nome in ["andar_baixo","andar_lado","andar_cima","golpe_a_baixo","golpe_b_baixo","conjurar_baixo"]:
		mob._tocar(nome,true)
		var tempo := 0.0
		while tempo<1.5:
			await process_frame
			var delta:=minf(root.get_process_delta_time(),.1)
			mob._animar(delta);tempo+=delta
	var mortes: Array[int]=[0]
	mob.inimigo_morreu.connect(func():mortes[0]+=1)
	mob.morrer()
	verificar("morte cancela ataques",not mob.esta_atacando and mob.iniciar_combo(Vector2.DOWN)==ERR_BUSY)
	mob._physics_process(.81);mob._physics_process(.1)
	verificar("morte emite conclusão uma única vez",mortes[0]==1)
	await quadros()
	print("FALHAS: ",falhas)
	quit(falhas)
