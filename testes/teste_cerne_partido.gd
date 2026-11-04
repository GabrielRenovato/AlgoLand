extends SceneTree

class Alvo:
	extends Node2D
	var estaMorto:=false
	var caido:=false
	var acertos:=0
	var forca:=Vector2.ZERO
	func receber_dano(_valor: int,empurrao:=Vector2.ZERO) -> void:
		acertos+=1;forca=empurrao

var falhas:=0
var cena: Node2D
var chefe: Node2D
var alvo: Alvo
var capturas:="res://capturas-cerne-partido"
func _initialize() -> void: rodar.call_deferred()
func verificar(nome: String,ok: bool) -> void:
	print("OK " if ok else "FALHA ",nome)
	if not ok:falhas+=1
func quadros(n:=4) -> void:
	for i in n:await process_frame;await physics_frame
func avancar(tempo: float) -> void:
	for i in int(round(tempo*100)):chefe._physics_process(.01)
func foto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	verificar("captura "+nome,root.get_texture().get_image().save_png(capturas.path_join(nome+".png"))==OK)
func rodar() -> void:
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes") or DisplayServer.get_name()=="headless":quit(1);return
	auto_accept_quit=false
	root.mode=Window.MODE_WINDOWED
	DirAccess.make_dir_recursive_absolute(capturas)
	root.content_scale_size=Vector2i(576,324);root.size=Vector2i(1152,648)
	change_scene_to_file("res://cenas/campanha/percurso_prototipo.tscn")
	await quadros(30)
	cena=current_scene
	chefe=load("res://cenas/inimigos/cerne_partido.tscn").instantiate()
	chefe.position=Vector2(82,-237)
	chefe.fala.connect(cena.fala_do_cerne)
	cena.add_child(chefe);chefe.set_physics_process(false)
	alvo=Alvo.new();alvo.add_to_group("jogadores");cena.add_child(alvo)
	alvo.position=chefe.position+Vector2(20,20)
	cena.jogador.position=chefe.position+Vector2(-105,45)
	cena.jogador.get_node("Camera2D").reset_smoothing()
	var vida: int=chefe.vida
	chefe.receber_dano(100)
	verificar("não é atingível antes de aterrissar",chefe.vida==vida)
	avancar(1.9)
	await foto("00-queda-aviso")
	verificar("queda tem preparação sem dano antecipado",alvo.acertos==0 and chefe.sprite.position.y<0)
	avancar(.32)
	verificar("impacto único causa dano e empurra",alvo.acertos==1 and alvo.forca.length()>250)
	avancar(.5)
	verificar("permanecer na cratera não repete impacto",alvo.acertos==1)
	await quadros();await foto("01-chegada-fala")
	avancar(3.9)
	var origem: Vector2=chefe.position
	alvo.position=origem+Vector2(260,0)
	cena.jogador.position=origem+Vector2(125,0)
	chefe._proxima_escolha_alvo=0
	chefe.set_physics_process(true)
	await create_timer(1.2).timeout
	chefe.set_physics_process(false)
	verificar("IA real persegue jogador na clareira",chefe.position.distance_to(origem)>20)
	await foto("01-perseguicao-real")
	chefe.position=origem
	chefe._livre_cerne(0)
	cena.jogador.position=origem+Vector2(-105,45)
	chefe._proxima_escolha_alvo=0
	alvo.position=chefe.position+Vector2(0,45)
	chefe._rumo=Vector2.DOWN
	verificar("inicia combo",chefe.iniciar_especial("combo")==OK)
	var antes: int=alvo.acertos
	avancar(.57)
	verificar("varrida tem aviso antes da janela",alvo.acertos==antes)
	avancar(.03)
	verificar("primeira varrida acerta uma vez",alvo.acertos==antes+1)
	avancar(1.04)
	verificar("segunda varrida tem janela própria",alvo.acertos==antes+2)
	avancar(.6)
	chefe.receber_dano(250)
	verificar("metade da vida inicia segunda fase",chefe.fase==2 and chefe.etapa==chefe.Etapa.TRANSFORMAR)
	await foto("02-fase2-fala")
	avancar(2.01)
	alvo.position=chefe.position+Vector2(-90,40)
	verificar("inicia conjuração",chefe.iniciar_especial("raizes")==OK)
	avancar(1.4)
	verificar("três apoios são inimigos cortáveis",chefe.apoios.size()==3 and chefe.apoios.all(func(a):return a.is_in_group("enemy") and a.get_node("AlvoGolpes").collision_layer==4))
	await quadros();await foto("03-raizes-cortaveis")
	var apoios: Array=chefe.apoios.duplicate()
	for apoio in apoios:apoio.receber_dano(8)
	verificar("cortar apoios interrompe especial e derruba",chefe.etapa==chefe.Etapa.VULNERAVEL and chefe._avisos.is_empty())
	var vida_vulneravel: int=chefe.vida
	chefe.receber_dano(4)
	verificar("núcleo vulnerável recebe dano dobrado",chefe.vida==vida_vulneravel-8)
	avancar(.5);await quadros();await foto("04-vulneravel")
	avancar(3.6)
	verificar("boss se levanta após janela vulnerável",chefe.etapa==chefe.Etapa.LIVRE)
	chefe._rumo=Vector2.RIGHT
	var antes_investida: Vector2=chefe.position
	chefe.iniciar_especial("investida")
	chefe.set_physics_process(true)
	await create_timer(1.3).timeout
	chefe.set_physics_process(false)
	verificar("investida real desloca o corpo",chefe.position.distance_to(antes_investida)>35)
	await foto("04-investida-real")
	avancar(1)
	alvo.position=chefe.position+Vector2(180,110)
	for acao in ["andar","combo","pancada","investida","conjurar","transformar","cair","morte"]:
		chefe._tocar(acao,true)
		var dados: Dictionary=chefe.FICHA_CERNE.data.animacoes[acao]
		for i in dados.quadros.size():
			chefe.tempo_animacao=.001
			for j in i:chefe.tempo_animacao+=float(dados.duracoes[j])
			chefe._aplicar_quadro()
			await quadros(2);await foto("05-"+acao+"-"+str(i))
		# Reprodução com tempos reais no Godot, usando os mesmos quadros do atlas.
		chefe._tocar(acao,true)
		var tempo:=0.0
		var duracao:=0.0
		for t in dados.duracoes:duracao+=float(t)
		if dados.loop:duracao*=2
		while tempo<duracao:
			await process_frame
			var delta:=minf(root.get_process_delta_time(),.1)
			chefe._animar(delta);tempo+=delta
	var mortes: Array[int]=[0]
	chefe.inimigo_morreu.connect(func():mortes[0]+=1)
	chefe.receber_dano(9999)
	verificar("morte cancela ataques e apoios",chefe.esta_morto and chefe._avisos.is_empty() and chefe.apoios.is_empty())
	chefe._physics_process(3.1)
	verificar("vitória espera a animação e é emitida uma vez",mortes[0]==1)
	alvo.queue_free();await quadros()
	for tamanho in [Vector2i(576,324),Vector2i(320,324),Vector2i(288,512)]:
		root.content_scale_size=tamanho;root.size=tamanho*2
		cena.fala_do_cerne("A Árvore ainda chama vocês…","Mas esta passagem permanece fechada.")
		await quadros(10)
		var painel: Rect2=cena.hud.faixa_banner.get_global_rect().grow(-4)
		for rotulo in [cena.hud.rotulo_banner,cena.hud.subtitulo_banner]:
			verificar("fala respeita moldura "+str(tamanho),painel.encloses(rotulo.get_global_rect()))
		await foto("06-fala-"+str(tamanho.x)+"x"+str(tamanho.y))
	print("FALHAS: ",falhas)
	quit(falhas)
