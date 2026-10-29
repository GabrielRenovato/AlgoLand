extends CharacterBody2D
## Réplica só visual: sem scripts de IA, timers, drops ou execução de animações do host.
const Profundidade := preload("res://codigo/globais/profundidade.gd")
var controlador: Node
var identificador := 0
var vida := 1
var esta_morto := false
var eh_chefe := false
var sprites: Array[Sprite2D] = []
var _alvo := Vector2.ZERO
var _tem_alvo := false

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
	scale = Vector2(float(dados.get("sx", 1)), float(dados.get("sy", 1)))
	global_position = Vector2(float(dados.get("x", 0)), float(dados.get("y", 0)))
	_alvo = global_position
	# As texturas são descritas só no nascimento, nunca enviadas como imagens pela rede.
	var texturas: Array = dados.get("texturas", [])
	for i in mini(texturas.size(), sprites.size()):
		var t := str(texturas[i])
		if t.begins_with("res://assets/inimigos/") and not ".." in t and t.ends_with(".png"):
			sprites[i].texture = load(t)
	return true

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
	_alvo = Vector2(float(e[1]), float(e[2]))
	vida = int(e[3])
	esta_morto = vida <= 0
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
	global_position = global_position.lerp(_alvo, minf(1.0, delta * 18))
	z_index = Profundidade.z_de(global_position.y)

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
