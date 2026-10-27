extends Node2D
## Prévia do personagem 3D fora do jogo (tela de criação): faz o papel do jogador para o
## HeroiBase3D, só com a aparência e sem equipamento. O herói não processa sozinho;
## a tela escolhe a direção e o clipe.
const HeroiBase3D := preload("res://codigo/jogador/heroi_base_3d.gd")
const DIRECOES := [0.0, PI/2.0, PI, -PI/2.0] # frente, direita, costas, esquerda

# Campos que o HeroiBase3D e seus modificadores leem do jogador.
var aparencia_raven: Dictionary = {}
var roupas_3d: Dictionary = {}
var usando_espada := false
var usando_lanca := false
var usando_arco := false
var usando_escudo := false
var modo_fazenda := false
var id_arma_atual := ""
var eh_p2 := false
var _fase_combo := 0
var _esta_atacando := false
var esta_em_dash := false
var esta_em_acao_fazenda := false
var esta_forjando := false
var esta_sentado := false
var estaMorto := false
var caido := false
var velocity := Vector2.ZERO
var _direcao_ataque := Vector2.DOWN
var _direcao_golpe_3d := Vector2.DOWN
var duracao_dash := 0.15
var _tempo_sentado := 0.0
var _frente_sentado := 0
var _lado_sentado := 0
var heroi: Node2D

func carregar_de_json() -> Dictionary:
	return {"roupas_3d": roupas_3d}

func _ready() -> void:
	heroi = HeroiBase3D.new()
	heroi.pecas_visiveis = 15
	add_child(heroi)
	heroi.set_process(false)
	heroi._acao = "parado"
	heroi._player.play("Idle_Loop")
	heroi._encaixar_espada(false)
	# O herói desce os pés até a linha do jogador (PES_JOGADOR); aqui os pés ficam na origem.
	position.y = -heroi.position.y

## Aplica aparência e roupas; `direcao` 0..3 como no Raven (frente, direita, costas, esquerda).
func mostrar(aparencia: Dictionary, roupas: Dictionary, direcao: int) -> void:
	aparencia_raven = aparencia
	roupas_3d = roupas
	if heroi == null or heroi._player == null: return
	if heroi.roupas_3d != roupas: heroi.definir_roupas_3d(roupas)
	heroi._aplicar_cores()
	heroi._modelo.rotation.y = DIRECOES[posmod(direcao, 4)]
