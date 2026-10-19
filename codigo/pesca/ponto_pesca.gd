extends "res://codigo/logica/interagivel.gd"

## Lugar da praia (e do pier) de onde dá para pescar: a interação (F/A) lança a linha para a água à frente.
## `direcao` é para onde fica a água; `ambiente` escolhe os peixes ("mar" ou "rio", ver peixes.gd).

const Sessao := preload("res://codigo/pesca/sessao_pesca.gd")

@export var direcao := Vector2.DOWN
@export var ambiente := "mar"

func _ready() -> void:
	nome_tela = "pesca"
	so_entre_ondas = false
	deslocamento_aviso = Vector2(0, -34)
	super._ready()

func pode_interagir_para(jogador: Node2D) -> bool:
	return jogador != null and jogador.get_world_2d() == get_world_2d() and jogador.movimento_habilitado \
		and not bool(jogador.get("esta_sentado")) and not Sessao.em_andamento(jogador) and not Transicao.ocupada \
		and Introducao.permite_interacao(self) and EventosJogo.inventario_de(jogador).tem_espaco()

func pode_interagir() -> bool:
	var jogador := Cooperativo.jogador_no_ambiente(self)
	return jogador != null and jogador.movimento_habilitado and not Sessao.em_andamento(jogador) and super.pode_interagir()

func abrir_tela() -> void:
	_pescar(Cooperativo._jogador1())

func abrir_tela_p2() -> void:
	_pescar(Cooperativo.jogador2())

func _pescar(jogador: Node2D) -> void:
	if not pode_interagir_para(jogador):
		return
	EventosJogo.inventario_de(jogador).sincronizar_vara()
	if not EventosJogo.inventario_de(jogador).vara_na_mao:
		# Funciona igual no teclado, no controle e no toque: a vara se escolhe na barra de baixo (casa, tecla, RB ou toque)
		Sons.tocar("erro", 0.0)
		get_tree().call_group(jogador.grupo_hud(), "avisar_barra", "EQUIPE A VARA NA BARRA DE BAIXO")
		return
	Sessao.new().iniciar(jogador, direcao.normalized(), ambiente)
