extends Node2D
## Arena do duelo online (só jogador contra jogador, sem ondas). Reaproveita o terreno da arena.
## Cada jogo manda o próprio estado (~15 Hz) e, quando acerta o adversário, um evento "golpe";
## quem recebe o golpe resolve defesa, aparo e dano no próprio jogador. Quem cai avisa o servidor,
## que conta o round (melhor de 3) — ver ferramentas/lobby/servidor/duelo.mjs.
const Remoto := preload("res://codigo/duelo/adversario_remoto.gd")
const ConexaoDuelo := preload("res://codigo/duelo/conexao_duelo.gd")
const FONTE := preload("res://assets/ui/Planes_ValMore.ttf")
## O dano das armas foi feito contra monstros: entre jogadores ele é reduzido.
const MULT_DANO_PVP := 0.6
const INTERVALO_ESTADO := 1.0 / 15.0
const CONTAGEM := 1.6
## Distância de cada lado em relação à chegada do portal.
const AFASTAMENTO := Vector2(72, 0)

@onready var jogador: CharacterBody2D = $Jogador
@onready var Duelo: Node = ConexaoDuelo.obter(get_tree())
var adversario: CharacterBody2D
var _hud: CanvasLayer
var _placar: Label
var _aviso: Label
var _nome_adversario: Label
var _vida_adversario: ProgressBar
var _tempo_estado := 0.0
var _contagem := 0.0
var _caiu := false
var _hp_antes := -1
var _encerrando := false
## Limite da luta: as células de terra ligadas à chegada (o desenho do chão é a parede).
var _terra: TileMapLayer
var _celulas_arena: Dictionary = {}
var _ultima_valida := Vector2.ZERO

func _ready() -> void:
	# Roda depois do jogador (prioridade maior) para desfazer o passo que sairia da terra.
	process_physics_priority = 100
	_mapear_arena()
	_hp_antes = int(jogador.hp_atual)
	adversario = Remoto.new()
	add_child(adversario)
	adversario.configurar(Duelo.adversario().get("perfil", {}))
	adversario.golpeado.connect(_ao_golpear_adversario)
	_montar_hud()
	Duelo.round_comecou.connect(_ao_round)
	Duelo.ponto_marcado.connect(_ao_ponto)
	Duelo.partida_terminou.connect(_ao_fim)
	Duelo.estado_remoto.connect(adversario.aplicar_estado)
	Duelo.evento_remoto.connect(_ao_evento)
	Duelo.caiu_local.connect(_ao_cair)
	_ao_round({"round": Duelo.round_atual})

func _ponto_do_lado(lado: int) -> Vector2:
	var chegada: Node2D = get_node("Terrains/Chegada_portal")
	return chegada.global_position + (AFASTAMENTO * (-1 if lado == 0 else 1))

func _ao_round(_dados: Dictionary) -> void:
	_caiu = false
	jogador.hp_atual = jogador.estatisticas.hp_maximo
	jogador.atualizar_barra_hp()
	jogador.global_position = _ponto_do_lado(Duelo.meu_lado)
	_ultima_valida = jogador.global_position
	jogador.velocity = Vector2.ZERO
	adversario.posicionar(_ponto_do_lado(1 - Duelo.meu_lado))
	adversario.estaMorto = false
	adversario.caido = false
	adversario.hp = adversario.hp_maximo
	# Contagem: ninguém se move nem apanha até "LUTE!".
	jogador.invulneravel = true
	jogador.desabilitar_todas_acoes(true)
	_contagem = CONTAGEM
	_mostrar("ROUND %d" % Duelo.round_atual)
	_atualizar_placar()

## Inunda a camada Terra a partir da chegada: só a área de luta, sem caminhos soltos fora dela.
func _mapear_arena() -> void:
	_terra = get_node_or_null("Terrains/Terra")
	if _terra == null: return
	var usadas := {}
	for celula in _terra.get_used_cells(): usadas[celula] = true
	var inicio := _terra.local_to_map(_terra.to_local(get_node("Terrains/Chegada_portal").global_position))
	if not usadas.has(inicio): return
	var fila: Array[Vector2i] = [inicio]
	_celulas_arena[inicio] = true
	while not fila.is_empty():
		var atual: Vector2i = fila.pop_back()
		for passo in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var vizinha: Vector2i = atual + passo
			if usadas.has(vizinha) and not _celulas_arena.has(vizinha):
				_celulas_arena[vizinha] = true
				fila.append(vizinha)

func dentro_da_arena(ponto: Vector2) -> bool:
	if _celulas_arena.is_empty(): return true
	return _celulas_arena.has(_terra.local_to_map(_terra.to_local(ponto)))

func _physics_process(_delta: float) -> void:
	if dentro_da_arena(jogador.global_position):
		_ultima_valida = jogador.global_position
	else:
		jogador.global_position = _ultima_valida
		jogador.velocity = Vector2.ZERO

func _process(delta: float) -> void:
	if _contagem > 0.0:
		_contagem -= delta
		if _contagem <= 0.0:
			jogador.desabilitar_todas_acoes(false)
			jogador.invulneravel = false
			_mostrar("LUTE!", 0.8)
	_tempo_estado -= delta
	if _tempo_estado <= 0.0 and Duelo.em_partida:
		_tempo_estado = INTERVALO_ESTADO
		Duelo.enviar_estado(estado_local())
	if is_instance_valid(adversario):
		_nome_adversario.text = adversario.apelido
		_vida_adversario.max_value = adversario.hp_maximo
		_vida_adversario.value = adversario.hp

## O que o adversário precisa para animar o meu personagem (adversario_remoto.gd: aplicar_estado).
func estado_local() -> Dictionary:
	var j = jogador
	var timer: Timer = j._temporizador
	var d = j.defesa
	var par := func(v: Vector2) -> Array: return [snappedf(v.x, 0.01), snappedf(v.y, 0.01)]
	return {
		"x": snappedf(j.global_position.x, 0.1), "y": snappedf(j.global_position.y, 0.1),
		"vx": snappedf(j.velocity.x, 0.1), "vy": snappedf(j.velocity.y, 0.1),
		"a": j._esta_atacando, "c": j._fase_combo, "tl": snappedf(timer.time_left, 0.01) if timer != null else 0.0,
		"da": par.call(j._direcao_ataque), "d3": par.call(j._direcao_golpe_3d), "dp": par.call(j.direcao_apontada()),
		"dash": j.esta_em_dash, "def": int(d.estado), "dg": par.call(d.direcao_guarda),
		"gt": snappedf(d._tempo, 0.01), "gi": d._indice, "gp": snappedf(d._pausa, 0.01),
		"gh": snappedf((Time.get_ticks_msec() - d._inicio_guarda_ms) / 1000.0, 0.01),
		"ar": j.no_arco.esta_disparando(), "ad": par.call(j.no_arco._direcao_disparo),
		"rf": j.no_reacao.visible and j.no_reacao.pose_atual == "ferido",
		"cai": j.caido or _caiu, "morto": _caiu, "hp": int(j.hp_atual), "hpm": int(j.estatisticas.hp_maximo),
		"arma": j.id_arma_atual, "es": j.usando_espada, "ec": j.usando_escudo, "la": j.usando_lanca, "arc": j.usando_arco,
	}

func _ao_golpear_adversario(dano: int, empurrao: Vector2) -> void:
	if _contagem > 0.0 or _caiu: return
	Duelo.enviar_evento({"tipo": "golpe", "dano": maxi(1, roundi(dano * MULT_DANO_PVP)), "kb": [snappedf(empurrao.x, 0.1), snappedf(empurrao.y, 0.1)]})

func _ao_evento(ev: Dictionary) -> void:
	if str(ev.get("tipo", "")) != "golpe" or _contagem > 0.0 or _caiu: return
	var kb: Array = ev.get("kb", [0, 0])
	# O próprio jogador resolve guarda, aparo, armadura e invulnerabilidade.
	jogador.receber_dano(clampi(int(ev.get("dano", 1)), 1, 9999), Vector2(float(kb[0]), float(kb[1])))

## Vida zerou (jogador.gd: morrer avisa o Duelo durante a partida).
func _ao_cair() -> void:
	if _caiu: return
	_caiu = true
	jogador.invulneravel = true
	jogador.desabilitar_todas_acoes(true)
	Duelo.avisar_queda()

func _ao_ponto(dados: Dictionary) -> void:
	var venci: bool = str(dados.get("vencedor", "")) == Duelo.eu
	_mostrar("VOCE VENCEU O ROUND" if venci else "VOCE PERDEU O ROUND", 2.0)
	if venci: adversario.estaMorto = true
	_atualizar_placar()

func _ao_fim(dados: Dictionary) -> void:
	if _encerrando: return
	_encerrando = true
	jogador.desabilitar_todas_acoes(true)
	var vencedor := str(dados.get("vencedor", ""))
	var texto := "VITORIA!" if vencedor == Duelo.eu else ("CONEXAO PERDIDA" if vencedor.is_empty() else "DERROTA")
	if str(dados.get("motivo", "")) == "abandono" and vencedor == Duelo.eu: texto = "VITORIA! (ADVERSARIO SAIU)"
	_mostrar(texto, 3.0)
	_atualizar_placar()
	await get_tree().create_timer(3.0).timeout
	voltar()

## Volta para onde estava, com a vida de antes do duelo (o duelo não cura nem fere).
func voltar() -> void:
	if _hp_antes > 0:
		jogador.hp_atual = mini(_hp_antes, jogador.estatisticas.hp_maximo)
		jogador.atualizar_barra_hp()
	jogador.invulneravel = false
	jogador.desabilitar_todas_acoes(false)
	Duelo.em_partida = false
	var destino: String = Duelo.cena_de_volta if not Duelo.cena_de_volta.is_empty() else "res://cenas/cidade.tscn"
	Duelo.reabrir_sala_ao_chegar = Duelo.conectado() and not Duelo.sala.is_empty()
	Transicao.ir_para(destino)

func _exit_tree() -> void:
	for sinal_e_metodo in [[Duelo.round_comecou, _ao_round], [Duelo.ponto_marcado, _ao_ponto], [Duelo.partida_terminou, _ao_fim],
			[Duelo.estado_remoto, adversario.aplicar_estado], [Duelo.evento_remoto, _ao_evento], [Duelo.caiu_local, _ao_cair]]:
		if sinal_e_metodo[0].is_connected(sinal_e_metodo[1]): sinal_e_metodo[0].disconnect(sinal_e_metodo[1])

# --- Interface do duelo

func _montar_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 8
	add_child(_hud)
	var topo := VBoxContainer.new()
	topo.set_anchors_preset(Control.PRESET_CENTER_TOP)
	topo.position = Vector2(-90, 6)
	topo.custom_minimum_size = Vector2(180, 0)
	topo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(topo)
	_placar = _rotulo(14)
	topo.add_child(_placar)
	_nome_adversario = _rotulo(10)
	topo.add_child(_nome_adversario)
	_vida_adversario = ProgressBar.new()
	_vida_adversario.show_percentage = false
	_vida_adversario.custom_minimum_size = Vector2(160, 7)
	var fundo := StyleBoxFlat.new()
	fundo.bg_color = Color(0.13, 0.08, 0.10, 0.85)
	var cheio := StyleBoxFlat.new()
	cheio.bg_color = Color(0.80, 0.28, 0.24)
	_vida_adversario.add_theme_stylebox_override("background", fundo)
	_vida_adversario.add_theme_stylebox_override("fill", cheio)
	topo.add_child(_vida_adversario)
	_aviso = _rotulo(22)
	_aviso.set_anchors_preset(Control.PRESET_CENTER)
	_aviso.position = Vector2(-200, -40)
	_aviso.custom_minimum_size = Vector2(400, 40)
	_hud.add_child(_aviso)

func _rotulo(tamanho: int) -> Label:
	var rotulo := Label.new()
	rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rotulo.add_theme_font_override("font", FONTE)
	rotulo.add_theme_font_size_override("font_size", tamanho)
	rotulo.add_theme_color_override("font_outline_color", Color(0.13, 0.08, 0.14))
	rotulo.add_theme_constant_override("outline_size", 4)
	rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rotulo

func _atualizar_placar() -> void:
	var meu: int = int(Duelo.placar.get(Duelo.eu, 0))
	var deles := 0
	for id in Duelo.placar:
		if str(id) != Duelo.eu: deles = int(Duelo.placar[id])
	_placar.text = "VOCE %d x %d %s" % [meu, deles, adversario.apelido if is_instance_valid(adversario) else ""]

func _mostrar(texto: String, duracao := 1.4) -> void:
	_aviso.text = texto
	_aviso.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(duracao)
	tween.tween_property(_aviso, "modulate:a", 0.0, 0.3)
