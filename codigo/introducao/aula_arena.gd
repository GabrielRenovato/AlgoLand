extends Node

## Primeira onda vencida depois do prólogo: Bento sai do portal da arena, vem até o lado do jogador, explica a janela entre as ondas
## (MELHORIAS, BIGORNA, ENCANTAR, PROXIMA ONDA e CIDADE), o ouro, os drops e as Brasas, e vai embora.
## O gerenciador de ondas espera executar() terminar para abrir a janela. Só marca a aula como feita no fim da conversa.
const Roteiro := preload("res://codigo/introducao/roteiro_introducao.gd")
const Guia := preload("res://codigo/introducao/guia_introducao.gd")
const Profundidade := preload("res://codigo/globais/profundidade.gd")
## Centro a centro, com os pés na mesma linha (mesma distância das conversas do prólogo)
const DISTANCIA_CONVERSA := 24.0
## De onde ele surge: um pouco mais para o lado, já aparecendo
const DISTANCIA_CHEGADA := 56.0
const TEMPO_MAXIMO_ANDANDO := 3.0

var _guia: CharacterBody2D

func executar(jogador: CharacterBody2D) -> void:
	var cena := get_parent()
	var dialogo: Control = EventosJogo.interface_p1()._telas["introducao"]
	# Sem a janela do portal, inventário ou pausa abrindo por baixo da conversa
	Introducao.cinematica = true
	jogador.desabilitar_todas_acoes(true)
	jogador.velocity = Vector2.ZERO
	jogador.animar()
	_guia = Guia.new()
	_guia.cena = cena
	_guia.jogador = jogador
	# Origem do Bento fica 9 px acima dos pés; a do jogador, PES_JOGADOR
	_guia.position = jogador.position + Vector2(0, Profundidade.PES_JOGADOR - 9.0)
	_guia.modulate.a = 0.0
	cena.add_child(_guia)
	var portal := cena.get_node_or_null("PortalDaArena") as Node2D
	var lado := _lado_livre(signf(portal.position.x - jogador.position.x) if portal != null else 1.0)
	var conversa := jogador.position + Vector2(lado * DISTANCIA_CONVERSA, Profundidade.PES_JOGADOR - 9.0)
	var chegada := conversa + Vector2(lado * (DISTANCIA_CHEGADA - DISTANCIA_CONVERSA), 0)
	# Sai da boca do portal (mesmo ponto do resgate no prólogo); sem portal, surge ao lado
	if portal != null:
		chegada = portal.position + Vector2(0, 18)
	_guia.position = chegada
	create_tween().tween_property(_guia, "modulate:a", 1.0, 0.35)
	await _andar(conversa)
	# A malha é de 8 px: o último passo acerta a linha exata dos pés
	var ajuste := create_tween()
	ajuste.tween_property(_guia, "position", conversa, 0.12)
	await ajuste.finished
	_guia.parar_para_conversa()
	jogador.parar_para_conversa(_guia.global_position)
	dialogo.iniciar(Roteiro.AULA_ARENA, "BENTO")
	EventosJogo.abrir_tela.emit("introducao")
	await dialogo.concluido
	Introducao.concluir_aula_arena()
	jogador.desabilitar_todas_acoes(true)
	await _andar(chegada)
	var sumir := create_tween()
	sumir.tween_property(_guia, "modulate:a", 0.0, 0.4)
	await sumir.finished
	_guia.queue_free()
	Introducao.cinematica = false
	if is_instance_valid(jogador):
		jogador.desabilitar_todas_acoes(false)
	queue_free()

## Lado do jogador com espaço até o ponto de chegada (prefere o lado do portal)
func _lado_livre(preferido: float) -> float:
	if preferido == 0.0:
		preferido = 1.0
	for lado in [preferido, -preferido]:
		if not _guia.test_move(_guia.global_transform, Vector2(lado * DISTANCIA_CHEGADA, 0)):
			return lado
	return preferido

func _andar(destino: Vector2) -> void:
	if not _guia.ir_ate(destino, false):
		_guia.position = destino
		return
	var limite := TEMPO_MAXIMO_ANDANDO
	while not _guia.chegou and limite > 0:
		limite -= get_physics_process_delta_time()
		await get_tree().physics_frame
