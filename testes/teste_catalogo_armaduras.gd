extends SceneTree
## Progressão do catálogo e efeitos de conjuntos novos pelo caminho real de acerto.
const Conjuntos := preload("res://codigo/dados/conjuntos_armadura.gd")
const Receitas := preload("res://codigo/dados/forja_armas.gd")
const Aparencia := preload("res://codigo/dados/aparencia.gd")
var falhas := 0

class Alvo extends Node2D:
	var esta_morto := false
	var eh_chefe := false
	var dano_recebido := 0
	func receber_dano(dano: int, _empurrao := Vector2.ZERO): dano_recebido += dano

func _initialize(): rodar.call_deferred()
func conferir(condicao: bool, mensagem: String):
	print("OK " if condicao else "FALHA ", mensagem)
	if not condicao: falhas += 1

func preparar_sorteio(jogador, indice: int):
	var rng := RandomNumberGenerator.new()
	for semente in 1000:
		rng.seed = semente
		var valor := 1.0
		for i in indice: valor = rng.randf()
		if valor < 0.1:
			jogador._rng_carrasco.seed = semente
			jogador._recargas_conjuntos.clear()
			return

func rodar():
	assert(OS.get_user_data_dir().ends_with("AlgoLand testes Carrasco"))
	root.get_node("Ranking").conexao_habilitada = false
	var raridades := {}
	var tipos := {}
	for conjunto in Conjuntos.CONJUNTOS:
		raridades[conjunto.RARIDADE] = int(raridades.get(conjunto.RARIDADE, 0)) + 1
		for tipo in conjunto.TIPOS:
			conferir(not tipos.has(tipo), "id único: "+tipo)
			tipos[tipo] = true
			var item = Receitas.criar_item(tipo)
			conferir(item != null and item.raridade == conjunto.RARIDADE and Receitas.onda_receita(tipo) >= conjunto.ONDA_MINIMA, "receita com raridade e progressão: "+tipo)
	conferir(Conjuntos.CONJUNTOS.size() == 10 and tipos.size() == 40 and raridades == {"comum":3,"incomum":2,"raro":2,"epico":2,"lendario":1}, "dez conjuntos cobrem as cinco raridades")
	conferir(Aparencia.roupas()[43].id == "armadura_cavaleiro" and Aparencia.roupas()[44].id == "armadura_cavaleiro_rubro" and Aparencia.roupas()[45].id == "traje_cavalheiro", "índices antigos dos saves preservados")
	var rng := RandomNumberGenerator.new()
	rng.seed = 712
	for onda in [1,5,10,15,20,30,40,50,60]:
		var encontrados := {}
		var precoce := false
		for i in 5000:
			var tipo := Conjuntos.sortear(rng, onda, false, true)
			if tipo.is_empty(): continue
			var conjunto := Conjuntos.de_tipo(tipo)
			precoce = precoce or conjunto.ONDA_MINIMA > onda
			encontrados[conjunto.ID] = true
		var esperados := 0
		for conjunto in Conjuntos.CONJUNTOS:
			if conjunto.ONDA_MINIMA <= onda: esperados += 1
		conferir(not precoce and encontrados.size() == esperados, "drops respeitam a progressão no andar %d" % onda)
	var inv = root.get_node("InventarioJogador")
	inv.limpar(); inv.criar_itens_iniciais(); inv.definir_linhas_extras(99)
	root.get_node("Introducao").pular_prologo()
	change_scene_to_file("res://cenas/cidade.tscn")
	for i in 35: await process_frame
	current_scene.process_mode = Node.PROCESS_MODE_DISABLED
	var jogador = current_scene.get_node("Jogador")
	var painel = root.get_node("PainelDebug")
	var slime = load("res://cenas/inimigos/slime.tscn").instantiate()
	current_scene.add_child(slime)
	slime.set_physics_process(false); slime.vida = 10000; slime.vida_maxima = 10000
	var geada := Conjuntos.de_tipo("elmo_guardiao_geada")
	painel._equipar_conjunto(geada.ID)
	preparar_sorteio(jogador, 2)
	jogador.aplicar_golpe(slime, Vector2.ZERO)
	conferir(slime.esta_congelado() and is_equal_approx(slime._congelado_restante,1.5), "Geada: acerto real congela por 1,5 segundo")
	conferir(not jogador._tentar_bonus_conjunto(geada,slime,20,0.0), "Geada: recarga bloqueia renovação")
	inv.desequipar("botas")
	jogador._recargas_conjuntos.clear()
	conferir(not jogador._tentar_bonus_conjunto(geada,slime,20,0.075) and jogador._tentar_bonus_conjunto(geada,slime,20,0.0), "Geada: três peças dão metade da chance")
	var trovao := Conjuntos.de_tipo("elmo_arauto_trovao")
	painel._equipar_conjunto(trovao.ID)
	var alvo := Alvo.new()
	current_scene.add_child(alvo); alvo.add_to_group("enemy")
	alvo.global_position = jogador.global_position
	var hp: int = jogador.hp_atual
	preparar_sorteio(jogador, 3)
	jogador.aplicar_golpe(alvo, Vector2.ZERO)
	var raio = get_first_node_in_group("raios_carrasco")
	conferir(raio != null, "Trovão: acerto real invoca raio")
	if raio != null:
		var antes := alvo.dano_recebido
		raio.cair()
		conferir(alvo.dano_recebido > antes and jogador.hp_atual == hp and not raio.atingiu_jogador, "Trovão: dano aliado atinge inimigo e preserva jogador")
		conferir(get_nodes_in_group("raios_carrasco").size() == 1, "raio não encadeia novos raios")
	conferir(not jogador._tentar_bonus_conjunto(trovao,alvo,20,0.0), "Trovão: recarga bloqueia segundo raio")
	for slot in ["cabeca","corpo","luvas"]: inv.desequipar(slot)
	jogador._recargas_conjuntos.clear()
	conferir(not jogador._tentar_bonus_conjunto(trovao,alvo,20,0.0), "uma peça sozinha não ativa raio")
	current_scene.queue_free(); current_scene = null
	for i in 3: await process_frame
	print("CATALOGO ARMADURAS: ",falhas," falhas")
	quit(1 if falhas else 0)
