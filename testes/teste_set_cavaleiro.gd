extends SceneTree

const Aparencia := preload("res://codigo/dados/aparencia.gd")
const Gerador := preload("res://ferramentas/personagem/gerar_set_cavaleiro.gd")
var _falhas := 0

class JogadorTeste extends Node2D:
	var roupa_atual := 2
	var cabelo_atual := 1
	var cor_cabelo := Color.RED
	var _pecas_debug := 15
	var pecas_cavaleiro: int:
		get:
			return _pecas_debug if not Aparencia.raiz_armadura_visual(roupa_atual).is_empty() else 0
		set(valor):
			_pecas_debug = valor
	func definir_aparencia(cabelo: int, roupa: int) -> void:
		cabelo_atual = cabelo
		roupa_atual = roupa
	func definir_peca_cavaleiro(peca: String, ativa: bool) -> void:
		var bit: int = Aparencia.PECAS_CAVALEIRO[peca]
		pecas_cavaleiro = (pecas_cavaleiro | bit) if ativa else (pecas_cavaleiro & ~bit)

func _initialize() -> void:
	_rodar()

func _verificar(nome: String, condicao: bool) -> void:
	print("OK " if condicao else "FALHA ", nome)
	if not condicao:
		_falhas += 1

func _rodar() -> void:
	# Estes testes validam os moldes legados; a base nova tem teste de integração próprio.
	await process_frame
	var indice := -1
	for i in Aparencia.total_roupas():
		if Aparencia.roupas()[i]["id"] == "armadura_cavaleiro":
			indice = i
	_verificar("set acrescentado preservando os índices existentes", Aparencia.roupas()[indice]["id"] == "armadura_cavaleiro" and Aparencia.roupas()[2]["id"] == "pfpn_v05" and Aparencia.roupas()[indice - 1]["id"] == "armadura_teste")
	for pagina in Gerador.CORPOS:
		var corpo: Image = load("res://assets/personagens/" + Gerador.CORPOS[pagina]).get_image()
		var set: Image = Aparencia.roupa(indice, pagina).get_image()
		_verificar(pagina + ": grade de 64 quadros preservada", set.get_size() == corpo.get_size())
		var coberto := true
		var sem_meio_alfa := true
		for y in corpo.get_height():
			for x in corpo.get_width():
				if corpo.get_pixel(x, y).a > 0.5 and set.get_pixel(x, y).a < 0.5:
					coberto = false
				var alfa := set.get_pixel(x, y).a
				if alfa != 0.0 and alfa != 1.0:
					sem_meio_alfa = false
		_verificar(pagina + ": set cobre o corpo em todas as poses", coberto)
		_verificar(pagina + ": pixels opacos sem suavização", sem_meio_alfa)
		_verificar(pagina + ": elmo oculta cabelo", Aparencia.cabelo(1, pagina, indice).get_image().is_invisible())
		for base in [6, 29, 34]:
			var vestido: Image = Aparencia.roupa(base, pagina, 15).get_image()
			_verificar(pagina + ": set completo não vaza roupa de baixo " + str(base), vestido.get_data() == set.get_data())
		var juntas := Image.create(512, 512, false, Image.FORMAT_RGBA8)
		var camadas: Array[Image] = []
		for peca in ["peitoral", "botas", "luvas", "elmo"]:
			var camada: Image = load("res://assets/personagens/conjuntos/carrasco/%s/%s.png" % [peca, pagina]).get_image()
			_verificar(pagina + ": folha independente de " + peca, camada.get_size() == corpo.get_size() and not camada.is_invisible())
			juntas.blend_rect(camada, Rect2i(0, 0, 512, 512), Vector2i.ZERO)
			camadas.append(camada)
		var recomposicao := true
		var sem_sobreposicao := true
		for y in 512:
			for x in 512:
				var original := set.get_pixel(x, y)
				var combinado := juntas.get_pixel(x, y)
				if original.a != combinado.a or (original.a > 0.5 and original != combinado):
					recomposicao = false
				var opacos := 0
				for camada in camadas:
					if camada.get_pixel(x, y).a > 0.5:
						opacos += 1
				if opacos > 1:
					sem_sobreposicao = false
		_verificar(pagina + ": quatro peças recompõem o set completo", recomposicao)
		_verificar(pagina + ": peças não compartilham pixels", sem_sobreposicao)
		_verificar(pagina + ": sem elmo preserva cabelo", not Aparencia.cabelo(1, pagina, indice, 14).get_image().is_invisible())
	var capa: Image = Aparencia.roupa(34, "andar").get_image()
	var peito_sobre_capa: Image = Aparencia.roupa(34, "andar", 2).get_image()
	_verificar("peitoral sozinho elimina a borda da capa nos ombros", capa.get_pixel(25, 27).a > 0.5 and peito_sobre_capa.get_pixel(25, 27).a == 0.0 and peito_sobre_capa.get_pixel(38, 27).a == 0.0)
	var andar: Image = Aparencia.roupa(indice, "andar").get_image()
	_verificar("corrida tem quadros diferentes acompanhando a passada", andar.get_region(Rect2i(0, 256, 64, 64)).get_data() != andar.get_region(Rect2i(128, 256, 64, 64)).get_data())
	var cena := Node2D.new()
	root.add_child(cena)
	current_scene = cena
	var jogador := JogadorTeste.new()
	jogador.name = "Jogador"
	cena.add_child(jogador)
	var painel := root.get_node("PainelDebug")
	painel._ao_set_cavaleiro()
	_verificar("F3 equipa o set preservando a escolha de cabelo", jogador.roupa_atual == indice and jogador.cabelo_atual == 1)
	painel._ao_set_cavaleiro()
	_verificar("F3 restaura a aparência anterior", jogador.roupa_atual == 2 and jogador.cabelo_atual == 1)
	painel._ao_peca_cavaleiro("peitoral")
	_verificar("F3 veste apenas o peitoral", jogador.roupa_atual == indice and jogador.pecas_cavaleiro == 2)
	painel._ao_peca_cavaleiro("botas")
	_verificar("F3 acrescenta botas mantendo peitoral", jogador.pecas_cavaleiro == 10)
	painel._ao_peca_cavaleiro("peitoral")
	_verificar("F3 retira peitoral mantendo botas", jogador.pecas_cavaleiro == 8)
	painel._ao_set_cavaleiro()
	_verificar("F3 restaura roupa depois de testar peças", jogador.roupa_atual == 2)
	jogador.pecas_cavaleiro = 15
	# Instancia o jogador real sem entrar na árvore: valida as camadas sem carregar/gravar saves.
	var real = load("res://cenas/jogador.tscn").instantiate()
	var camadas := {
		"sprite_corpo": "BaseSprites/Corpo",
		"corpo_espada_escudo_ataque": "AttackSwordAnimation/CorpoEspadaEscudo",
		"corpo_lanca_escudo_ataque": "AttackSpearAnimation/Corpo",
		"sprite_corpo_forja": "Forja/Corpo",
		"sprite_cabelo": "BaseSprites/Cabelo", "sprite_roupa": "BaseSprites/Roupa",
		"cabelo_ataque": "AttackSwordAnimation/Cabelo", "roupa_ataque": "AttackSwordAnimation/Roupa",
		"cabelo_lanca_ataque": "AttackSpearAnimation/Cabelo", "roupa_lanca_ataque": "AttackSpearAnimation/Roupa",
		"sprite_cabelo_forja": "Forja/Cabelo", "sprite_roupa_forja": "Forja/Roupa",
	}
	for chave in camadas:
		real.set(chave, real.get_node("CompositeSprites/" + camadas[chave]))
	real.definir_aparencia(1, indice)
	for chave in ["sprite_cabelo", "cabelo_ataque", "cabelo_lanca_ataque", "sprite_cabelo_forja"]:
		_verificar("jogador real: elmo oculta " + chave, real.get(chave).texture.get_image().is_invisible())
	real._aplicar_roupa_sentado()
	_verificar("jogador real: sentado mantém o set", real.sprite_roupa_forja.texture == Aparencia.roupa(indice, "sentado"))
	real.definir_peca_cavaleiro("elmo", false)
	_verificar("jogador real: retirar só o elmo mantém outras peças", real.pecas_cavaleiro == 14 and not real.sprite_cabelo.texture.get_image().is_invisible())
	real.definir_aparencia(1, 2)
	_verificar("jogador real: roupa anterior restaura cabelo", not real.sprite_cabelo.texture.get_image().is_invisible())
	var rubro := -1
	for i in Aparencia.total_roupas():
		if Aparencia.roupas()[i]["id"] == "armadura_cavaleiro_rubro":
			rubro = i
	_verificar("Rubro acrescentado sem mudar índice do Carrasco", Aparencia.roupas()[rubro]["id"] == "armadura_cavaleiro_rubro" and rubro == indice + 1)
	real.pecas_cavaleiro = 15
	real.definir_aparencia(1, rubro)
	_verificar("Rubro real: máscara completa e cabelo oculto", real.pecas_cavaleiro == 15 and real.sprite_cabelo.texture.get_image().is_invisible())
	_verificar("Rubro real: corpo da caminhada preserva cabeça original", real.sprite_corpo.texture == Aparencia.corpo("andar", rubro, 15))
	_verificar("Rubro real: espada e lança preservam cabeça original", real.corpo_espada_escudo_ataque.texture == Aparencia.corpo("espada", rubro, 15) and real.corpo_lanca_escudo_ataque.texture == Aparencia.corpo("lanca", rubro, 15))
	for pagina in Gerador.CORPOS:
		var textura := Aparencia.roupa(rubro, pagina)
		_verificar("Rubro " + pagina + ": usa a própria folha", textura.resource_path == "res://assets/personagens/conjuntos/cavaleiro_rubro/" + pagina + ".png")
		_verificar("Rubro " + pagina + ": cabeça original preservada com elmo", Aparencia.corpo(pagina, rubro, 15).resource_path == "res://assets/personagens/" + Gerador.CORPOS[pagina])
		_verificar("Rubro " + pagina + ": retirar elmo restaura corpo original", Aparencia.corpo(pagina, rubro, 14).resource_path == "res://assets/personagens/" + Gerador.CORPOS[pagina])
	real.definir_peca_cavaleiro("elmo", false)
	_verificar("Rubro real: retirar elmo restaura cabelo", real.pecas_cavaleiro == 14 and not real.sprite_cabelo.texture.get_image().is_invisible())
	_verificar("Rubro real: retirar elmo restaura cabeça do corpo", real.sprite_corpo.texture == Aparencia.corpo("andar", rubro, 14))
	real.definir_peca_cavaleiro("elmo", true)
	real._aplicar_roupa_sentado()
	_verificar("Rubro real: sentado usa nova folha", real.sprite_roupa_forja.texture == Aparencia.roupa(rubro, "sentado"))
	painel._alternar_armadura("armadura_cavaleiro_rubro")
	_verificar("F3 Rubro veste conjunto visual", jogador.roupa_atual == rubro and jogador.pecas_cavaleiro == 15)
	painel._ao_peca_rubra("luvas")
	_verificar("F3 Rubro retira só as luvas", jogador.pecas_cavaleiro == 11)
	painel._alternar_armadura("armadura_cavaleiro_rubro")
	_verificar("F3 Rubro restaura roupa anterior", jogador.roupa_atual == 2)
	real.status_armas.free()
	real.free()
	for arquivo in ["fazenda_jogador", "arco_jogador", "reacao_jogador"]:
		var componente = load("res://codigo/jogador/" + arquivo + ".gd").new()
		componente.jogador = jogador
		cena.add_child(componente)
		componente.set_process(false)
		if arquivo == "reacao_jogador":
			componente._familia = "um_mao"
		componente._sincronizar_aparencia()
		_verificar(arquivo + ": cabelo visível sem elmo", not componente._cabelo.texture.get_image().is_invisible())
		jogador.roupa_atual = indice
		componente._sincronizar_aparencia()
		_verificar(arquivo + ": troca apenas da roupa oculta cabelo", componente._cabelo.texture.get_image().is_invisible())
		jogador.pecas_cavaleiro = 14
		componente._sincronizar_aparencia()
		_verificar(arquivo + ": retirar só o elmo atualiza cabelo", not componente._cabelo.texture.get_image().is_invisible())
		jogador.pecas_cavaleiro = 15
		jogador.roupa_atual = 2
		componente._sincronizar_aparencia()
		_verificar(arquivo + ": retirar o elmo restaura cabelo", not componente._cabelo.texture.get_image().is_invisible())
		jogador.roupa_atual = rubro
		componente._sincronizar_aparencia()
		var pagina_rubra := "fazenda" if arquivo == "fazenda_jogador" else ("arco_p2" if arquivo == "arco_jogador" else "reacao_um_mao")
		_verificar(arquivo + ": nova identidade com mesma máscara atualiza roupa", componente._roupa.texture == Aparencia.roupa(rubro, pagina_rubra, 15) and componente._cabelo.texture.get_image().is_invisible())
		_verificar(arquivo + ": corpo preserva a cabeça original", componente._corpo.texture == Aparencia.corpo(pagina_rubra, rubro, 15))
		jogador.roupa_atual = 2
		componente.queue_free()
	print("Falhas: ", _falhas)
	call_deferred("_encerrar")

func _encerrar() -> void:
	quit(_falhas)
