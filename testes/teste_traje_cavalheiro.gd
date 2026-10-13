extends SceneTree

## Validação visual e do F3 sem carregar a arena ou gravar inventário.
const Aparencia := preload("res://Codigos/DadosLocais/aparencia.gd")
const Padrao := preload("res://Codigos/DadosLocais/padrao_armadura.gd")
const Conjuntos := preload("res://Codigos/DadosLocais/conjuntos_armadura.gd")
var _falhas := 0

class JogadorTeste extends Node2D:
	var roupa_atual := 2
	var cabelo_atual := 1
	var cor_cabelo := Color.GREEN
	var pecas_cavaleiro := 15
	func definir_aparencia(cabelo: int, roupa: int) -> void:
		cabelo_atual = cabelo
		roupa_atual = roupa

func _initialize() -> void:
	_rodar()

func _verificar(nome: String, condicao: bool) -> void:
	print("OK " if condicao else "FALHA ", nome)
	if not condicao:
		_falhas += 1

func _rodar() -> void:
	await process_frame
	var indice := -1
	for i in Aparencia.total_roupas():
		if Aparencia.roupas()[i]["id"] == "traje_cavalheiro":
			indice = i
	_verificar("novo traje registrado depois dos índices anteriores", indice > 0 and Aparencia.roupas()[indice - 1]["id"] == "armadura_cavaleiro_rubro")
	var raiz := "res://CharacterSprites/Conjuntos/cavalheiro/"
	var config := Padrao.carregar("res://ferramentas/armaduras/em_preparacao/cavalheiro/manifesto.json")
	_verificar("Mordomo lendário com congelamento, sem drop natural", config["modo_visual"] == "tecido" and config["raridade"] == "lendario" and config["bonus"]["tipo"] == "congelamento" and config["chances_drop"] == {"normal": 0.0, "mutante": 0.0, "chefe": 0.0})
	_verificar("peças reais do Cavalheiro disponíveis para equipar pelo F3", Conjuntos.de_tipo("elmo_cavalheiro") != null)
	for pagina in Padrao.CORPOS:
		var corpo: Texture2D = load("res://CharacterSprites/" + Padrao.CORPOS[pagina])
		_verificar(pagina + ": cabeça original preservada", Aparencia.corpo(pagina, indice, 15) == corpo)
		var traje := Aparencia.roupa(indice, pagina)
		_verificar(pagina + ": própria folha nas poses do jogador", traje.resource_path == raiz + pagina + ".png")
		var cartola: Image = load(raiz + "elmo/" + pagina + ".png").get_image()
		var limites := {}
		for linha in 8:
			for coluna in 8:
				var origem := Vector2i(coluna * 64, linha * 64)
				limites[origem] = Aparencia.limites_cabelo_cartola(cartola.get_region(Rect2i(origem, Vector2i(64, 64))))
		for cabelo in [0, 1, 4, 6]:
			var original := Aparencia.cabelo(cabelo, pagina, -1, 0).get_image()
			var sob_aba := Aparencia.cabelo(cabelo, pagina, indice, 15).get_image()
			var correto := true
			for y in 512:
				for x in 512:
					var esperado := original.get_pixel(x, y)
					var origem := Vector2i((x / 64) * 64, (y / 64) * 64)
					if y - origem.y < int(limites[origem][x - origem.x]) or cartola.get_pixel(x, y).a > 0.5:
						esperado = Color.TRANSPARENT
					var atual := sob_aba.get_pixel(x, y)
					if esperado.a != atual.a or (esperado.a > 0.5 and esperado != atual):
						correto = false
			_verificar(pagina + ": cabelo %d preservado somente fora da cartola" % cabelo, correto)
		_verificar(pagina + ": retirar cartola restaura todo o cabelo", Aparencia.cabelo(1, pagina, indice, 14) == Aparencia.cabelo(1, pagina, -1, 0))
		var base := corpo.get_image()
		var vestimenta := traje.get_image()
		var cabelo_base := Aparencia.cabelo(0, pagina, -1, 0).get_image()
		var roupa_base := Aparencia.roupa(2, pagina).get_image()
		if pagina == "andar":
			for direcao in 4:
				var regiao := Rect2i(0, direcao * 64, 64, 64)
				var cabeca := cabelo_base.get_region(regiao).get_used_rect()
				var cranio := base.get_region(regiao).get_region(Rect2i(cabeca.position, Vector2i(cabeca.size.x, 7))).get_used_rect()
				var quadro := cartola.get_region(regiao)
				var area := quadro.get_used_rect()
				var copa := quadro.get_region(Rect2i(area.position, Vector2i(area.size.x, roundi(area.size.y * 0.6)))).get_used_rect()
				_verificar("direção %d: copa centrada no crânio, sem deslocamento pelo nariz" % direcao, area.position.x + copa.get_center().x == cabeca.position.x + cranio.get_center().x)
		var rosto_preservado := true
		for linha in 8:
			for coluna in 8:
				var origem := Vector2i(coluna * 64, linha * 64)
				var cabeca := cabelo_base.get_region(Rect2i(origem, Vector2i(64, 64))).get_used_rect()
				if cabeca.size == Vector2i.ZERO:
					continue
				for y in range(cabeca.position.y + 8, cabeca.position.y + 13):
					for x in range(cabeca.position.x, cabeca.end.x):
						var ponto := origem + Vector2i(x, y)
						if base.get_pixelv(ponto).a > 0.5 and roupa_base.get_pixelv(ponto).a < 0.5 and vestimenta.get_pixelv(ponto).a > 0.5:
							rosto_preservado = false
		_verificar(pagina + ": vestimenta não pinta o rosto", rosto_preservado)
	var cena := Node2D.new()
	root.add_child(cena)
	current_scene = cena
	var jogador := JogadorTeste.new()
	jogador.name = "Jogador"
	cena.add_child(jogador)
	var painel := root.get_node("PainelDebug")
	painel._alternar_armadura("traje_cavalheiro")
	_verificar("F3 veste as quatro peças sem mudar cabelo ou cor", jogador.roupa_atual == indice and jogador.pecas_cavaleiro == 15 and jogador.cabelo_atual == 1 and jogador.cor_cabelo == Color.GREEN)
	painel._alternar_armadura("armadura_cavaleiro_rubro")
	painel._alternar_armadura("traje_cavalheiro")
	painel._alternar_armadura("traje_cavalheiro")
	_verificar("F3 restaura roupa original após alternar conjuntos", jogador.roupa_atual == 2)
	# Jogador real fora da árvore: não executa _ready nem lê/grava a partida.
	var real = load("res://cenas/Jogador.tscn").instantiate()
	var camadas := {
		"sprite_corpo": "BaseSprites/Corpo", "sprite_cabelo": "BaseSprites/Cabelo", "sprite_roupa": "BaseSprites/Roupa",
		"corpo_espada_escudo_ataque": "AttackSwordAnimation/CorpoEspadaEscudo", "cabelo_ataque": "AttackSwordAnimation/Cabelo", "roupa_ataque": "AttackSwordAnimation/Roupa",
		"corpo_lanca_escudo_ataque": "AttackSpearAnimation/Corpo", "cabelo_lanca_ataque": "AttackSpearAnimation/Cabelo", "roupa_lanca_ataque": "AttackSpearAnimation/Roupa",
		"sprite_corpo_forja": "Forja/Corpo", "sprite_cabelo_forja": "Forja/Cabelo", "sprite_roupa_forja": "Forja/Roupa",
	}
	for chave in camadas:
		real.set(chave, real.get_node("CompositeSprites/" + camadas[chave]))
	real.cor_cabelo = Color.GREEN
	real.definir_aparencia(1, indice)
	_verificar("jogador real veste traje completo", real.pecas_cavaleiro == 15 and real.sprite_roupa.texture == Aparencia.roupa(indice, "andar"))
	_verificar("jogador real mantém cabelo colorido separado da cartola", real.sprite_cabelo.modulate == Color.GREEN and not real.sprite_cabelo.texture.get_image().is_invisible() and real.sprite_roupa.modulate == Color.WHITE)
	_verificar("jogador real usa traje nos ataques", real.roupa_ataque.texture == Aparencia.roupa(indice, "espada") and real.roupa_lanca_ataque.texture == Aparencia.roupa(indice, "lanca"))
	for par in [[real.sprite_cabelo, real.sprite_roupa], [real.cabelo_ataque, real.roupa_ataque], [real.cabelo_lanca_ataque, real.roupa_lanca_ataque]]:
		var cartola = par[1].get_parent().get_node("CartolaSobreCabelo")
		for ordem in [[5, 2], [1, 4], [4, 4]]:
			par[0].z_index = ordem[0]
			par[1].z_index = ordem[1]
			par[0].flip_h = false
			par[1].flip_h = true
			par[1].frame = 37
			par[0].visible = true
			par[1].visible = true
			cartola.sincronizar()
			_verificar("cartola acima do cabelo e da roupa após mudança da animação", cartola.z_index > par[0].z_index and cartola.z_index > par[1].z_index)
			_verificar("cartola acompanha quadro e espelhamento da roupa sem tintura do cabelo", cartola.frame == 37 and cartola.flip_h and cartola.modulate == Color.WHITE)
			_verificar("cabelo original não desenha uma cópia sobre a cabeça composta", par[0].self_modulate.a == 0)
		par[1].visible = false
		cartola.sincronizar()
		_verificar("camada inativa não deixa cartola flutuando", not cartola.visible)
	real._aplicar_roupa_sentado()
	_verificar("jogador real usa traje sentado", real.sprite_roupa_forja.texture == Aparencia.roupa(indice, "sentado"))
	real.definir_aparencia(1, 2)
	_verificar("jogador real restaura roupa e cabelo", real.sprite_roupa.texture == Aparencia.roupa(2, "andar") and real.sprite_cabelo.texture == Aparencia.cabelo(1, "andar"))
	_verificar("retirar traje oculta a camada extra da cartola", not real.sprite_roupa.get_parent().get_node("CartolaSobreCabelo").visible)
	_verificar("retirar traje restaura o desenho do cabelo original", real.sprite_cabelo.self_modulate == Color.WHITE)
	real.status_armas.free()
	real.free()
	jogador.roupa_atual = indice
	for arquivo in ["fazenda_jogador", "arco_jogador", "reacao_jogador"]:
		var componente = load("res://Codigos/Jogador/" + arquivo + ".gd").new()
		componente.jogador = jogador
		cena.add_child(componente)
		componente.set_process(false)
		if arquivo == "reacao_jogador":
			componente._familia = "um_mao"
		componente._sincronizar_aparencia()
		var pagina := "fazenda" if arquivo == "fazenda_jogador" else ("arco_p2" if arquivo == "arco_jogador" else "reacao_um_mao")
		_verificar(arquivo + ": traje e cabelo sob cartola nas ações reais", componente._roupa.texture == Aparencia.roupa(indice, pagina) and componente._cabelo.texture == Aparencia.cabelo(1, pagina, indice, 15))
		var cartola = componente.get_node("CartolaSobreCabelo")
		componente._cabelo.z_index = 5
		componente._roupa.z_index = 4
		cartola.sincronizar()
		_verificar(arquivo + ": cabeça composta acima do cabelo original oculto", cartola.z_index > componente._cabelo.z_index and componente._cabelo.self_modulate.a == 0)
		var imagem_cartola: Image = load(raiz + "elmo/" + pagina + ".png").get_image()
		var imagem_composta: Image = cartola.texture.get_image()
		var sem_tintura := true
		for y in 512:
			for x in 512:
				var pixel := imagem_cartola.get_pixel(x, y)
				if pixel.a > 0.5 and pixel != imagem_composta.get_pixel(x, y):
					sem_tintura = false
		_verificar(arquivo + ": cabelo colorido não altera nenhum pixel da cartola", sem_tintura)
		componente.queue_free()
	print("Falhas: ", _falhas)
	call_deferred("quit", _falhas)
