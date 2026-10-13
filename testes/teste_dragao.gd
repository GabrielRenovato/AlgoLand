extends SceneTree

const AreaGolpe := preload("res://Codigos/Efeitos/area_ataque_dragao.gd")
const Profundidade := preload("res://Codigos/Globais/profundidade.gd")
var falhas := 0

class JogadorTeste extends Node2D:
	var estaMorto := false
	var invulneravel := false
	var golpes := 0
	var ultimo_dano := 0
	var ultima_forca := Vector2.ZERO
	func receber_dano(valor: int, forca: Vector2) -> void:
		golpes += 1
		ultimo_dano = valor
		ultima_forca = forca

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
	cena.add_child(jogador)
	var chefe = load("res://cenas/inimigos/dragao_vermelho.tscn").instantiate()
	cena.add_child(chefe)
	chefe.set_physics_process(false)
	verificar("dragão nativo reconhecido como chefe", chefe.eh_chefe and chefe.is_in_group("boss_dragao"))
	var hurtbox := Area2D.new()
	hurtbox.name = "AreaDano"
	hurtbox.collision_layer = 2
	hurtbox.collision_mask = 0
	var colisor := CollisionShape2D.new()
	colisor.shape = CapsuleShape2D.new()
	colisor.shape.radius = 7
	colisor.shape.height = 24
	hurtbox.add_child(colisor)
	jogador.add_child(hurtbox)
	verificar("área de contato desligada no dragão", not chefe.get_node("ataque").monitoring)
	# Mesmo um chamado herdado com contato confirmado não deve causar dano.
	chefe.get_node("ataque").monitoring = true
	await physics_frame
	await physics_frame
	verificar("jogador realmente sobreposto ao contato no teste", chefe.get_node("ataque").get_overlapping_areas().has(hurtbox))
	chefe.aplicar_dano_contato()
	chefe._physics_process(0.01)
	verificar("encostar e perseguir não causam dano", jogador.golpes == 0)
	chefe._cancelar_area()
	chefe.estado = chefe.Estado.LIVRE
	chefe._combo_sopro = false
	chefe._recarga_patada = 10
	chefe.get_node("ataque").monitoring = false
	chefe._linha = 2
	for caso in [[7.0, 0.0, true], [11.0, 0.0, false], [1000.0, 1000.0, true], [1030.0, 1010.0, false]]:
		chefe.position.y = caso[0]
		jogador.position.y = caso[1]
		jogador.z_index = Profundidade.z_de(jogador.position.y + Profundidade.PES_JOGADOR)
		chefe._atualizar_ordem_desenho()
		verificar("patas respeitam os pés na posição %s" % str(caso), chefe.z_index < jogador.z_index if caso[2] else chefe.z_index > jogador.z_index + 6)
	chefe.position.y = 14
	jogador.position.y = 0
	chefe._linha = 3
	chefe._atualizar_ordem_desenho()
	verificar("pose esquerda usa as patas, sem ordenar pela cauda", chefe.altura_pes == -4 and chefe.z_index < jogador.z_index)
	chefe._linha = 0
	chefe.position = Vector2.ZERO
	jogador.position = Vector2.ZERO
	jogador.z_index = Profundidade.z_de(Profundidade.PES_JOGADOR)
	verificar("cone alcança somente a frente", AreaGolpe.contem_ponto("sopro", Vector2(80, 0), Vector2.RIGHT, 150) and not AreaGolpe.contem_ponto("sopro", Vector2(-80, 0), Vector2.RIGHT, 150) and not AreaGolpe.contem_ponto("sopro", Vector2(80, 100), Vector2.RIGHT, 150))
	verificar("asas têm área maior que cauda", not AreaGolpe.contem_ponto("cauda", Vector2(100, 0), Vector2.RIGHT, 82) and AreaGolpe.contem_ponto("asas", Vector2(100, 0), Vector2.RIGHT, 112))
	for tipo in chefe.ATAQUES:
		jogador.position = Vector2(60, 0)
		var antes: int = jogador.golpes
		verificar(tipo + " inicia preparação", chefe.iniciar_ataque(tipo, jogador.position))
		chefe._physics_process(0.2)
		verificar(tipo + " avisa sem dano", jogador.golpes == antes and chefe._area_golpe != null)
		verificar(tipo + " não mostra sprite de impacto antes do golpe", not chefe._area_golpe._efeito.visible)
		var direcao: Vector2 = chefe._direcao_golpe
		jogador.position = Vector2(70, 1)
		chefe._physics_process(1.0)
		chefe._physics_process(0.01)
		verificar(tipo + " não dá dano antes da expansão do efeito", jogador.golpes == antes)
		chefe._physics_process(float(chefe.DURACOES[tipo]) * 0.35)
		verificar(tipo + " causa um impacto com direção fixada", jogador.golpes == antes + 1 and chefe._direcao_golpe == direcao)
		var efeito = chefe._area_golpe._efeito
		verificar(tipo + " mostra sprite animado no impacto", efeito.visible and efeito.texture != null and efeito.hframes == 6)
		chefe._area_golpe.atualizar(1, true, float(chefe.DURACOES[tipo]) * 0.5)
		verificar(tipo + " anima no relógio do golpe", efeito.frame == 3)
		chefe._area_golpe.atualizar(1, true, float(chefe.DURACOES[tipo]) * 0.99)
		verificar(tipo + " termina com dissipação", efeito.frame == 5)
		chefe._physics_process(0.1)
		verificar(tipo + " não multiplica dano por frame", jogador.golpes == antes + 1)
		chefe._physics_process(1.0)
		chefe._physics_process(0.7)
		verificar(tipo + " termina e remove área", chefe.estado == chefe.Estado.LIVRE and chefe._area_golpe == null)
	var golpes_antes_salto: int = jogador.golpes
	chefe.iniciar_ataque("cauda", jogador.position)
	chefe._physics_process(1.0)
	chefe._physics_process(0.2)
	verificar("impacto da cauda não se perde ao saltar o quadro de dano", jogador.golpes == golpes_antes_salto + 1)
	chefe._physics_process(1.0)
	chefe._physics_process(0.7)
	chefe.iniciar_ataque("sopro", jogador.position)
	chefe._physics_process(1.0)
	chefe._physics_process(0.01)
	var quadro_efeito: int = chefe._area_golpe._efeito.frame
	chefe.aplicar_congelamento(2.0)
	var tempo: float = chefe._tempo_estado
	var frame: int = chefe.sprite.frame
	var antes: int = jogador.golpes
	chefe._physics_process(0.5)
	verificar("gelo pausa animação, ataque e dano", chefe._tempo_estado == tempo and chefe.sprite.frame == frame and jogador.golpes == antes)
	verificar("gelo pausa o efeito do fogo junto com o dragão", chefe._area_golpe._efeito.frame == quadro_efeito)
	verificar("casca gigante cobre o dragão", chefe._efeito_gelo._sprite.texture.get_height() == 128)
	chefe._physics_process(2.0)
	verificar("gelo expira sem antecipar o golpe", not chefe.esta_congelado() and chefe._tempo_estado == tempo)
	chefe.aplicar_congelamento(2.0)
	var ouro_antes: int = root.get_node("DadosJogo").moedas
	chefe.morrer()
	chefe.morrer()
	verificar("morte cancela golpe e gelo", chefe.esta_morto and chefe._area_golpe == null and not chefe.esta_congelado())
	verificar("morte repetida concede recompensa somente uma vez", root.get_node("DadosJogo").moedas == ouro_antes + 250)
	await create_timer(1.0).timeout
	verificar("morte remove chefe após animação", not is_instance_valid(chefe))
	await process_frame
	var gerenciador = load("res://Codigos/Logicas/Gerenciador-de-ondas.gd").new()
	verificar("dragão entra na onda 50 e minotauro na onda 10", gerenciador.chefe_da_onda(50).id == "dragao_vermelho" and gerenciador.chefe_da_onda(10).id == "minotauro")
	verificar("rodízio repete dragão na onda 100", gerenciador.chefe_da_onda(100).id == "dragao_vermelho")
	gerenciador.free()
	for pagina in ["movimento", "sopro", "cauda", "asas", "voo", "patada"]:
		var imagem := Image.load_from_file("res://inimigos/dragao_vermelho/" + pagina + ".png")
		verificar(pagina + " tem 24 células nativas", imagem.get_size() == Vector2i(768, 512))
		if pagina == "movimento":
			# Regressão do fragmento de asa que aparecia abaixo das patas na caminhada.
			var sob_patas := imagem.get_region(Rect2i(2 * 128, 2 * 128 + 119, 128, 9))
			verificar("caminhada lateral sem pedaço da próxima linha", not sob_patas.get_used_rect().has_area())
		var binaria := true
		for y in imagem.get_height():
			for x in imagem.get_width():
				var alpha := imagem.get_pixel(x, y).a
				if alpha != 0 and alpha != 1:
					binaria = false
		verificar(pagina + " mantém pixels opacos ou transparentes", binaria)
		for linha in 4:
			for coluna in 6:
				verificar(pagina + " quadro %d,%d válido" % [linha, coluna], imagem.get_region(Rect2i(coluna * 128, linha * 128, 128, 128)).get_used_rect().has_area())
	var painel := root.get_node("PainelDebug")
	verificar("F3 oferece chefe, ataques, combo e especial em dropdown", painel._opcoes.has("DRAGAO") and painel._opcoes["DRAGAO"].size() == 6)
	print("Falhas: ", falhas)
	cena.queue_free()
	await process_frame
	quit(falhas)
