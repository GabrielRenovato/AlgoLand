extends Node

## Encontro de chegada sem saque da arena e sem cronômetro durante menus.
var cena: Node2D
var ativa := false
var tempo := 0.0
var onda := 0
var criaturas: Array[Node2D] = []
var chefe: Node2D
var chefe_iniciado := false
const PAUSA_ENTRE_ONDAS := 1.5 ## depois de limpar uma onda
const LIMITE_ONDA := 9.0 ## a próxima onda vem mesmo com rebentos vivos
const PAUSA_CHEFE := 2.0
var _desde_onda := 0.0

func iniciar() -> Error:
	if ativa: return ERR_BUSY
	var pronto: bool = cena.controlador.objetivos_disponiveis().any(func(o):return o.alvo=="raizes_despertas")
	if cena.regiao!="chegada" or not pronto: return ERR_UNAVAILABLE
	if cena.sessao!=null and cena.sessao.ativo and not cena.sessao.sou_host():
		cena.sessao.enviar({"t":"vigilia_pedido","andar":1})
		return OK
	ativa = true
	tempo = 0
	onda = 0
	_desde_onda = 0.0
	_informar(true)
	cena.hud.anunciar("As raízes despertaram!","Fique dentro do anel vermelho e resista aos rebentos.",3.5)
	return OK

func _process(delta: float) -> void:
	if not ativa or not cena.interface._telas_abertas.is_empty() or cena.jogador.estaMorto: return
	tempo += delta
	criaturas = criaturas.filter(func(n):return is_instance_valid(n) and not n.esta_morto)
	_desde_onda += delta
	if onda<3 and (onda==0 or (criaturas.is_empty() and _desde_onda>=PAUSA_ENTRE_ONDAS) or _desde_onda>=LIMITE_ONDA):
		_desde_onda=0.0
		_onda()
	if onda==3 and criaturas.is_empty() and _desde_onda>=PAUSA_CHEFE and not chefe_iniciado:
		chefe_iniciado=true
		_som("chefe_aparece", -3.0)
		cena.hud.anunciar("O guardião da clareira desperta!","Siga o marcador e derrube o Cerne Partido.",3.5)
		chefe=preload("res://cenas/inimigos/cerne_partido.tscn").instantiate()
		var origem: Array=cena.terreno.dados.alvos.raizes_despertas.p
		chefe.position=cena._livre(Vector2(origem[0],origem[1]))
		var grupo: int=cena.sessao.jogadores_na_partida() if cena.sessao!=null and cena.sessao.ativo else 1
		chefe.vida=480+240*(grupo-1)
		chefe.fala.connect(cena.fala_do_cerne)
		cena.saque_inicial.registrar(chefe,"cerne")
		chefe.inimigo_morreu.connect(_vencer_chefe)
		cena.add_child(chefe)

func _vencer_chefe() -> void:
	if not ativa:return
	ativa=false
	_informar(false)
	if cena.controlador.interagir("vencer","raizes_despertas")==OK:
		if cena.sessao!=null:cena.sessao.registrar_combate("raizes_despertas")
		cena.salvar_retorno()
		_som("chefe_morre", -3.0)
		cena._avisar("O guardião caiu. A passagem está livre.")

func _informar(em_andamento: bool) -> void:
	if cena.sessao!=null and cena.sessao.ativo and cena.sessao.sou_host():
		cena.sessao.enviar({"t":"vigilia_estado","andar":1,"ativa":em_andamento})

func _som(arquivo: String, volume := -6.0, tom := 1.0) -> void:
	var tocador := AudioStreamPlayer.new()
	tocador.stream = load("res://assets/audio/%s.wav" % arquivo)
	tocador.volume_db = volume
	tocador.pitch_scale = tom
	tocador.finished.connect(tocador.queue_free)
	add_child(tocador)
	tocador.play()

func _onda() -> void:
	onda += 1
	_som("onda_inicio")
	cena.hud.anunciar("Rebentos! Onda %d/3" % onda,"",2.0)
	var origem := Vector2(cena.terreno.dados.alvos.raizes_despertas.p[0],cena.terreno.dados.alvos.raizes_despertas.p[1])
	var quantidade: int = (2 if onda<3 else 3)+(cena.sessao.jogadores_na_partida()-1 if cena.sessao!=null and cena.sessao.ativo else 0)
	for i in quantidade:
		var criatura := preload("res://cenas/inimigos/rebento_raizes.tscn").instantiate()
		var angulo: float = (i+onda*0.7)*TAU/3
		criatura.position = cena._livre(origem+Vector2(cos(angulo)*55,sin(angulo)*34))
		criatura.vida = 16+onda*2
		criatura.dano = 2
		cena.saque_inicial.registrar(criatura)
		cena.add_child(criatura)
		criaturas.append(criatura)

func _exit_tree() -> void:
	if is_instance_valid(chefe):chefe.queue_free()
	for criatura in criaturas:
		if is_instance_valid(criatura): criatura.queue_free()
