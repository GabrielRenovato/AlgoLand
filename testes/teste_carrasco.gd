extends SceneTree

# Executar em cópia do projeto com config/name="AlgoLand testes Carrasco".
# Carrega a arena e grava inventário: a guarda abaixo exige o diretório isolado de teste.
const Carrasco := preload("res://codigo/dados/conjunto_carrasco.gd")
const Dados := preload("res://codigo/modelos/dados_item.gd")
const Aparencia := preload("res://codigo/dados/aparencia.gd")
const Icones := preload("res://codigo/ui/icones_itens.gd")
var _falhas := 0
var _arena: Node
var _jogador: Node
var _inv: Node

class AlvoTeste extends Node2D:
	var esta_morto := false
	var eh_chefe := false
	var dano_recebido := 0
	func receber_dano(dano: int, _empurrao: Vector2 = Vector2.ZERO) -> void:
		dano_recebido += dano

func _initialize() -> void:
	_rodar()

func _verificar(nome: String, condicao: bool) -> void:
	print("OK " if condicao else "FALHA ", nome)
	if not condicao:
		_falhas += 1

func _rodar() -> void:
	await process_frame
	if not OS.get_user_data_dir().ends_with("AlgoLand testes Carrasco"):
		push_error("Teste exige uma cópia com dados isolados: config/name=AlgoLand testes Carrasco")
		quit(1)
		return
	var drop = load("res://codigo/logica/equipamento_drop.gd")
	var rng := RandomNumberGenerator.new()
	rng.seed = 391
	var precoce := false
	for i in 500:
		precoce = precoce or Carrasco.TIPOS.has(drop.criar_item(rng, 0, true, true).tipo)
	_verificar("conjunto não cai antes da onda 1", not precoce)
	var total := 0
	var variantes := {}
	var lendarios := true
	for i in 10000:
		var item: DadosItem = drop.criar_item(rng, 14, false, true)
		if Carrasco.TIPOS.has(item.tipo):
			total += 1
			variantes[item.tipo] = true
			lendarios = lendarios and item.raridade == "comum" and item.nivel == 1 and item.categoria == Carrasco.TIPOS[item.tipo]["slot"] and not item.duas_maos and item.afixos.is_empty()
	_verificar("sorteio raro inclui as quatro peças e seus slots", total > 850 and total < 1150 and variantes.size() == 4 and lendarios)
	for tipo in Carrasco.TIPOS:
		var item: DadosItem = drop.criar_item(rng, 22, false, false, "comum", tipo)
		var copia := Dados.de_dict(item.para_dict())
		_verificar(tipo + ": comum com nível e afixos preservados no save", copia.tipo == tipo and copia.nivel == item.nivel and copia.raridade == "comum" and copia.afixos == item.afixos and copia.categoria == item.categoria)
		_verificar(tipo + ": ícone próprio disponível", Icones.obter(item, self) != null)
	_inv = root.get_node("InventarioJogador")
	_inv.limpar()
	_inv.criar_itens_iniciais()
	_inv.salvar()
	_arena = load("res://cenas/cenario.tscn").instantiate()
	root.add_child(_arena)
	current_scene = _arena
	for i in 4:
		await process_frame
	_arena.get_node("enemySpawner/GerenciadorOndas").parar_ondas()
	_jogador = _arena.get_node("Jogador")
	_jogador.set_physics_process(false)
	_jogador.definir_aparencia(1, 2)
	var defesa_base: int = _jogador.bonus_defesa
	var vita_base: int = _jogador.bonus_vitalidade
	var basicos := {}
	for slot in ["cabeca", "corpo", "luvas", "botas"]:
		basicos[slot] = _inv.equipados[slot]
	var pecas := {}
	for tipo in Carrasco.TIPOS:
		var item: DadosItem = drop.criar_item(rng, 14, false, false, "lendario", tipo)
		pecas[item.categoria] = item
		var no: Node2D = drop.soltar_item(item, _jogador.global_position, _arena, rng)
		no._tentar_pegar()
		_verificar(tipo + ": drop recolhido vai à mochila", _inv.indice_de(item) >= 0)
		_inv.equipar(item)
		_verificar(tipo + ": equipa no slot correto", _inv.equipados[item.categoria] == item)
	_verificar("quatro peças ativam a aparência real sem trocar a roupa escolhida", _jogador.pecas_cavaleiro == 15 and _jogador.roupa_atual == 2 and _jogador.sprite_cabelo.texture.get_image().is_invisible())
	_inv.salvar("user://teste_carrasco_equipado.json")
	var modelo = load("res://codigo/modelos/modelo_inventario.gd").new()
	modelo.carregar("user://teste_carrasco_equipado.json")
	_verificar("save preserva o conjunto equipado nos quatro slots", Carrasco.mascara(modelo.equipados) == 15)
	modelo.free()
	var defesa_set: int = _jogador.bonus_defesa
	var vida_set: int = _jogador.bonus_vitalidade
	_jogador._aplicar_modelo()
	_jogador._aplicar_modelo()
	_verificar("sincronizar os mesmos itens não duplica bônus", _jogador.bonus_defesa == defesa_set and _jogador.bonus_vitalidade == vida_set)
	var alvo := AlvoTeste.new()
	_arena.add_child(alvo)
	alvo.add_to_group("enemy")
	alvo.global_position = _jogador.global_position
	var chefe := AlvoTeste.new()
	chefe.eh_chefe = true
	_arena.add_child(chefe)
	chefe.add_to_group("enemy")
	chefe.global_position = alvo.global_position + Vector2(8, 0)
	_verificar("quatro peças ativam raio em sorteio favorável", _jogador._tentar_raio_carrasco(alvo, 20, 0.0))
	_verificar("recarga impede múltiplos raios no mesmo ataque", not _jogador._tentar_raio_carrasco(alvo, 20, 0.0))
	var raio: Node = get_first_node_in_group("raios_carrasco")
	var hp_antes: int = _jogador.hp_atual
	raio.cair()
	_verificar("raio causa dano em área de 200%, inclusive no chefe", alvo.dano_recebido == 40 and chefe.dano_recebido == 40)
	_verificar("raio aliado não atinge o jogador na mesma posição", _jogador.hp_atual == hp_antes and not raio.atingiu_jogador)
	raio.remove_from_group("raios_carrasco")
	var semente := 0
	var busca := RandomNumberGenerator.new()
	for i in range(1, 100):
		busca.seed = i
		if busca.randf() < Carrasco.CHANCE_RAIO:
			semente = i
			break
	_inv.equipar(_inv.buscar_por_tipo("espada_basica"))
	_jogador._recarga_carrasco = 0.0
	_jogador._rng_carrasco.seed = semente
	_jogador.aplicar_golpe(alvo, Vector2.ZERO)
	var raio_golpe: Node = get_first_node_in_group("raios_carrasco")
	_verificar("acerto real da arma dispara o efeito do conjunto", raio_golpe != null)
	if raio_golpe != null:
		raio_golpe.remove_from_group("raios_carrasco")
	_jogador._recarga_carrasco = 0.0
	_jogador._rng_carrasco.seed = semente
	var flecha = load("res://codigo/jogador/flecha.gd").new()
	_arena.add_child(flecha)
	flecha.iniciar(_jogador, Vector2.RIGHT)
	flecha._ao_alvo_entrar(alvo)
	_verificar("flecha real também dispara o efeito do conjunto", get_first_node_in_group("raios_carrasco") != null)
	_inv.desequipar("cabeca")
	_jogador._recarga_carrasco = 0.0
	_verificar("três peças dão só metade da chance (5%) e restauram cabelo", not _jogador._tentar_raio_carrasco(alvo, 20, 0.06) and not _jogador.sprite_cabelo.texture.get_image().is_invisible())
	for slot in basicos:
		if basicos[slot] == null:
			_inv.desequipar(slot)
		else:
			_inv.equipar(basicos[slot])
	_verificar("trocar de volta restaura exatamente os bônus básicos", _jogador.bonus_defesa == defesa_base and _jogador.bonus_vitalidade == vita_base and _jogador.pecas_cavaleiro == 0)
	# O traje cosmético do F3 não concede o bônus do conjunto.
	for i in Aparencia.total_roupas():
		if Aparencia.roupas()[i]["id"] == "armadura_cavaleiro":
			_jogador.definir_aparencia(1, i)
	_verificar("prévia cosmética não ativa raio sem os itens", not _jogador._tentar_raio_carrasco(alvo, 20, 0.0))
	_verificar("sorteio fora de 10% não ativa", not Carrasco.pode_ativar(pecas, 0.0, 0.5))
	_inv.salvar()
	_inv.limpar()
	_inv.carregar()
	_verificar("inventário salva e recarrega as peças da mochila", _inv.buscar_por_tipo("elmo_carrasco") != null)
	print("Falhas: ", _falhas)
	_jogador.status_armas.free()
	if _jogador.estatisticas is Node:
		_jogador.estatisticas.free()
	_arena.queue_free()
	await process_frame
	call_deferred("_encerrar")

func _encerrar() -> void:
	quit(_falhas)
