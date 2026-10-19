extends SceneTree

## Arena e saves somente na cópia isolada.
const Rubro := preload("res://assets/personagens/conjuntos/cavaleiro_rubro/definicao.gd")
const Carrasco := preload("res://codigo/dados/conjunto_carrasco.gd")
const Conjuntos := preload("res://codigo/dados/conjuntos_armadura.gd")
const Dados := preload("res://codigo/modelos/dados_item.gd")
const Icones := preload("res://codigo/ui/icones_itens.gd")
var _falhas := 0

func _initialize() -> void:
	_rodar()

func _verificar(nome: String, passou: bool) -> void:
	print("OK " if passou else "FALHA ", nome)
	if not passou:
		_falhas += 1

func _rodar() -> void:
	await process_frame
	if not OS.get_user_data_dir().ends_with("AlgoLand testes Carrasco"):
		push_error("Use a cópia isolada AlgoLand testes Carrasco.")
		quit(1)
		return
	var drop: GDScript = load("res://codigo/logica/equipamento_drop.gd")
	var rng := RandomNumberGenerator.new()
	rng.seed = 6831
	_verificar("Rubro comum e bônus somente de status", Rubro.RARIDADE == "comum" and Rubro.TIPO_BONUS == "status" and Rubro.BONUS_DEFESA == 0.1 and Rubro.BONUS_VITALIDADE == 0.1)
	var precoce := false
	for i in 500:
		precoce = precoce or Rubro.TIPOS.has(drop.criar_item(rng, 0, true, true).tipo)
	_verificar("Rubro não cai antes da onda 1", not precoce)
	var total := 0
	var variantes := {}
	var corretos := true
	for i in 10000:
		var item: DadosItem = drop.criar_item(rng, 4, false, true)
		if Rubro.TIPOS.has(item.tipo):
			total += 1
			variantes[item.tipo] = true
			corretos = corretos and item.raridade == "comum" and item.afixos.is_empty() and item.encantamento == "" and item.categoria == Rubro.TIPOS[item.tipo]["slot"] and item.nivel == 1
	_verificar("sorteio traz as quatro peças comuns no nível 1", total > 850 and total < 1150 and variantes.size() == 4 and corretos)
	var inv := root.get_node("InventarioJogador")
	inv.limpar()
	inv.criar_itens_iniciais()
	var arena: Node = load("res://cenas/cenario.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	for i in 4:
		await process_frame
	arena.get_node("enemySpawner/GerenciadorOndas").parar_ondas()
	var jogador := arena.get_node("Jogador")
	jogador.set_physics_process(false)
	jogador.definir_aparencia(1, 2)
	var pecas := {}
	for tipo in Rubro.TIPOS:
		var item: DadosItem = drop.criar_item(rng, 4, false, false, "", tipo)
		item.nivel = 2
		_verificar(tipo + ": nome e ícone próprios", item.nome().contains("CAVALEIRO RUBRO") and Icones.obter(item, self) != null)
		var copia := Dados.de_dict(item.para_dict())
		_verificar(tipo + ": serialização mantém categoria, nível e raridade", copia.tipo == tipo and copia.categoria == item.categoria and copia.nivel == 2 and copia.raridade == "comum")
		pecas[item.categoria] = item
		var no: Node2D = drop.soltar_item(item, jogador.global_position, arena, rng)
		no._tentar_pegar()
		inv.equipar(item)
		if pecas.size() < 4:
			# Peças no nível 2: metade do efeito x 1,25 de escala (1 peça nada)
			var esperado := 0.0 if pecas.size() < 2 else 0.0625
			_verificar("bônus parcial com " + str(pecas.size()) + " peças", is_equal_approx(jogador.estatisticas.bonus_defesa_conjunto, esperado) and is_equal_approx(jogador.estatisticas.bonus_vitalidade_conjunto, esperado))
	_verificar("quatro peças reais nível 2 dão 12,5% de defesa e vitalidade", jogador.estatisticas.defesa == roundi(jogador.bonus_defesa * 1.125) and jogador.estatisticas.vitalidade == roundi((jogador.vitalidade_base + jogador.bonus_vitalidade) * 1.125) and is_equal_approx(jogador.estatisticas.bonus_defesa_conjunto, 0.125))
	_verificar("Rubro não ativa o raio do Carrasco", not Carrasco.pode_ativar(inv.equipados, 0.0, 0.0))
	_verificar("visual real usa o Rubro e mantém a cabeça da base refinada", jogador.sprite_roupa.texture.resource_path == Rubro.RAIZ_SPRITES + "andar.png" and jogador.sprite_corpo.texture.resource_path == "res://assets/personagens/refinado/paginas/andar.png")
	var defesa: int = jogador.estatisticas.defesa
	var vitalidade: int = jogador.estatisticas.vitalidade
	for i in 5:
		jogador._aplicar_modelo()
	_verificar("reaplicar inventário não acumula bônus", jogador.estatisticas.defesa == defesa and jogador.estatisticas.vitalidade == vitalidade)
	jogador.no_arco._sincronizar_aparencia()
	var textura_anterior: Texture2D = jogador.no_arco._roupa.texture
	var outra: DadosItem = drop.criar_item(rng, 14, false, false, "", "elmo_carrasco")
	inv.adicionar(outra)
	inv.equipar(outra)
	jogador.no_arco._sincronizar_aparencia()
	_verificar("misturar conjuntos mantém só o bônus parcial do Rubro (3/4) e não ativa o raio", is_equal_approx(jogador.estatisticas.bonus_defesa_conjunto, 0.0625) and is_equal_approx(jogador.estatisticas.bonus_vitalidade_conjunto, 0.0625) and not Carrasco.pode_ativar(inv.equipados, 0.0, 0.0))
	_verificar("trocar o elmo com a mesma máscara atualiza o arco", jogador.pecas_cavaleiro == 15 and jogador.no_arco._roupa.texture != textura_anterior and jogador.raizes_armadura["elmo"] == Carrasco.RAIZ_SPRITES)
	inv.equipar(pecas["cabeca"])
	_verificar("restaurar a quarta peça retorna ao mesmo bônus", jogador.estatisticas.defesa == defesa and jogador.estatisticas.vitalidade == vitalidade)
	pecas["corpo"].nivel = 3
	jogador._aplicar_modelo()
	_verificar("melhorar uma peça não muda o nível do conjunto (vale a mais fraca) nem acumula", jogador.estatisticas.defesa == roundi(jogador.bonus_defesa * 1.125) and jogador.estatisticas.vitalidade == roundi((jogador.vitalidade_base + jogador.bonus_vitalidade) * 1.125))
	inv.salvar("user://teste_rubro_equipado.json")
	var modelo = load("res://codigo/modelos/modelo_inventario.gd").new()
	modelo.carregar("user://teste_rubro_equipado.json")
	_verificar("save mantém quatro peças e nível melhorado", Rubro.mascara(modelo.equipados) == 15 and modelo.equipados["corpo"].nivel == 3)
	modelo.free()
	for slot in ["cabeca", "corpo", "luvas", "botas"]:
		inv.desequipar(slot)
	for i in 2:
		await process_frame
	root.get_node("PainelDebug")._alternar_armadura("armadura_cavaleiro_rubro")
	_verificar("prévia do F3 não concede os 10%", jogador.estatisticas.bonus_defesa_conjunto == 0.0 and jogador.estatisticas.bonus_vitalidade_conjunto == 0.0)
	root.get_node("PainelDebug")._ao_drop_conjunto("cavaleiro_rubro")
	var gerados := get_nodes_in_group("equipamento_drop")
	var todos_rubros := gerados.size() == 4
	for no in gerados:
		todos_rubros = todos_rubros and Rubro.TIPOS.has(no.item.tipo) and no.item.raridade == "comum"
	_verificar("F3 gera quatro drops reais do Rubro", todos_rubros)
	print("Falhas: ", _falhas)
	quit(_falhas)
