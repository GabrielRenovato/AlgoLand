extends SceneTree

## Arena e saves somente na cópia isolada.
const Rubro := preload("res://CharacterSprites/Conjuntos/cavaleiro_rubro/definicao.gd")
const Carrasco := preload("res://Codigos/DadosLocais/conjunto_carrasco.gd")
const Conjuntos := preload("res://Codigos/DadosLocais/conjuntos_armadura.gd")
const Dados := preload("res://Codigos/Modelos/dados_item.gd")
const Icones := preload("res://Codigos/UI/icones_itens.gd")
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
	var drop: GDScript = load("res://Codigos/Logicas/equipamento_drop.gd")
	var rng := RandomNumberGenerator.new()
	rng.seed = 6831
	_verificar("Rubro incomum e bônus somente de status", Rubro.RARIDADE == "incomum" and Rubro.TIPO_BONUS == "status" and Rubro.BONUS_DEFESA == 0.1 and Rubro.BONUS_VITALIDADE == 0.1)
	var precoce := false
	for i in 500:
		precoce = precoce or Rubro.TIPOS.has(drop.criar_item(rng, 3, true, true).tipo)
	_verificar("Rubro não cai antes da onda 4", not precoce)
	var total := 0
	var variantes := {}
	var corretos := true
	for i in 10000:
		var item: DadosItem = drop.criar_item(rng, 4, false, false)
		if Rubro.TIPOS.has(item.tipo):
			total += 1
			variantes[item.tipo] = true
			corretos = corretos and item.raridade == "incomum" and item.afixos.is_empty() and item.encantamento == "" and item.categoria == Rubro.TIPOS[item.tipo]["slot"] and item.nivel >= 1 and item.nivel <= 2
	_verificar("sorteio da onda 4 traz as quatro peças incomuns", total > 3200 and total < 3800 and variantes.size() == 4 and corretos)
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
		_verificar(tipo + ": serialização mantém categoria, nível e raridade", copia.tipo == tipo and copia.categoria == item.categoria and copia.nivel == 2 and copia.raridade == "incomum")
		pecas[item.categoria] = item
		var no: Node2D = drop.soltar_item(item, jogador.global_position, arena, rng)
		no._tentar_pegar()
		inv.equipar(item)
		if pecas.size() < 4:
			_verificar("bônus ainda desligado com " + str(pecas.size()) + " peças", jogador.estatisticas.bonus_defesa_conjunto == 0.0 and jogador.estatisticas.bonus_vitalidade_conjunto == 0.0)
	_verificar("quatro peças reais dão 10% de defesa e vitalidade", jogador.estatisticas.defesa == roundi(jogador.bonus_defesa * 1.1) and jogador.estatisticas.vitalidade == roundi((jogador.vitalidade_base + jogador.bonus_vitalidade) * 1.1) and jogador.estatisticas.bonus_defesa_conjunto == 0.1)
	_verificar("Rubro não ativa o raio do Carrasco", not Carrasco.pode_ativar(inv.equipados, 0.0, 0.0))
	_verificar("visual real usa o Rubro e mantém a cabeça original", jogador.sprite_roupa.texture.resource_path == Rubro.RAIZ_SPRITES + "andar.png" and jogador.sprite_corpo.texture.resource_path == "res://CharacterSprites/Body/body_1.png")
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
	_verificar("misturar conjuntos desliga os dois bônus", jogador.estatisticas.bonus_defesa_conjunto == 0.0 and jogador.estatisticas.bonus_vitalidade_conjunto == 0.0 and not Carrasco.pode_ativar(inv.equipados, 0.0, 0.0))
	_verificar("trocar o elmo com a mesma máscara atualiza o arco", jogador.pecas_cavaleiro == 15 and jogador.no_arco._roupa.texture != textura_anterior and jogador.raizes_armadura["elmo"] == Carrasco.RAIZ_SPRITES)
	inv.equipar(pecas["cabeca"])
	_verificar("restaurar a quarta peça retorna ao mesmo bônus", jogador.estatisticas.defesa == defesa and jogador.estatisticas.vitalidade == vitalidade)
	pecas["corpo"].nivel = 3
	jogador._aplicar_modelo()
	_verificar("melhorar peça recalcula os 10% sem acumulação", jogador.estatisticas.defesa == roundi(jogador.bonus_defesa * 1.1) and jogador.estatisticas.vitalidade == roundi((jogador.vitalidade_base + jogador.bonus_vitalidade) * 1.1))
	inv.salvar("user://teste_rubro_equipado.json")
	var modelo = load("res://Codigos/Modelos/modelo_inventario.gd").new()
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
		todos_rubros = todos_rubros and Rubro.TIPOS.has(no.item.tipo) and no.item.raridade == "incomum"
	_verificar("F3 gera quatro drops reais do Rubro", todos_rubros)
	print("Falhas: ", _falhas)
	quit(_falhas)
