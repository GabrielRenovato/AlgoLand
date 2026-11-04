extends Node

## Conteúdo exclusivo do segundo estágio; não altera abertura nem encontros da chegada.
var terreno: Node2D
var cena: Node2D
var rebentos: Array[Node2D] = []
var _anunciado := false
var _investigou := false
var _tutorial: Control
var _tutorial_visivel := false
var _tutorial_recebia_input := false
var _tutorial_processava := false
var trabalhador: CharacterBody2D
var _nome_medido := false

func _ready() -> void:
	cena = terreno.get_parent()
	_tutorial=cena.hud.get_node_or_null("MiniTutorial")
	if _tutorial!=null:
		_tutorial_visivel=_tutorial.visible
		_tutorial_recebia_input=_tutorial.is_processing_input()
		_tutorial_processava=_tutorial.is_processing()
		_tutorial.hide()
		_tutorial.set_process_input(false)
		_tutorial.set_process(false)
	for id in ["carreto","trabalhador","saida_regiao"]:
		var alvo: Dictionary = cena.alvos[id]
		var antigo: Node2D = alvo.no
		var no := preload("res://codigo/campanha/interacao_estrada.gd").new()
		no.id = id
		no.roteiro = self
		no.cena_responsavel = cena
		no.so_entre_ondas = false
		no.position = antigo.position
		no.z_index = antigo.z_index
		no.deslocamento_aviso = Vector2(0,-45 if id=="trabalhador" else -28)
		cena.add_child(no)
		for filho in antigo.get_children():
			if filho is Sprite2D and filho!=antigo._aviso: filho.reparent(no)
		alvo.rotulo.reparent(no)
		alvo.rotulo.z_as_relative=false
		alvo.rotulo.z_index=899
		alvo.no = no
		antigo.queue_free()
	_criar_trabalhador()
	if cena.sessao==null or not cena.sessao.ativo or cena.sessao.sou_host():
		_criar_encontros()

func _criar_trabalhador() -> void:
	var gerador := preload("res://codigo/dados/gerador_npcs.gd")
	var ficha := gerador.gerar(72021,"agricultor")
	ficha.nome="Trabalhador refugiado"
	ficha.aparencia.roupas_3d={"camisa":"colete_agricultor","calca":"calca_cargo","calcado":"botinas_trabalho","cabelo":"cabelo_cacheado"}
	var pele := Color("c89270")
	var cabelo := Color("51372b")
	ficha.aparencia.cor_pele=[pele.r,pele.g,pele.b]
	ficha.aparencia.cor=[cabelo.r,cabelo.g,cabelo.b,1.0]
	trabalhador=preload("res://cenas/npcs/npc_gerado.tscn").instantiate()
	trabalhador.name="TrabalhadorGerado"
	trabalhador.ficha=gerador.normalizar(ficha)
	trabalhador.z_as_relative=false
	cena.alvos.trabalhador.no.add_child(trabalhador)
	trabalhador.visual.renderizado.connect(_alinhar_trabalhador,CONNECT_ONE_SHOT)

func _alinhar_trabalhador() -> void:
	# O nome nativo é substituído pela indicação de proximidade da campanha.
	trabalhador.get_node("NomeNPC").hide()
	var alvo: Dictionary=cena.alvos.trabalhador
	var rotulo: Label=alvo.rotulo
	var desenho: Rect2=trabalhador.visual.retangulo_aparente()
	_nome_medido=desenho.has_area()
	var topo: float=desenho.position.y if _nome_medido else -40.0
	rotulo.position=Vector2(-rotulo.size.x/2,topo-rotulo.size.y-6)
	alvo.no.deslocamento_aviso=Vector2(0,rotulo.position.y-13)
	alvo.no._aviso.position=alvo.no.deslocamento_aviso

func _criar_encontros() -> void:
	for grupo in terreno.dados.encontros:
		for ponto in grupo.pontos:
			var inimigo := preload("res://cenas/inimigos/rebento_raizes.tscn").instantiate()
			inimigo.name = "RebentoEstrada_"+str(rebentos.size())
			var previsto := Vector2(ponto[0],ponto[1])
			inimigo.position = previsto if terreno.ponto_seguro(previsto) else terreno.ponto_livre(previsto)
			inimigo.vida = 24
			inimigo.dano = 2
			inimigo.raio_percepcao = 110.0
			# Pertence ao terreno para encerrar junto dele ao voltar ao mapa.
			cena.saque_inicial.registrar(inimigo)
			terreno.add_child(inimigo)
			rebentos.append(inimigo)

func _process(_delta: float) -> void:
	if not is_instance_valid(cena.jogador) or cena.interface==null: return
	# A primeira renderização pode ocorrer fora da câmera. Medir uma única vez
	# quando a silhueta existir, sem ler o SubViewport a cada quadro da partida.
	if not _nome_medido and is_instance_valid(trabalhador) and trabalhador._aviso.is_on_screen():
		_alinhar_trabalhador()
	if not _anunciado and cena.interface._telas_abertas.is_empty():
		_anunciado=true
		cena.hud.anunciar("Estrada dos Carreteiros","Siga os rastros do ataque até o abrigo.",3)

func _contar(texto: String, titulo: String) -> void:
	cena.hud.faixa_banner.hide()
	var paginas: Array[String] = [texto]
	cena.interface._telas.introducao.iniciar(paginas,titulo)
	EventosJogo.abrir_tela_de(cena.jogador,"introducao")

func interagir(id: String) -> Error:
	if cena._ocupado or cena._frame_ultima_interacao==Engine.get_process_frames() or cena.jogador.estaMorto or not cena.interface._telas_abertas.is_empty(): return ERR_BUSY
	if cena.alvo_proximo()!=id:return ERR_UNAVAILABLE
	cena._frame_ultima_interacao=Engine.get_process_frames()
	if id=="saida_regiao":
		if not cena.controlador.progresso.missao_concluida("estrada_interrompida"):
			var feitos: Array = cena.controlador.progresso.objetivos_cumpridos("estrada_interrompida")
			cena._avisar("Fale com o trabalhador refugiado antes de seguir para a vila." if "carreto" in feitos else "Examine o carreto e fale com o trabalhador refugiado antes de seguir para a vila.")
			return ERR_UNAVAILABLE
		var vivos := rebentos.filter(func(r): return is_instance_valid(r) and not r.is_queued_for_deletion()).size()
		if vivos>0:
			cena._avisar("Ainda há %d rebento%s na estrada. Derrote %s para concluir a estrada." % [vivos,"" if vivos==1 else "s","o" if vivos==1 else "todos"])
			return ERR_BUSY
		cena._mostrar_conclusao("ESTRADA CONCLUÍDA", "Você encontrou o trabalhador com vida. Siga até a Vila das Flores e conte a Dara onde ele está.", "vila")
		return OK
	var lado: Error = cena.controlador.interagir("recuperar" if id=="carreto" else "entregar",id)
	if lado==OK:
		cena.salvar_retorno()
		_contar("Entre as tábuas quebradas ainda há cintas de ferro, pinos e um aro inteiro. Dá para levar tudo a Ivo." if id=="carreto" else "Rosa mandou isto? Diga a ela que as raízes não fazem barulho: sobem por baixo da terra, como se soubessem onde pisamos.","Ferragens do carreto" if id=="carreto" else "Trabalhador refugiado")
		return OK
	var tipo := "investigar" if id=="carreto" else "conversar"
	var erro: Error = cena.controlador.interagir(tipo,id)
	# O relato a Dara pertence ao acolhimento, após concluir a estrada.
	if erro==OK:cena.salvar_retorno()
	if erro!=OK and erro!=ERR_UNAVAILABLE:
		cena._resposta(id,erro)
		return erro
	if id=="carreto":
		_investigou=true
		_contar("O eixo cedeu quando as raízes atravessaram a estrada. Parte da carga foi arrastada, mas há pegadas saindo do carreto: alguém fugiu pelo acostamento, em direção ao abrigo de madeira.","O carreto interrompido")
	else:
		trabalhador.iniciar_conversa(cena.jogador.global_position)
		cena._morador_conversando=trabalhador
		_contar("Eu carregava mantimentos para a vila. As raízes vieram por baixo das rodas… Soltei a carga e corri até este abrigo. Se encontrar a Dara, diga que estou vivo. Ela conhece este caminho.","Trabalhador refugiado")
	return erro if erro!=ERR_UNAVAILABLE else OK

func _exit_tree() -> void:
	if is_instance_valid(_tutorial):
		_tutorial.visible=_tutorial_visivel
		_tutorial.set_process_input(_tutorial_recebia_input)
		_tutorial.set_process(_tutorial_processava)
	# As interações pertencem ao cenário e são removidas por abrir_regiao.
	for inimigo in rebentos:
		if is_instance_valid(inimigo): inimigo.queue_free()
