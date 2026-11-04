extends SceneTree
## Contratos do GLB: pele vinculada, arma na mão, origem e ciclo sem deriva.
var falhas := 0

func _initialize() -> void:
	rodar.call_deferred()

func verificar(nome: String, valido: bool) -> void:
	print("OK " if valido else "FALHA ", nome)
	if not valido: falhas += 1

func rodar() -> void:
	var visual = load("res://cenas/inimigos/lorde_goblin_3d.tscn").instantiate()
	root.add_child(visual)
	visual.set_process(false)
	var esqueleto: Skeleton3D = visual.find_children("*", "Skeleton3D", true, false)[0]
	var animador: AnimationPlayer = visual.find_children("*", "AnimationPlayer", true, false)[0]
	verificar("esqueleto próprio de dezoito ossos", esqueleto.get_bone_count() == 18)
	var arma := esqueleto.find_bone("martelo")
	var mao := esqueleto.find_bone("mao_D")
	verificar("martelo vinculado à mão direita", arma >= 0 and mao >= 0 and esqueleto.get_bone_parent(arma) == mao)
	verificar("respiração inicia e repete", animador.current_animation == "parado" and animador.get_animation("parado").loop_mode == Animation.LOOP_LINEAR)
	animador.pause()
	animador.seek(0,true)
	esqueleto.force_update_all_bone_transforms()
	var pegada := esqueleto.get_bone_global_pose(mao).affine_inverse() * esqueleto.get_bone_global_pose(arma)
	var ciclo_valido := true
	for i in 17:
		animador.seek(animador.get_animation("parado").length * i/16.0,true)
		esqueleto.force_update_all_bone_transforms()
		var relativa := esqueleto.get_bone_global_pose(mao).affine_inverse() * esqueleto.get_bone_global_pose(arma)
		ciclo_valido = ciclo_valido and relativa.origin.distance_to(pegada.origin) < .0001
		for osso in esqueleto.get_bone_count():
			ciclo_valido = ciclo_valido and esqueleto.get_bone_global_pose(osso).is_finite()
		ciclo_valido = ciclo_valido and esqueleto.get_bone_global_pose(esqueleto.find_bone("raiz")).origin.length() < .001
	verificar("ciclo finito, raiz estável e empunhadura preservada", ciclo_valido)
	var pesos_validos := true
	var texturas_validas := true
	var vertices := 0
	var vertices_mao := 0
	var vertices_arma: Array[Vector3] = []
	var folga_mao_valida := true
	var limites := AABB()
	var primeiro := true
	for instancia: MeshInstance3D in visual.find_children("*", "MeshInstance3D", true, false):
		if instancia.skin == null: continue # Anéis de efeito não pertencem à pele.
		var caixa: AABB = instancia.global_transform * instancia.get_aabb()
		limites = caixa if primeiro else limites.merge(caixa)
		primeiro = false
		pesos_validos = pesos_validos and instancia.skin != null and instancia.get_node_or_null(instancia.skeleton) == esqueleto
		for superficie in instancia.mesh.get_surface_count():
			var mat: BaseMaterial3D = instancia.mesh.surface_get_material(superficie)
			texturas_validas = texturas_validas and mat.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST
			var dados: Array = instancia.mesh.surface_get_arrays(superficie)
			var pontos: PackedVector3Array = dados[Mesh.ARRAY_VERTEX]
			var pesos: PackedFloat32Array = dados[Mesh.ARRAY_WEIGHTS]
			var ossos: PackedInt32Array = dados[Mesh.ARRAY_BONES]
			var influencias := int(pesos.size()/pontos.size())
			vertices += pontos.size()
			for v in pontos.size():
				var soma := 0.0
				for j in influencias:
					var indice := v*influencias+j
					soma += pesos[indice]
					pesos_validos = pesos_validos and is_finite(pesos[indice]) and pesos[indice] >= 0 and ossos[indice] >= 0 and ossos[indice] < instancia.skin.get_bind_count()
					if pesos[indice] > .5:
						var nome_osso := instancia.skin.get_bind_name(ossos[indice])
						var osso_vinculado := esqueleto.find_bone(nome_osso) if not nome_osso.is_empty() else instancia.skin.get_bind_bone(ossos[indice])
						if osso_vinculado == arma:
							vertices_arma.append(esqueleto.global_transform.affine_inverse()*instancia.global_transform*pontos[v])
						if osso_vinculado == mao:
							var ponto: Vector3 = instancia.global_transform * pontos[v]
							var distancia_cabo := Vector2(ponto.x+1.47,ponto.z-.33).length()
							folga_mao_valida = folga_mao_valida and distancia_cabo >= .0595*1.5
							vertices_mao += 1
				pesos_validos = pesos_validos and absf(soma-1.0) < .001
	verificar("vértices com pesos normalizados e ligações válidas", pesos_validos and vertices > 1000)
	verificar("pintura preserva filtro nearest", texturas_validas)
	verificar("a pegada envolve o cabo sem atravessá-lo", folga_mao_valida and vertices_mao > 100)
	verificar("origem no chão e porte ampliado de boss", absf(limites.position.y) < .001 and limites.end.y > 3.5 and limites.end.y < 3.7)
	# Os dois punhos ficam fixos no cabo em toda a janela de pegada dupla.
	var clips_validos := true
	var pegadas_validas := true
	var metadados: Dictionary = visual.DADOS_ATAQUES.data
	for nome: String in metadados:
		clips_validos = clips_validos and animador.has_animation(nome)
		if not animador.has_animation(nome): continue
		var info: Dictionary = metadados[nome]
		var clipe := animador.get_animation(nome)
		clips_validos = clips_validos and absf(clipe.length-float(info["duracao_s"])) < .02 and clipe.loop_mode == Animation.LOOP_NONE
		animador.play(nome)
		animador.pause()
		for lado in ["mao_D","mao_E"]:
			var max_pos := 0.0
			var max_rot := 0.0
			var id_mao := esqueleto.find_bone(lado)
			var referencia := Transform3D.IDENTITY
			for amostra in 25:
				var tempo := lerpf(float(info["pegada_dupla"][0]),float(info["pegada_dupla"][1]),amostra/24.0)
				animador.seek(tempo,true)
				esqueleto.force_update_all_bone_transforms()
				var relativa := esqueleto.get_bone_global_pose(id_mao).affine_inverse()*esqueleto.get_bone_global_pose(arma)
				if amostra == 0: referencia = relativa
				max_pos = maxf(max_pos,relativa.origin.distance_to(referencia.origin))
				max_rot = maxf(max_rot,relativa.basis.get_rotation_quaternion().angle_to(referencia.basis.get_rotation_quaternion()))
				pegadas_validas = pegadas_validas and relativa.origin.distance_to(referencia.origin) < .002
				pegadas_validas = pegadas_validas and relativa.basis.get_rotation_quaternion().angle_to(referencia.basis.get_rotation_quaternion()) < .005
			print("PEGADA ",nome," ",lado," ",max_pos," ",max_rot)
		# Sem salto ao sair do repouso ou regressar a ele.
		for tempo in [0.0,clipe.length]:
			animador.seek(tempo,true)
			esqueleto.force_update_all_bone_transforms()
			for osso in esqueleto.get_bone_count():
				var atual := esqueleto.get_bone_global_pose(osso)
				var repouso := esqueleto.get_bone_global_rest(osso)
				if atual.origin.distance_to(repouso.origin) >= .003: print("REPOUSO ",nome," ",tempo," ",esqueleto.get_bone_name(osso)," ",atual.origin.distance_to(repouso.origin))
				clips_validos = clips_validos and atual.is_finite() and atual.origin.distance_to(repouso.origin) < .003
	verificar("três ataques completos sem ciclo ou salto de repouso",clips_validos)
	verificar("duas mãos presas ao cabo durante os três ataques",pegadas_validas)
	animador.play("impacto_area")
	animador.pause()
	animador.seek(float(metadados["impacto_area"]["eventos"][1]["tempo_s"]),true)
	esqueleto.force_update_all_bone_transforms()
	var deformacao := esqueleto.get_bone_global_pose(arma)*esqueleto.get_bone_global_rest(arma).affine_inverse()
	var altura_min := INF
	for ponto in vertices_arma: altura_min = minf(altura_min,(deformacao*ponto).y)
	verificar("martelo toca o chão sem enterramento no impacto",altura_min >= -.003 and altura_min < .03)
	# Medir as três voltas da raiz, mesmo que as quaternions finais coincidam.
	animador.play("giro_area")
	animador.pause()
	var angulo_anterior := 0.0
	var giro_acumulado := 0.0
	for i in range(int(ceil(animador.get_animation("giro_area").length*60))+1):
		animador.seek(i/60.0,true)
		esqueleto.force_update_all_bone_transforms()
		var base := esqueleto.get_bone_global_pose(esqueleto.find_bone("raiz")).basis
		var angulo := atan2(base.x.z,base.x.x)
		if i>0: giro_acumulado += wrapf(angulo-angulo_anterior,-PI,PI)
		angulo_anterior = angulo
	verificar("giratório executa três voltas",absf(absf(giro_acumulado)-3*TAU)<.01)
	animador.play("giro_area")
	animador.pause()
	var janela_elevacao: Array = metadados["giro_area"]["pegada_dupla"]
	var alturas: Array[float] = []
	for frac in [0.0,.25,.5,.75,1.0]:
		animador.seek(lerpf(float(janela_elevacao[0]),float(janela_elevacao[1]),frac),true)
		esqueleto.force_update_all_bone_transforms()
		alturas.append(esqueleto.get_bone_global_pose(esqueleto.find_bone("raiz")).origin.y)
	print("ALTURAS_GIRO ",alturas)
	verificar("giro sobe meio metro e desce sem salto",absf(alturas[0])<.002 and absf(alturas[4])<.002 and absf(alturas[2]-.5)<.002 and alturas[1]>0 and alturas[1]<alturas[2] and absf(alturas[1]-alturas[3])<.002)
	# Passos grandes também precisam despachar todos os impactos uma vez.
	var recebidos: Array = []
	var avisos: Array = []
	var concluidas: Array = []
	visual.impacto.connect(func(acao,indice,centro,raio):recebidos.append([acao,indice,centro,raio]))
	visual.aviso_area.connect(func(acao,centro,raio):avisos.append([acao,centro,raio]))
	visual.acao_concluida.connect(func(acao):concluidas.append(acao))
	visual.cancelar_ataque()
	var eventos_validos: bool = not visual.tocar_ataque("inexistente")
	for nome: String in metadados:
		eventos_validos = eventos_validos and visual.tocar_ataque(nome) and not visual.tocar_ataque(nome)
		visual._process(5.0)
		visual._process(.2)
	eventos_validos = eventos_validos and recebidos.size()==9 and avisos.size()==1 and concluidas.size()==3 and animador.current_animation=="parado"
	visual.tocar_ataque("impacto_area")
	visual._process(float(metadados["impacto_area"]["eventos"][0]["tempo_s"])*.5)
	visual.cancelar_ataque()
	visual._process(4.0)
	eventos_validos = eventos_validos and recebidos.size()==9 and avisos.size()==1 and concluidas.size()==3
	verificar("eventos únicos, conclusão e cancelamento sem dano tardio",eventos_validos)
	var fontes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://arte/fontes/inimigos/lorde_goblin_3d/animacoes_kaykit.json"))
	var fontes_validas: bool = fontes.get("licenca","") == "CC0" and fontes["clipes"].size()==4
	for nome: String in fontes["clipes"]:
		var dados: Dictionary = fontes["clipes"][nome]
		var caminho: String = "res://"+dados["arquivo"]
		fontes_validas = fontes_validas and FileAccess.get_sha256(caminho)==dados["sha256"] and (String(dados["fonte"]).begins_with("Melee_2H_Attack_") or dados["fonte"]=="Walking_A")
	verificar("ataques transferidos de fontes gratuitas rastreáveis",fontes_validas)
	var tornado: MeshInstance3D = visual.get_node("TornadoDoMartelo")
	var janela_giro: Array = metadados["giro_area"]["pegada_dupla"]
	visual.amostrar_efeitos(&"giro_area",float(janela_giro[0])+.3)
	var tornado_valido := tornado.visible and tornado.mesh.get_faces().size()>100
	var primeira_rotacao := tornado.rotation.y
	visual.amostrar_efeitos(&"giro_area",float(janela_giro[0])+.4)
	tornado_valido = tornado_valido and absf(tornado.rotation.y-primeira_rotacao)>.5
	visual.amostrar_efeitos(&"giro_area",float(janela_giro[1])+.1)
	tornado_valido = tornado_valido and not tornado.visible
	visual.amostrar_efeitos(&"impacto_area",float(metadados["impacto_area"]["eventos"][1]["tempo_s"]))
	tornado_valido = tornado_valido and not tornado.visible
	visual.amostrar_efeitos(&"giro_area",float(janela_giro[0])+.3)
	visual.cancelar_ataque()
	tornado_valido = tornado_valido and not tornado.visible
	verificar("tornado gira somente na janela ativa e some ao cancelar",tornado_valido)
	visual.queue_free()
	await process_frame
	print("FALHAS: ",falhas)
	quit(1 if falhas else 0)
