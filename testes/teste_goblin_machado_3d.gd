extends SceneTree
## Importação real, pesos, ciclos e pegadas após adaptar os clipes locais.
var falhas := 0
func _initialize() -> void: rodar.call_deferred()
func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ", nome)
	if not ok: falhas += 1
func rodar() -> void:
	var visual = load("res://cenas/inimigos/goblin_machado_3d.tscn").instantiate()
	root.add_child(visual)
	var s: Skeleton3D = visual.find_children("*", "Skeleton3D", true, false)[0]
	var a: AnimationPlayer = visual.animador
	verificar("rig próprio com 23 ossos", s.get_bone_count() == 23)
	verificar("parado inicia automaticamente", a.current_animation == "parado")
	a.pause()
	a.seek(0.0, true)
	s.force_update_all_bone_transforms()
	var arma := s.find_bone("Machado")
	verificar("mãos vinculadas ao machado", s.get_bone_parent(s.find_bone("RightHand")) == arma and s.get_bone_parent(s.find_bone("LeftHand")) == arma)
	var pegadas := {}
	for lado in ["RightHand", "LeftHand"]:
		pegadas[lado] = s.get_bone_global_pose(arma).affine_inverse() * s.get_bone_global_pose(s.find_bone(lado))
	var esperadas := ["parado", "correr", "ataque_1", "ataque_2", "andar", "ferido", "morrer"]
	for nome in esperadas:
		verificar("clipe importado " + nome, a.has_animation(nome))
		if not a.has_animation(nome): continue
		var c := a.get_animation(nome)
		verificar("ciclo e duração " + nome, c.length > 0.5 and (c.loop_mode == Animation.LOOP_LINEAR) == (nome in ["parado", "correr", "andar"]))
		visual.tocar(nome, 0.0)
		a.pause()
		var valido := true
		var posicoes := []
		var pegada_valida := true
		var erro_max := 0.0
		var angulo_max := 0.0
		for q in 17:
			a.seek(c.length * q / 17.0, true)
			s.force_update_all_bone_transforms()
			for i in s.get_bone_count():
				valido = valido and s.get_bone_global_pose(i).is_finite()
			for lado in pegadas:
				var relativa := s.get_bone_global_pose(arma).affine_inverse() * s.get_bone_global_pose(s.find_bone(lado))
				erro_max = maxf(erro_max, relativa.origin.distance_to(pegadas[lado].origin))
				angulo_max = maxf(angulo_max, relativa.basis.get_rotation_quaternion().angle_to(pegadas[lado].basis.get_rotation_quaternion()))
				pegada_valida = pegada_valida and relativa.origin.distance_to(pegadas[lado].origin) < 0.001
				pegada_valida = pegada_valida and relativa.basis.get_rotation_quaternion().angle_to(pegadas[lado].basis.get_rotation_quaternion()) < 0.005
			var quadril := s.get_bone_pose_position(s.find_bone("Hips")) - s.get_bone_rest(s.find_bone("Hips")).origin
			posicoes.append(quadril)
			if nome != "morrer":
				valido = valido and absf(quadril.x) < (0.20 if nome.begins_with("ataque") else 0.01) and absf(quadril.z) < (0.20 if nome.begins_with("ataque") else 0.01)
		print("PEGADA ",nome," erro_m=",erro_max," angulo_rad=",angulo_max)
		verificar("duas mãos fixas no cabo " + nome, pegada_valida)
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
					if m.name.begins_with("Machado_") and pesos[indice] > 0.001:
						arma_valida = true
						var osso_vinculado := m.skin.get_bind_bone(ossos[indice])
						var nome_vinculado := m.skin.get_bind_name(ossos[indice])
						if not nome_vinculado.is_empty(): osso_vinculado = s.find_bone(nome_vinculado)
						pesos_validos = pesos_validos and osso_vinculado == s.find_bone("Machado")
				pesos_validos = pesos_validos and absf(soma - 1.0) < 0.002
	verificar("todos os vértices ponderados e machado preso ao osso da arma", pesos_validos and arma_valida and vertices > 1000)
	verificar("clipe inválido recusado", not visual.tocar(&"inexistente"))
	visual.tocar(&"ataque_1", 0.0)
	a.advance(a.get_animation("ataque_1").length + 0.1)
	verificar("ataque retorna ao parado", a.current_animation == "parado")
	visual.tocar(&"morrer", 0.0)
	a.advance(a.get_animation("morrer").length + 0.1)
	verificar("morte não retorna ao parado", a.assigned_animation == "morrer")
	print("Falhas: ", falhas, "; vértices: ", vertices)
	quit(1 if falhas else 0)
