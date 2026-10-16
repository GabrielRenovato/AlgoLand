extends SceneTree
const Aparencia := preload("res://codigo/dados/aparencia.gd")
var imagens := {}
var falhas := 0
var amostras := 0
var cabelos_ocultos := []

func _initialize() -> void:
	_rodar()

func _rodar() -> void:
	if ProjectSettings.get_setting("application/config/name") != "AlgoLand testes Carrasco":
		quit(1)
		return
	await process_frame
	var arena: Node = load("res://cenas/cenario.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	await process_frame
	arena.process_mode = Node.PROCESS_MODE_DISABLED
	var jogador: Node = arena.get_node("Jogador")
	jogador.troca_sem_pose = true
	jogador.equipar_lanca()
	jogador.no_reacao.encerrar()
	jogador._arvore_animacao.active = true
	cabelos_ocultos = [jogador.sprite_cabelo,jogador.cabelo_lanca_ataque,jogador.no_reacao._cabelo]
	var roupas := [2]
	if "--conjuntos" in OS.get_cmdline_user_args():
		for indice in Aparencia.total_roupas():
			if not Aparencia.raiz_armadura_visual(indice).is_empty():
				roupas.append(indice)
	for roupa in roupas:
		for cabelo in [0,4,6]:
			jogador.definir_aparencia(cabelo,roupa)
			for direcao in [Vector2.DOWN,Vector2.UP,Vector2.RIGHT,Vector2.LEFT]:
				for golpe in [1,2,3]:
					jogador._on_temporizador_ataque_timeout()
					jogador._direcao_ataque = direcao
					jogador.virar_para(direcao)
					jogador._maquina_estados.start("idle")
					jogador._arvore_animacao.advance(0)
					jogador.iniciar_slash_ataque_lanca("AtaqueLancaSlash_%d" % golpe,0.5)
					for instante in 32:
						jogador._arvore_animacao.advance(1.0/60)
						amostras += 1
						var quadros := []
						for sprite: Sprite2D in [jogador.corpo_lanca_escudo_ataque,jogador.cabelo_lanca_ataque,jogador.roupa_lanca_ataque,jogador.braco_lanca_ataque]:
							quadros.append(sprite.frame)
							if not sprite.is_visible_in_tree() or _vazio(sprite):
								print("FALHA cabelo=%d direção=%s golpe=%d instante=%d camada=%s quadro=%d visivel=%s" % [cabelo,direcao,golpe,instante,sprite.name,sprite.frame,sprite.is_visible_in_tree()])
								falhas += 1
						if quadros[0] != quadros[1] or quadros[0] != quadros[2] or quadros[0] != quadros[3]:
							print("FALHA quadros divergentes: ",quadros)
							falhas += 1
				# Confere a volta ao movimento e as poses de sacar, guardar e aparar.
				jogador._on_temporizador_ataque_timeout()
				for andando in [false,true]:
					jogador.velocity = direcao*30 if andando else Vector2.ZERO
					jogador._arvore_animacao.set("parameters/running/blend_position",direcao)
					jogador.animar()
					for instante in 32:
						jogador._arvore_animacao.advance(1.0/60)
						for sprite: Sprite2D in [jogador.sprite_corpo,jogador.sprite_cabelo,jogador.sprite_roupa,jogador.sprite_lanca]:
							_inspecionar(sprite,"movimento %s %s" % [andando,direcao])
				for pose in ["sacar","guardar","aparar","esquiva","ferido"]:
					jogador.no_reacao.tocar(pose,direcao,"lanca","lanca_basica",1,0)
					for coluna in jogador.no_reacao._sequencia.size():
						jogador.no_reacao._indice = coluna
						jogador.no_reacao._aplicar_quadro()
						for sprite: Sprite2D in [jogador.no_reacao._corpo,jogador.no_reacao._cabelo,jogador.no_reacao._roupa,jogador.no_reacao._arma]:
							_inspecionar(sprite,pose+str(direcao))
					jogador.no_reacao.encerrar()
	jogador._temporizador.stop()
	arena.queue_free()
	current_scene = null
	await process_frame
	print("Amostras reais: %d; falhas: %d" % [amostras,falhas])
	quit(falhas)

func _inspecionar(sprite: Sprite2D, contexto: String) -> void:
	amostras += 1
	if not sprite.is_visible_in_tree() or _vazio(sprite):
		print("FALHA %s camada=%s quadro=%d" % [contexto,sprite.name,sprite.frame])
		falhas += 1

func _vazio(sprite: Sprite2D) -> bool:
	var chave := sprite.texture.get_instance_id()
	if not imagens.has(chave):
		imagens[chave] = sprite.texture.get_image()
	var imagem: Image = imagens[chave]
	if sprite in cabelos_ocultos and imagem.is_invisible():
		return false # Elmos fechados ocultam a camada inteira de cabelo.
	var lado := imagem.get_width()/8
	return imagem.get_region(Rect2i((sprite.frame%8)*lado,(sprite.frame/8)*lado,lado,lado)).is_invisible()
