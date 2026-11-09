extends SceneTree
## Reações dos moradores ao progresso, conversas guardadas no save e cartão de encerramento do beta.
const Elenco=preload("res://codigo/dados/moradores_primeira_raiz.gd")
const Reacoes=preload("res://codigo/dados/reacoes_primeira_raiz.json")
var cena:Node2D
var falhas:=0
var capturas:="user://capturas-reacoes"
func _initialize():rodar.call_deferred()
func conferir(texto:String,ok:bool):
	print("OK " if ok else "FALHA ",texto)
	if not ok:falhas+=1
func quadros(n:=8):
	for i in n:await process_frame
func foto(nome:String):
	await RenderingServer.frame_post_draw
	conferir("captura "+nome,root.get_texture().get_image().save_png(capturas.path_join(nome+".png"))==OK)
func fechar():
	cena.interface._telas.introducao._fechar_fala()
	await quadros(3)
func falar(id:String) -> String:
	conferir("conversa com "+id,cena._conversar_morador(id)==OK)
	var texto:String=cena.interface._telas.introducao._paginas[0]
	await fechar()
	return texto
func tecla():
	var evento:=InputEventKey.new()
	evento.keycode=KEY_SPACE;evento.pressed=true
	root.push_input(evento)
	await quadros(2)

func rodar():
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes") or DisplayServer.get_name()=="headless":quit(1);return
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--capturas="):capturas=a.trim_prefix("--capturas=")
	DirAccess.make_dir_recursive_absolute(capturas)
	root.get_node("Ranking").conexao_habilitada=false
	set_meta("dicas_vistas",{"golpe":true,"rebento":true,"vida":true})
	conferir_dados()
	var p=load("res://codigo/campanha/progresso_campanha.gd").new()
	p.iniciar("user://percurso_primeira_raiz","prototipo")
	var catalogo=load("res://codigo/campanha/catalogo_campanha.gd").dados()
	for m in ["sobreviver_queda","estrada_interrompida","acolhimento"]:
		for o in catalogo.missoes[m].objetivos:p.registrar_objetivo(m,o.id)
	conferir("rejeita visitas negativas",p.registrar_conversa("teo",-1,[])==ERR_INVALID_PARAMETER)
	conferir("rejeita reação de missão inexistente",p.registrar_conversa("teo",1,["inexistente"])==ERR_INVALID_PARAMETER)
	p.salvar_retorno("vila",Vector2(0,180))
	set_meta("campanha_nova_instancia",false)
	root.mode=Window.MODE_WINDOWED;root.content_scale_size=Vector2i(576,324);root.size=Vector2i(1152,648)
	change_scene_to_file("res://cenas/campanha/percurso_prototipo.tscn")
	await quadros(70);cena=current_scene
	if cena.cinema_cidade_ativa():cena.cinema_cidade.cancelar()
	cena.registro_run.set_process(false)
	cena.registro_run.apresentada=true
	cena.interface._fechar_tela("resultado")
	cena.jogador.invulneravel=true
	conferir("vila real com moradores",cena.regiao=="vila" and cena.moradores.size()==15)
	await conferir_conversas()
	await conferir_epilogo()
	print("FALHAS: ",falhas);quit(1 if falhas else 0)

## Todo morador reage aos marcos jogáveis do beta, com textos que cabem no diálogo.
func conferir_dados():
	var missoes:Dictionary=load("res://codigo/campanha/catalogo_campanha.gd").dados().missoes
	for id in Elenco.dados():
		var textos:Dictionary=Reacoes.data.get(id,{})
		conferir("reage à chegada, à defesa e ao moinho: "+id,["estrada_interrompida","defesa_da_vila","moinho_vazao"].all(func(m):return textos.has(m)))
		conferir("reações usam missões reais: "+id,textos.keys().all(func(m):return missoes.has(m)))
		conferir("reações curtas: "+id,textos.values().all(func(t):return str(t).length()>20 and str(t).length()<=180))

func conferir_conversas():
	var progresso=cena.controlador.progresso
	var apresentacao:String=Elenco.conversa("teo",0)[0]
	conferir("primeira conversa apresenta",mesma(await falar("teo"),apresentacao))
	conferir("segunda conversa reage ao acolhimento",mesma(await falar("teo"),Reacoes.data.teo.acolhimento))
	var terceira:String=await falar("teo")
	conferir("reação não se repete",not mesma(terceira,Reacoes.data.teo.acolhimento) and not mesma(terceira,apresentacao))
	cena.abrir_regiao("chegada",false);await quadros(35)
	cena.abrir_regiao("vila");await quadros(35)
	if cena.cinema_cidade_ativa():cena.cinema_cidade.cancelar()
	var depois:String=await falar("teo")
	conferir("voltar à vila não repete apresentação nem reação",not mesma(depois,apresentacao) and not mesma(depois,Reacoes.data.teo.acolhimento))
	var reaberto=load("res://codigo/campanha/progresso_campanha.gd").new()
	reaberto.iniciar("user://percurso_primeira_raiz","prototipo")
	conferir("visitas ficam no save",int(reaberto.conversas.get("teo",{}).get("visitas",0))==4 and "acolhimento" in reaberto.conversas.teo.vistas)
	# Marco novo e pedido opcional: primeiro o marco, depois o pedido, cada um uma vez.
	progresso._concluidas.append("defesa_da_vila")
	progresso._concluidas.append("pesca_primeiras_fisgadas")
	conferir("Téo reage à defesa",mesma(await falar("teo"),Reacoes.data.teo.defesa_da_vila))
	conferir("Bia se apresenta antes de reagir",mesma(await falar("bia"),Elenco.conversa("bia",0)[0]))
	conferir("Bia reage à defesa",mesma(await falar("bia"),Reacoes.data.bia.defesa_da_vila))
	conferir("Bia reage à pesca",mesma(await falar("bia"),Reacoes.data.bia.pesca_primeiras_fisgadas))
	var nova:String=await falar("bia")
	conferir("Bia volta às falas comuns",not Reacoes.data.bia.values().any(func(t):return mesma(nova,t)))
	progresso._concluidas.erase("pesca_primeiras_fisgadas")
	progresso._concluidas.erase("defesa_da_vila")

func conferir_epilogo():
	cena._epilogo_pendente=true
	await quadros(4)
	var cartao:Node=cena.get_node_or_null("Epilogo")
	conferir("epílogo abre quando não há tela aberta",cartao!=null and cartao.ativa and not cena._epilogo_pendente)
	if cartao==null:return
	conferir("epílogo mostra o fim do beta",cartao._estado.text=="FIM DO BETA")
	for tamanho in [Vector2i(576,324),Vector2i(288,512)]:
		root.content_scale_size=tamanho;root.size=tamanho*2
		await quadros(6)
		if cartao._revelar!=null:cartao._revelar.kill()
		cartao._historia.visible_ratio=1.0
		await quadros(2)
		var papel:Rect2=cartao._historia.get_parent().get_global_rect()
		conferir("texto do epílogo cabe %s" % tamanho,Rect2(Vector2.ZERO,Vector2(tamanho)).encloses(papel) and cartao._historia.get_line_count()*cartao._historia.get_line_height()<=cartao._historia.size.y+2)
		await foto("epilogo_%dx%d" % [tamanho.x,tamanho.y])
	root.content_scale_size=Vector2i(576,324);root.size=Vector2i(1152,648)
	var limite:=Time.get_ticks_msec()+10000
	while not cartao._pronto and Time.get_ticks_msec()<limite:await process_frame
	await tecla()
	await quadros(45)
	conferir("epílogo fecha com uma tecla",not is_instance_valid(cartao))

## O diálogo divide falas longas em páginas: basta a primeira página bater com o começo do texto.
func mesma(pagina:String,texto:String) -> bool:
	return not pagina.is_empty() and texto.begins_with(pagina.replace("\n"," ").strip_edges())
