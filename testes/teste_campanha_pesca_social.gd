extends SceneTree
var falhas:=0
var cena: Node2D
var capturas:="/tmp/campanha-social-previas"
func _initialize():rodar.call_deferred()
func verificar(nome: String,ok: bool):
	print("OK " if ok else "FALHA ",nome)
	if not ok:falhas+=1
func quadros(n:=8):
	for i in n:await process_frame
func parar_cinema():
	for no in cena.get_children():
		if no.has_method("pular") and no.get("ativa"):no.pular()
	await quadros(8)
func foto(nome: String):
	await RenderingServer.frame_post_draw
	verificar("captura "+nome,root.get_texture().get_image().save_png(capturas.path_join(nome+".png"))==OK)
func capturar_peixe(id: String):
	var j: Node=cena.jogador
	var rio=load("res://codigo/campanha/pesca_rios.gd")
	var margem: Vector2=rio.margem_proxima(cena.terreno,j.position)
	verificar("há margem real e caminhável",margem.is_finite())
	if not margem.is_finite():return
	j.position=margem
	var direcao:=Vector2.ZERO
	for d in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]:
		if cena.alvo_pesca_rio(margem+Vector2(0,14),d,44).is_finite():direcao=d;break
	j.parar_para_conversa(j.global_position+direcao*32)
	j.inventario.definir_vara_na_mao(true)
	verificar("vara lança olhando para o rio",load("res://codigo/pesca/ponto_pesca.gd").tentar_lancar(j))
	var sessao=j.get_node_or_null("SessaoPesca")
	if sessao==null:verificar("sessão de pesca criada",false);return
	sessao.forca_lancamento=1.0;sessao._lancar()
	verificar("boia carregada permanece dentro da água",cena.terreno.peso_agua(j.to_global(sessao._alvo))>=0.65)
	sessao.peixe=id;sessao._pegar(false)
	await quadros(8)
	await foto("captura-"+id+"-"+str(cena.controlador.progresso.objetivos_cumpridos("pesca_primeiras_fisgadas").size()))
	sessao._terminar();await quadros(5)
func rodar():
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes") or DisplayServer.get_name()=="headless":quit(1);return
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--capturas="):capturas=a.trim_prefix("--capturas=")
	root.get_node("Ranking").conexao_habilitada=false
	DirAccess.make_dir_recursive_absolute(capturas)
	root.size=Vector2i(1152,648);root.content_scale_size=Vector2i(576,324)
	var p=load("res://codigo/campanha/progresso_campanha.gd").new()
	p.iniciar("user://percurso_primeira_raiz","prototipo")
	for id in ["sobreviver_queda","estrada_interrompida","acolhimento"]:p.confirmar_conclusao(id)
	set_meta("campanha_destino","vila");set_meta("campanha_nova_instancia",true)
	change_scene_to_file("res://cenas/campanha/percurso_prototipo.tscn")
	await quadros(100);cena=current_scene
	var inv: Node=cena.jogador.inventario
	verificar("cidade abre como praça pública",is_instance_valid(cena.lobby_cidade) and cena.lobby_cidade.mapa==4 and not cena.cinema_cidade_ativa())
	verificar("acolhimento não reinicia",cena.controlador.progresso.missao_concluida("acolhimento"))
	verificar("só a vara permanece entre os utensílios",inv.buscar_por_tipo("vara_pesca")!=null or inv.mochila.any(func(item):return item!=null and item.categoria=="vara"))
	verificar("ferramentas agrícolas ficam fora da campanha",not inv.mochila.any(func(item):return item!=null and item.categoria=="ferramenta"))
	cena.jogador.position=cena.alvos.leilao.no.position
	await quadros(3)
	verificar("barraca abre leilão",cena.interagir_proximo()==OK)
	await quadros(12)
	var mercado: Node=cena.interface._telas.mercado
	verificar("leilão usa cliente de ouro e conta da campanha",mercado.visible and mercado._cliente.nome_moeda()=="OURO" and mercado._cliente.arquivo.begins_with("user://percurso_primeira_raiz/"))
	await foto("leilao-pc")
	root.content_scale_size=Vector2i(480,270);root.size=Vector2i(960,540)
	await quadros(12);await foto("leilao-mobile")
	verificar("painel de leilão cabe no celular",Rect2(Vector2.ZERO,Vector2(480,270)).encloses(mercado.painel.get_global_rect()))
	cena.interface._fechar_tela("mercado")
	root.content_scale_size=Vector2i(576,324);root.size=Vector2i(1152,648)
	verificar("Nilo aceita pedido opcional",cena.controlador.interagir("conversar","nilo")==OK)
	var ouro_antes: int=inv.ouro_campanha
	verificar("clareira continua acessível",cena.abrir_regiao("chegada",false)==OK)
	await quadros(35);await parar_cinema()
	verificar("cartão acompanha o pedido de pesca ativo",cena.objetivo_de_campanha().id=="pesca_primeiras_fisgadas" and cena.objetivo_de_campanha().secundaria)
	verificar("não pesca longe da água",not cena.alvo_pesca_rio(Vector2.ZERO,Vector2.DOWN,44).is_finite())
	for i in 3:await capturar_peixe("carpa")
	verificar("três capturas ficam no diário",cena.controlador.progresso.objetivos_cumpridos("pesca_primeiras_fisgadas").has("captura_3"))
	cena.abrir_regiao("vila");await quadros(35)
	verificar("Nilo recebe relato",cena.controlador.interagir("conversar","nilo")==OK)
	await quadros(12)
	verificar("pedido paga 30 de ouro",inv.ouro_campanha==ouro_antes+30)
	cena._conferir_missoes();await quadros(3)
	verificar("recompensa não duplica",inv.ouro_campanha==ouro_antes+30)
	# A missão principal vem antes: a primeira conversa com Lia é o aviso da defesa.
	verificar("Lia dá o aviso da defesa primeiro",cena.controlador.interagir("conversar","lia")==OK and "aviso" in cena.controlador.progresso.objetivos_cumpridos("defesa_da_vila"))
	verificar("Lia libera pedido de carpas",cena.controlador.interagir("conversar","lia")==OK and "pedido" in cena.controlador.progresso.objetivos_cumpridos("pesca_carpas_da_vila"))
	cena.abrir_regiao("chegada",false);await quadros(35);await parar_cinema()
	await capturar_peixe("bagre")
	verificar("pedido de carpas não conta outras espécies",not "captura_1" in cena.controlador.progresso.objetivos_cumpridos("pesca_carpas_da_vila"))
	for i in 2:await capturar_peixe("carpa")
	cena.abrir_regiao("vila");await quadros(35)
	verificar("Lia recebe relato das carpas",cena.controlador.interagir("conversar","lia")==OK)
	await quadros(12)
	verificar("dois pedidos pagam 80 de ouro",inv.ouro_campanha==ouro_antes+80)
	var reaberto=load("res://codigo/campanha/progresso_campanha.gd").new()
	reaberto.iniciar("user://percurso_primeira_raiz","prototipo")
	verificar("pedidos persistem ao reabrir",reaberto.missao_concluida("pesca_primeiras_fisgadas") and reaberto.missao_concluida("pesca_carpas_da_vila"))
	var cidade_antes: Node=cena.terreno
	verificar("estágio 5 continua bloqueado sem trocar a cidade",cena.abrir_regiao("moinho")==ERR_UNAUTHORIZED and cena.terreno==cidade_antes)
	verificar("vara e peixes são preservados na cidade",inv.mochila.any(func(item):return item!=null and item.categoria=="vara") and inv.buscar_por_tipo("peixe:carpa")!=null)
	await foto("cidade-final")
	# Reabrir com retorno junto à barraca não pode trazer o banco para o leilão.
	cena.jogador.position=cena.alvos.leilao.no.position
	cena.salvar_retorno()
	cena.abrir_regiao("vila");await quadros(35)
	cena.jogador.position=cena.alvos.leilao.no.position
	verificar("retorno preserva interações distintas",cena.alvo_proximo()=="leilao" and cena.alvos.descanso.no.position.distance_to(cena.alvos.leilao.no.position)>34)
	verificar("leilão reabre depois do retorno",cena.interagir_proximo()==OK)
	await quadros(12)
	mercado=cena.interface._telas.mercado
	mercado._trocar_aba(1)
	mercado._escolher_item(inv.buscar_por_tipo("peixe:carpa"))
	root.content_scale_size=Vector2i(480,270);root.size=Vector2i(960,540)
	await quadros(12)
	verificar("taxa de venda mostra ouro",mercado._recebe_venda.text.contains("OURO") and not mercado._recebe_venda.text.contains("BRASA"))
	verificar("formulário de venda cabe no celular",Rect2(Vector2.ZERO,Vector2(480,270)).encloses(mercado.painel.get_global_rect()))
	await foto("vender-mobile")
	mercado._trocar_aba(2);await quadros(12)
	await foto("meus-mobile")
	print("FALHAS: ",falhas)
	quit(falhas)
