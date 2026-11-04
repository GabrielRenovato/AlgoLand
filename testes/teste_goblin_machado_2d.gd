extends SceneTree
var falhas := 0
var impactos := 0
var mortes := 0
func _initialize() -> void: rodar.call_deferred()
func verificar(nome: String, condicao: bool) -> void:
	print("OK " if condicao else "FALHA ",nome)
	if not condicao: falhas += 1
func rodar() -> void:
	var visual = load("res://cenas/inimigos/goblin_machado_2d_visual.tscn").instantiate()
	root.add_child(visual)
	visual.impacto_ataque.connect(func(): impactos += 1)
	visual.morte_finalizada.connect(func(): mortes += 1)
	var registro: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/inimigos/goblin_machado_2d/registro_animacoes.json"))
	verificar("corrida aprovada permanece identica",FileAccess.get_sha256("res://assets/inimigos/goblin_machado_2d/correr_direita.png")=="316b5015323689627e2d1ffc21bff297fe3051abba3ec872961a6daf3d14799a")
	verificar("ataque segue poses novas em ordem sem retorno intermediario",registro.animacoes.ataque_direita.ordem_fontes.map(func(q): return int(q))==range(8))
	verificar("rastro presente apenas na passagem impacto e continuacao",registro.animacoes.ataque_direita.efeito_corte.quadros.map(func(q): return int(q))==[3,4,5])
	var corte: AtlasTexture = visual.sprite_frames.get_frame_texture("ataque_direita",4)
	var imagem_corte := corte.atlas.get_image().get_region(Rect2i(corte.region))
	var pixels_claros := 0
	for y in range(300,520):
		for x in range(40,624):
			var cor := imagem_corte.get_pixel(x,y)
			if cor.a>.8 and cor.r>.7 and cor.g>.75 and cor.b>.85: pixels_claros += 1
	verificar("arco claro largo visivel no impacto",pixels_claros>10000)
	verificar("direcoes preparadas e reacoes nas quatro direcoes",Array(visual.sprite_frames.get_animation_names()).all(func(n): return String(n).get_slice("_",1) in ["direita","cima","baixo","esquerda"]) and visual.sprite_frames.has_animation("ataque_cima") and visual.sprite_frames.has_animation("ataque_baixo"))
	verificar("raiz e escala comuns ao player",visual.offset==Vector2(0,-240) and visual.scale.is_equal_approx(Vector2.ONE*.071))
	for nome in registro.animacoes:
		var ficha: Dictionary = registro.animacoes[nome]
		var tempos := true
		var margem := true
		for q in visual.sprite_frames.get_frame_count(nome):
			var textura: AtlasTexture = visual.sprite_frames.get_frame_texture(nome,q)
			var area := textura.atlas.get_image().get_region(Rect2i(textura.region)).get_used_rect()
			margem = margem and area.position.x>=16 and area.position.y>=16 and area.end.x<=624 and area.end.y<=624
			var duracao: float = visual.sprite_frames.get_frame_duration(nome,q)/visual.sprite_frames.get_animation_speed(nome)
			tempos = tempos and is_equal_approx(duracao,float(ficha.duracoes_ms[q])/1000.0)
		verificar("quadros registrados e nenhuma celula cortada: "+nome,margem and visual.sprite_frames.get_frame_count(nome)==ficha.duracoes_ms.size())
		verificar("tempos iguais no atlas e no motor: "+nome,tempos)
	var guarda: AtlasTexture = visual.sprite_frames.get_frame_texture("parado_direita",0)
	var area := guarda.atlas.get_image().get_region(Rect2i(guarda.region)).get_used_rect()
	var altura := area.size.y*.071
	verificar("guarda com altura do player (31px)",altura>=30.0 and altura<=32.0)
	await process_frame
	await process_frame
	visual.tocar("ataque")
	await create_timer(.35).timeout
	verificar("preparacao sem dano antecipado",impactos==0)
	await create_timer(.2).timeout
	verificar("impacto unico no corte",impactos==1)
	await create_timer(.45).timeout
	verificar("recuperacao retorna a guarda",visual.animation==&"parado_direita" and impactos==1)
	visual.tocar("ataque")
	await create_timer(.95).timeout
	verificar("novo ataque reinicia sinal uma unica vez",impactos==2 and visual.animation==&"parado_direita")
	visual.tocar("correr")
	await create_timer(1.05).timeout
	verificar("corrida fecha mais de dois ciclos",visual.is_playing() and visual.animation==&"correr_direita" and visual.sprite_frames.get_animation_loop("correr_direita"))
	visual.tocar("ataque","cima")
	await create_timer(.35).timeout
	verificar("ataque cima prepara sem impacto antecipado",impactos==2 and visual.animation==&"ataque_cima")
	await create_timer(.2).timeout
	verificar("ataque cima emite impacto unico",impactos==3)
	await create_timer(.45).timeout
	verificar("ataque cima recupera para propria guarda",impactos==3 and visual.animation==&"parado_cima")
	var guarda_cima: AtlasTexture = visual.sprite_frames.get_frame_texture("parado_cima",0)
	var altura_cima := guarda_cima.atlas.get_image().get_region(Rect2i(guarda_cima.region)).get_used_rect().size.y*.071
	verificar("guarda cima com altura do player",altura_cima>=30.0 and altura_cima<=32.0)
	visual.tocar("ataque","baixo")
	await create_timer(.35).timeout
	verificar("ataque baixo prepara sem impacto antecipado",impactos==3 and visual.animation==&"ataque_baixo")
	await create_timer(.2).timeout
	verificar("ataque baixo emite impacto unico",impactos==4)
	await create_timer(.45).timeout
	verificar("ataque baixo recupera para propria guarda",impactos==4 and visual.animation==&"parado_baixo")
	var guarda_baixo: AtlasTexture = visual.sprite_frames.get_frame_texture("parado_baixo",0)
	var altura_baixo := guarda_baixo.atlas.get_image().get_region(Rect2i(guarda_baixo.region)).get_used_rect().size.y*.071
	verificar("guarda baixo com altura do player",altura_baixo>=30.0 and altura_baixo<=32.0)
	var preservados: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://arte/fontes/inimigos/goblin_machado_2d/preservacao_antes_dano_morte.json"))
	var preservado := true
	for arquivo in preservados:
		preservado = preservado and FileAccess.get_sha256("res://assets/inimigos/goblin_machado_2d/"+arquivo)==preservados[arquivo]
	verificar("modelo corrida e ataques preservados",preservado)
	for acao in ["ferido","morte"]:
		var fiel := true
		for q in visual.sprite_frames.get_frame_count(acao+"_direita"):
			var direita: AtlasTexture = visual.sprite_frames.get_frame_texture(acao+"_direita",q)
			var esquerda: AtlasTexture = visual.sprite_frames.get_frame_texture(acao+"_esquerda",q)
			var pose := Image.load_from_file(direita.atlas.resource_path).get_region(Rect2i(direita.region))
			var espelho := Image.load_from_file(esquerda.atlas.resource_path).get_region(Rect2i(esquerda.region))
			pose.flip_x()
			pose.premultiply_alpha()
			espelho.premultiply_alpha()
			fiel = fiel and pose.get_data()==espelho.get_data()
		verificar("esquerda espelha direita: "+acao,fiel)
	for direcao in ["direita","baixo","cima","esquerda"]:
		visual.reiniciar(direcao)
		visual.tocar("ferido",direcao)
		await create_timer(.08).timeout
		verificar("dano avanca e nao repete: "+direcao,visual.animation==StringName("ferido_"+direcao) and visual.frame>=1 and not visual.sprite_frames.get_animation_loop(visual.animation))
		await create_timer(.3).timeout
		verificar("dano retorna a guarda: "+direcao,visual.animation==StringName("parado_"+direcao))
		var mortes_antes := mortes
		visual.tocar("morte",direcao)
		await create_timer(.4).timeout
		verificar("morte tem queda progressiva: "+direcao,visual.animation==StringName("morte_"+direcao) and visual.frame>=3 and mortes==mortes_antes)
		visual.tocar("ferido",direcao)
		visual.tocar("ataque","direita")
		await create_timer(1.0).timeout
		verificar("morte termina uma vez e permanece no chao: "+direcao,visual.animation==StringName("morte_"+direcao) and visual.frame==7 and not visual.is_playing() and mortes==mortes_antes+1)
		var corpo: AtlasTexture = visual.sprite_frames.get_frame_texture("morte_"+direcao,7)
		verificar("corpo deitado tem silhueta baixa: "+direcao,corpo.atlas.get_image().get_region(Rect2i(corpo.region)).get_used_rect().size.y<340)
	verificar("dano e morte nao emitem golpe",impactos==4)
	visual.queue_free()
	print("FALHAS: ",falhas)
	quit(1 if falhas else 0)
