extends SceneTree

var falhas := 0

class JogadorTeste extends Node2D:
	var estaMorto := false
	var invulneravel := false
	var golpes := 0
	var dano_recebido := 0
	var empurrao := Vector2.ZERO
	func receber_dano(dano: int, forca: Vector2) -> void:
		golpes += 1
		dano_recebido = dano
		empurrao = forca
		global_position += forca.normalized() * 100

func _initialize() -> void:
	_rodar()

func verificar(nome: String, condicao: bool) -> void:
	print("OK " if condicao else "FALHA ", nome)
	if not condicao:
		falhas += 1

func _rodar() -> void:
	await process_frame
	var cena := Node2D.new()
	root.add_child(cena)
	current_scene = cena
	var jogador := JogadorTeste.new()
	jogador.name = "Jogador"
	jogador.position = Vector2(55, 0)
	cena.add_child(jogador)
	var chefe = load("res://cenas/inimigos/dragao_vermelho.tscn").instantiate()
	cena.add_child(chefe)
	chefe.set_physics_process(false)
	chefe._physics_process(0.016)
	verificar("aproximação inicia a patada automaticamente", chefe.ataque_atual == "patada" and chefe.estado == chefe.Estado.PREPARANDO)
	verificar("patada não é dano de contato", jogador.golpes == 0 and not chefe.get_node("ataque").monitoring)
	chefe._physics_process(0.35)
	chefe._physics_process(0.1)
	verificar("patada causa dano menor e empurrão maior", jogador.golpes == 1 and jogador.dano_recebido < chefe.dano and jogador.empurrao.length() >= 479)
	verificar("patada empurra para fora da distância inicial", jogador.position.x > 150)
	chefe._physics_process(0.2)
	chefe._physics_process(0.16)
	verificar("patada emenda sopro sem recarga normal", chefe.estado == chefe.Estado.PREPARANDO and chefe.ataque_atual == "sopro")
	var esperado: Vector2 = (chefe.to_local(jogador.global_position) - chefe._area_golpe.origem).normalized()
	verificar("sopro mira a posição depois do empurrão", chefe._direcao_golpe.is_equal_approx(esperado))
	verificar("patada tem recarga para não repetir a cada frame", chefe._recarga_patada > 3)
	chefe.aplicar_congelamento(1.0)
	var tempo: float = chefe._tempo_estado
	chefe._physics_process(0.5)
	verificar("congelamento pausa também o combo", chefe._tempo_estado == tempo)
	chefe.queue_free()
	await process_frame
	cena.queue_free()
	await process_frame
	print("Falhas: ", falhas)
	quit(falhas)
