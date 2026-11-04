extends SceneTree
## Duas instâncias do motor: saguão por estágio, WebRTC, combate e saves isolados.
var falhas := 0
var host := false
var pasta := ""
var sessao: Node
var mensagens: Array[String]=[]
func _initialize() -> void: rodar.call_deferred()
func conferir(ok: bool, texto: String) -> void:
	print("OK " if ok else "FALHA ",texto)
	if not ok: falhas+=1
func esperar(condicao: Callable, segundos := 30.0) -> bool:
	var fim := Time.get_ticks_msec()+int(segundos*1000)
	while Time.get_ticks_msec()<fim:
		if condicao.call(): return true
		await process_frame
	return false
func marcar(nome: String, texto := "ok") -> void:
	FileAccess.open(pasta.path_join(nome),FileAccess.WRITE).store_string(texto)
func tem(nome: String) -> bool: return FileAccess.file_exists(pasta.path_join(nome))
func rodar() -> void:
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"): quit(1);return
	for arg in OS.get_cmdline_user_args():
		if arg=="--host":host=true
		if arg.begins_with("--coop-teste-pasta="):pasta=arg.trim_prefix("--coop-teste-pasta=")
	if not pasta.begins_with("/tmp/"):quit(1);return
	await process_frame
	sessao=load("res://codigo/campanha/sessao_expedicao.gd").obter_expedicao(self)
	sessao.erro.connect(func(texto):print("AVISO ",texto))
	sessao.mensagem_sala.connect(func(_autor,texto):mensagens.append(texto))
	if host:
		sessao.solicitar("criar","chegada")
		if not await esperar(func():return not sessao.codigo.is_empty()):conferir(false,"criar sala de chegada");quit(1);return
		marcar("sala",sessao.codigo)
	else:
		if not await esperar(func():return tem("sala")):quit(1);return
		var salas: Array=[]
		sessao.salas_recebidas.connect(func(recebidas):salas.assign(recebidas))
		sessao.solicitar("listar","chegada")
		conferir(await esperar(func():return salas.size()==1 and salas[0].regiao=="chegada"),"lista mostra o estágio correto")
		sessao.solicitar("entrar","chegada",FileAccess.get_file_as_string(pasta.path_join("sala")))
	conferir(await esperar(func():return sessao.conectado),"WebRTC da expedição conectado")
	if falhas:quit(1);return
	if host:
		conferir(sessao.enviar_chat("Prontos para a clareira?"),"líder envia mensagem na sala")
		conferir(await esperar(func():return "Vamos!" in mensagens),"líder recebe resposta do convidado")
	else:
		conferir(await esperar(func():return "Prontos para a clareira?" in mensagens),"convidado recebe conversa da sala")
		conferir(sessao.enviar_chat("Vamos!"),"convidado responde antes da partida")
	if host:sessao.iniciar()
	conferir(await esperar(func():return current_scene!=null and current_scene.get("mundo_online")!=null),"entra na clareira compartilhada")
	if falhas:quit(1);return
	var cena=current_scene
	var controle=cena.mundo_online
	conferir(cena.regiao=="chegada" and not root.has_node("CoopOnline"),"sessão separada da arena")
	conferir(await esperar(func():return controle.parceiros.size()==1),"avatar do parceiro presente")
	cena.jogador.position=cena.alvos.espada_inicial.no.position
	conferir(cena.interagir_proximo()==OK,"abre baú pessoal antes de coletar")
	conferir(await esperar(func():return cena.terreno.estado_bau==cena.terreno.EstadoBau.ABERTO),"animação termina antes de liberar saque")
	for id in ["espada_inicial","escudo_inicial"]:
		await process_frame
		cena.jogador.position=cena.alvos[id].no.position
		cena.jogador.velocity=Vector2.ZERO
		conferir(cena.interagir_proximo()==OK,"equipamento pessoal "+id)
	await process_frame
	cena.jogador.position=cena.alvos.kit_resgate.no.position
	cena.jogador.velocity=Vector2.ZERO
	conferir(cena.interagir_proximo()==OK,"investiga posto antes de enfrentar o guardiao")
	if cena.interface._telas.introducao.visible:cena.interface._telas.introducao._fechar_fala()
	await process_frame
	marcar("equipado-host" if host else "equipado-convidado")
	if host:
		await esperar(func():return tem("equipado-convidado"))
		conferir(is_instance_valid(cena.inimigo),"anfitrião simula o rebento")
		if not is_instance_valid(cena.inimigo):quit(1);return
		conferir(cena.inimigo.scene_file_path.ends_with("rebento_raizes.tscn"),"campanha usa monstro de raízes próprio")
		cena.inimigo.ia_habilitada=false
		marcar("inimigo",str(cena.inimigo.position.x)+","+str(cena.inimigo.position.y))
		conferir(await esperar(func():return tem("replica-raiz")),"convidado recebeu o visual do rebento")
		conferir(cena.inimigo.iniciar_combo(Vector2.DOWN)==OK,"anfitrião inicia preparação do combo")
		marcar("aviso-raiz")
		conferir(await esperar(func():return tem("dano")),"golpe do convidado chega ao anfitrião")
		conferir(cena.inimigo.vida<18,"vida compartilhada diminuiu")
		conferir(cena.registro_run.dados().grupo.any(func(p):return p.id!=sessao.eu and p.dano>0),"anfitriao registra dano efetivo do convidado")
		cena.inimigo.receber_dano(9999)
		conferir(await esperar(func():return tem("combate")),"vitória registrada pelo convidado")
		var cerne=load("res://cenas/inimigos/cerne_partido.tscn").instantiate()
		cerne.position=Vector2(82,-237)
		cerne.fala.connect(cena.fala_do_cerne)
		cena.saque_inicial.registrar(cerne,"cerne")
		cena.add_child(cerne);cerne.set_physics_process(false)
		conferir(await esperar(func():return tem("cerne-visual")),"convidado recebeu boss próprio")
		cerne._physics_process(1.9)
		conferir(await esperar(func():return tem("cerne-caindo")),"queda sincroniza deslocamento do sprite")
		cerne._physics_process(.4)
		conferir(await esperar(func():return tem("cerne-fala")),"fala do boss sincronizada")
		cerne._physics_process(4.3)
		cerne.receber_dano(250);cerne._physics_process(2.1)
		cerne.iniciar_especial("raizes");cerne._physics_process(1.4)
		conferir(await esperar(func():return tem("cerne-apoios")),"apoios cortáveis replicados")
		for apoio in cerne.apoios.duplicate():apoio.receber_dano(10)
		cerne.receber_dano(9999);cerne._physics_process(3.1)
		conferir(tem_azul(cena.jogador.inventario),"anfitriao recebe armadura azul pessoal do Cerne")
		conferir(await esperar(func():return tem("saque-azul")),"convidado confirma recompensa pessoal antes de sair")
		marcar("sair")
		await create_timer(0.5).timeout
		cena.voltar_ao_mapa()
		conferir(await esperar(func():return current_scene is Control),"anfitrião volta ao mapa")
		conferir(await esperar(func():return tem("fim")),"convidado retorna após saída do anfitrião")
	else:
		conferir(await esperar(func():return controle._inimigos.size()>0),"convidado recebe réplica sem IA local")
		conferir(cena.rebentos_espalhados.is_empty(),"convidado não duplica rebentos com IA local")
		await esperar(func():return tem("inimigo") and controle._inimigos.size()==11)
		conferir(controle._inimigos.size()==11,"sala replica encontro inicial e dez rebentos")
		var coordenadas:=FileAccess.get_file_as_string(pasta.path_join("inimigo")).split(",")
		var posicao_inicial:=Vector2(float(coordenadas[0]),float(coordenadas[1]))
		var alvo=controle._inimigos.values()[0]
		for replica in controle._inimigos.values():
			if replica.position.distance_to(posicao_inicial)<alvo.position.distance_to(posicao_inicial): alvo=replica
		conferir(alvo.sprites[0].hframes==8 and alvo.sprites[0].vframes==6,"réplica conserva grade das animações do rebento")
		marcar("replica-raiz")
		await esperar(func():return tem("aviso-raiz"))
		var aviso_recebido: bool=await esperar(func():return not controle._espelhos.is_empty())
		conferir(aviso_recebido,"convidado recebe aviso do ataque antes do dano")
		if not aviso_recebido:quit(1);return
		cena.jogador.position=alvo.position+Vector2(0,20)
		await create_timer(0.3).timeout
		var hp: int=alvo.vida
		controle.pedir_golpe(alvo.identificador,4,Vector2.ZERO)
		conferir(await esperar(func():return is_instance_valid(alvo) and alvo.vida<hp),"dano confirmado pela simulação do anfitrião")
		marcar("dano")
		conferir(await esperar(func():return "combate" in cena.controlador.progresso.objetivos_cumpridos("sobreviver_queda")),"vitória compartilhada respeita objetivos pessoais")
		marcar("combate")
		conferir(await esperar(func():return controle._inimigos.values().any(func(no):return is_instance_valid(no) and no.nome_chefe=="Cerne Partido")),"boss nasce como réplica sem IA local")
		var boss_visual: Node
		for no in controle._inimigos.values():
			if no.nome_chefe=="Cerne Partido":boss_visual=no
		if boss_visual==null:quit(1);return
		conferir(boss_visual.sprites[0].vframes==5 and boss_visual.get_child(1).shape is CapsuleShape2D and boss_visual.get_child(1).shape.radius==27 and boss_visual.get_child(1).position.y==-27,"boss preserva atlas e colisão próprios")
		marcar("cerne-visual")
		conferir(await esperar(func():return boss_visual.sprites[0].position.y<-100),"convidado vê boss acima do solo")
		marcar("cerne-caindo")
		conferir(await esperar(func():return cena.hud.rotulo_banner.text.contains("A Árvore ainda chama")),"convidado recebe fala de chegada")
		marcar("cerne-fala")
		conferir(await esperar(func():return controle._inimigos.size()>=14),"convidado recebe três apoios da conjuração")
		marcar("cerne-apoios")
		conferir(await esperar(func():return "cerne" in cena.jogador.inventario.saque_campanha.garantias),"convidado recebe evento de saque do anfitriao")
		conferir(tem_azul(cena.jogador.inventario),"convidado conserva azul na mochila ou como pendencia")
		var recibos:int=cena.jogador.inventario.saque_campanha.recibos.size()
		controle._receber({"t":"saque_inicial","de":"outro_convidado","evento":"falso","regiao":"chegada","x":0,"y":0,"garantia":"cerne"})
		conferir(cena.jogador.inventario.saque_campanha.recibos.size()==recibos,"convidado rejeita saque enviado por outro convidado")
		conferir(await esperar(func():return cena.registro_run.dados().grupo.any(func(p):return p.dano>0)),"resultado recebe dano confirmado pelo anfitriao")
		var seq_antes: int=cena.registro_run._ultimo_seq
		controle._receber({"t":"resumo_campanha","de":"outro_convidado","resumo":{"regiao":"chegada","seq":999999}})
		conferir(cena.registro_run._ultimo_seq==seq_antes,"convidado rejeita ranking forjado")
		marcar("saque-azul")
		conferir(await esperar(func():return current_scene is Control),"fim da sala retorna ao mapa da campanha")
		marcar("fim")
	conferir(not root.get_node("Progresso").partida_ativa,"expedição não inicia run da arena")
	print("FALHAS: ",falhas)
	sessao.sair()
	quit(falhas)

func tem_azul(inv:Node) -> bool:
	for item in inv.mochila+inv.equipados.values():
		if item!=null and item.tipo.ends_with("_guarda_novato") and item.raridade=="raro":return true
	for p in inv.saque_campanha.get("pendentes",{}).values():
		if p.get("item",{}).get("raridade")=="raro":return true
	return false
