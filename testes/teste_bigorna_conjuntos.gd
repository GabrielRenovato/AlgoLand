extends SceneTree

# Rodar na cópia isolada: godot --headless --path <copia> --script res://testes/teste_bigorna_conjuntos.gd
# Bigorna com peça de conjunto: o slot aceita, o custo é ouro + 1 moeda de forja, o nível sobe só na instância e o bônus acompanha.

const Equipamentos := preload("res://codigo/dados/equipamentos.gd")
const Conjuntos := preload("res://codigo/dados/conjuntos_armadura.gd")
const Rubro := preload("res://assets/personagens/conjuntos/cavaleiro_rubro/definicao.gd")
const DadosItemScript := preload("res://codigo/modelos/dados_item.gd")
const Raridades := preload("res://codigo/dados/raridades.gd")
var _falhas := 0
var _cena: Node
var _jogador: Node2D
var _inv: Node

func _initialize() -> void:
	_rodar()

func _verificar(nome: String, condicao: bool, detalhe: String = "") -> void:
	print("OK " if condicao else "FALHA ", nome, "" if condicao else ": " + detalhe)
	if not condicao:
		_falhas += 1

func _quadros(n: int) -> void:
	for i in n:
		await process_frame

func _rodar() -> void:
	await process_frame
	if not OS.get_user_data_dir().ends_with("AlgoLand testes Carrasco"):
		push_error("Use a cópia isolada AlgoLand testes Carrasco.")
		quit(1)
		return
	root.get_node("Progresso").caminho_save = "user://teste_bigorna_progresso.json"
	root.get_node("Fazenda").caminho_save = "user://teste_bigorna_fazenda.json"
	root.get_node("Progresso").apagar()
	root.get_node("Fazenda").apagar()
	_inv = root.get_node("InventarioJogador")
	_inv.limpar()
	_inv.criar_itens_iniciais()
	_cena = load("res://cenas/cenario.tscn").instantiate()
	root.add_child(_cena)
	current_scene = _cena
	await _quadros(10)
	_jogador = _cena.get_node("Jogador")
	_cena.get_node("enemySpawner/GerenciadorOndas").parar_ondas()
	var mercante: Control = get_first_node_in_group("tela_mercante")
	_verificar("tela do mercador existe", mercante != null)
	if mercante == null:
		quit(1)
		return
	var pecas := {}
	var rng := RandomNumberGenerator.new()
	var drop: GDScript = load("res://codigo/logica/equipamento_drop.gd")
	for tipo in Rubro.TIPOS:
		var item: DadosItem = drop.criar_item(rng, 1, false, false, "", tipo)
		pecas[item.categoria] = item
		_inv.adicionar(item)
		_inv.equipar(item)
	await _quadros(3)
	var antes: float = _jogador.estatisticas.bonus_defesa_conjunto
	_verificar("4/4 nível 1 dá 10%", is_equal_approx(antes, 0.1), str(antes))
	var casa: Control = load("res://cenas/ui/componentes/item_ui.tscn").instantiate()
	root.add_child(casa)
	casa.exibir(pecas["corpo"])
	_verificar("o slot da bigorna aceita peça de conjunto", mercante._slot_bigorna.aceita_item(casa))
	var basico: Control = load("res://cenas/ui/componentes/item_ui.tscn").instantiate()
	root.add_child(basico)
	basico.exibir(_inv.buscar_por_tipo("armadura_basica"))
	_verificar("e recusa armadura básica", not mercante._slot_bigorna.aceita_item(basico))
	mercante._painel_bigorna.visible = true
	mercante._slot_bigorna.colocar_item(casa)
	var dados: Dictionary = mercante._dados_upgrade()
	_verificar("dados do upgrade de conjunto", not dados.is_empty() and dados["conjunto"] and dados["moedas_forja"] == 1 and dados["custo"] == Equipamentos.NIVEIS_CUSTO[1], str(dados))
	_inv.limpar()
	_inv.adicionar_moedas_forja(0)
	_verificar("sem moeda de forja o upgrade fica bloqueado", not mercante._dados_upgrade().get("forja_ok", true) or mercante._dados_upgrade().is_empty())
	# Reequipa e confirma o refino sem animação nem temporizador.
	for categoria in pecas:
		_inv.adicionar(pecas[categoria])
		_inv.equipar(pecas[categoria])
	await _quadros(3)
	var temporizadores_antes := _jogador.get_children().filter(func(no): return no is Timer).size()
	var conclusoes := [0]
	_jogador.forja_finalizada.connect(func(): conclusoes[0]+=1)
	_jogador.iniciar_forja(pecas["corpo"])
	_verificar("refino imediato e concluído uma vez", pecas["corpo"].nivel==2 and conclusoes[0]==1)
	_verificar("refino não cria espera nem bloqueia movimento", not _jogador.esta_forjando and _jogador.movimento_habilitado and _jogador.get_children().filter(func(no): return no is Timer).size()==temporizadores_antes)
	var visual := _jogador.get_node("HeroiRaven")
	visual._process(0.0)
	_verificar("refino não reproduz martelada", visual._animacao!="forjar" and not _jogador.no_forja.visible)
	await _quadros(3)
	_verificar("o nível sobe só na peça forjada", pecas["corpo"].nivel == 2 and pecas["cabeca"].nivel == 1)
	_verificar("o nível do conjunto continua o da peça mais fraca", is_equal_approx(_jogador.estatisticas.bonus_defesa_conjunto, 0.1), str(_jogador.estatisticas.bonus_defesa_conjunto))
	for categoria in ["cabeca", "luvas", "botas"]:
		_jogador._on_forja_finalizada(pecas[categoria])
		await _quadros(2)
	_verificar("com as quatro peças no nível 2 o bônus vira 12,5%", is_equal_approx(_jogador.estatisticas.bonus_defesa_conjunto, 0.125), str(_jogador.estatisticas.bonus_defesa_conjunto))
	var dados_nv: Dictionary = Rubro.dados("peitoral_cavaleiro_rubro", 2)
	_verificar("o pacote do slot usa o nível novo da peça", _jogador._pacote_aplicado["corpo"]["defesa"] == int(dados_nv["bonus_defesa"]), str(_jogador._pacote_aplicado["corpo"]))
	# Nível 5: a bigorna passa a subir a raridade e somar um bônus, até o lendário
	var peito: DadosItem = pecas["corpo"]
	peito.nivel = 5
	_jogador._aplicar_modelo()
	await _quadros(2)
	mercante._slot_bigorna.colocar_item(casa)
	casa.exibir(peito)
	var asc: Dictionary = mercante._dados_upgrade()
	_verificar("nível 5 oferece a ascensão comum > incomum", not asc.is_empty() and asc["proximo"].get("ascensao", false) and asc["proximo"]["raridade_nova"] == "incomum", str(asc.get("proximo", {})))
	var raridades_vistas: Array = []
	for i in 4:
		_jogador._on_forja_finalizada(peito)
		await _quadros(2)
		raridades_vistas.append(peito.raridade)
	_verificar("quatro ascensões levam ao lendário passo a passo", raridades_vistas == ["incomum", "raro", "epico", "lendario"], str(raridades_vistas))
	_verificar("cada ascensão soma um bônus diferente (4 no lendário)", peito.afixos.size() == 4, str(peito.afixos))
	_verificar("o nível fica em 5", peito.nivel == 5)
	var esperado_def: int = Raridades.escalar(int(Rubro.dados("peitoral_cavaleiro_rubro", 5)["bonus_defesa"]), "lendario") + roundi(peito.afixo("defesa"))
	_verificar("o pacote do slot usa a raridade lendária e os bônus", _jogador._pacote_aplicado["corpo"]["defesa"] == esperado_def, "%s x %d" % [str(_jogador._pacote_aplicado["corpo"]), esperado_def])
	_jogador._on_forja_finalizada(peito)
	_verificar("lendário nível 5 não sobe mais", peito.raridade == "lendario" and peito.nivel == 5 and peito.afixos.size() == 4)
	_verificar("bigorna mostra máximo no lendário", mercante._dados_upgrade()["proximo"].is_empty())
	var copia := DadosItemScript.de_dict(peito.para_dict())
	_verificar("save mantém a raridade e os bônus ganhos", copia.raridade == "lendario" and copia.afixos == peito.afixos)
	print("Falhas: ", _falhas)
	quit(_falhas)
