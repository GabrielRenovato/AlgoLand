extends RefCounted

## Aproximação lateral, sentar, pose em repouso e levantar sem atravessar as colisões do corredor.
const Dados := preload("res://codigo/cidade/dados_cidade.gd")
const DURACAO := 0.9
const QUADROS := 9
const TEMPO_ACOMODAR := 0.55
## A folha de costas preserva o pivô de caminhada; o quadril sentado precisa subir até o tampo do banco.
const AJUSTE_COSTAS := Vector2(0, -8)
var estado := "pe"
var _banco: Node2D
var _tempo := 0.0
var _chegada := Vector2.ZERO
var _sentado := Vector2.ZERO
var _textura_original: Texture2D
var _posicao_sprite_original := Vector2.ZERO
var _folha: Texture2D
var _grade := Vector2i(7, 4)

func ocupado() -> bool:
	return estado != "pe"

func _pode_sentar(npc: Node2D) -> bool:
	return npc.vila.local == "pousada" and Dados.LUGARES_FESTA.has(npc.id) and npc.visible and not npc.dormindo \
		and not npc._saindo and not npc.agenda.get("dormindo", false) and not npc.passeando_taverna and not npc.atendendo_mesas

func atualizar(npc: Node2D, delta: float) -> bool:
	var pode := _pode_sentar(npc)
	if estado == "pe":
		if not pode:
			_liberar()
			return false
		if _folha == null:
			var caminho := "res://assets/npcs/cidade/sentados/" + str(Dados.MORADORES[npc.id]["folha"]) + ("_costas" if npc.id in Dados.COSTAS_FESTA else "") + ".png"
			if not ResourceLoader.exists(caminho):
				return false
			_folha = load(caminho)
		if not is_instance_valid(_banco):
			for banco in npc.get_tree().get_nodes_in_group("assentos"):
				if banco.get_world_2d() != npc.get_world_2d() or banco.ocupada:
					continue
				if banco.global_position.distance_to(Dados.LUGARES_FESTA[npc.id] + Vector2(0, 3)) < 4:
					_banco = banco
					_banco.ocupada = true
					_banco.set_meta("morador", npc.id)
					_sentado = Dados.LUGARES_FESTA[npc.id]
					# O corredor entre bancos não comporta o corpo: chega pelo lado da fileira.
					_chegada = _sentado + (Vector2(32, 0) if npc.id in Dados.COSTAS_FESTA else Vector2(0, -12))
					npc._ir_ate(_chegada)
					if not npc.caminho.is_empty():
						_chegada = npc.caminho[-1]
					break
		if not is_instance_valid(_banco) or not npc.caminho.is_empty():
			return false
		_textura_original = npc.sprite.texture
		_posicao_sprite_original = npc.sprite.position
		_grade = Vector2i(npc.sprite.hframes, npc.sprite.vframes)
		_chegada = npc.position
		estado = "acomodando"
		_tempo = 0
	if not pode and estado in ["sentando", "sentado", "acomodando"]:
		estado = "desacomodando" if estado == "acomodando" else "levantando"
		_tempo = 0.0
	_tempo += delta
	var p := clampf(_tempo / DURACAO, 0, 1)
	match estado:
		"acomodando":
			_andar(npc, _chegada, _sentado, _tempo / TEMPO_ACOMODAR)
			if _tempo >= TEMPO_ACOMODAR:
				_trocar_folha(npc, true)
				estado = "sentando"
				_tempo = 0
		"sentando":
			npc.position = _sentado
			_alinhar_pose(npc, p)
			npc.sprite.frame = mini(int(p * QUADROS), QUADROS - 1)
			if p >= 1:
				estado = "sentado"
		"sentado":
			npc.position = _sentado
			_alinhar_pose(npc, 1.0)
			npc.sprite.frame = QUADROS - 1
		"levantando":
			_alinhar_pose(npc, 1.0 - p)
			npc.sprite.frame = maxi(QUADROS - 1 - int(p * QUADROS), 0)
			if p >= 1:
				_trocar_folha(npc, false)
				estado = "desacomodando"
				_tempo = 0
		"desacomodando":
			_andar(npc, _sentado, _chegada, _tempo / TEMPO_ACOMODAR)
			if _tempo >= TEMPO_ACOMODAR:
				_liberar()
				estado = "pe"
				npc._ir_ate(npc._alvo)
				return false
	if is_instance_valid(_banco):
		# O corpo fica acima do banco também na pose de costas.
		npc.z_index = _banco.z_da_cadeira() + 1
	return true

func _andar(npc: Node2D, de: Vector2, ate: Vector2, p: float) -> void:
	npc.position = de.lerp(ate, clampf(p, 0, 1))
	var linha: int = npc._direcao(ate - de)
	npc.sprite.frame = linha * _grade.x + 1 + int(_tempo * 10) % npc._quadros_andar

func _trocar_folha(npc: Node2D, sentando: bool) -> void:
	npc.sprite.frame = 0
	npc.sprite.texture = _folha if sentando else _textura_original
	npc.sprite.hframes = QUADROS if sentando else _grade.x
	npc.sprite.vframes = 1 if sentando else _grade.y
	npc.sprite.position = _posicao_sprite_original

func _alinhar_pose(npc: Node2D, progresso: float) -> void:
	npc.sprite.position = _posicao_sprite_original + ((AJUSTE_COSTAS * progresso).round() if npc.id in Dados.COSTAS_FESTA else Vector2.ZERO)

func _liberar() -> void:
	if is_instance_valid(_banco):
		_banco.ocupada = false
		_banco.remove_meta("morador")
	_banco = null
