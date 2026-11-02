extends "res://codigo/inimigos/rebento_raizes.gd"

## Chefe da chegada: dano só nas janelas anunciadas; progresso é da campanha.
signal fala(texto: String, complemento: String)
signal aterrissou
signal fase_alterada(fase: int)
const FICHA_CERNE := preload("res://assets/inimigos/cerne_partido/animacoes.json")
enum Etapa { QUEDA, LIVRE, COMBO, PANCADA, INVESTIDA, CONJURAR, TRANSFORMAR, VULNERAVEL, MORTE }
var etapa := Etapa.QUEDA
var fase := 1
var relogio := 0.0
var recarga := 1.0
var _origem := Vector2.ZERO
var _rumo := Vector2.DOWN
var _vez := 0
var _atingidos_investida: Dictionary = {}
var apoios: Array[Node2D] = []

func _ajustar_agente() -> void:
	super()
	# A campanha usa uma malha regional única, diferente das três classes da arena.
	if _agente!=null:_agente.navigation_layers=1

func _ready() -> void:
	eh_chefe=true
	nome_chefe="Cerne Partido"
	usar_barra_vida=false
	super()
	_origem=global_position
	vida_maxima=vida
	_tocar("parado",true)
	sprite.visible=false
	_criar_aviso(global_position,78)

func _tocar(nome: String,reiniciar := false) -> void:
	if not FICHA_CERNE.data.animacoes.has(nome): nome="parado"
	if animacao==nome and not reiniciar: return
	animacao=nome
	tempo_animacao=0
	_aplicar_quadro()

func _aplicar_quadro() -> void:
	if not is_instance_valid(sprite): return
	var dados: Dictionary=FICHA_CERNE.data.animacoes.get(animacao,FICHA_CERNE.data.animacoes.parado)
	var duracao := 0.0
	for t in dados.duracoes: duracao+=float(t)
	var tempo := fmod(tempo_animacao,duracao) if dados.loop else minf(tempo_animacao,duracao)
	var indice: int=dados.quadros.size()-1
	for i in dados.duracoes.size():
		if tempo<float(dados.duracoes[i]): indice=i;break
		tempo-=float(dados.duracoes[i])
	sprite.frame=int(dados.quadros[indice])
	sprite.flip_h=animacao=="lado" and ultima_direcao_horizontal<0

func _physics_process(delta: float) -> void:
	var cena:=get_parent()
	if cena.get("interface")!=null and not cena.interface._telas_abertas.is_empty(): return
	_atualizar_ordem_desenho()
	if etapa==Etapa.MORTE:
		_animar(delta)
		if tempo_animacao>=3.0 and not _sinal_morte_emitido:
			_sinal_morte_emitido=true
			inimigo_morreu.emit()
			queue_free()
		return
	_atualizar_efeitos(delta)
	if esta_morto or esta_congelado(): return
	relogio+=delta
	match etapa:
		Etapa.QUEDA:
			_progresso_aviso(0,minf(relogio/2.2,1))
			sprite.visible=relogio>=1.5
			sprite.position.y=-320*(1-pow(clampf((relogio-1.5)/.7,0,1),2))
			if relogio>=2.2 and not _impactos.has("queda"):
				_impactos["queda"]=true
				_impacto_aviso(0)
				_onda_dano(global_position,78,8,280)
				_tremer_camera(7,.35)
				Sons.tocar("chefe_aparece",0)
				aterrissou.emit()
				fala.emit("A Árvore ainda chama vocês…","Mas esta passagem permanece fechada.")
			if relogio>=6.5: _livre_cerne(1.0)
		Etapa.LIVRE:
			recarga=maxf(recarga-delta,0)
			var alvo:=obter_jogador()
			velocity=Vector2.ZERO
			if alvo!=null:
				var vetor: Vector2=alvo.global_position-global_position
				if vetor.length()>58 and global_position.distance_to(_origem)<175:
					velocity=_direcao_ate(alvo,vetor,delta)*velocidade
					_alvo_do_rumo=velocity.normalized()
					if _desvio_restante>0:
						_desvio_restante-=delta
						velocity=_desvio_direcao*velocidade
				elif global_position.distance_to(_origem)>=175:
					velocity=(_origem-global_position).normalized()*velocidade
				elif recarga>.25 and vetor.length()>1:
					# Reposicionar entre os golpes; preparar o ataque continua prendendo os pés.
					var lateral: Vector2=vetor.normalized().orthogonal()*(1 if _vez%2==0 else -1)
					if not test_move(global_transform,lateral*12):velocity=lateral*velocidade*.75
				move_and_slide()
				_vigiar_travamento(delta,velocity)
				_tocar("andar" if velocity.length()>2 else "parado")
				if recarga<=0:
					_rumo=vetor.normalized() if vetor.length()>1 else Vector2.DOWN
					_vez+=1
					if fase==2 and _vez%3==0: iniciar_especial("raizes")
					elif fase==2 and vetor.length()>85 and _vez%2==0: iniciar_especial("investida")
					elif vetor.length()<82: iniciar_especial("pancada" if _vez%3==0 else "combo")
		Etapa.COMBO:
			_progresso_aviso(0,minf(relogio/.58,1))
			_impactar("a",.58,global_position+_rumo*46,44)
			if relogio>=1.05 and not _impactos.has("aviso_b"):
				_impactos["aviso_b"]=true
				_criar_aviso(global_position+_rumo*46,44)
			_progresso_aviso(1,clampf((relogio-1.05)/.58,0,1))
			_impactar("b",1.63,global_position+_rumo*46,44)
			if relogio>=2.2: _livre_cerne(1.2)
		Etapa.PANCADA:
			_progresso_aviso(0,minf(relogio/.9,1))
			_impactar("pancada",.9,global_position+_rumo*35,65)
			if relogio>=2: _livre_cerne(1.5)
		Etapa.INVESTIDA:
			for i in _avisos.size(): _progresso_aviso(i,minf(relogio/.98,1))
			if relogio>=.98 and relogio<1.63:
				velocity=_rumo*190
				if (global_position+velocity*delta).distance_to(_origem)>175:
					velocity=Vector2.ZERO
					relogio=1.63
				move_and_slide()
				for alvo in jogadores_vivos():
					if global_position.distance_to(alvo.global_position)<44 and not _parede_entre(global_position,alvo.global_position) and not _atingidos_investida.has(alvo.get_instance_id()):
						_atingidos_investida[alvo.get_instance_id()]=true
						alvo.receber_dano(10,_rumo*250)
			if relogio>=2.28: _livre_cerne(1.6)
		Etapa.CONJURAR:
			if relogio>=1.3 and not _impactos.has("apoios"):
				_impactos["apoios"]=true
				_criar_apoios()
			for i in _zonas.size():
				_progresso_aviso(i,clampf((relogio-1.3)/3.2,0,1))
				_impactar("raiz_"+str(i),4.5+i*.12,_zonas[i],22)
			if relogio>=4.98: _livre_cerne(1.4)
		Etapa.TRANSFORMAR:
			if relogio>=2: _livre_cerne(.6)
		Etapa.VULNERAVEL:
			if relogio>=4: _livre_cerne(1.2)
	_animar(delta)

func iniciar_especial(tipo: String) -> Error:
	if etapa!=Etapa.LIVRE or esta_morto: return ERR_BUSY
	_cancelar_ataque()
	_impactos.clear()
	relogio=0
	esta_atacando=true
	velocity=Vector2.ZERO
	match tipo:
		"combo":
			etapa=Etapa.COMBO;_tocar("combo",true)
			_criar_aviso(global_position+_rumo*46,44)
		"pancada":
			etapa=Etapa.PANCADA;_tocar("pancada",true)
			_criar_aviso(global_position+_rumo*35,65)
		"investida":
			etapa=Etapa.INVESTIDA;_tocar("investida",true)
			_atingidos_investida.clear()
			for i in 4: _criar_aviso(global_position+_rumo*(24+i*33),36)
		"raizes":
			etapa=Etapa.CONJURAR;_tocar("conjurar",true)
			var alvo:=obter_jogador()
			var centro: Vector2=alvo.global_position if alvo!=null else global_position+_rumo*70
			for i in 5:
				var p: Vector2=centro+_rumo.orthogonal()*(i-2)*30
				if not _parede_entre(global_position,p):_zonas.append(p);_criar_aviso(p,22)
		_: _livre_cerne(0);return ERR_INVALID_PARAMETER
	return OK

func _impactar(id: String,instante: float,centro: Vector2,raio: float) -> void:
	if relogio<instante or _impactos.has(id): return
	_impactos[id]=true
	_onda_dano(centro,raio,8 if fase==1 else 11,160)
	if id.begins_with("raiz_"):
		var efeito:=Erupcao.new();efeito.position=centro;get_parent().add_child(efeito)
	else:
		var indice:=1 if id=="b" else 0
		_impacto_aviso(indice)
	golpe_executado.emit(id,0)

func _onda_dano(centro: Vector2,raio: float,quantidade: int,forca: float) -> void:
	for alvo in jogadores_vivos():
		var p: Vector2=alvo.global_position+Vector2(0,8)
		if p.distance_to(centro)>raio or _parede_entre(global_position,p): continue
		var rumo: Vector2=(p-centro).normalized()
		if rumo.length_squared()<.1:rumo=Vector2.DOWN
		alvo.receber_dano(quantidade,rumo*forca)

func _criar_apoios() -> void:
	for deslocamento in [Vector2(-58,28),Vector2(0,65),Vector2(58,28)]:
		var ponto: Vector2=global_position+deslocamento
		var terreno=get_parent().get("terreno")
		var livre:=terreno==null
		for angulo in [0.0,.6,-.6,1.2,-1.2,PI]:
			var candidato: Vector2=global_position+deslocamento.rotated(angulo)
			if terreno!=null and not terreno.ponto_seguro(candidato-Vector2(0,11)):continue
			if apoios.any(func(a):return is_instance_valid(a) and a.position.distance_to(candidato)<28):continue
			ponto=candidato;livre=true;break
		if not livre:continue
		var apoio:=preload("res://cenas/inimigos/apoio_cerne.tscn").instantiate()
		apoio.position=ponto
		apoio.inimigo_morreu.connect(_apoio_cortado.bind(apoio))
		get_parent().add_child(apoio)
		apoios.append(apoio)
	if apoios.is_empty():
		_cancelar_ataque();etapa=Etapa.VULNERAVEL;relogio=0;_tocar("cair",true);_sinal_vulneravel()

## Janela de dano dobrado: o chefe pisca em dourado e mostra o aviso acima da cabeça.
func _sinal_vulneravel() -> void:
	var rotulo := Label.new()
	rotulo.text = "VULNERÁVEL!"
	rotulo.position = Vector2(-34, -118)
	rotulo.add_theme_font_size_override("font_size", 9)
	rotulo.add_theme_color_override("font_color", Color("ffd873"))
	rotulo.add_theme_color_override("font_shadow_color", Color.BLACK)
	rotulo.add_theme_constant_override("shadow_offset_x", 1)
	rotulo.add_theme_constant_override("shadow_offset_y", 1)
	rotulo.z_index = 50
	add_child(rotulo)
	var t := rotulo.create_tween().set_parallel(true)
	t.tween_property(rotulo, "position:y", -134.0, 1.6)
	t.tween_property(rotulo, "modulate:a", 0.0, 1.6).set_delay(1.8)
	t.chain().tween_callback(rotulo.queue_free)
	var corpo: Sprite2D = get_node_or_null("Texture")
	if corpo != null:
		var piscar := create_tween().set_loops(3)
		piscar.tween_property(corpo, "modulate", Color(1.6, 1.4, 0.8), 0.3)
		piscar.tween_property(corpo, "modulate", Color.WHITE, 0.3)

func _apoio_cortado(apoio: Node2D) -> void:
	apoios.erase(apoio)
	if etapa==Etapa.CONJURAR and apoios.is_empty():
		_cancelar_ataque()
		etapa=Etapa.VULNERAVEL;relogio=0
		_tocar("cair",true)
		_sinal_vulneravel()

func _limpar_apoios() -> void:
	for apoio in apoios:
		if is_instance_valid(apoio):apoio.queue_free()
	apoios.clear()

func _livre_cerne(atraso: float) -> void:
	_cancelar_ataque();_limpar_apoios()
	etapa=Etapa.LIVRE;relogio=0;recarga=atraso
	velocity=Vector2.ZERO
	_tocar("parado",true)

func receber_dano(quantidade: int,_empurrao := Vector2.ZERO) -> void:
	if esta_morto or etapa in [Etapa.QUEDA,Etapa.TRANSFORMAR]: return
	var recebido:=quantidade*2 if etapa==Etapa.VULNERAVEL else quantidade
	vida-=recebido
	gerar_rotulo_dano(recebido);_avisar_vida_chefe();_flash_acerto()
	if vida<=0:morrer();return
	if fase==1 and vida<=vida_maxima/2:
		fase=2;etapa=Etapa.TRANSFORMAR;relogio=0
		velocity=Vector2.ZERO
		_cancelar_ataque();_limpar_apoios()
		_tocar("transformar",true)
		fase_alterada.emit(2)
		fala.emit("Minha casca pode ceder.","Minha vigília, não.")

func receber_dano_efeito(quantidade: int,_cor: Color) -> void:
	receber_dano(quantidade)

func morrer() -> void:
	if esta_morto:return
	esta_morto=true;etapa=Etapa.MORTE
	collision_layer=0
	velocity=Vector2.ZERO
	_cancelar_ataque();_limpar_apoios();_limpar_gelo_morte()
	_tocar("morte",true)
	fala.emit("Eu… ainda guardava…","")
	get_tree().call_group("hud","esconder_chefe")
	Sons.tocar("chefe_morre",0)

func _exit_tree() -> void:
	_limpar_apoios()
	if eh_chefe:get_tree().call_group("hud","esconder_chefe")
	super()
