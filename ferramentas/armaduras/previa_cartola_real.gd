extends SceneTree

## Desenha as camadas e AnimationPlayer da cena real sem executar o jogador
## nem carregar a arena ou a partida do usuário.
const Aparencia := preload("res://Codigos/DadosLocais/aparencia.gd")

func _initialize() -> void:
	_rodar()

func _rodar() -> void:
	await process_frame
	var viewport := SubViewport.new()
	viewport.size = Vector2i(768, 576)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var indice := -1
	for i in Aparencia.total_roupas():
		if Aparencia.roupas()[i]["id"] == "traje_cavalheiro":
			indice = i
	var animacoes := ["idle_down", "idle_up", "running_right", "sword_slash_1_down"]
	for linha in 3:
		for coluna in 4:
			var real = load("res://cenas/Jogador.tscn").instantiate()
			var refs := {
				"sprite_corpo": "BaseSprites/Corpo", "sprite_cabelo": "BaseSprites/Cabelo", "sprite_roupa": "BaseSprites/Roupa",
				"corpo_espada_escudo_ataque": "AttackSwordAnimation/CorpoEspadaEscudo", "cabelo_ataque": "AttackSwordAnimation/Cabelo", "roupa_ataque": "AttackSwordAnimation/Roupa",
				"corpo_lanca_escudo_ataque": "AttackSpearAnimation/Corpo", "cabelo_lanca_ataque": "AttackSpearAnimation/Cabelo", "roupa_lanca_ataque": "AttackSpearAnimation/Roupa",
				"sprite_corpo_forja": "Forja/Corpo", "sprite_cabelo_forja": "Forja/Cabelo", "sprite_roupa_forja": "Forja/Roupa",
			}
			for chave in refs:
				real.set(chave, real.get_node("CompositeSprites/" + refs[chave]))
			real.cor_cabelo = Color("678642")
			real.definir_aparencia([0, 1, 4][linha], indice)
			var composto: Node2D = real.get_node("CompositeSprites")
			composto.get_node("Animation/AnimationTree").active = false
			real.remove_child(composto)
			viewport.add_child(composto)
			composto.position = Vector2(coluna * 192 + 96, linha * 192 + 110)
			composto.scale = Vector2(3, 3)
			var animador: AnimationPlayer = composto.get_node("Animation/AnimationPlayer")
			animador.play("RESET")
			animador.advance(0)
			animador.play(animacoes[coluna])
			animador.seek(0.15, true)
			animador.pause()
			if coluna == 3:
				composto.get_node("BaseSprites").hide()
				for nome in ["CorpoEspadaEscudo", "Cabelo", "Roupa"]:
					composto.get_node("AttackSwordAnimation/" + nome).show()
			for grupo in ["BaseSprites", "AttackSwordAnimation", "AttackSpearAnimation", "Forja"]:
				for camada in composto.get_node(grupo).get_children():
					if camada.name in ["Lanca", "Escudo", "Braco", "BracoEspada", "Arm"]:
						camada.hide()
			real.status_armas.free()
			real.free()
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var args := OS.get_cmdline_user_args()
	viewport.get_texture().get_image().save_png(args[0])
	quit()
