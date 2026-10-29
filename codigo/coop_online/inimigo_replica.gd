extends CharacterBody2D
## Réplica só visual: sem scripts de IA, timers, drops ou execução de animações do host.
const Profundidade := preload("res://codigo/globais/profundidade.gd")
var controlador: Node
var identificador := 0
var vida := 1
var esta_morto := false
var eh_chefe := false
var eh_mutante := false
var sprites: Array[Sprite2D] = []
var _alvo := Vector2.ZERO
var _tem_alvo := false
var vida_maxima := 1
var nome_chefe := ""
var _barra: Node2D
var _velocidade := Vector2.ZERO
var _instante_alvo := 0.0

func configurar(dados: Dictionary) -> bool:
	var caminho := str(dados.get("cena", ""))
	if not caminho.begins_with("res://cenas/inimigos/") or ".." in caminho or not caminho.ends_with(".tscn"): return false
	var recurso := load(caminho) as PackedScene
	if recurso == null: return false
	var visual := recurso.instantiate()
	_limpar(visual)
	add_child(visual)
	visual.position = Vector2.ZERO
	for no in visual.find_children("*", "Sprite2D", true, false): sprites.append(no)
	var forma := CollisionShape2D.new()
	var capsula := CapsuleShape2D.new()
	capsula.radius = 9
	capsula.height = 25
	forma.shape = capsula
	add_child(forma)
	collision_layer = 4
	collision_mask = 0
	add_to_group("enemy")
	identificador = int(dados.get("id", 0))
	eh_chefe = bool(dados.get("chefe", false))
	eh_mutante = bool(dados.get("mut", false))
	scale = Vector2(float(dados.get("sx", 1)), float(dados.get("sy", 1)))
	global_position = Vector2(float(dados.get("x", 0)), float(dados.get("y", 0)))
	_alvo = global_position
	# As texturas são descritas só no nascimento, nunca enviadas como imagens pela rede.
	var texturas: Array = dados.get("texturas", [])
	for i in mini(texturas.size(), sprites.size()):
		var t := str(texturas[i])
		if t.begins_with("res://assets/inimigos/") and not ".." in t and t.ends_with(".png"):
			sprites[i].texture = load(t)
	vida_maxima = maxi(1, int(dados.get("vm", 1)))
	vida = vida_maxima
	nome_chefe = str(dados.get("nome", ""))
	if eh_chefe:
		# Como no anfitrião: a vida do chefe fica no HUD, não sobre a cabeça.
		get_tree().call_group("hud", "mostrar_chefe", nome_chefe, vida, vida_maxima)
	elif bool(dados.get("barra", true)):
		_barra = preload("res://cenas/barra_de_vida.tscn").instantiate()
		_barra.name = "HPBar"
		add_child(_barra)
		_barra.position = Vector2(0, -float(dados.get("ab", 22.0)))
		_barra.vida_maxima = vida_maxima
		_barra.definir_vida_atual(vida_maxima)
	return true

func remover() -> void:
	if eh_chefe: get_tree().call_group("hud", "esconder_chefe")
	queue_free()

func _limpar(no: Node) -> void:
	no.set_script(null)
	for grupo in no.get_groups(): no.remove_from_group(grupo)
	no.process_mode = Node.PROCESS_MODE_DISABLED
	if no is CollisionObject2D:
		no.collision_layer = 0
		no.collision_mask = 0
	if no is Timer: no.stop()
	if no is AnimationPlayer: no.stop()
	if no is AnimationTree: no.active = false
	for filho in no.get_children(): _limpar(filho)

func aplicar(e: Array) -> void:
	if e.size() < 5: return
	var novo_alvo := Vector2(float(e[1]), float(e[2]))
	var agora := Time.get_ticks_msec() / 1000.0
	if _tem_alvo:
		# Velocidade medida entre dois pacotes: o inimigo continua andando até o próximo chegar, em vez de chegar atrasado.
		var dt := clampf(agora - _instante_alvo, 0.03, 0.25)
		_velocidade = (novo_alvo - _alvo) / dt
		if _velocidade.length() > 600.0: _velocidade = Vector2.ZERO
	_alvo = novo_alvo
	_instante_alvo = agora
	var anterior := vida
	vida = int(e[3])
	if e.size() >= 6: vida_maxima = maxi(vida_maxima, int(e[5]))
	esta_morto = vida <= 0
	if vida < anterior and _tem_alvo: _mostrar_dano(anterior - vida)
	if _barra != null:
		_barra.vida_maxima = vida_maxima
		if vida < anterior and _tem_alvo: _barra.atualizar_barra(vida)
		else: _barra.definir_vida_atual(vida)
	if eh_chefe and vida != anterior: get_tree().call_group("hud", "atualizar_chefe", maxi(vida, 0), vida_maxima)
	if not _tem_alvo:
		global_position = _alvo
		_tem_alvo = true
	var poses: Array = e[4]
	for i in mini(poses.size(), sprites.size()):
		var p: Array = poses[i]
		if p.size() < 6: continue
		var s := sprites[i]
		s.hframes = maxi(1, int(p[0]))
		s.vframes = maxi(1, int(p[1]))
		s.frame = clampi(int(p[2]), 0, s.hframes * s.vframes - 1)
		s.flip_h = bool(p[3])
		s.visible = bool(p[4])
		s.rotation = float(p[5])

func _process(delta: float) -> void:
	var previsto := _alvo + _velocidade * clampf(Time.get_ticks_msec() / 1000.0 - _instante_alvo, 0.0, 0.12)
	global_position = global_position.lerp(previsto, minf(1.0, delta * 22))
	z_index = Profundidade.z_de(global_position.y)

## O anfitrião já mostra o número do golpe; aqui ele vem da queda de vida recebida (vários golpes podem somar).
func _mostrar_dano(valor: int) -> void:
	var rotulo = preload("res://cenas/dano_flutuante.tscn").instantiate()
	rotulo.global_position = global_position - Vector2(0, 20.0 * maxf(scale.y, 1.0))
	rotulo.definir_dano(valor, Color.WHITE)
	get_tree().current_scene.add_child(rotulo)

func receber_dano(dano: int, empurrao: Vector2 = Vector2.ZERO) -> void:
	if controlador != null and not esta_morto: controlador.pedir_golpe(identificador, dano, empurrao)
func receber_dano_efeito(dano: int, _cor: Color) -> void: receber_dano(dano)
func aplicar_queimadura(dano: int, intervalo: float, duracao: float, cor: Color) -> void:
	controlador.pedir_efeito(identificador, {"tipo": "fogo", "dano": dano, "intervalo": intervalo, "duracao": duracao, "cor": cor.to_html()})
func aplicar_congelamento(duracao: float) -> void: controlador.pedir_efeito(identificador, {"tipo": "gelo", "duracao": duracao})
func aplicar_lentidao(fator: float, duracao: float) -> void: controlador.pedir_efeito(identificador, {"tipo": "lento", "fracao": fator, "duracao": duracao})
func congelar(_duracao: float) -> void: pass
func empurrar(_forca: Vector2) -> void: pass
func atordoar(duracao: float) -> void: controlador.pedir_efeito(identificador, {"tipo": "atordoar", "duracao": duracao})
func esta_atordoado() -> bool: return false
