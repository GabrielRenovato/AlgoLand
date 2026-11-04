extends SceneTree
## Estrutura real do rig, pesos, ciclos e deslocamento após importar os FBX Mixamo.
var falhas := 0
func _initialize() -> void: rodar.call_deferred()
func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ", nome)
	if not ok: falhas += 1
func rodar() -> void:
	var visual = load("res://cenas/inimigos/goblin_capuz_3d.tscn").instantiate()
	root.add_child(visual)
	var s: Skeleton3D = visual.find_children("*", "Skeleton3D", true, false)[0]
	var a: AnimationPlayer = visual.animador
	verificar("rig próprio com 22 ossos", s.get_bone_count() == 22)
	verificar("parado inicia automaticamente", a.current_animation == "parado")
	var esperadas := ["parado", "correr", "ataque_1", "ataque_2", "defesa", "ferido", "morrer"]
	for nome in esperadas:
		verificar("clipe importado " + nome, a.has_animation(nome))
		if not a.has_animation(nome): continue
		var c := a.get_animation(nome)
		verificar("ciclo e duração " + nome, c.length > 0.5 and (c.loop_mode == Animation.LOOP_LINEAR) == (nome in ["parado", "correr", "defesa"]))
		visual.tocar(nome, 0.0)
		a.pause()
		var valido := true
		var posicoes := []
		for q in 17:
			a.seek(c.length * q / 17.0, true)
			s.force_update_all_bone_transforms()
			for i in s.get_bone_count():
				valido = valido and s.get_bone_global_pose(i).is_finite()
			var quadril := s.get_bone_pose_position(s.find_bone("Hips"))
			posicoes.append(quadril)
			if nome != "morrer":
				valido = valido and absf(quadril.x) < 0.01 and absf(quadril.z) < 0.01
		verificar("poses finitas e raiz no lugar " + nome, valido)
	var malhas: Array = visual.find_children("*", "MeshInstance3D", true, false)
	var pesos_validos := true
	var vertices := 0
	var arma_valida := false
	for m: MeshInstance3D in malhas:
		pesos_validos = pesos_validos and m.skin != null and m.get_node_or_null(m.skeleton) == s
		for superficie in m.mesh.get_surface_count():
			var dados := m.mesh.surface_get_arrays(superficie)
			var pesos: PackedFloat32Array = dados[Mesh.ARRAY_WEIGHTS]
			var ossos: PackedInt32Array = dados[Mesh.ARRAY_BONES]
			var pontos: PackedVector3Array = dados[Mesh.ARRAY_VERTEX]
			var influencias := pesos.size() / pontos.size()
			vertices += pontos.size()
			for v in pontos.size():
				var soma := 0.0
				for j in influencias:
					var indice := v * influencias + j
					soma += pesos[indice]
					if m.name.begins_with("Lamina_curva") and pesos[indice] > 0.001:
						arma_valida = true
						var osso_vinculado := m.skin.get_bind_bone(ossos[indice])
						var nome_vinculado := m.skin.get_bind_name(ossos[indice])
						if not nome_vinculado.is_empty(): osso_vinculado = s.find_bone(nome_vinculado)
						pesos_validos = pesos_validos and osso_vinculado == s.find_bone("RightHand")
				pesos_validos = pesos_validos and absf(soma - 1.0) < 0.002
	verificar("todos os vértices ponderados e lâmina na mão direita", pesos_validos and arma_valida and vertices > 1000)
	var laudo: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://ferramentas/inimigos/goblin_capuz_3d/validacao_faca.json"))
	verificar("laudo corresponde ao GLB atual",laudo.get("modelo_sha256")==FileAccess.get_sha256("res://assets/inimigos/goblin_capuz_3d/goblin_capuz_animado.glb"))
	var contatos: Array=laudo.get("clipes",[])
	verificar("lâmina sem interseções nos sete clipes",contatos.size()==7 and contatos.all(func(c):return c.intersecoes.is_empty()))
	verificar("clipe inválido recusado", not visual.tocar(&"inexistente"))
	visual.tocar(&"ataque_1", 0.0)
	a.advance(a.get_animation("ataque_1").length + 0.1)
	verificar("ataque retorna ao parado", a.current_animation == "parado")
	visual.tocar(&"morrer", 0.0)
	a.advance(a.get_animation("morrer").length + 0.1)
	verificar("morte não retorna ao parado", a.assigned_animation == "morrer")
	print("Falhas: ", falhas, "; vértices: ", vertices)
	quit(1 if falhas else 0)
