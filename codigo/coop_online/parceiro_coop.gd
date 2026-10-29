extends "res://codigo/duelo/adversario_remoto.gd"
## Apenas o avatar do parceiro, sem inventário ou save locais.
var controlador: Node
var id_jogador := ""
var _placa: Node2D
var _nome: Label
var _fundo_vida: ColorRect
var _vida: ColorRect
var _aviso: Label
var _progresso: ColorRect
const LARGURA_VIDA := 30.0
var invulneravel := false
var hp_atual: int:
	get: return hp
	set(valor): hp = valor

func _ready() -> void:
	atraso = 0.05
	remove_from_group("enemy")
	add_to_group("jogadores")
	set_meta("parceiro_coop", true)
	collision_layer = 0
	var area := Area2D.new()
	area.name = "AreaDano"
	area.collision_layer = 2
	area.collision_mask = 0
	var forma := CollisionShape2D.new()
	var capsula := CapsuleShape2D.new()
	capsula.radius = 6.0
	capsula.height = 26.0
	forma.shape = capsula
	forma.position = Vector2(0, -2)
	area.add_child(forma)
	add_child(area)
	_montar_placa()

## Nome e vida sobre a cabeça, como nos beat'em ups em grupo: dá para achar o aliado e ver quem precisa de ajuda.
func _montar_placa() -> void:
	_placa = Node2D.new()
	_placa.position = Vector2(0, -64)
	_placa.z_index = 100
	add_child(_placa)
	_nome = Label.new()
	_nome.add_theme_font_override("font", preload("res://assets/ui/Planes_ValMore.ttf"))
	_nome.add_theme_font_size_override("font_size", 8)
	_nome.add_theme_constant_override("outline_size", 3)
	_nome.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.12))
	_nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_nome.size = Vector2(80, 10)
	_nome.position = Vector2(-40, -11)
	_placa.add_child(_nome)
	_fundo_vida = ColorRect.new()
	_fundo_vida.color = Color(0.1, 0.06, 0.12, 0.9)
	_fundo_vida.size = Vector2(LARGURA_VIDA + 2, 5)
	_fundo_vida.position = Vector2(-LARGURA_VIDA / 2.0 - 1, 0)
	_placa.add_child(_fundo_vida)
	_vida = ColorRect.new()
	_vida.size = Vector2(LARGURA_VIDA, 3)
	_vida.position = Vector2(1, 1)
	_fundo_vida.add_child(_vida)
	_aviso = Label.new()
	_aviso.add_theme_font_override("font", preload("res://assets/ui/Planes_ValMore.ttf"))
	_aviso.add_theme_font_size_override("font_size", 7)
	_aviso.add_theme_constant_override("outline_size", 3)
	_aviso.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.12))
	_aviso.add_theme_color_override("font_color", Color("ffd966"))
	_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aviso.size = Vector2(120, 10)
	_aviso.position = Vector2(-60, 8)
	_aviso.visible = false
	_placa.add_child(_aviso)
	_progresso = ColorRect.new()
	_progresso.color = Color("ffd966")
	_progresso.size = Vector2(0, 2)
	_progresso.position = Vector2(-LARGURA_VIDA / 2.0, 19)
	_progresso.visible = false
	_placa.add_child(_progresso)

## Cor própria de cada vaga da sala (P1 azul, P2 vermelho, P3 verde, P4 amarelo), a mesma do painel do grupo.
func definir_vaga(vaga: int) -> void:
	if _nome != null: _nome.add_theme_color_override("font_color", CORES_VAGA[clampi(vaga, 0, 3)])

const CORES_VAGA: Array[Color] = [Color("7fb5ff"), Color("ff8a80"), Color("8de08d"), Color("ffd966")]

## Aviso e barra de reanimação sobre o caído. fracao < 0 esconde tudo; texto vazio mantém só a barra.
func mostrar_reviver(fracao: float, texto := "") -> void:
	if _aviso == null: return
	_aviso.visible = fracao >= 0.0 and not texto.is_empty()
	_aviso.text = texto
	_progresso.visible = fracao > 0.0
	_progresso.size.x = LARGURA_VIDA * clampf(fracao, 0.0, 1.0)

func _process(_delta: float) -> void:
	if _nome == null: return
	_nome.text = apelido
	var fracao := clampf(float(hp) / float(maxi(hp_maximo, 1)), 0.0, 1.0)
	_vida.size.x = LARGURA_VIDA * fracao
	_vida.color = Color("66d96b") if fracao > 0.5 else (Color("f2c14e") if fracao > 0.25 else Color("e0524d"))
	_placa.visible = not estaMorto or caido

func receber_dano(dano: int, empurrao: Vector2 = Vector2.ZERO) -> void:
	if controlador != null and not estaMorto:
		controlador.dano_no_parceiro(self, dano, empurrao)

func grupo_hud() -> String: return "hud_remoto_coop"

func levantar_caido(fracao: float = 0.5) -> void:
	if controlador != null and controlador.sessao.sou_host():
		controlador.sessao.enviar_para(id_jogador, {"t": "reviver", "andar": controlador.andar, "fr": fracao})

func aplicar_petrificacao(duracao: float) -> bool:
	if controlador != null and controlador.sessao.sou_host():
		controlador.sessao.enviar_para(id_jogador, {"t": "petrificar", "andar": controlador.andar, "duracao": duracao})
	return true

func receber_hitkill_chefe() -> void:
	if controlador != null and controlador.sessao.sou_host():
		controlador.sessao.enviar_para(id_jogador, {"t": "execucao", "andar": controlador.andar})
