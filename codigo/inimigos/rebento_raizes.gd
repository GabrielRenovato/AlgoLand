extends "res://codigo/inimigos/inimigo_base.gd"

## Ataques discretos: preparação, janela de impacto e recuperação sem dano de contato.
signal golpe_executado(tipo: String, indice: int)
const FICHA := preload("res://assets/inimigos/rebento_raizes/animacoes.json")
const ATLAS := [preload("res://assets/inimigos/rebento_raizes/atlas_1.png"), preload("res://assets/inimigos/rebento_raizes/atlas_2.png"), preload("res://assets/inimigos/rebento_raizes/atlas_3.png")]
const Indicador := preload("res://codigo/efeitos/indicador_ataque.gd")
const Erupcao := preload("res://codigo/inimigos/erupcao_raizes.gd")
enum Estado { LIVRE, COMBO, CONJURANDO, REAGINDO, MORRENDO }
var estado := Estado.LIVRE
var animacao := "parado_baixo"
var tempo_animacao := 0.0
var tempo_estado := 0.0
var _recarga := 1.1
var _recarga_raizes := 3.0
var _direcao_visual := "baixo"
var _rumo_ataque := Vector2.DOWN
var _impactos: Dictionary = {}
var _avisos: Array[Node2D] = []
var _zonas: Array[Vector2] = []
var _sinal_morte_emitido := false
@export var ia_habilitada := true
## Zero mantém a perseguição dos encontros; os rebentos espalhados usam percepção local.
@export var raio_percepcao := 0.0
var _perseguindo := false

func obter_jogador() -> Node2D:
	var alvo := super()
	if raio_percepcao<=0: return alvo
	if alvo==null:
		_perseguindo=false
		return null
	var alcance := raio_percepcao*1.4 if _perseguindo else raio_percepcao
	_perseguindo=global_position.distance_to(alvo.global_position)<=alcance
	return alvo if _perseguindo else null

func _ready() -> void:
	super()
	_tocar("parado_baixo")

func definir_animacao(_nome: String) -> void: pass
func aplicar_dano_contato() -> void: pass

func definir_direcao_animacao(dir: Vector2) -> void:
	if esta_atacando or dir.length_squared()<.01: return
	if absf(dir.x)>absf(dir.y)*1.2:
		_direcao_visual="lado"
		ultima_direcao_horizontal=signf(dir.x)
	else:
		_direcao_visual="baixo" if dir.y>=0 else "cima"

func _physics_process(delta: float) -> void:
	if esta_morto:
		_animar(delta)
		if tempo_animacao>=.8 and not _sinal_morte_emitido:
			_sinal_morte_emitido=true
			inimigo_morreu.emit()
			queue_free()
		return
	_recarga=maxf(_recarga-delta,0)
	_recarga_raizes=maxf(_recarga_raizes-delta,0)
	if estado==Estado.LIVRE:
		if ia_habilitada:
			super(delta)
		else:
			_atualizar_efeitos(delta)
			_atualizar_ordem_desenho()
		if esta_morto or esta_congelado(): return
		if esta_atordoado():
			_tocar("reagir_"+_direcao_visual)
		else:
			_tocar(("andar_" if velocity.length()>2 else "parado_")+_direcao_visual)
			var alvo := obter_jogador()
			if ia_habilitada and alvo!=null and _recarga<=0:
				var distancia := global_position.distance_to(alvo.global_position)
				if distancia<=44: iniciar_combo(alvo.global_position-global_position)
				elif distancia>=52 and distancia<=125 and _recarga_raizes<=0: iniciar_raizes(alvo.global_position)
	else:
		_atualizar_efeitos(delta)
		_atualizar_ordem_desenho()
		if esta_morto or esta_congelado(): return
		if esta_atordoado():
			_atordoado=maxf(_atordoado-delta,0)
			_cancelar_ataque()
			estado=Estado.REAGINDO
			tempo_estado=0
			_tocar("reagir_"+_direcao_visual)
		velocity=velocity.move_toward(Vector2.ZERO,desaceleracao_knockback*delta)
		move_and_slide()
		tempo_estado+=delta
		match estado:
			Estado.COMBO: _avancar_combo()
			Estado.CONJURANDO: _avancar_raizes()
			Estado.REAGINDO:
				if tempo_estado>=.24: estado=Estado.LIVRE
	_animar(delta)

func iniciar_combo(direcao: Vector2) -> Error:
	if esta_morto or estado!=Estado.LIVRE or esta_congelado() or esta_atordoado(): return ERR_BUSY
	definir_direcao_animacao(direcao)
	_rumo_ataque=direcao.normalized() if direcao.length_squared()>.01 else Vector2.DOWN
	estado=Estado.COMBO
	esta_atacando=true
	velocity=Vector2.ZERO
	tempo_estado=0
	_impactos.clear()
	_tocar("golpe_a_"+_direcao_visual,true)
	_criar_aviso(global_position+_rumo_ataque*23,28)
	return OK

func _avancar_combo() -> void:
	if tempo_estado<.5:
		_progresso_aviso(0,tempo_estado/.5)
	if tempo_estado>=.5 and not _impactos.has(0):
		_impactos[0]=true
		_impacto_aviso(0)
		_atingir(global_position+_rumo_ataque*23,28,false)
		golpe_executado.emit("combo",0)
	if tempo_estado>=.92 and not _impactos.has("segundo"):
		_impactos["segundo"]=true
		_tocar("golpe_b_"+_direcao_visual,true)
		_criar_aviso(global_position+_rumo_ataque*23,30)
	if tempo_estado>=.92 and tempo_estado<1.42: _progresso_aviso(1,(tempo_estado-.92)/.5)
	if tempo_estado>=1.42 and not _impactos.has(1):
		_impactos[1]=true
		_impacto_aviso(1)
		_atingir(global_position+_rumo_ataque*23,30,false)
		golpe_executado.emit("combo",1)
	if tempo_estado>=1.95: _terminar_ataque(1.2)

func iniciar_raizes(alvo: Vector2) -> Error:
	if esta_morto or estado!=Estado.LIVRE or esta_congelado() or esta_atordoado(): return ERR_BUSY
	if alvo.distance_to(global_position)>140 or _parede_entre(global_position,alvo): return ERR_UNAVAILABLE
	definir_direcao_animacao(alvo-global_position)
	_rumo_ataque=(alvo-global_position).normalized()
	estado=Estado.CONJURANDO
	esta_atacando=true
	velocity=Vector2.ZERO
	tempo_estado=0
	_impactos.clear()
	_zonas.clear()
	_tocar("conjurar_"+_direcao_visual,true)
	# Posições travadas antes da execução: esquivar sai do alcance indicado.
	for deslocamento in [-21.0,0.0,21.0]:
		var p: Vector2 = alvo+_rumo_ataque*float(deslocamento)
		if _parede_entre(global_position,p): continue
		_zonas.append(p)
		_criar_aviso(p,17)
	_recarga_raizes=6.0
	return OK

func _avancar_raizes() -> void:
	for i in _zonas.size():
		var instante := .8+i*.18
		_progresso_aviso(i,minf(tempo_estado/instante,1))
		if tempo_estado>=instante and not _impactos.has(i):
			_impactos[i]=true
			_impacto_aviso(i)
			var efeito := Erupcao.new()
			efeito.position=_zonas[i]
			get_parent().add_child(efeito)
			_atingir(_zonas[i],17,false)
			golpe_executado.emit("raizes",i)
	if tempo_estado>=1.7: _terminar_ataque(1.5)

func _parede_entre(a: Vector2,b: Vector2) -> bool:
	var consulta:=PhysicsRayQueryParameters2D.create(a,b,64)
	return not get_world_2d().direct_space_state.intersect_ray(consulta).is_empty()

func _atingir(centro: Vector2,raio: float,frontal: bool) -> void:
	if esta_morto or esta_atordoado() or esta_congelado(): return
	for alvo in jogadores_vivos():
		var ponto: Vector2=alvo.global_position+Vector2(0,8)
		var diferenca := ponto-centro
		if diferenca.length()>raio: continue
		if frontal and diferenca.length()>5 and diferenca.normalized().dot(_rumo_ataque)<.15: continue
		if _parede_entre(global_position,ponto): continue
		alvo.receber_dano(obter_dano(),(ponto-global_position).normalized()*110)
		atingiu_jogador.emit()

func _criar_aviso(ponto: Vector2,raio: float) -> void:
	var aviso := Indicador.new()
	get_parent().add_child(aviso)
	aviso.configurar(ponto,raio)
	_avisos.append(aviso)

func _progresso_aviso(indice: int,progresso: float) -> void:
	if indice<_avisos.size() and is_instance_valid(_avisos[indice]): _avisos[indice].atualizar_progresso(progresso)

func _impacto_aviso(indice: int) -> void:
	if indice<_avisos.size() and is_instance_valid(_avisos[indice]): _avisos[indice].detonar_impacto()

func _cancelar_ataque() -> void:
	for aviso in _avisos:
		if is_instance_valid(aviso): aviso.cancelar()
	_avisos.clear()
	_zonas.clear()
	esta_atacando=false

func _terminar_ataque(recarga: float) -> void:
	_cancelar_ataque()
	estado=Estado.LIVRE
	_recarga=recarga
	_tocar("parado_"+_direcao_visual)

func _tocar(nome: String,reiniciar := false) -> void:
	if not FICHA.data.animacoes.has(nome): nome="parado_baixo"
	if animacao==nome and not reiniciar: return
	animacao=nome
	tempo_animacao=0
	_aplicar_quadro()

func _animar(delta: float) -> void:
	tempo_animacao+=delta
	_aplicar_quadro()

func _aplicar_quadro() -> void:
	var dados: Dictionary=FICHA.data.animacoes[animacao]
	var duracoes: Array=dados.duracoes
	var duracao := 0.0
	for d in duracoes: duracao+=float(d)
	var t := fmod(tempo_animacao,duracao) if dados.loop else minf(tempo_animacao,duracao)
	var indice := duracoes.size()-1
	for i in duracoes.size():
		if t<float(duracoes[i]): indice=i;break
		t-=float(duracoes[i])
	var quadro := int(dados.quadros[indice])
	var pagina := quadro/16
	sprite.texture=ATLAS[pagina]
	sprite.hframes=8
	sprite.vframes=2
	sprite.frame=quadro%16
	sprite.flip_h=_direcao_visual=="lado" and ultima_direcao_horizontal<0

func receber_dano(quantidade: int,empurrao := Vector2.ZERO) -> void:
	if esta_morto: return
	super(quantidade,empurrao)
	if esta_morto: return
	_cancelar_ataque()
	estado=Estado.REAGINDO
	tempo_estado=0
	_recarga=.8
	_tocar("reagir_"+_direcao_visual,true)

func morrer() -> void:
	if esta_morto: return
	esta_morto=true
	collision_layer=0
	estado=Estado.MORRENDO
	velocity=Vector2.ZERO
	_cancelar_ataque()
	_limpar_gelo_morte()
	_tocar_som_morte()
	_ao_morrer_chefe()
	_tocar("morte",true)

func _exit_tree() -> void:
	_cancelar_ataque()
	super()
