extends SceneTree
## Verifica margem, pivô, encerramento e sinais de uma reprodução real do recurso.
var falhas := 0
var impactos: Array[int] = []
var terminou := false
var mortes := 0
var instantes_impacto: Array[int] = []

func verificar(nome: String, condicao: bool) -> void:
	print("OK " if condicao else "FALHA ",nome)
	if not condicao: falhas += 1

func _initialize() -> void:
	rodar.call_deferred()

func rodar() -> void:
	var visual = load("res://cenas/inimigos/goblin_adaga_visual.tscn").instantiate()
	root.add_child(visual)
	var registro: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/inimigos/goblin_adaga/registro_animacoes.json"))
	var preservados: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://arte/fontes/inimigos/goblin_adaga/preservacao_antes_corte.json"))
	var recursos_preservados := true
	for arquivo in preservados:
		recursos_preservados = recursos_preservados and FileAccess.get_sha256("res://assets/inimigos/goblin_adaga/"+arquivo)==preservados[arquivo]
	verificar("corridas dano e modelo preservados",recursos_preservados)
	verificar("cena carrega somente direcoes preparadas", Array(visual.sprite_frames.get_animation_names()).all(func(n): return registro.direcoes.any(func(d): return String(n).ends_with("_"+d))))
	verificar("pivo continua nos pes entre acoes", visual.offset == Vector2(0,-240) and visual.scale == Vector2.ONE * float(registro.escala))
	for nome in registro.animacoes:
		var ficha: Dictionary = registro.animacoes[nome]
		var tempos_corretos := true
		var margem := true
		for q in visual.sprite_frames.get_frame_count(nome):
			var textura: AtlasTexture = visual.sprite_frames.get_frame_texture(nome,q)
			var imagem := textura.atlas.get_image().get_region(Rect2i(textura.region))
			var area := imagem.get_used_rect()
			margem = margem and area.position.x >= 16 and area.position.y >= 16 and area.end.x <= 624 and area.end.y <= 624
			var segundos: float = visual.sprite_frames.get_frame_duration(nome,q) / visual.sprite_frames.get_animation_speed(nome)
			tempos_corretos = tempos_corretos and is_equal_approx(segundos,float(ficha.duracoes_ms[q])/1000.0)
		verificar("sem recorte ou invasao de celula: " + nome,margem)
		verificar("duracoes do motor seguem registro: " + nome,tempos_corretos)
	for acao in ["correr","combo","ferido","morte"]:
		var fiel := true
		for q in visual.sprite_frames.get_frame_count(acao+"_direita"):
			var direita: AtlasTexture = visual.sprite_frames.get_frame_texture(acao+"_direita",q)
			var esquerda: AtlasTexture = visual.sprite_frames.get_frame_texture(acao+"_esquerda",q)
			var pose := Image.load_from_file(direita.atlas.resource_path).get_region(Rect2i(direita.region))
			pose.flip_x()
			# Comparar o atlas exportado: fix_alpha_border do importador pode mudar
			# alguns RGB de bordas semitransparentes conforme a vizinhança.
			var pose_esquerda := Image.load_from_file(esquerda.atlas.resource_path).get_region(Rect2i(esquerda.region))
			pose.premultiply_alpha()
			pose_esquerda.premultiply_alpha()
			fiel = fiel and pose.get_data() == pose_esquerda.get_data()
		verificar("esquerda espelha direita sem inverter ordem: "+acao,fiel)
	visual.impacto_combo.connect(func(golpe: int):
		impactos.append(golpe)
		instantes_impacto.append(Time.get_ticks_msec()))
	visual.combo_encerrado.connect(func(): terminou = true)
	for direcao in registro.direcoes:
		var com_efeito := true
		for q in [1,5,9]:
			var textura: AtlasTexture = visual.sprite_frames.get_frame_texture("combo_"+direcao,q)
			var imagem := textura.atlas.get_image().get_region(Rect2i(textura.region))
			var pixels_claros := 0
			for y in imagem.get_height():
				for x in imagem.get_width():
					var cor := imagem.get_pixel(x,y)
					if cor.a>.8 and cor.r>.7 and cor.g>.75 and cor.b>.85: pixels_claros += 1
			com_efeito = com_efeito and pixels_claros>800
		verificar("tres cortes com rastro claro legivel: "+direcao,com_efeito)
		var nome_combo: String = "combo_"+direcao
		var nome_corrida: String = "correr_"+direcao
		var nome_guarda: String = "parado_"+direcao
		if direcao not in registro.direcoes_combo:
			verificar("direcao nova oferece corrida e guarda: "+direcao, not visual.sprite_frames.has_animation(nome_combo) and visual.sprite_frames.has_animation(nome_guarda) and visual.sprite_frames.get_frame_count(nome_corrida) == 8)
			var contato: AtlasTexture = visual.sprite_frames.get_frame_texture(nome_corrida,0)
			var area_contato := contato.atlas.get_image().get_region(Rect2i(contato.region)).get_used_rect()
			var altura_contato: float = area_contato.size.y * visual.scale.y
			verificar("altura da corrida igual ao player (31 px): "+direcao, altura_contato >= 30.0 and altura_contato <= 32.0)
			visual.tocar("correr",direcao)
			await create_timer(0.9).timeout
			verificar("corrida em ciclo apos duas passadas: "+direcao, visual.is_playing() and visual.animation == StringName(nome_corrida) and visual.sprite_frames.get_animation_loop(nome_corrida))
			continue
		var parado: AtlasTexture = visual.sprite_frames.get_frame_texture(nome_guarda,0)
		var area_parado := parado.atlas.get_image().get_region(Rect2i(parado.region)).get_used_rect()
		var altura: float = area_parado.size.y * visual.scale.y
		verificar("altura igual ao player (31 px): "+direcao,altura >= 30.0 and altura <= 32.0)
		var pausas_corretas := true
		for quadro in [3,7]:
			var segundos: float = visual.sprite_frames.get_frame_duration(nome_combo,quadro) / visual.sprite_frames.get_animation_speed(nome_combo)
			var recuperacao: float = registro.duracoes_golpes_ms[quadro] / 1000.0
			pausas_corretas = pausas_corretas and is_equal_approx(segundos-recuperacao,float(registro.intervalo_entre_golpes_ms)/1000.0)
		verificar("pausa preserva velocidade dos golpes: "+direcao,pausas_corretas and registro.intervalo_entre_golpes_ms >= 200)
		# A leitura dos atlas bloqueia o primeiro frame; estabiliza o relógio antes da reprodução.
		await process_frame
		await process_frame
		impactos.clear()
		instantes_impacto.clear()
		terminou = false
		visual.tocar("combo",direcao)
		await create_timer(0.4).timeout
		verificar("primeiro intervalo sem segundo impacto: "+direcao,impactos == [1])
		await create_timer(0.45).timeout
		verificar("segundo intervalo sem terceiro impacto: "+direcao,impactos == [1,2])
		await create_timer(0.65).timeout
		verificar("tres impactos unicos: "+direcao,impactos == [1,2,3])
		verificar("intervalos reais entre impactos: "+direcao,instantes_impacto.size() == 3 and instantes_impacto[1]-instantes_impacto[0] >= 400 and instantes_impacto[2]-instantes_impacto[1] >= 400)
		verificar("retorno a guarda da mesma direcao: "+direcao,terminou and visual.animation == StringName(nome_guarda))
		await create_timer(0.2).timeout
		verificar("combo nao repete sozinho: "+direcao,impactos == [1,2,3])
		visual.tocar("correr",direcao)
		await create_timer(0.9).timeout
		verificar("corrida em ciclo apos duas passadas: "+direcao,visual.is_playing() and visual.animation == StringName(nome_corrida) and visual.sprite_frames.get_animation_loop(nome_corrida))
	for direcao in registro.direcoes:
		var nome_ferido: String = "ferido_"+direcao
		verificar("reacao de dano em quatro poses sem ciclo: "+direcao,visual.sprite_frames.get_frame_count(nome_ferido)==4 and not visual.sprite_frames.get_animation_loop(nome_ferido))
		visual.tocar("ferido",direcao)
		await create_timer(.07).timeout
		verificar("dano avanca alem da primeira pose: "+direcao,visual.animation==StringName(nome_ferido) and visual.frame>=1)
		await create_timer(.35).timeout
		verificar("dano retorna a guarda da mesma direcao: "+direcao,visual.animation==StringName("parado_"+direcao))
	var preservacao_morte: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://arte/fontes/inimigos/goblin_adaga/preservacao_antes_morte.json"))
	var anteriores_preservados := true
	for arquivo in preservacao_morte:
		anteriores_preservados = anteriores_preservados and FileAccess.get_sha256("res://assets/inimigos/goblin_adaga/"+arquivo)==preservacao_morte[arquivo]
	verificar("todos recursos anteriores a morte preservados",anteriores_preservados)
	visual.morte_finalizada.connect(func(): mortes += 1)
	for d in registro.direcoes:
		visual.reiniciar(d)
		var antes := mortes
		var golpes_antes := impactos.size()
		visual.tocar("morte",d)
		await create_timer(.4).timeout
		verificar("morte avanca na queda sem repetir: "+d,visual.animation==StringName("morte_"+d) and visual.frame>=3 and mortes==antes and not visual.sprite_frames.get_animation_loop(visual.animation))
		visual.tocar("combo",d)
		visual.tocar("ferido",d)
		await create_timer(1.0).timeout
		verificar("morte permanece deitada e encerra uma vez: "+d,visual.animation==StringName("morte_"+d) and visual.frame==7 and not visual.is_playing() and mortes==antes+1 and impactos.size()==golpes_antes)
		var final: AtlasTexture = visual.sprite_frames.get_frame_texture("morte_"+d,7)
		verificar("corpo final tem silhueta baixa: "+d,final.atlas.get_image().get_region(Rect2i(final.region)).get_used_rect().size.y<340)
	visual.queue_free()
	await process_frame
	print("FALHAS: ",falhas)
	quit(falhas)
