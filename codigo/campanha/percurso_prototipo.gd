extends Node2D

## Cena de integração, disponível somente em um projeto de testes isolado.
## Regiões próprias e expedições compartilham apenas eventos validados da campanha.
const Controlador := preload("res://codigo/campanha/controlador_campanha.gd")
const Elenco := preload("res://codigo/dados/moradores_primeira_raiz.gd")
const Preparos := preload("res://codigo/campanha/preparos_ivo.gd")
const TreinoDara := preload("res://codigo/campanha/treino_dara.gd")
const Recompensas := preload("res://codigo/campanha/recompensas_cidade.gd")
const Servicos := preload("res://codigo/campanha/servicos_vila.gd")
var moradores:Dictionary={}
var hora_da_cidade:=10.0
var _visitas_moradores:Dictionary={}
var _reacoes_moradores:Dictionary={}
## O cartão de encerramento do beta abre quando o relato ao Nilo termina.
var _epilogo_pendente:=false
var _morador_conversando:Node
var _treino: Node
var _escolha_ativa := ""
## Poções de cura que vêm no baú de resgate, junto com a espada.
const POCOES_INICIAIS := 5
var _recompensados: Array = []
var _nome_servico := ""
const FALAS_PASSOS := {
	"pesca_primeiras_fisgadas:pedido":"Os rios da clareira têm peixe o ano inteiro. Leve sua vara, segure o ataque olhando para a água e solte para lançar. Pesque três peixes e volte para contar como foi. Pago 30 de ouro pelo relato.",
	"pesca_primeiras_fisgadas:relato":"Três boas fisgadas! Continue praticando. Aqui estão os 30 de ouro; os peixes continuam com você.",
	"pesca_carpas_da_vila:pedido":"Quero saber se as carpas voltaram ao rio. Pesque duas carpas e me traga notícias. Tenho 50 de ouro pelo serviço; você pode ficar com os peixes.",
	"pesca_carpas_da_vila:relato":"As carpas voltaram! Obrigada pela notícia. Aqui estão seus 50 de ouro.",
	"acolhimento:dara": "Você veio pela estrada? Nosso trabalhador ainda não voltou. Me diga por onde passou e por onde voltaria: é assim que eu sei quais caminhos ainda estão de pé.",
	"acolhimento:retorno": "Vivo, então. Vou buscá-lo pelo caminho que você indicou e marcar os dois trechos para a ronda. Obrigada por voltar para contar.",
	"acolhimento:lia": "Você tem cama e comida aqui, sem dever nada por isso. Mas a vila anda apertada: cerca rachando, mantimento sumindo. Fale com o Tomás, ele sabe dizer onde começou.",
	"pomar_sulcos:pedido": "Alguém leva minha colheita e eu não sei dizer quem. Veja a cerca partida, o canal e o chão revirado. Se achar pegadas, não vá atrás sozinho: me traga o que viu.",
	"ferro_que_ainda_serve:pedido": "O eixo do carreto cedeu, mas o ferro das cintas ainda presta. Recupere as ferragens na Estrada dos Carreteiros e traga para mim. Vou separar uma parte para você e lhe dar um projeto de luvas.",
	"ferro_que_ainda_serve:entrega": "Cintas, pinos e até um aro inteiro. Separei 3 ferros e 2 madeiras para você, além do projeto de luvas. Para fabricar: abra a mochila, use o pergaminho da receita e depois consulte essa arma na forja da cidade. A receita fica aprendida; os materiais são consumidos quando encomendar. Cada peça leva de um a três dias para ficar pronta.",
	"quem_ficou_para_tras:pedido": "O trabalhador que você achou mal comeu desde o ataque. Leve estes suprimentos ao abrigo da estrada, veja como ele está e depois me conte.",
	"quem_ficou_para_tras:relato": "As raízes subiram por baixo, sem barulho? Então é isso que anda revirando a estrada. Obrigada por ir até lá. Leve uns curativos para a próxima saída.",
	"defesa_da_vila:aviso": "Os sulcos que você viu na estrada chegaram à entrada sul, e os rebentos vêm primeiro. Leve a ligação do Ivo e monte a barreira; eu aviso o povo.",
	"defesa_da_vila:reparo": "A entrada rachou, mas dá para consertar: temos madeira. O Nilo viu movimento na margem do moinho. Se for lá, siga a trilha da água; a entrada de manutenção fica junto da roda.",
	"moinho_vazao:margem": "A marca nas pedras mostra até onde a água chegava. Agora ela está represada sob a bacia. Pegadas de goblins e marcas de sacos arrastados seguem para a transmissão antiga.",
	"moinho_vazao:comporta": "O comando externo foi calçado com cunhas. Há pegadas de goblins ao redor. A transmissão segue sob a praça; será preciso alcançar a comporta principal pelas galerias.",
	"moinho_vazao:eixo": "A roda está inteira, mas sem corrente não pode girar. As marcas de manutenção levam à escadaria central. Os goblins ocuparam as galerias que dão acesso à alavanca.",
	"moinho_vazao:dungeon": "A alavanca destravou a comporta principal. A corrente voltou ao moinho. Retorne pela entrada e leve a notícia a Nilo.",
	"moinho_vazao:relato": "Ouvi a roda daqui! Com a água de volta, podemos moer o grão que restou. Então os goblins estavam acampados nas galerias, guardando a comporta. Vou avisar a Dara para vigiar a entrada enquanto Osvaldo confere o mecanismo.",
	"antes_de_sair_outra_vez:pedido": "Antes de sair outra vez, quero ver você bloquear, esquivar e responder no tempo. Se o treino sair limpo, a estrada não pega ninguém de surpresa. Quando quiser, peça o boneco.",
}
const DadosCidade := preload("res://codigo/cidade/dados_cidade.gd")
var controlador := Controlador.new()
var jogador: CharacterBody2D
var alvos: Dictionary = {}
var inimigo: Node2D
var rebentos_espalhados: Array[Node2D] = []
var _rebentos_preparados := false
var goblins_espalhados: Array[Node2D] = []
var _goblins_preparados := false
var regiao := "chegada"
var limites := Rect2(-640, -448, 1280, 896)
var hud: CanvasLayer
var interface: CanvasLayer
var _ocupado := false
var _frame_ultima_interacao := -1
var _destino_apos_conclusao := ""
## Derrota em curso: a janela "Você caiu" leva de volta à entrada da região ao fechar ou ao escolher.
var _derrota_pendente := false
const TEMPO_QUEDA_DERROTA := 2.2
var _ponto := Vector2(-464,224)
var _nome_proximo := ""
var terreno: Node2D
var _tempo_save := 0.0
var encontro: Node
var sessao: Node
var mundo_online: Node
var carregamento: Node
var registro_run: Node
var saque_inicial: Node
var cinema_cidade: Node
var lobby_cidade: Node2D
var vigilia_remota := -1 ## -1 desconhecido; 0 sem vigília no grupo; 1 em andamento (informado pelo anfitrião)
var _ultima_posicao := Vector2(INF,INF)
# Carrega apenas a região visitada; as demais podem conter texturas e modelos grandes.
const TERRENOS := {
	"chegada":"res://cenas/campanha/terreno_chegada.tscn",
	"estrada":"res://cenas/campanha/terreno_estrada.tscn",
	"vila":"res://cenas/campanha/terreno_vila.tscn",
	"pomar":"res://cenas/campanha/terreno_pomar.tscn",
	"moinho":"res://cenas/campanha/terreno_moinho.tscn"}

func equipamentos_encontrados(permanentes := false) -> Array:
	var permitidos := []
	var p := controlador.progresso
	var historico := p.retrato()
	# Inventário usa conquistas permanentes; baú, tutorial e encontros usam a tentativa atual.
	var cumpridos: Array = historico.get("objetivos",{}).get("sobreviver_queda",[]) if permanentes else p.objetivos_cumpridos("sobreviver_queda")
	var completa: bool = "sobreviver_queda" in historico.get("concluidas",[]) if permanentes else p.missao_concluida("sobreviver_queda")
	for par in [["espada","espada_basica"],["escudo","escudo_basico"]]:
		if completa or par[0] in cumpridos: permitidos.append(par[1])
	return permitidos

func _restaurar_equipamentos() -> void:
	for tipo in equipamentos_encontrados(true):
		var item = jogador.inventario.buscar_por_tipo(tipo)
		if item == null:
			item = jogador.inventario._criar_item({"tipo":tipo,"categoria":"arma" if tipo == "espada_basica" else "escudo","duas_maos":false})
			if jogador.inventario.adicionar(item) < 0:
				push_error("Inventário sem espaço para o equipamento encontrado.")
				continue
		if jogador.inventario.slot_de(item).is_empty():
			jogador.inventario.equipar(item)
	jogador.inventario.salvar()

func salvar_retorno() -> Error:
	if not is_instance_valid(terreno) or not terreno.ponto_seguro(jogador.position) or jogador.estaMorto:
		return ERR_UNAVAILABLE
	var erro := controlador.progresso.salvar_retorno(regiao,jogador.position)
	if erro == OK:
		_ultima_posicao = jogador.position
	return erro

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if is_instance_valid(jogador): salvar_retorno()

func _ao_derrota() -> void:
	if sessao!=null and sessao.ativo:
		sessao._falhar("A expedição terminou. Seu progresso foi preservado.")
		return
	# Antes a cena recarregava no mesmo quadro: parecia travar e o jogador sumia para a entrada.
	# Agora o corpo cai (animação "morrer" do herói 3D), e uma janela explica e oferece tentar de novo.
	_derrota_pendente = true
	await get_tree().create_timer(TEMPO_QUEDA_DERROTA).timeout
	if not is_inside_tree() or not _derrota_pendente: return
	var nome: String = Controlador.Catalogo.dados().destinos.get(regiao, {}).get("nome", "região")
	var paginas: Array[String] = ["Você foi derrotado. As missões e os itens continuam salvos; você volta para a entrada de %s." % nome]
	var opcoes: Array[String] = ["Tentar de novo"]
	_escolha_ativa = "derrota"
	interface._telas.introducao.iniciar_com_opcoes(paginas, opcoes, "Você caiu")
	EventosJogo.abrir_tela_de(jogador, "introducao")

func _sair_da_derrota() -> void:
	if not _derrota_pendente: return
	_derrota_pendente = false
	_recomecar.call_deferred()

func _recomecar() -> void:
	var entrada: Array = terreno.dados.entrada
	controlador.progresso.salvar_retorno(regiao,Vector2(entrada[0],entrada[1]))
	get_tree().set_meta("campanha_destino",regiao)
	get_tree().set_meta("campanha_nova_instancia",true)
	get_tree().reload_current_scene()


func _ready() -> void:
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes") and get_tree().root.get_node("Saves").mundo != "campanha":
		push_error("Abra o protótipo pelo launcher isolado.")
		get_tree().quit(1)
		return
	sessao = get_tree().root.get_node_or_null("CampanhaOnline")
	# Todos os personagens 3D da campanha numa tela só (antes, uma tela por personagem a todo quadro).
	add_child(preload("res://codigo/jogador/atlas_herois_3d.gd").new())
	Introducao.pular_prologo()
	Introducao.aula_arena = false
	var erro := controlador.iniciar("user://percurso_primeira_raiz", "prototipo")
	if erro != OK:
		push_error("Não foi possível abrir a campanha isolada: %s" % error_string(erro))
		get_tree().quit(1)
		return
	InventarioJogador.caminho_save = "user://percurso_primeira_raiz/inventario.json"
	var retorno := controlador.progresso.ponto_retorno()
	var destino := str(retorno.get("regiao","chegada"))
	if get_tree().has_meta("campanha_destino"):
		destino = str(get_tree().get_meta("campanha_destino"))
		get_tree().remove_meta("campanha_destino")
	# O launcher pode abrir direto numa região (--destino=vila), sem passar pelo seletor.
	for argumento in OS.get_cmdline_user_args():
		if argumento.begins_with("--destino=") and Controlador.Catalogo.dados().destinos.has(argumento.trim_prefix("--destino=")):
			destino = argumento.trim_prefix("--destino=")
	# Saves e atalhos antigos podem apontar para estágios agora fechados.
	if not destino in Controlador.Catalogo.REGIOES_HABILITADAS:
		destino = "vila" if controlador.progresso.acesso_liberado("vila") else "chegada"
	# Cobre a montagem do mapa: antes aparecia um fundo cinza com o personagem. Os testes automáticos (--script) não a usam.
	if not "--script" in OS.get_cmdline_args() or "--carregamento" in OS.get_cmdline_user_args():
		carregamento = preload("res://codigo/campanha/carregamento_campanha.gd").new()
		add_child(carregamento)
		carregamento.mostrar(destino)
	jogador = preload("res://cenas/jogador.tscn").instantiate()
	jogador.set_script(preload("res://codigo/campanha/jogador_campanha.gd"))
	jogador.equipamentos_permitidos = equipamentos_encontrados(true)
	jogador.name = "Jogador"
	add_child(jogador)
	jogador.derrota_campanha.connect(_ao_derrota)
	registro_run=preload("res://codigo/campanha/registro_run.gd").new()
	add_child(registro_run)
	registro_run.iniciar(self)
	saque_inicial=preload("res://codigo/campanha/saque_inicial.gd").new()
	add_child(saque_inicial)
	saque_inicial.iniciar(self)
	_restaurar_equipamentos()
	if carregamento != null:
		jogador.desabilitar_todas_acoes(true)
		carregamento.definir_progresso(0.25, "PREPARANDO O PERSONAGEM")
	hud = preload("res://cenas/ui.tscn").instantiate()
	add_child(hud)
	interface = preload("res://cenas/ui/interface.tscn").instantiate()
	interface.name = "Interface"
	interface.set_script(preload("res://codigo/campanha/interface_campanha.gd"))
	add_child(interface)
	interface._telas.introducao.concluido.connect(_apos_conclusao)
	interface._telas.introducao.escolhido.connect(_ao_escolher)
	var guia := preload("res://codigo/campanha/guia_objetivo.gd").new()
	guia.cena = self
	add_child(guia)
	var dicas := preload("res://codigo/campanha/dicas_combate.gd").new()
	dicas.cena = self
	add_child(dicas)
	controlador.alterado.connect(_atualizar)
	controlador.alterado.connect(func():_conferir_missoes.call_deferred())
	if carregamento != null: carregamento.definir_progresso(0.5, "MONTANDO A INTERFACE")
	for i in 8:
		await get_tree().process_frame
		if carregamento != null: carregamento.definir_progresso(0.5 + 0.03 * (i + 1))
	if carregamento != null: carregamento.definir_progresso(0.8, "MONTANDO O MAPA")
	var nova: bool = bool(get_tree().get_meta("campanha_nova_instancia",true))
	if get_tree().has_meta("campanha_nova_instancia"): get_tree().remove_meta("campanha_nova_instancia")
	abrir_regiao(destino,nova)
	if carregamento != null:
		carregamento.definir_progresso(0.95, "QUASE PRONTO")
		await carregamento.finalizar()
		if is_instance_valid(jogador) and not jogador.estaMorto and not cinema_cidade_ativa() and not bool(get_tree().get_meta("cinema_ativo",false)): jogador.desabilitar_todas_acoes(false)

func cinema_cidade_ativa() -> bool:
	return is_instance_valid(cinema_cidade) and cinema_cidade.ativa

func objetivo_de_campanha() -> Dictionary:
	var objetivo := controlador.objetivo_atual()
	var texto: String = objetivo.get("texto","Percurso disponível concluído. Volte ao mapa para revisitar as regiões; a próxima etapa está em preparação.")
	if regiao == "moinho" and objetivo.get("alvo","") == "comporta_moinho" and is_instance_valid(terreno.roteiro):
		texto = terreno.roteiro.instrucao_do_puzzle()
	if regiao == "moinho" and is_instance_valid(terreno.roteiro) and terreno.roteiro.dentro:
		texto = terreno.roteiro.instrucao_interna()
	if regiao == "chegada" and controlador.progresso.missao_concluida("sobreviver_queda") and (objetivo.is_empty() or objetivo.regiao!=regiao):
		texto = "Clareira concluída! Use a saída para seguir pela Estrada dos Carreteiros."
		return {"id":"sobreviver_queda","fase":"concluida","texto":texto,"titulo":"Clareira concluída","andares":true}
	if not objetivo.is_empty() and objetivo.regiao != controlador.regiao:
		texto += " Vá para " + Controlador.Catalogo.dados().destinos[objetivo.regiao].nome + "."
	return {"id":objetivo.get("missao","defesa_da_vila"),"fase":objetivo.get("id","preparacao"),
		"texto":texto,"titulo":"Primeira Raiz","andares":true,"secundaria":not objetivo.is_empty() and bool(controlador._catalogo.missoes[objetivo.missao].opcional)}

func _avisar(texto: String) -> void:
	hud.anunciar(texto,"",3.0)

func fala_do_cerne(texto: String, complemento: String, transmitir := true) -> void:
	hud.anunciar(texto+("\n"+complemento if not complemento.is_empty() else ""),"Cerne Partido",4.0)
	if transmitir and sessao!=null and sessao.ativo and sessao.sou_host():
		sessao.enviar({"t":"cerne_fala","andar":1,"texto":texto,"complemento":complemento})

func _resposta(id: String, erro: Error) -> void:
	if erro != OK:
		if erro==ERR_BUSY:
			var minima: float = float(Controlador.Catalogo.dados().destinos[regiao].get("duracao",{}).get("minima",60))
			_avisar("A passagem ainda está instável. Explore mais %d s antes de partir." % ceili(maxf(minima-controlador.tempo_ativo(regiao),1.0)))
		else:
			_avisar("Ainda há tarefas anteriores a resolver.")
		return
	if id == "marco_estrada":
		_mostrar_conclusao("CLAREIRA CONCLUÍDA", "Você encontrou seus equipamentos e sobreviveu à queda. O caminho está livre. Continue pelo mapa regional até a Estrada dos Carreteiros.", "estrada")
		return
	if id == "tomas" and controlador.progresso.missao_concluida("pomar_sulcos"):
		_mostrar_conclusao("PERCURSO CONCLUÍDO", "Tomás recebeu seu relato: goblins saqueiam o pomar, e as raízes atravessam a cerca por baixo. Lia precisa de ajuda com os sulcos que chegaram à entrada da vila. Fale com ela para preparar a defesa. Seu progresso foi salvo.", "vila")
		return
	if id in ["dara","trabalhador","lia","estela","tomas"]:
		var fala := _fala(id)
		var nome: String = alvos[id].nome
		var retrato := "mistica" if id == "estela" else ("mercador" if id in ["tomas","trabalhador"] else "lia")
		var paginas: Array[String] = [fala.get_slice(": ",1)]
		interface._telas.introducao.iniciar(paginas,nome,retrato)
		EventosJogo.abrir_tela_de(jogador,"introducao")
	elif id=="barreira_pomar":
		var texto: String=Preparos.texto(controlador.progresso.preparo,"barreira")
		var paginas: Array[String] = [texto if not texto.is_empty() else _fala(id)]
		interface._telas.introducao.iniciar(paginas,"Barreira de teste")
		EventosJogo.abrir_tela_de(jogador,"introducao")
	elif id in ["sulcos_chegada","kit_resgate"]:
		var texto := "Os sulcos vêm de baixo das raízes. Não foram feitos por patas. Adiante, um tecido azul marca uma trilha antiga." if id=="sulcos_chegada" else "A caixa vazia tem encaixes de espada e escudo. Alguém deixou socorro para quem chega. O mesmo símbolo aparece nas ruínas além das raízes."
		var paginas: Array[String] = [texto]
		interface._telas.introducao.iniciar(paginas,"Vestígios da Primeira Raiz")
		EventosJogo.abrir_tela_de(jogador,"introducao")
	elif id in ["margem_secura", "comporta_moinho", "roda_moinho", "entrada_dungeon"]:
		var ids := {"margem_secura":"margem", "comporta_moinho":"comporta", "roda_moinho":"eixo", "entrada_dungeon":"dungeon"}
		var fala: String = FALAS_PASSOS.get("moinho_vazao:" + ids[id], "")
		interface._telas.introducao.iniciar([fala], "Bacia do Moinho")
		EventosJogo.abrir_tela_de(jogador,"introducao")
	else:
		_avisar("Equipamento recolhido" if id in ["espada_inicial","escudo_inicial"] else "Descoberta registrada")

func _descansar() -> Error:
	if _ocupado or not interface._telas_abertas.is_empty():return ERR_BUSY
	_frame_ultima_interacao=Engine.get_process_frames()
	jogador.curar(maxi(0,int(jogador.estatisticas.hp_maximo)-int(jogador.hp_atual)))
	jogador.stamina=jogador.stamina_maxima
	_avisar("Você descansa um pouco. Vida e fôlego recuperados.")
	return OK

## Reações ao progresso (codigo/dados/reacoes_primeira_raiz.json). Dos marcos principais vale só o mais recente
## que tenha texto para o morador; cada pedido opcional concluído rende uma fala própria. Cada reação aparece uma vez.
const Reacoes := preload("res://codigo/dados/reacoes_primeira_raiz.json")
const MARCOS_REACAO := ["moinho_vazao","pomar_sulcos","defesa_da_vila","acolhimento","estrada_interrompida"]
const PEDIDOS_REACAO := ["quem_ficou_para_tras","ferro_que_ainda_serve","antes_de_sair_outra_vez","pesca_primeiras_fisgadas","pesca_carpas_da_vila"]

func _reacao(id: String) -> String:
	return str(_reacao_marco(id)[1])

func _reacao_marco(id: String) -> Array:
	var textos: Dictionary = Reacoes.data.get(id,{})
	for missao in MARCOS_REACAO:
		if textos.has(missao) and controlador.progresso.missao_concluida(missao):return [missao,str(textos[missao])]
	return ["",""]

## Primeira reação ainda não ouvida: o marco atual, depois os pedidos concluídos.
func _reacao_pendente(id: String) -> Array:
	var vistas: Array = _reacoes_moradores.get(id,[])
	var candidatas: Array = [_reacao_marco(id)]
	var textos: Dictionary = Reacoes.data.get(id,{})
	for missao in PEDIDOS_REACAO:
		if textos.has(missao) and controlador.progresso.missao_concluida(missao):candidatas.append([missao,str(textos[missao])])
	for par in candidatas:
		if not str(par[0]).is_empty() and not par[0] in vistas:return par
	return ["",""]

## Encerramento do beta: cartão ilustrado com o que mudou e o gancho para as próximas regiões.
func _mostrar_epilogo() -> void:
	_epilogo_pendente=false
	var cartao:=preload("res://codigo/campanha/carregamento_campanha.gd").new()
	cartao.name="Epilogo"
	add_child(cartao)
	jogador.desabilitar_todas_acoes(true)
	cartao.mostrar("fim_beta")
	await cartao.finalizar()
	if is_instance_valid(jogador) and not jogador.estaMorto:jogador.desabilitar_todas_acoes(false)

## Visitas e reações vêm do save: voltar à vila não repete a apresentação de cada morador.
func _carregar_conversas() -> void:
	_visitas_moradores.clear()
	_reacoes_moradores.clear()
	for id in controlador.progresso.conversas:
		var registro: Dictionary = controlador.progresso.conversas[id]
		_visitas_moradores[id]=int(registro.get("visitas",0))
		_reacoes_moradores[id]=Array(registro.get("vistas",[])).duplicate()

func _guardar_conversa(id: String) -> void:
	var vistas: Variant = _reacoes_moradores.get(id,[])
	controlador.progresso.registrar_conversa(id,int(_visitas_moradores.get(id,0)),vistas if vistas is Array else [])

## Entrega os prêmios das missões concluídas e grava o recibo no save; a falta de espaço na mochila adia a entrega.
func _conferir_missoes() -> void:
	if not is_instance_valid(jogador) or hud==null or not jogador.inventario.tem_espaco():
		if is_instance_valid(jogador) and hud!=null and not controlador.progresso.recompensas_pendentes().filter(func(m):return Recompensas.tem(m)).is_empty():
			_avisar("Mochila cheia. Libere espaço para receber a recompensa.")
		return
	for id in controlador.progresso.recompensas_pendentes():
		if not Recompensas.tem(id) or id in _recompensados:continue
		if not Recompensas.entregar(jogador,id):
			_avisar("Mochila cheia. Libere espaço para receber a recompensa.")
			continue
		_recompensados.append(id)
		controlador.progresso.registrar_recompensa(id)
		hud.anunciar("Missão concluída: %s" % Controlador.Catalogo.dados().missoes[id].nome,"Recompensa: %s" % Recompensas.texto(id),5.0)

## A bancada só vira ação quando o objetivo `oficio` está liberado ou a ligação já foi pedida.
func _bancada_disponivel() -> bool:
	return not controlador.progresso.preparo.is_empty() or controlador.objetivos_disponiveis().any(func(o):return o.alvo=="bancada_ivo" and o.tipo=="oficio" and o.regiao==regiao)

func _usar_bancada() -> Error:
	if _ocupado or not interface._telas_abertas.is_empty():return ERR_BUSY
	_frame_ultima_interacao=Engine.get_process_frames()
	if moradores.has("ivo"):
		# Ivo para de seguir a rotina enquanto atende; `_apos_conclusao` encerra a conversa.
		_morador_conversando=moradores["ivo"]
		_morador_conversando.iniciar_conversa(jogador.global_position)
	var escolhida: String=controlador.progresso.preparo
	var paginas: Array[String] = []
	if not escolhida.is_empty():
		paginas.append("A %s está pronta para reforçar a barreira da entrada. Quando a defesa vier, é ela que vai." % Preparos.texto(escolhida,"nome").to_lower())
		interface._telas.introducao.iniciar(paginas,"Bancada de Ivo","ferreiro")
	else:
		paginas.append("Esta bancada prepara uma ligação para reforçar a barreira da entrada da vila; não fabrica armas. Escolha uma opção. A ligação é entregue pronta, sem gastar os materiais da mochila.")
		for id in Preparos.ids():
			paginas.append("%s: %s" % [Preparos.texto(id,"nome"),Preparos.texto(id,"oferta")])
		paginas.append("Qual delas você leva?")
		_escolha_ativa="preparo"
		interface._telas.introducao.iniciar_com_opcoes(paginas,Preparos.opcoes(),"Bancada de Ivo","ferreiro")
	EventosJogo.abrir_tela_de(jogador,"introducao")
	return OK

func _ao_escolher(indice: int) -> void:
	var escolha := _escolha_ativa
	_escolha_ativa=""
	match escolha:
		"preparo":_ao_escolher_preparo(indice)
		"treino":
			if indice==0:_iniciar_treino()
		"parar_treino":
			if indice==0 and is_instance_valid(_treino):_treino.encerrar(false)
		"tomas_menu":
			match indice:
				0:_abrir_menu.call_deferred("tomas_compra",[],_nome_servico)
				1:_abrir_menu.call_deferred("tomas_menu",[Servicos.vender_excedentes(jogador)],_nome_servico)
		"tomas_compra":
			if indice<3:_abrir_menu.call_deferred("tomas_compra",[Servicos.comprar(jogador,["ferro","madeira","fibra"][indice])],_nome_servico)
			else:_abrir_menu.call_deferred("tomas_menu",[],_nome_servico)
		"bau_inicial":
			if indice==0:_pegar_bau()
		"derrota":
			_sair_da_derrota()
		"rosa_menu":
			match indice:
				0:_abrir_menu.call_deferred("rosa_menu",[Servicos.tratar(jogador)],_nome_servico)
				1:_abrir_menu.call_deferred("rosa_menu",[Servicos.comprar_cura(jogador)],_nome_servico)

## Menus de serviço em ouro: Tomás compra e vende materiais; Rosa trata ferimentos e vende cura.
func _abrir_menu(menu: String,paginas: Array,nome: String) -> void:
	var falas: Array[String]=[]
	for pagina in paginas:falas.append(str(pagina))
	var opcoes: Array[String]
	match menu:
		"tomas_menu":
			falas.append("O que vai ser? Vendo o básico e compro o que sobra de material.")
			opcoes=["Comprar","Vender excedentes","Sair"]
		"tomas_compra":
			falas.append("Ferro, madeira ou fibra?")
			opcoes=["Ferro (%d)" % Servicos.PRECOS_COMPRA.ferro,"Madeira (%d)" % Servicos.PRECOS_COMPRA.madeira,"Fibra (%d)" % Servicos.PRECOS_COMPRA.fibra,"Voltar"]
		"bau_inicial":
			var itens: Array[String] = []
			var feitos: Array = controlador.progresso.objetivos_cumpridos("sobreviver_queda")
			if not "espada" in feitos: itens.append("• Espada")
			if not "escudo" in feitos: itens.append("• Escudo")
			if not "espada" in feitos: itens.append("• %d poções de cura" % POCOES_INICIAIS)
			if itens.is_empty(): return
			falas.append("Dentro do baú de resgate:\n" + "\n".join(itens))
			opcoes=["Pegar tudo","Deixar para depois"]
		"rosa_menu":
			falas.append("Posso cuidar de você ou preparar um curativo.")
			opcoes=["Tratar ferimentos (%d)" % Servicos.CUSTO_TRATAMENTO,"Comprar cura (%d)" % Servicos.PRECO_CURA,"Sair"]
		_:return
	_escolha_ativa=menu
	_nome_servico=nome
	interface._telas.introducao.iniciar_com_opcoes(falas,opcoes,nome)
	EventosJogo.abrir_tela_de(jogador,"introducao")

func _usar_barricada() -> Error:
	if _ocupado or not interface._telas_abertas.is_empty():return ERR_BUSY
	_frame_ultima_interacao=Engine.get_process_frames()
	var atual:={}
	for o in controlador.objetivos_disponiveis():
		if o.alvo=="barricada_vila" and o.regiao==regiao:
			atual=o
			break
	if atual.is_empty():
		_avisar("A barreira da entrada segura por enquanto.")
		return OK
	if atual.tipo=="vencer":
		if is_instance_valid(encontro) and encontro.ativa:return OK
		return encontro.iniciar()
	var erro:=controlador.interagir("reparar","barricada_vila")
	if erro!=OK:
		_resposta("barricada_vila",erro)
		return erro
	salvar_retorno()
	var texto:String=Preparos.texto(controlador.progresso.preparo,"barricada")
	var paginas: Array[String]=[texto if not texto.is_empty() else "Você firma a barreira da entrada com o que tem à mão. Quando estiver pronto, volte aqui para chamar a defesa."]
	interface._telas.introducao.iniciar(paginas,"Barreira da entrada")
	EventosJogo.abrir_tela_de(jogador,"introducao")
	return OK

## Dara só oferece o treino a quem já tem espada e escudo; durante o treino oferece encerrá-lo.
func _oferecer_treino(paginas: Array[String],nome: String) -> bool:
	var falas: Array[String]=paginas.duplicate()
	var opcoes: Array[String]
	if is_instance_valid(_treino):
		falas=["Quer parar o treino por agora?"]
		opcoes=["Parar","Continuar"]
		_escolha_ativa="parar_treino"
	elif jogador.usando_espada and jogador.usando_escudo:
		falas.append("Quer treinar bloqueio, esquiva e contra-ataque comigo? Levo um boneco para perto.")
		opcoes=["Treinar","Agora não"]
		_escolha_ativa="treino"
	else:
		return false
	interface._telas.introducao.iniciar_com_opcoes(falas,opcoes,nome)
	EventosJogo.abrir_tela_de(jogador,"introducao")
	return true

func _iniciar_treino() -> void:
	if is_instance_valid(_treino):return
	_treino=TreinoDara.new()
	_treino.cena=self
	_treino.jogador=jogador
	add_child(_treino)
	_treino.terminado.connect(_ao_terminar_treino)
	_treino.iniciar(_livre(moradores["dara"].position+Vector2(70,-10)))

func _ao_terminar_treino(concluido: bool) -> void:
	if not concluido:
		_avisar("Treino encerrado.")
		return
	var missao_nova: bool=controlador.interagir("treinar","treino_dara")==OK
	if missao_nova: salvar_retorno()
	var paginas: Array[String]=["Bom. Você defendeu, esquivou e respondeu no tempo. É isso que mantém alguém de pé lá fora. Se quiser repetir, é só falar comigo."]
	interface._telas.introducao.iniciar(paginas,"Dara")
	EventosJogo.abrir_tela_de(jogador,"introducao")

func _ao_escolher_preparo(indice: int) -> void:
	var ids := Preparos.ids()
	if indice<0 or indice>=ids.size():return
	var erro := controlador.progresso.registrar_preparo(ids[indice])
	if erro!=OK:
		_avisar("Não foi possível guardar a ligação. Fale com Ivo de novo.")
		return
	controlador.alterado.emit()
	salvar_retorno()
	_atualizar()
	_mostrar_feito_ivo.call_deferred(str(ids[indice]))

func _mostrar_feito_ivo(escolha: String) -> void:
	var paginas: Array[String] = [Preparos.texto(escolha,"feito")]
	interface._telas.introducao.iniciar(paginas,"Bancada de Ivo","ferreiro")
	EventosJogo.abrir_tela_de(jogador,"introducao")
	_avisar("Recebido: %s" % Preparos.texto(escolha,"nome"))

func _mostrar_conclusao(titulo: String, texto: String, destino: String) -> void:
	_destino_apos_conclusao = destino
	var paginas: Array[String] = [texto]
	interface._telas.introducao.iniciar(paginas,titulo)
	EventosJogo.abrir_tela_de(jogador,"introducao")

func _apos_conclusao() -> void:
	if _derrota_pendente:
		_sair_da_derrota()
		return
	if is_instance_valid(_morador_conversando):_morador_conversando.encerrar_conversa()
	_morador_conversando=null
	if _destino_apos_conclusao.is_empty(): return
	var destino := _destino_apos_conclusao
	_destino_apos_conclusao = ""
	registro_run.apresentada=true
	interface.mostrar_resultado.call_deferred(destino)

func voltar_ao_mapa() -> void:
	if cinema_cidade_ativa(): cinema_cidade.cancelar()
	salvar_retorno()
	if sessao!=null and sessao.ativo: sessao.sair()
	get_tree().set_meta("campanha_mapa_regional",true)
	get_tree().change_scene_to_file("res://cenas/campanha/seletor_campanha.tscn")

func _livre(posicao: Vector2) -> Vector2:
	# Os pontos do layout já têm áreas livres. A navegação só deve corrigir
	# obstáculos, sem colapsar entradas/interações antes da sincronização do mapa.
	if terreno.ponto_seguro(posicao): return posicao
	# Corrige junto ao objeto: o ponto de retorno pode estar em outra interação.
	var mapa := get_world_2d().navigation_map
	for raio in range(8, 129, 8):
		for passo in 16:
			var candidato := posicao+Vector2.DOWN.rotated(TAU*passo/16.0)*raio
			if not terreno.ponto_seguro(candidato):continue
			var navegavel := NavigationServer2D.map_get_closest_point(mapa,candidato)
			if candidato.distance_to(navegavel)<=8 and terreno.ponto_seguro(navegavel) \
					and not NavigationServer2D.map_get_path(mapa,_ponto,navegavel,true).is_empty():return navegavel
	var proximo := NavigationServer2D.map_get_closest_point(get_world_2d().navigation_map,posicao)
	return proximo if terreno.ponto_seguro(proximo) else _ponto

func abrir_regiao(id: String, nova_instancia := true) -> Error:
	if id=="vila":
		nova_instancia=false
	var erro := controlador.definir_regiao(id)
	if erro != OK:
		return erro
	if not TERRENOS.has(id): return ERR_UNAVAILABLE
	if id=="vila" and sessao!=null and sessao.ativo:sessao.sair()
	# Uma reentrada encerra as câmeras e efeitos da instância anterior antes de criar o cenário.
	if cinema_cidade_ativa(): cinema_cidade.cancelar()
	for no in get_children():
		if no.has_method("pular") and no.get("ativa"): no.pular()
	if nova_instancia:
		var inicio: Error = controlador.progresso.iniciar_instancia(id)
		if inicio != OK: return inicio
		if saque_inicial != null:
			inicio = saque_inicial.iniciar_instancia(id)
			if inicio != OK: return inicio
	if registro_run!=null:registro_run.reiniciar(id)
	if interface!=null and interface._telas_abertas.has("resultado"):
		interface._fechar_tela("resultado")
	# Conversas e lojas pertencem à região anterior; não podem bloquear a nova.
	if interface!=null and interface._telas_abertas.has("introducao"):
		interface._fechar_tela("introducao")
	_escolha_ativa=""
	_nome_servico=""
	_ocupado = false
	_frame_ultima_interacao = -1

	if cinema_cidade_ativa(): cinema_cidade.cancelar()
	_carregar_conversas()
	regiao = id
	for goblin in goblins_espalhados:
		if is_instance_valid(goblin):
			remove_child(goblin)
			goblin.queue_free()
	goblins_espalhados.clear()
	_goblins_preparados=false
	for rebento in rebentos_espalhados:
		if is_instance_valid(rebento):
			remove_child(rebento)
			rebento.queue_free()
	rebentos_espalhados.clear()
	_rebentos_preparados=false
	for alvo in alvos.values():
		alvo.no.queue_free()
	alvos.clear()
	moradores.clear()
	_morador_conversando=null
	if is_instance_valid(inimigo):
		inimigo.queue_free()
	inimigo = null
	if is_instance_valid(terreno):
		remove_child(terreno)
		terreno.queue_free()
	terreno = (load(TERRENOS[id]) as PackedScene).instantiate()
	terreno.name = "Terrains"
	add_child(terreno)
	if terreno.has_signal("abertura_bau_concluida"):
		terreno.abertura_bau_concluida.connect(_ao_bau_aberto)
		if controlador.progresso.bau_resgate_aberto: terreno.restaurar_bau_aberto()
	limites = terreno.limites
	if is_instance_valid(lobby_cidade):
		remove_child(lobby_cidade)
		lobby_cidade.queue_free()
		lobby_cidade=null
	if id=="vila":
		lobby_cidade=preload("res://codigo/campanha/lobby_cidade_campanha.gd").new()
		add_child(lobby_cidade)

	var camera: Camera2D = jogador.get_node("Camera2D")
	camera.limit_left = int(limites.position.x)
	camera.limit_top = int(limites.position.y)
	camera.limit_right = int(limites.end.x)
	camera.limit_bottom = int(limites.end.y)
	var entrada: Array = terreno.dados.entrada
	_ponto = Vector2(entrada[0],entrada[1])
	var retorno := controlador.progresso.ponto_retorno()
	var primeira_chegada := id == "chegada" and (nova_instancia or retorno.is_empty())
	if not nova_instancia and retorno.get("regiao") == id:
		var pos: Array = retorno.posicao
		var restaurada := Vector2(pos[0],pos[1])
		if terreno.ponto_seguro(restaurada): _ponto = restaurada
	jogador.position = _livre(_ponto)
	camera.reset_smoothing()
	var detalhes := {
		"espada_inicial":["Espada","coletar",""],"escudo_inicial":["Escudo","coletar",""],
		"sulcos_chegada":["Sulcos do despertar","investigar",""],"kit_resgate":["Posto de resgate","investigar",""],"raizes_despertas":["Raízes luminosas","vigilia",""],
		"marco_estrada":["Saída para a estrada","descobrir",""],
		"carreto":["Rastros do carreto","investigar",""],"trabalhador":["Trabalhador refugiado","conversar",""],
		"dara":["Dara","conversar","lia"],"lia":["Lia","conversar","lia"],"estela":["Estela","conversar","mistica"],
		"bancada_ivo":["Bancada de Ivo","oficio",""],"descanso":["Banco de descanso","descansar",""],"barricada_vila":["Barreira da entrada","reparar",""],"tomas":["Tomás","conversar","mercador"],
		"cerca_pomar":["Cerca partida","investigar",""],"raiz_pomar":["Raízes junto aos brotos","investigar",""],
		"sulco_pomar":["Sulcos no chão","investigar",""],"barreira_pomar":["Barreira de teste","reparar",""],
		"canal_pomar":["Canal sob a barreira","descobrir",""],
		"margem_secura":["Marcas da água","investigar",""],"comporta_moinho":["Transmissão externa","investigar",""],
		"roda_moinho":["Roda sem corrente","investigar",""],"entrada_dungeon":["Entrada das galerias","reparar",""],
		"registro_entrada":["Registro de entrada","ajustar",""],
		"registro_desvio":["Registro de desvio","ajustar",""],
		"registro_retorno":["Registro de retorno","ajustar",""],
		"saida_regiao":["Voltar ao mapa","sair",""]}
	for alvo in terreno.dados.alvos:
		if id=="vila" and Elenco.dados().has(alvo):continue
		var pos: Array = terreno.dados.alvos[alvo].p
		var detalhe: Array = detalhes[alvo]
		_alvo(alvo,detalhe[0],Vector2(pos[0],pos[1]),detalhe[1],detalhe[2])
	if id == "moinho":
		terreno.roteiro = load("res://codigo/campanha/roteiro_bacia.gd").new()
		terreno.add_child(terreno.roteiro)
		terreno.roteiro.iniciar(self, terreno)
	if id=="vila":
		_criar_moradores()
		_alvo("leilao","Leilão dos aventureiros",Vector2(-456,-72),"leilao","")
	_criar_bau_escondido(id)
	_aplicar_atmosfera(id)
	if id=="chegada":
		var margem := preload("res://codigo/campanha/pesca_rios.gd").margem_proxima(terreno,jogador.position)
		if margem.is_finite():
			_alvo("rio_pesca","Margem de pesca",margem,"pescar","")
	if is_instance_valid(encontro): encontro.queue_free()
	encontro = load("res://codigo/campanha/defesa_vila.gd" if id=="vila" else "res://codigo/campanha/vigilia_chegada.gd").new()
	encontro.cena = self
	add_child(encontro)
	_preparar_criatura()
	if is_instance_valid(mundo_online):
		mundo_online.queue_free()
		mundo_online=null
	if id!="vila" and sessao!=null and sessao.ativo:
		if get_tree().has_meta("campanha_estacao"): terreno.definir_estacao(int(get_tree().get_meta("campanha_estacao")))
		if is_instance_valid(mundo_online): mundo_online.queue_free()
		mundo_online = preload("res://codigo/campanha/mundo_expedicao.gd").new()
		add_child(mundo_online)
		mundo_online.configurar(sessao,self)
	salvar_retorno()
	_atualizar()
	_conferir_missoes.call_deferred()
	if id == "chegada":
		var abertura := preload("res://codigo/campanha/abertura_chegada.gd").new()
		abertura.cena = self
		abertura.concluida.connect(abertura.queue_free)
		add_child(abertura)
		_iniciar_abertura(abertura, primeira_chegada)
	elif id == "vila" and not controlador.progresso.missao_concluida("acolhimento") and not "retorno" in controlador.progresso.objetivos_cumpridos("acolhimento"):
		cinema_cidade = preload("res://codigo/campanha/chegada_cidade.gd").new()
		cinema_cidade.cena = self
		cinema_cidade.concluida.connect(cinema_cidade.queue_free)
		add_child(cinema_cidade)
		cinema_cidade.iniciar()
	return OK

func _iniciar_abertura(abertura: Node, primeira: bool) -> void:
	while is_instance_valid(carregamento) and carregamento.ativa: await get_tree().process_frame
	if is_instance_valid(abertura): abertura.iniciar(primeira)

func _alvo(id: String, texto: String, deslocamento: Vector2, tipo: String, npc := "") -> void:
	var no := preload("res://codigo/campanha/interacao_campanha.gd").new()
	no.id = id
	no.so_entre_ondas = false
	no.deslocamento_aviso = Vector2(0,-42 if not npc.is_empty() else -28)
	var no_bau := id in ["espada_inicial","escudo_inicial"] and terreno.has_method("abrir_bau")
	if no_bau: no.deslocamento_aviso=Vector2(0,-84)
	no.position = _livre(deslocamento)
	if regiao == "moinho" and id in ["registro_entrada","registro_desvio","registro_retorno"]:
		no.position = deslocamento+Vector2(0,14)
		no.deslocamento_aviso = Vector2(0,-38)
	no.z_index = preload("res://codigo/globais/profundidade.gd").z_de(no.position.y)
	add_child(no)
	if not npc.is_empty():
		var geometria := DadosCidade.geometria_sprite(npc)
		var sprite := Sprite2D.new()
		sprite.texture = load(DadosCidade.caminho_sprite(npc))
		sprite.hframes = int(geometria.grade[0])
		sprite.vframes = int(geometria.grade[1])
		sprite.scale = Vector2.ONE*float(geometria.escala_mapa)
		sprite.position.y = 9-(float(geometria.pes_y)-32)*float(geometria.escala_mapa)
		no.add_child(sprite)
	elif id in ["espada_inicial", "escudo_inicial"] and not terreno.has_method("aplicar_equipamentos_encontrados"):
		var item := Sprite2D.new()
		var tipo_item := "espada_basica" if id == "espada_inicial" else "escudo_basico"
		item.texture = load("res://assets/personagens/raven_fantasy/icones/" + tipo_item + ".png")
		item.position.y = -8
		no.add_child(item)
	var nome := Label.new()
	nome.text = texto
	nome.position = Vector2(-56,-66 if not npc.is_empty() else -50)
	if no_bau: nome.position.y=-104
	nome.size.x = 112
	nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nome.add_theme_color_override("font_color", Color("fff0c2"))
	nome.add_theme_color_override("font_shadow_color", Color.BLACK)
	nome.add_theme_constant_override("shadow_offset_x",1)
	nome.add_theme_constant_override("shadow_offset_y",1)
	nome.add_theme_font_size_override("font_size",8)
	no.add_child(nome)
	alvos[id] = {"no":no,"nome":texto,"tipo":tipo,"rotulo":nome}

func _preparar_criatura() -> void:
	if sessao!=null and sessao.ativo and not sessao.sou_host(): return
	if regiao == "pomar" and not _goblins_preparados:
		_goblins_preparados=true
		_povoar_goblins.call_deferred(terreno.get_instance_id())
	if regiao != "chegada": return
	if equipamentos_encontrados().size() < 2: return
	if not _rebentos_preparados:
		_rebentos_preparados=true
		var cena_rebento := load("res://cenas/inimigos/rebento_raizes.tscn") as PackedScene
		for ponto in terreno.dados.get("rebentos",[]):
			var rebento: Node2D = cena_rebento.instantiate()
			rebento.position=_livre(Vector2(ponto[0],ponto[1]))
			rebento.vida=18
			rebento.dano=2
			rebento.raio_percepcao=125.0
			saque_inicial.registrar(rebento)
			add_child(rebento)
			rebentos_espalhados.append(rebento)
	if is_instance_valid(inimigo): return
	# O rebento que vigia a passagem só aparece depois de examinar o posto de resgate (mesmo lugar do baú).
	if not "resgate" in controlador.progresso.objetivos_cumpridos("sobreviver_queda"): return
	if controlador.progresso.missao_concluida("sobreviver_queda") or "combate" in controlador.progresso.objetivos_cumpridos("sobreviver_queda"): return
	inimigo = load("res://cenas/inimigos/rebento_raizes.tscn").instantiate()
	var pos: Array = terreno.dados.inimigo
	inimigo.position = _livre(Vector2(pos[0],pos[1]))
	inimigo.vida = 18
	inimigo.dano = 1
	saque_inicial.registrar(inimigo,"guarda")
	inimigo.inimigo_morreu.connect(_vencer_criatura)
	add_child(inimigo)

func _povoar_goblins(id_terreno: int) -> void:
	# A malha de navegação precisa sincronizar antes de resolver os pontos livres.
	await get_tree().physics_frame
	await get_tree().physics_frame
	if regiao != "pomar" or not is_instance_valid(terreno) or terreno.get_instance_id()!=id_terreno:return
	goblins_espalhados=load("res://codigo/campanha/goblins_pomar.gd").povoar(self)

func _vencer_criatura() -> void:
	var erro := controlador.interagir("vencer", "criatura_inicial")
	if erro==OK and sessao!=null: sessao.registrar_combate("criatura_inicial")
	if erro != OK:
		_avisar("Examine o posto de resgate antes de seguir.")
	else:
		_avisar("A passagem abriu. Investigue os sulcos deixados pelas raízes.")

func _process(_delta: float) -> void:
	if not is_instance_valid(jogador) or hud == null:
		return
	if is_instance_valid(terreno) and terreno.has_method("atualizar_oclusao"):
		terreno.atualizar_oclusao(jogador,_delta)
	_atualizar_marcadores(_delta)
	if _epilogo_pendente and interface._telas_abertas.is_empty():_mostrar_epilogo()
	if regiao=="vila" and interface._telas_abertas.is_empty() and not cinema_cidade_ativa():
		var luz:=get_tree().get_first_node_in_group("iluminacao")
		hora_da_cidade=float(luz.hora) if luz!=null else fposmod(hora_da_cidade+_delta/24.0,24.0)
		for morador in moradores.values():morador.atualizar_rotina(hora_da_cidade)
	if interface._telas_abertas.is_empty() and not jogador.estaMorto and not get_tree().paused:
		controlador.contar_tempo(_delta)
	_tempo_save += _delta
	if _tempo_save > 2:
		_tempo_save = 0
		salvar_retorno()
	var perto := alvo_proximo()
	for id in alvos:
		var rotulo: Label = alvos[id].rotulo
		if not is_instance_valid(rotulo):continue
		rotulo.visible = id == perto and interface._telas_abertas.is_empty() and not cinema_cidade_ativa()
		if rotulo.visible:
			var cartao: Control = hud.get_node("ObjetivoPrincipal")
			var area_nome := rotulo.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,rotulo.size)
			var area_cartao := cartao.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,cartao.size)
			rotulo.visible = not area_nome.intersects(area_cartao)
	jogador.bloquear_ataques(cinema_cidade_ativa() or (regiao == "chegada" and not ("espada" in controlador.progresso.objetivos_cumpridos("sobreviver_queda") and "escudo" in controlador.progresso.objetivos_cumpridos("sobreviver_queda")) and not controlador.progresso.missao_concluida("sobreviver_queda")))

func alvo_proximo() -> String:
	var proximo := ""
	var distancia := 34.0
	for id in alvos:
		if not alvos[id].no.visible:
			continue
		if regiao=="chegada" and id in ["sulcos_chegada","kit_resgate","raizes_despertas"]:
			if not controlador.objetivos_disponiveis().any(func(objetivo):return objetivo.alvo==id): continue
			if id=="raizes_despertas" and is_instance_valid(encontro) and encontro.ativa: continue
		var d: float = jogador.position.distance_to(alvos[id].no.position)
		if d < distancia:
			distancia = d
			proximo = id
	return proximo

func interagir_proximo() -> Error:
	if _ocupado or _frame_ultima_interacao==Engine.get_process_frames() or not interface._telas_abertas.is_empty() or jogador.estaMorto:
		return ERR_BUSY
	var id := alvo_proximo()
	if id=="rio_pesca":
		_avisar("Selecione a vara e segure o ataque olhando para o rio.")
		return ERR_UNAVAILABLE
	if id.is_empty():
		return ERR_UNAVAILABLE
	if regiao=="estrada" and is_instance_valid(terreno.roteiro):
		return terreno.roteiro.interagir(id)
	if regiao == "moinho" and is_instance_valid(terreno.roteiro):
		var resposta: Dictionary = terreno.roteiro.interagir(id)
		if not resposta.is_empty():
			_frame_ultima_interacao = Engine.get_process_frames()
			_avisar(str(resposta.texto))
			return OK
	if id in ["espada_inicial","escudo_inicial"] and terreno.has_method("abrir_bau"):
		if terreno.estado_bau==terreno.EstadoBau.ABRINDO: return ERR_BUSY
		if terreno.estado_bau==terreno.EstadoBau.FECHADO:
			var abertura: Error=terreno.abrir_bau()
			_frame_ultima_interacao=Engine.get_process_frames()
			_atualizar()
			return abertura
	if id in ["espada_inicial","escudo_inicial"] and not jogador.inventario.tem_espaco():
		_avisar("Libere espaço na mochila.")
		return ERR_OUT_OF_MEMORY
	if id.begins_with("bau_escondido"): return _abrir_bau_escondido(id)
	if id == "trabalhador_vila": return _conversar_trabalhador()
	if id=="leilao":
		EventosJogo.abrir_tela_de(jogador,"mercado")
		return OK
	if moradores.has(id):return _conversar_morador(id)
	if id=="descanso":return _descansar()
	if id=="barricada_vila":return _usar_barricada()
	if id=="bancada_ivo" and _bancada_disponivel():return _usar_bancada()
	_ocupado = true
	_frame_ultima_interacao=Engine.get_process_frames()
	if alvos[id].tipo == "sair":
		_ocupado = false
		voltar_ao_mapa()
		return OK
	if id == "marco_estrada" and controlador.progresso.missao_concluida("sobreviver_queda"):
		get_tree().set_meta("campanha_regiao_selecionada","estrada")
		_ocupado = false
		voltar_ao_mapa()
		return OK
	var tipo: String = alvos[id].tipo
	for objetivo in controlador.objetivos_disponiveis():
		if objetivo.alvo == id and objetivo.regiao == regiao:
			tipo = objetivo.tipo
	if id == "raizes_despertas":
		_ocupado = false
		return encontro.iniciar()
	var erro := controlador.interagir(tipo,id)
	if erro == OK and id in ["espada_inicial","escudo_inicial","kit_resgate"]:
		if id == "espada_inicial": _dar_pocoes_iniciais()
		if id != "kit_resgate": _restaurar_equipamentos()
		_preparar_criatura()
	if erro == OK: salvar_retorno()
	_resposta(id,erro)
	_ocupado = false
	return erro

func _ao_bau_aberto() -> void:
	var erro := controlador.progresso.registrar_abertura_bau()
	if erro!=OK:
		_avisar("Não foi possível salvar a abertura do baú.")
	else:
		_abrir_menu.call_deferred("bau_inicial",[],"Baú de resgate")
	_atualizar()

## Recolhe o que falta do baú inicial (espada, escudo e, junto com a espada, as poções de cura).
func _pegar_bau() -> void:
	for id in ["espada_inicial","escudo_inicial"]:
		if (("espada" if id=="espada_inicial" else "escudo") in controlador.progresso.objetivos_cumpridos("sobreviver_queda")):continue
		if not jogador.inventario.tem_espaco():
			_avisar("Libere espaço na mochila.")
			break
		var erro := controlador.interagir("coletar",id)
		if erro!=OK:continue
		if id=="espada_inicial":_dar_pocoes_iniciais()
		_restaurar_equipamentos()
		_preparar_criatura()
	salvar_retorno()
	_atualizar()
	_avisar("Equipamento recolhido.")

func _dar_pocoes_iniciais() -> void:
	var mochila: Node = jogador.inventario
	if not mochila.adicionar_coletavel("pocao","cura",POCOES_INICIAIS) or not mochila.salvar():
		_avisar("Não foi possível guardar as poções.")

func _fala(id: String) -> String:
	match id:
		"dara":
			if "retorno" in controlador.progresso.objetivos_cumpridos("acolhimento"):
				return "Dara: Você o encontrou com vida. Vou organizar o retorno pela rota que indicou e avisar a Lia."
			return "Dara: Você veio pela Estrada dos Carreteiros. Nosso trabalhador levava mantimentos para a vila e não voltou. Diga o que viu."
		"trabalhador": return "Trabalhador: Os rebentos vieram pelos sulcos e viraram o carreto. Me escondi aqui. Antes disso, vi goblins carregando sacos na trilha do moinho. Avise a Dara na vila; não sei se aquela trilha ainda é segura."
		"lia": return "Lia: Você tem abrigo aqui. Precisamos entender os ataques antes da próxima defesa."
		"estela": return "Estela: A árvore chama pessoas capazes de atravessar. Ainda temos muito a descobrir."
		"tomas": return "Tomás: As cercas não seguram essas criaturas. Precisamos seguir o caminho delas."
		"barreira_pomar": return "A cerca voltou a fechar a passagem usada pelos goblins, mas os sulcos das raízes continuam por baixo. Examine o canal."
		"canal_pomar": return "Há pegadas de goblins junto ao canal, mas os sulcos seguem entre as raízes, sob a cerca. Leve a Tomás o relato dos saqueadores e da passagem subterrânea."
		"margem_secura": return FALAS_PASSOS["moinho_vazao:margem"]
		"comporta_moinho": return FALAS_PASSOS["moinho_vazao:comporta"]
		"roda_moinho": return FALAS_PASSOS["moinho_vazao:eixo"]
		"entrada_dungeon": return FALAS_PASSOS["moinho_vazao:dungeon"]
		"bancada_ivo": return "Ivo: Escolha uma ligação para reforçar a barreira da entrada da vila. Esta bancada não fabrica armas."
	return "Descoberta registrada no diário da campanha."

func _atualizar() -> void:
	if is_instance_valid(terreno) and terreno.has_method("aplicar_equipamentos_encontrados"):
		terreno.aplicar_equipamentos_encontrados(equipamentos_encontrados())
	if is_instance_valid(terreno):
		var missao_terreno := "moinho_vazao" if regiao == "moinho" else "pomar_sulcos"
		var cumpridos: Array = controlador.progresso.objetivos_cumpridos(missao_terreno)
		if controlador.progresso.missao_concluida("pomar_sulcos"): cumpridos.append("barreira")
		terreno.aplicar_descobertas(cumpridos)
		if regiao == "moinho":
			var disponiveis := controlador.objetivos_disponiveis().filter(func(o): return o.regiao == "moinho")
			for id in ["margem_secura", "comporta_moinho", "roda_moinho", "entrada_dungeon"]:
				if alvos.has(id): alvos[id].no.visible = disponiveis.any(func(o): return o.alvo == id)
	if regiao == "moinho" and is_instance_valid(terreno.roteiro): terreno.roteiro.atualizar()
	for id in ["espada_inicial", "escudo_inicial"]:
		if alvos.has(id):
			var objetivo_item := "espada" if id == "espada_inicial" else "escudo"
			alvos[id].no.visible = not (controlador.progresso.missao_concluida("sobreviver_queda") or objetivo_item in controlador.progresso.objetivos_cumpridos("sobreviver_queda"))
			if terreno.has_method("abrir_bau"):
				var aberto: bool=terreno.estado_bau==terreno.EstadoBau.ABERTO
				var abrindo: bool=terreno.estado_bau==terreno.EstadoBau.ABRINDO
				if abrindo: alvos[id].no.visible=false
				if id=="escudo_inicial" and not "espada_basica" in equipamentos_encontrados(): alvos[id].no.visible=false
				var nome := ("Pegar espada" if id=="espada_inicial" else "Pegar escudo") if aberto else "Abrir baú"
				alvos[id].nome=nome
				alvos[id].rotulo.text=nome
	if is_instance_valid(hud) and hud.has_node("ObjetivoPrincipal"):
		hud.get_node("ObjetivoPrincipal").atualizar()

func _criar_moradores() -> void:
	var cidade:Node=terreno
	# Espera a geometria desta região aparecer nas consultas do servidor.
	var mapa:=get_world_2d().navigation_map
	var entrada:=Vector2(cidade.dados.entrada[0],cidade.dados.entrada[1])
	var pronta:=false
	for tentativa in 30:
		await get_tree().physics_frame
		await get_tree().process_frame
		if not is_instance_valid(cidade) or terreno!=cidade or regiao!="vila":return
		if NavigationServer2D.map_get_closest_point_owner(mapa,entrada)==cidade.navegacao.get_rid():
			pronta=true
			break
	if not pronta:
		push_error("Navegação da cidade ainda não disponível para os moradores.")
		return
	for id in Elenco.dados():
		var pessoa:Dictionary=Elenco.dados()[id]
		var morador:CharacterBody2D=preload("res://cenas/npcs/npc_gerado.tscn").instantiate()
		morador.name=id.to_pascal_case()
		morador.ficha=Elenco.ficha(id)
		morador.velocidade=20.0 if pessoa.importante else 22.0
		for ponto in pessoa.rota:morador.rota.append(_ponto_morador(Vector2(ponto[0],ponto[1])))
		for trecho in pessoa.get("rotina",[]):
			var periodo:Dictionary=trecho.duplicate(true)
			var caminho:=PackedVector2Array()
			for ponto in trecho.rota:caminho.append(_ponto_morador(Vector2(ponto[0],ponto[1])))
			periodo.rota=caminho
			morador.rotina.append(periodo)
		morador.position=morador.rota[0]
		if not morador.rotina.is_empty():
			morador.velocidade=22.0
			morador.atualizar_rotina(hora_da_cidade,true)
		add_child(morador)
		moradores[id]=morador
		alvos[id]={"no":morador,"nome":pessoa.nome,"tipo":"conversar","rotulo":null}
		var interacao:=preload("res://codigo/campanha/interacao_campanha.gd").new()
		interacao.id=id
		interacao.cena_responsavel=self
		interacao.so_entre_ondas=false
		morador.add_child(interacao)
		morador.visual.renderizado.connect(_rotular_morador.bind(id,morador,interacao),CONNECT_ONE_SHOT)
	_criar_trabalhador_vila()

## O trabalhador resgatado na estrada passa a morar na vila depois do acolhimento (a vila reage ao progresso).
func _criar_trabalhador_vila() -> void:
	if not controlador.progresso.missao_concluida("acolhimento") or not moradores.has("rosa"): return
	var trabalhador: CharacterBody2D = preload("res://cenas/npcs/npc_gerado.tscn").instantiate()
	trabalhador.name = "TrabalhadorResgatado"
	var ficha: Dictionary = preload("res://codigo/dados/gerador_npcs.gd").gerar(4417, "agricultor")
	ficha.nome = "Bento"
	trabalhador.ficha = ficha
	var ponto := _ponto_morador(moradores["rosa"].rota[0] + Vector2(36, 18))
	trabalhador.rota.append(ponto)
	trabalhador.position = ponto
	add_child(trabalhador)
	alvos["trabalhador_vila"] = {"no":trabalhador,"nome":"Bento","tipo":"conversar","rotulo":null}
	var interacao := preload("res://codigo/campanha/interacao_campanha.gd").new()
	interacao.id = "trabalhador_vila"
	interacao.cena_responsavel = self
	interacao.so_entre_ondas = false
	trabalhador.add_child(interacao)
	trabalhador.visual.renderizado.connect(_rotular_trabalhador.bind(trabalhador, interacao), CONNECT_ONE_SHOT)

func _rotular_trabalhador(trabalhador: Node, interacao: Node) -> void:
	if not is_instance_valid(trabalhador): return
	var rotulo: Label = trabalhador.get_node_or_null("NomeNPC")
	if rotulo == null: return
	rotulo.visible = false
	interacao._aviso.position = Vector2(0, rotulo.position.y-13)

func _conversar_trabalhador() -> Error:
	var trabalhador: Node = alvos["trabalhador_vila"].no
	_frame_ultima_interacao = Engine.get_process_frames()
	trabalhador.iniciar_conversa(jogador.global_position)
	_morador_conversando = trabalhador
	var fala := "Obrigado por me tirar da estrada. Agora ajudo a Rosa com os curativos enquanto a perna sara."
	if controlador.progresso.missao_concluida("defesa_da_vila"):
		fala = "Disseram que você segurou a entrada sul. Se as carroças voltarem a andar, eu volto a carregar o grão."
	if controlador.progresso.missao_concluida("moinho_vazao"):
		fala = "Ouvi a roda do moinho girando de novo! Amanhã mesmo levo o primeiro saco de grão para lá."
	var paginas: Array[String] = [fala]
	interface._telas.introducao.iniciar(paginas, "Bento")
	EventosJogo.abrir_tela_de(jogador, "introducao")
	return OK

func _rotular_morador(id: String,morador: Node,interacao: Node) -> void:
	if not is_instance_valid(morador) or not moradores.has(id) or moradores[id]!=morador:return
	var rotulo:Label=morador.get_node("NomeNPC")
	rotulo.visible=false
	alvos[id].rotulo=rotulo
	# Nome e botão mantêm a mesma âncora acima da cabeça, em duas alturas.
	interacao._aviso.position=Vector2(0,rotulo.position.y-13)

## "!" acima de quem tem missão ou entrega para o jogador agora (o mesmo objetivo que a conversa registraria).
var _marcadores: Dictionary = {}
var _espera_marcadores := 0.0
func _atualizar_marcadores(delta: float) -> void:
	_espera_marcadores -= delta
	if _espera_marcadores > 0.0: return
	_espera_marcadores = 0.2
	var com_missao: Dictionary = {}
	for objetivo in controlador.objetivos_disponiveis():
		if objetivo.get("regiao","") == regiao and moradores.has(objetivo.get("alvo","")): com_missao[objetivo.alvo] = true
	for id in moradores:
		var morador: Node = moradores[id]
		if not is_instance_valid(morador): continue
		# Ao trocar de região os moradores são recriados e o "!" antigo é liberado junto com eles.
		var guardado: Variant = _marcadores.get(id)
		var marcador: Label = guardado if is_instance_valid(guardado) else null
		if marcador == null: _marcadores.erase(id)
		if com_missao.has(id) and marcador == null:
			marcador = Label.new()
			marcador.text = "!"
			marcador.add_theme_font_override("font", preload("res://codigo/ui/estilo_campanha.gd").FONTE)
			marcador.add_theme_font_size_override("font_size", 18)
			marcador.add_theme_color_override("font_color", Color("ffd34d"))
			marcador.add_theme_color_override("font_outline_color", Color("2a1a08"))
			marcador.add_theme_constant_override("outline_size", 4)
			marcador.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			marcador.size = Vector2(16, 20)
			# Logo acima da cabeça (os pés do morador ficam na origem).
			marcador.position = Vector2(-8, -40)
			marcador.z_index = 50
			morador.add_child(marcador)
			var pulo := marcador.create_tween().set_loops()
			pulo.tween_property(marcador, "position:y", marcador.position.y - 3, 0.45).set_trans(Tween.TRANS_SINE)
			pulo.tween_property(marcador, "position:y", marcador.position.y, 0.45).set_trans(Tween.TRANS_SINE)
			_marcadores[id] = marcador
		elif not com_missao.has(id) and marcador != null:
			if is_instance_valid(marcador): marcador.queue_free()
			_marcadores.erase(id)
		# Perto o bastante para o botão de conversar aparecer, o "!" sai do caminho.
		if is_instance_valid(_marcadores.get(id)):
			_marcadores[id].visible = morador.global_position.distance_to(jogador.global_position) > 44.0

## Diário de missões (tecla J ou toque no painel da missão): principais e secundárias, com o passo atual de cada uma.
func abrir_diario() -> void:
	if not interface._telas_abertas.is_empty() or jogador.estaMorto: return
	var andamento: Array[String] = []
	var secundarias: Array[String] = []
	var concluidas: Array[String] = []
	var catalogo: Dictionary = controlador._catalogo
	var destinos: Dictionary = Controlador.Catalogo.dados().destinos
	var disponiveis: Array[Dictionary] = controlador.objetivos_disponiveis()
	for missao in catalogo.missoes:
		var dados: Dictionary = catalogo.missoes[missao]
		# Regiões ainda fechadas no beta não entram no diário.
		if not str(dados.get("destino","")) in Controlador.Catalogo.REGIOES_HABILITADAS: continue
		if controlador.progresso.missao_concluida(missao):
			concluidas.append(str(dados.nome))
			continue
		if not controlador.progresso.pode_concluir(missao): continue
		var passo := ""
		for objetivo in disponiveis:
			if objetivo.missao == missao:
				passo = str(objetivo.texto)
				var lugar: String = destinos[objetivo.regiao].nome
				if objetivo.regiao != regiao and not lugar in passo: passo += " (" + lugar + ")"
				break
		var linha := "• %s: %s" % [dados.nome, passo] if not passo.is_empty() else "• %s" % dados.nome
		if bool(dados.get("opcional", false)): secundarias.append(linha)
		else: andamento.append(linha)
	var paginas: Array[String] = []
	for grupo in [["EM ANDAMENTO", andamento], ["SECUNDÁRIAS", secundarias]]:
		var linhas: Array = grupo[1]
		for inicio in range(0, linhas.size(), 2):
			paginas.append(grupo[0] + "\n" + "\n".join(linhas.slice(inicio, inicio + 2)))
	if not concluidas.is_empty(): paginas.append("CONCLUÍDAS\n" + ", ".join(concluidas) + ".")
	if paginas.is_empty(): return
	interface._telas.introducao.iniciar(paginas, "Diário de missões")
	EventosJogo.abrir_tela_de(jogador, "introducao")

func _unhandled_input(evento: InputEvent) -> void:
	if evento is InputEventKey and evento.pressed and not evento.echo and evento.physical_keycode == KEY_J and not Controle.digitando:
		abrir_diario()
		get_viewport().set_input_as_handled()

## Tom de luz fixo por região (a campanha não tem relógio de dia: o da Iluminacao encerra o dia e leva a dormir).
const ATMOSFERAS := {"chegada": Color(0.96, 0.98, 1.0), "estrada": Color(1.0, 0.96, 0.9),
	"vila": Color(1.0, 1.0, 1.0), "pomar": Color(1.0, 0.94, 0.84), "moinho": Color(0.93, 0.97, 1.0)}
func _aplicar_atmosfera(id_regiao: String) -> void:
	var tom := get_node_or_null("AtmosferaRegiao") as CanvasModulate
	if tom == null:
		tom = CanvasModulate.new()
		tom.name = "AtmosferaRegiao"
		add_child(tom)
	tom.color = ATMOSFERAS.get(id_regiao, Color.WHITE)

## Um baú escondido por região, longe da entrada e das missões; o lugar é sempre o mesmo para a mesma região.
const POCOES_BAU_ESCONDIDO := 2
func _criar_bau_escondido(id_regiao: String) -> void:
	var id := "bau_escondido_" + id_regiao
	if id in controlador.progresso.baus_abertos or not is_instance_valid(terreno) or terreno.get("limites") == null: return
	var entrada := Vector2(terreno.dados.entrada[0], terreno.dados.entrada[1])
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	var limites: Rect2 = terreno.limites.grow(-48)
	var ponto := Vector2.INF
	for tentativa in 600:
		var candidato := Vector2(rng.randf_range(limites.position.x, limites.end.x), rng.randf_range(limites.position.y, limites.end.y))
		if candidato.distance_to(entrada) < 320.0 or not terreno.ponto_seguro(candidato): continue
		# Longe de casas, cercas e troncos: perto deles o baú some atrás da arte.
		var obstaculos: Array = terreno.get("obstaculos") if terreno.get("obstaculos") is Array else []
		if obstaculos.any(func(area: Rect2) -> bool: return area.grow(56.0).has_point(candidato)): continue
		if alvos.values().any(func(alvo: Dictionary) -> bool: return is_instance_valid(alvo.no) and alvo.no.global_position.distance_to(candidato) < 140.0): continue
		ponto = candidato
		break
	if not ponto.is_finite(): return
	_alvo(id, "Baú escondido", ponto, "abrir", "")
	var bau := Sprite2D.new()
	bau.texture = load("res://assets/cenario/campanha/clareiras_modulares/primavera/bau_resgate.png")
	bau.scale = Vector2.ONE * 0.05
	bau.position.y = -10
	alvos[id].no.add_child(bau)

func _abrir_bau_escondido(id: String) -> Error:
	if _ocupado or not interface._telas_abertas.is_empty(): return ERR_BUSY
	_frame_ultima_interacao = Engine.get_process_frames()
	var ouro := 20 + (hash(id) % 3) * 10
	var mochila: Node = jogador.inventario
	if not mochila.adicionar_coletavel("pocao", "cura", POCOES_BAU_ESCONDIDO) or not mochila.salvar():
		_avisar("Libere espaço na mochila.")
		return ERR_OUT_OF_MEMORY
	if controlador.progresso.registrar_bau_escondido(id) != OK:
		_avisar("Não foi possível guardar o baú.")
		return FAILED
	jogador.adicionar_moedas(ouro)
	Sons.tocar("moeda")
	if alvos.has(id) and is_instance_valid(alvos[id].no): alvos[id].no.queue_free()
	alvos.erase(id)
	var paginas: Array[String] = ["Você achou um baú escondido!\n• %d poções de cura\n• %d de ouro" % [POCOES_BAU_ESCONDIDO, ouro]]
	interface._telas.introducao.iniciar(paginas, "Baú escondido")
	EventosJogo.abrir_tela_de(jogador, "introducao")
	return OK

func _ponto_morador(ponto: Vector2) -> Vector2:
	for raio in [0,16,32,48,64]:
		for deslocamento in [Vector2.ZERO,Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN,Vector2(-1,-1),Vector2(1,1)]:
			var candidato:Vector2=ponto+deslocamento*raio
			var navegavel:Vector2=terreno.ponto_livre(candidato)
			if navegavel.distance_to(candidato)<2 and terreno.ponto_seguro(navegavel):return navegavel
	push_error("Rota de morador sem passagem livre: %s" % ponto)
	return _ponto

func _conversar_morador(id: String) -> Error:
	var morador:Node=moradores[id]
	_morador_conversando=morador
	morador.iniciar_conversa(jogador.global_position)
	var etapa:=false
	var passo:=""
	for objetivo in controlador.objetivos_disponiveis():
		if objetivo.alvo!=id or objetivo.regiao!=regiao:continue
		var erro:Error=controlador.interagir(objetivo.tipo,id)
		if erro!=OK:
			morador.encerrar_conversa()
			_morador_conversando=null
			return erro
		etapa=true
		passo="%s:%s" % [objetivo.missao,objetivo.id]
		salvar_retorno()
		break
	if etapa and id=="tomas" and controlador.progresso.missao_concluida("pomar_sulcos"):
		_resposta(id,OK)
		return OK
	var visitas:int=int(_visitas_moradores.get(id,0))
	var paginas:Array[String]=Elenco.conversa(id,visitas)
	if id=="dara" and visitas==0:paginas.append("Quando quiser treinar, me procure. E na mochila, a aba da espada mostra a árvore de maestria: cada nó explica o que você pode aprender.")
	if visitas>0 and not morador.falas_atividade.is_empty():
		paginas=[str(morador.falas_atividade[posmod(visitas-1,morador.falas_atividade.size())])]
	var reacao:=_reacao_pendente(id)
	if visitas>0 and not str(reacao[1]).is_empty():
		paginas=[str(reacao[1])]
		var vistas:Array=_reacoes_moradores.get(id,[]) if _reacoes_moradores.get(id) is Array else []
		vistas.append(reacao[0])
		_reacoes_moradores[id]=vistas
	if etapa:paginas.push_front(FALAS_PASSOS.get(passo,_fala(id).get_slice(": ",1)))
	if etapa and passo=="moinho_vazao:relato":
		paginas.append("A Estela passou a manhã medindo os sulcos perto da bacia. Diz que eles não terminam no pomar: seguem para o norte, na direção da pedreira. Eu só sei que o rio sabia antes de nós.")
		_epilogo_pendente=true
	# A conversa que avança a missão termina sempre dizendo o próximo passo, em uma linha.
	if etapa and passo!="moinho_vazao:relato":
		var proximo: String = str(objetivo_de_campanha().get("texto",""))
		if not proximo.is_empty(): paginas.append("Próximo: " + proximo)
	_visitas_moradores[id]=visitas+1
	_guardar_conversa(id)
	if id=="dara" and regiao=="vila" and _oferecer_treino(paginas,alvos[id].nome):return OK
	if id in ["tomas","rosa"] and regiao=="vila":
		_abrir_menu(id+"_menu",paginas,alvos[id].nome)
		return OK
	interface._telas.introducao.iniciar(paginas,alvos[id].nome)
	EventosJogo.abrir_tela_de(jogador,"introducao")
	return OK

func alvo_pesca_rio(origem: Vector2, direcao: Vector2, alcance: float) -> Vector2:
	return preload("res://codigo/campanha/pesca_rios.gd").alvo(terreno,origem,direcao,alcance)

func registrar_captura_pesca(especie: String) -> void:
	preload("res://codigo/campanha/pedidos_pesca.gd").registrar(self,especie)
