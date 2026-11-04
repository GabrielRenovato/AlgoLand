extends SceneTree
## Confere encaixe, tempos e reprodução do estudo sem substituir o chefe ativo.
var falhas := 0

func conferir(nome: String, condicao: bool) -> void:
	print("OK " if condicao else "FALHA ", nome)
	if not condicao: falhas += 1

func _initialize() -> void:
	rodar.call_deferred()

func rodar() -> void:
	var visual: AnimatedSprite2D = load("res://cenas/inimigos/lorde_goblin_2d_visual.tscn").instantiate()
	root.add_child(visual)
	var ficha: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/inimigos/lorde_goblin_2d/registro_animacoes.json"))
	var frames := visual.sprite_frames
	conferir("oito quadros e golpe sem repeticao", frames.get_frame_count("martelada_direita") == 8 and not frames.get_animation_loop("martelada_direita"))
	conferir("raiz dos pes e escala do chefe", visual.offset == Vector2(0,-194) and visual.scale == Vector2.ONE*float(ficha.escala))
	var tempo := 0.0
	var margem := true
	var tempos := true
	for i in 8:
		var textura: AtlasTexture = frames.get_frame_texture("martelada_direita",i)
		var imagem := Image.load_from_file(textura.atlas.resource_path).get_region(Rect2i(textura.region))
		var area := imagem.get_used_rect()
		margem = margem and area.position.x >= 16 and area.position.y >= 16 and area.end.x <= 496 and area.end.y <= 496
		var duracao := frames.get_frame_duration("martelada_direita",i)/frames.get_animation_speed("martelada_direita")
		tempos = tempos and is_equal_approx(duracao,float(ficha.duracoes_ms[i])/1000.0)
		tempo += duracao
	conferir("corpo e marreta inteiros com margem nas oito poses", margem)
	conferir("duracoes do motor iguais ao registro e total de um segundo", tempos and is_equal_approx(tempo,1.0))
	conferir("impacto no quadro do contato aos 480ms", ficha.impacto_quadro == 4 and ficha.impacto_ms == 480)
	visual.play("martelada_direita")
	await create_timer(1.15).timeout
	conferir("reproducao termina na guarda sem repetir", not visual.is_playing() and visual.frame == 7)
	visual.queue_free()
	quit(1 if falhas else 0)
