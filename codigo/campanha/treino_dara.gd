extends Node
## Treino curto de Dara: bloquear, esquivar e contra-atacar o boneco. O golpe do boneco é leve (DANO) e
## o resultado é lido no jogador (guarda, esquiva e aparo perfeito), então vale para qualquer arma com escudo.
signal terminado(concluido: bool)
enum Fase { BLOQUEIO, ESQUIVA, CONTRA }
const Boneco := preload("res://codigo/campanha/boneco_treino.gd")
const METAS := [3, 3, 2]
const TITULOS := ["Bloqueio", "Esquiva", "Contra-ataque"]
const DICAS := [
	"Segure Ctrl para defender quando o boneco levantar o braço.",
	"Aperte Shift para esquivar quando o boneco levantar o braço.",
	"Defenda o golpe e ataque o boneco logo em seguida.",
]
const DANO := 4
const ALCANCE := 110.0
const AVISO := 0.8
const JANELA_CONTRA := 3.0
var cena: Node2D
var jogador: Node2D
var boneco: Node2D
var fase := Fase.BLOQUEIO
var acertos := 0
var _espera := 1.5
var _aviso := 0.0
var _janela := 0.0
var _longe := 0.0
var _ativo := false

func iniciar(ponto: Vector2) -> void:
	boneco = Boneco.new()
	boneco.position = ponto
	jogador.get_parent().add_child(boneco)
	boneco.golpeado.connect(_ao_golpear_boneco)
	_ativo = true
	_anunciar_fase()

func ativo() -> bool:
	return _ativo

func encerrar(concluido: bool) -> void:
	if not _ativo:
		return
	_ativo = false
	if is_instance_valid(boneco):
		boneco.queue_free()
	terminado.emit(concluido)
	queue_free()

func _anunciar_fase() -> void:
	cena.hud.anunciar("Treino: %s" % TITULOS[fase], DICAS[fase], 4.0)

func _process(delta: float) -> void:
	if not _ativo:
		return
	if not is_instance_valid(jogador) or not is_instance_valid(boneco):
		encerrar(false)
		return
	if jogador.estaMorto:
		encerrar(false)
		return
	if not cena.interface._telas_abertas.is_empty():
		return
	if _janela > 0.0:
		_janela -= delta
		if _janela <= 0.0:
			_falhar("Tarde demais. Defenda e ataque logo depois.")
		return
	if _aviso > 0.0:
		_aviso -= delta
		boneco.definir_armando(1.0 - maxf(_aviso, 0.0) / AVISO)
		if _aviso <= 0.0:
			_golpear()
		return
	if jogador.global_position.distance_to(boneco.global_position) > ALCANCE:
		_longe += delta
		if _longe > 6.0:
			_longe = 0.0
			cena._avisar("Chegue perto do boneco de treino.")
		return
	_espera -= delta
	if _espera <= 0.0:
		_aviso = AVISO

func _golpear() -> void:
	boneco.definir_armando(0.0)
	var direcao: Vector2 = (jogador.global_position - boneco.global_position).normalized()
	if jogador.hp_atual <= DANO + 2:
		jogador.curar(DANO + 2)
	var com_guarda: bool = jogador.defesa.em_guarda()
	var esquivou: bool = jogador.invulneravel or jogador.esta_em_dash
	var vida_antes: int = int(jogador.hp_atual)
	var aparo_antes: Variant = jogador.contragolpe_ate_ms
	jogador.receber_dano(DANO, direcao * 120.0)
	var perdeu: int = vida_antes - int(jogador.hp_atual)
	var defendeu: bool = jogador.contragolpe_ate_ms != aparo_antes or (com_guarda and perdeu < DANO)
	match fase:
		Fase.BLOQUEIO:
			if defendeu:
				_acertar()
			else:
				_falhar("Você esquivou. Agora defenda com Ctrl." if esquivou else "O golpe passou. Levante a guarda antes dele.")
		Fase.ESQUIVA:
			if esquivou:
				_acertar()
			else:
				_falhar("Você defendeu. Agora esquive com Shift." if defendeu else "O golpe passou. Esquive quando o braço subir.")
		Fase.CONTRA:
			if defendeu:
				_janela = JANELA_CONTRA
				cena._avisar("Agora ataque!")
			else:
				_falhar("Defenda o golpe primeiro. Depois ataque.")

func _ao_golpear_boneco() -> void:
	if _ativo and fase == Fase.CONTRA and _janela > 0.0:
		_janela = 0.0
		_acertar()

func _acertar() -> void:
	acertos += 1
	_espera = 1.6
	if acertos < METAS[fase]:
		cena._avisar("%s %d/%d" % [TITULOS[fase], acertos, METAS[fase]])
		return
	acertos = 0
	if fase == Fase.CONTRA:
		encerrar(true)
		return
	fase = (fase + 1) as Fase
	_espera = 2.5
	_anunciar_fase()

func _falhar(texto: String) -> void:
	_espera = 1.8
	cena._avisar(texto)
