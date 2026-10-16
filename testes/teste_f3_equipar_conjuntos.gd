extends SceneTree

## Arena e inventário somente na cópia isolada do projeto.
const Conjuntos := preload("res://codigo/dados/conjuntos_armadura.gd")
const Dados := preload("res://codigo/modelos/dados_item.gd")
const Aparencia := preload("res://codigo/dados/aparencia.gd")
const Icones := preload("res://codigo/ui/icones_itens.gd")
var _falhas := 0

func _initialize() -> void:
	_rodar()

func _verificar(nome: String, condicao: bool) -> void:
	print("OK " if condicao else "FALHA ", nome)
	if not condicao:
		_falhas += 1

func _rodar() -> void:
	await process_frame
	if not OS.get_user_data_dir().ends_with("AlgoLand testes Carrasco"):
		push_error("Teste requer a cópia isolada AlgoLand testes Carrasco.")
		quit(1)
		return
	var inv := root.get_node("InventarioJogador")
	inv.limpar()
	inv.criar_itens_iniciais()
	# Trocar os três conjuntos seguidos guarda 12 peças na mochila; o kit agora ocupa 3 casas com as ferramentas da fazenda
	inv.definir_linhas_extras(1)
	var arena: Node = load("res://cenas/cenario.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	for i in 4:
		await process_frame
	arena.get_node("enemySpawner/GerenciadorOndas").parar_ondas()
	var jogador := arena.get_node("Jogador")
	jogador.set_physics_process(false)
	jogador.definir_aparencia(1, 2)
	inv.equipar(inv.buscar_por_tipo("espada_basica"))
	var painel := root.get_node("PainelDebug")
	var arma = inv.equipados["arma"]
	# Usa os callbacks que o dropdown oferece, não apenas o método interno.
	for i in 3:
		painel._opcoes["CONJUNTOS"][i][1].call()
		var id: String = ["cavalheiro", "cavaleiro_rubro", "carrasco"][i]
		var completo := true
		for slot in ["cabeca", "corpo", "luvas", "botas"]:
			var item: Dados = inv.equipados[slot]
			var conjunto := Conjuntos.de_tipo(item.tipo) if item != null else null
			completo = completo and conjunto != null and conjunto.ID == id and item.categoria == slot
			_verificar(id + "/" + slot + ": nome e ícone de item real", item != null and not item.nome().is_empty() and Icones.obter(item, self) != null)
		_verificar(id + ": dropdown equipa os quatro slots reais", completo and jogador.pecas_cavaleiro == 15 and inv.equipados["arma"] == arma)
		_verificar(id + ": visual vem dos slots sem prévia sobreposta", jogador.raizes_armadura.size() == 4 and Aparencia.raiz_armadura_visual(jogador.roupa_atual).is_empty())
		if id == "cavalheiro":
			_verificar("cartola equipada mantém o cabelo composto", jogador.sprite_cabelo.self_modulate.a == 0 and jogador.sprite_cabelo.get_parent().get_node("CartolaSobreCabelo").visible)
			_verificar("Mordomo comum congela sem multiplicador de status", jogador.estatisticas.bonus_defesa_conjunto == 0 and Conjuntos.de_tipo("elmo_cavalheiro").RARIDADE == "comum" and Conjuntos.de_tipo("elmo_cavalheiro").TIPO_BONUS == "congelamento" and Conjuntos.de_tipo("elmo_cavalheiro").chance_drop(99, true, true) == 0.1)
		if id == "cavaleiro_rubro":
			_verificar("Rubro ativa os 10% pelas quatro peças reais", jogador.estatisticas.bonus_defesa_conjunto == 0.1 and jogador.estatisticas.bonus_vitalidade_conjunto == 0.1)
		var anteriores: Dictionary = inv.equipados.duplicate()
		var mochila: Array = inv.mochila.duplicate()
		inv.equipados["corpo"].nivel = 3
		painel._opcoes["CONJUNTOS"][i][1].call()
		_verificar(id + ": repetir preserva instâncias, nível e mochila", inv.equipados == anteriores and inv.mochila == mochila and inv.equipados["corpo"].nivel == 3)
	# Todos os itens antigos permanecem disponíveis após trocar de conjunto.
	for conjunto in Conjuntos.CONJUNTOS:
		for tipo in conjunto.TIPOS:
			_verificar(tipo + ": peça não perdida nas trocas", inv.buscar_por_tipo(tipo) != null)
	painel._alternar_armadura("traje_cavalheiro")
	painel._equipar_conjunto("cavalheiro")
	_verificar("equipar retira prévia cosmética e conserva a roupa base", jogador.roupa_atual == 2 and jogador.raizes_armadura["elmo"].ends_with("cavalheiro/"))
	inv.remover_da_mochila(inv.buscar_por_tipo("lanca_basica"))
	_verificar("retirada da cartola tem espaço reservado na mochila", inv.desequipar("cabeca"))
	_verificar("retirar cartola pelo inventário remove o visual e restaura cabelo", jogador.pecas_cavaleiro == 14 and jogador.sprite_cabelo.self_modulate == Color.WHITE and not jogador.sprite_cabelo.get_parent().get_node("CartolaSobreCabelo").visible)
	painel._equipar_conjunto("cavalheiro")
	for componente in [jogador.no_arco, jogador.no_reacao, jogador.no_fazenda]:
		if componente == jogador.no_reacao:
			componente._familia = "um_mao"
		componente._sincronizar_aparencia()
		_verificar("ação real conserva cartola equipada pelos slots", componente.get_node("CartolaSobreCabelo").texture != null and componente._cabelo.self_modulate.a == 0)
	inv.salvar("user://teste_f3_conjuntos.json")
	var copia = load("res://codigo/modelos/modelo_inventario.gd").new()
	copia.carregar("user://teste_f3_conjuntos.json")
	_verificar("save mantém as quatro peças nos slots", Conjuntos.de_tipo("elmo_cavalheiro").mascara(copia.equipados) == 15 and copia.equipados["corpo"].nivel == 3)
	copia.free()
	# Mochila cheia com peças do conjunto disponíveis ainda permite troca simples.
	while inv.tem_espaco():
		inv.adicionar(Dados.new())
	painel._equipar_conjunto("carrasco")
	_verificar("mochila cheia permite trocar por peças que já estão nela", Conjuntos.de_tipo("elmo_carrasco").mascara(inv.equipados) == 15)
	var novos := {}
	for slot in ["cabeca", "corpo", "luvas", "botas"]:
		var novo := Dados.new()
		novo.categoria = slot
		novo.tipo = inv.equipados[slot].tipo
		novos[slot] = novo
	var antes: Dictionary = inv.equipados.duplicate()
	var bag: Array = inv.mochila.duplicate()
	_verificar("sem espaço para peças anteriores recusa a troca inteira", not inv.equipar_conjunto_armadura(novos) and inv.equipados == antes and inv.mochila == bag)
	print("Falhas: ", _falhas)
	quit(_falhas)
