extends "res://codigo/logica/interagivel.gd"

var id := ""

func _ready() -> void:
	nome_tela = "conversa_cidade"
	so_entre_ondas = false
	deslocamento_aviso = Vector2(0, -34)
	super._ready()

func pode_interagir() -> bool:
	var jogador: Node = Cooperativo.jogador_no_ambiente(self)
	return get_parent().visible and not get_parent().ocupado_na_forja and jogador != null and jogador.movimento_habilitado and not Transicao.ocupada and super.pode_interagir()

## Cooperativo: cada jogador conversa pelo próprio estado (antes valia o do jogador mais perto do morador, e um
## jogador sentado ao lado travava a conversa do outro)
func pode_interagir_para(jogador: Node2D) -> bool:
	return jogador != null and get_parent().visible and not get_parent().ocupado_na_forja and jogador.get_world_2d() == get_world_2d() \
		and jogador.movimento_habilitado and not bool(jogador.get("esta_sentado")) and not Transicao.ocupada \
		and Introducao.permite_interacao(self)

func abrir_tela() -> void:
	if pode_interagir():
		Cidade.conversar(id)

func abrir_tela_p2() -> void:
	if pode_interagir_para(Cooperativo.jogador2()):
		Cidade.conversar(id, Cooperativo.jogador2())

func _ao_tela_aberta(nome: String) -> void:
	if nome == nome_tela:
		_tela_aberta = Cidade.interlocutor == id

func _ao_corpo_saiu(corpo: Node2D) -> void:
	if corpo.is_in_group("character"):
		jogador_perto = false
		_aviso.visible = false
		# Todos os moradores compartilham a mesma tela. Só o interlocutor pode fechá-la.
		if _tela_aberta and Cidade.interlocutor == id:
			fechar_tela()
