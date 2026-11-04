extends SceneTree

class SessaoTeste:
	extends Node
	signal salas_recebidas(salas: Array)
	signal mudou
	signal erro(texto: String)
	signal mensagem_sala(autor: String,texto: String)
	var codigo:=""
	var eu:="ana"
	var dono:="ana"
	var jogadores: Array=[]
	var pedidos: Array=[]
	var iniciado:=false
	func sou_host() -> bool:return eu==dono
	func todos_conectados() -> bool:return true
	func esta_conectado(_id: String) -> bool:return true
	func solicitar(acao: String,regiao: String,sala:="") -> void:pedidos.append([acao,regiao,sala])
	func iniciar() -> void:iniciado=true
	func sair() -> void:codigo=""
	func enviar_chat(texto: String) -> bool:mensagem_sala.emit("ANA",texto);return true

var falhas:=0
var dialogo: CanvasLayer
func _initialize() -> void:rodar.call_deferred()
func verificar(nome: String,ok: bool) -> void:
	print("OK " if ok else "FALHA ",nome)
	if not ok:falhas+=1
func quadros(n:=10) -> void:
	for i in n:await process_frame
func foto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	verificar("captura "+nome,root.get_texture().get_image().save_png("res://capturas-salas-campanha/"+nome+".png")==OK)
func area_visivel(no: Control) -> Rect2:
	var area:=no.get_global_rect()
	var pai:=no.get_parent()
	while pai!=null:
		if pai is Control and pai.clip_contents:area=area.intersection(pai.get_global_rect())
		pai=pai.get_parent()
	return area
func conferir(tamanho: Vector2i) -> void:
	verificar("painel cabe "+str(tamanho),Rect2(Vector2.ZERO,Vector2(tamanho)).encloses(dialogo.painel.get_global_rect()))
	for rotulo in dialogo.painel.find_children("*","Label",true,false):
		var area:=area_visivel(rotulo)
		if area.has_area():verificar("texto respeita moldura "+str(tamanho),dialogo.painel.get_global_rect().grow(-8).encloses(area))
func rodar() -> void:
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes") or DisplayServer.get_name()=="headless":quit(1);return
	auto_accept_quit=false
	root.mode=Window.MODE_WINDOWED
	DirAccess.make_dir_recursive_absolute("res://capturas-salas-campanha")
	var sessao:=SessaoTeste.new();root.add_child(sessao)
	dialogo=load("res://codigo/campanha/dialogo_salas.gd").new()
	dialogo.regiao="chegada";dialogo.nome_regiao="Clareiras da Chegada";dialogo.sessao=sessao
	root.add_child(dialogo)
	var salas: Array=[{"campanha":"campanha_primeira_raiz_v1","regiao":"chegada","codigo":"RAIZ01","anfitriao":"Ana e os aventureiros do vale","jogadores":2,"maximo":4,"em_partida":false},{"campanha":"campanha_primeira_raiz_v1","regiao":"chegada","codigo":"RAIZ02","anfitriao":"Lia","jogadores":4,"maximo":4,"em_partida":false}]
	dialogo._receber_salas(salas)
	for tamanho in [Vector2i(576,324),Vector2i(960,540),Vector2i(320,324),Vector2i(288,512)]:
		root.content_scale_size=tamanho;root.size=tamanho*2
		await quadros(15);conferir(tamanho)
		await foto("01-estagio-"+str(tamanho.x)+"x"+str(tamanho.y))
	dialogo._entrar_rapido()
	verificar("entrada rápida escolhe vaga disponível",sessao.pedidos[-1]==["entrar","chegada","RAIZ01"])
	sessao.codigo="RAIZ01"
	for i in 4:sessao.jogadores.append({"id":"ana" if i==0 else "amigo"+str(i),"perfil":{"apelido":"ANA" if i==0 else "Aventureiro de nome comprido "+str(i),"visual":{"versao":1,"cabelo":i+1,"roupa":i+1}}})
	dialogo._atualizar()
	verificar("sala possui quatro cartões reais",dialogo.vagas.get_child_count()==4 and dialogo._avatares.size()==4)
	for tamanho in [Vector2i(576,324),Vector2i(960,540),Vector2i(320,324),Vector2i(288,512)]:
		root.content_scale_size=tamanho;root.size=tamanho*2
		await quadros(20);conferir(tamanho)
		print("AVATAR ",tamanho," palco=",dialogo._avatares[0].get_parent().size," desenho=",dialogo._avatares[0].get_meta("limites_desenho",Rect2())," escala=",dialogo._avatares[0].scale," corpo=",dialogo.conteudo.size)
		await foto("02-sala-"+str(tamanho.x)+"x"+str(tamanho.y))
	dialogo.entrada_chat.text="Vamos proteger a clareira!";dialogo._enviar_chat()
	verificar("chat aparece e limpa entrada",dialogo.historico_chat.text.contains("ANA: Vamos proteger") and dialogo.entrada_chat.text.is_empty())
	dialogo.iniciar.pressed.emit();verificar("botão inicia a sessão",sessao.iniciado)
	sessao.eu="amigo1";dialogo._atualizar();verificar("convidado aguarda o anfitrião",dialogo.iniciar.disabled)
	sessao.jogadores.resize(1);dialogo._atualizar();await quadros()
	verificar("vagas livres mantêm quatro cartões",dialogo.vagas.get_child_count()==4 and dialogo._avatares.size()==1)
	await foto("03-vagas-abertas")
	dialogo.fechar();await quadros()
	print("FALHAS: ",falhas);quit(falhas)
