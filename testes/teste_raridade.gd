extends SceneTree

# Rodar: godot --headless --path . --script res://testes/teste_raridade.gd
# Raridade dos equipamentos (codigo/dados/raridades.gd): sorteio, multiplicador, afixos, salvamento, bônus simétricos ao trocar de item
# (duas espadas do MESMO tipo com raridades diferentes), forja por instância, hotbar, drop no chão, mochila cheia e venda.
# ATENCAO: carrega a cena de jogo e mexe no inventário (grava user://inventario.json); faça backup do user:// antes.

const Raridades := preload("res://codigo/dados/raridades.gd")
const Equipamentos := preload("res://codigo/dados/equipamentos.gd")
const DadosItemScript := preload("res://codigo/modelos/dados_item.gd")
const Conjuntos := preload("res://codigo/dados/conjuntos_armadura.gd")

# Carregado em _rodar (usa o autoload InventarioJogador, que ainda não existe quando o script é compilado)
var EquipamentoDrop: GDScript
var _falhas: int = 0
var _cena: Node
var _jogador: Node2D
var _inv: Node

func _initialize() -> void:
	_rodar()

func _verificar(nome: String, condicao: bool, detalhe: String = "") -> void:
	if condicao:
		print("OK ", nome)
	else:
		_falhas += 1
		print("FALHA ", nome, ": ", detalhe)

## O kit inicial já vem com espada e escudo equipados e as ferramentas da fazenda na primeira linha; estes cenários partem das
## mãos vazias e da barra só de armas (espada, lança e escudo nas casas 1 a 3; ferramentas na terceira linha)
func _kit_sem_maos() -> void:
	_inv.criar_itens_iniciais()
	_inv.desequipar("arma")
	_inv.desequipar("escudo")
	_inv.mover_para_mochila(_inv.buscar_por_tipo("lanca_basica"), 1)
	_inv.mover_para_mochila(_inv.buscar_por_tipo("escudo_basico"), 2)
	for i in 3:
		_inv.mover_para_mochila(_inv.buscar_por_tipo(["enxada", "regador", "mao"][i]), 10 + i)

func _quadros(n: int) -> void:
	for i in n:
		await process_frame

func _ms(ms: int) -> void:
	await create_timer(ms / 1000.0).timeout

func _novo(tipo: String, categoria: String, raridade: String, nivel: int = 1, afixos: Dictionary = {}):
	var item = DadosItemScript.new()
	item.id = StringName(tipo)
	item.tipo = tipo
	item.categoria = categoria
	item.raridade = raridade
	item.nivel = nivel
	item.afixos = afixos
	item.duas_maos = Equipamentos.familia_de(tipo) in ["lanca", "arco"]
	return item

## Foto dos números que equipamento mexe (para conferir que voltam ao que eram)
func _foto() -> Dictionary:
	var e = _jogador.estatisticas
	return {"defesa": _jogador.bonus_defesa, "vit": _jogador.bonus_vitalidade, "crit": e.bonus_critico, "dcrit": e.bonus_dano_critico,
			"roubo": e.roubo_vida, "vel": e.bonus_velocidade_item, "dano": e.dano_arma}

func _igual(a: Dictionary, b: Dictionary) -> bool:
	for k in a:
		if not is_equal_approx(float(a[k]), float(b[k])):
			return false
	return true

# --- Dados puros -----------------------------------------------------------------------------------------------------

func _testar_dados() -> void:
	_verificar("5 raridades na ordem comum..lendario", Raridades.ORDEM == ["comum", "incomum", "raro", "epico", "lendario"], str(Raridades.ORDEM))
	_verificar("o multiplicador sobe com a raridade", Raridades.multiplicador("comum") < Raridades.multiplicador("incomum") and Raridades.multiplicador("incomum") < Raridades.multiplicador("raro") \
			and Raridades.multiplicador("raro") < Raridades.multiplicador("epico") and Raridades.multiplicador("epico") < Raridades.multiplicador("lendario"), "")
	_verificar("escalar: comum nao muda", Raridades.escalar(8, "comum") == 8, "")
	_verificar("escalar: raridade acima sempre da pelo menos +1 (mesmo com valor pequeno)", Raridades.escalar(2, "incomum") == 3 and Raridades.escalar(1, "raro") == 2, "%d %d" % [Raridades.escalar(2, "incomum"), Raridades.escalar(1, "raro")])
	_verificar("escalar: zero continua zero", Raridades.escalar(0, "lendario") == 0, "")
	_verificar("escalar: lendario 40 -> 60", Raridades.escalar(40, "lendario") == 60, str(Raridades.escalar(40, "lendario")))
	_verificar("raridade desconhecida cai em comum", Raridades.cor("xyz") == Raridades.cor("comum") and Raridades.multiplicador("xyz") == 1.0, "")

	# Sorteio: distribuição com seed fixa
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var contagem := {}
	for r in Raridades.ORDEM:
		contagem[r] = 0
	var n := 20000
	for i in n:
		contagem[Raridades.sortear(rng, 1)] += 1
	_verificar("onda 1: comum e a mais frequente, e cada raridade e mais rara que a anterior", contagem["comum"] > contagem["incomum"] and contagem["incomum"] > contagem["raro"] \
			and contagem["raro"] > contagem["epico"] and contagem["epico"] > contagem["lendario"], str(contagem))
	_verificar("onda 1: comum perto de 60%", absf(float(contagem["comum"]) / n - 0.58) < 0.04, str(float(contagem["comum"]) / n))
	_verificar("o lendario aparece (raro, mas nao zero)", contagem["lendario"] > 0, str(contagem["lendario"]))
	var alta := {"lendario": 0, "epico": 0}
	for i in n:
		var r := Raridades.sortear(rng, 40)
		if alta.has(r):
			alta[r] += 1
	_verificar("onda alta desloca o sorteio para raridades melhores", alta["lendario"] > contagem["lendario"] and alta["epico"] > contagem["epico"], "%s x %s" % [str(alta), str(contagem)])
	var chefe_comum := 0
	var chefe_raro_ou_mais := 0
	for i in 5000:
		var r := Raridades.sortear(rng, 10, 2, "raro")
		if r == "comum" or r == "incomum":
			chefe_comum += 1
		else:
			chefe_raro_ou_mais += 1
	_verificar("piso do chefe: nunca sai comum nem incomum", chefe_comum == 0 and chefe_raro_ou_mais == 5000, str(chefe_comum))

	# Afixos
	var arma_ok := true
	var escudo_ok := true
	var enc_ok := true
	for r in Raridades.ORDEM:
		for i in 50:
			var afixos := Raridades.sortear_afixos(rng, "arma", r)
			var quantos := Raridades.quantidade_afixos(r)
			if r == "lendario":
				enc_ok = enc_ok and afixos.has("encantamento") and afixos.size() == quantos
			else:
				arma_ok = arma_ok and afixos.size() == quantos and not afixos.has("encantamento")
			var af_escudo := Raridades.sortear_afixos(rng, "escudo", r)
			escudo_ok = escudo_ok and af_escudo.size() == quantos
			for id in af_escudo:
				escudo_ok = escudo_ok and "escudo" in Raridades.AFIXOS[id]["slots"]
	_verificar("afixos por raridade: 0, 0, 1, 2 (arma)", arma_ok, "")
	_verificar("lendario de arma traz o encantamento no lugar de um afixo (3 no total)", enc_ok, "")
	_verificar("afixos de escudo so saem do pool do escudo, sem repetir", escudo_ok, "")
	var sem_repetir := true
	for i in 100:
		var af := Raridades.sortear_afixos(rng, "arma", "epico")
		sem_repetir = sem_repetir and af.size() == 2
	_verificar("epico: 2 afixos diferentes", sem_repetir, "")
	_verificar("texto do afixo percentual e inteiro", Raridades.texto_afixo("critico", 0.04) == "+4% CRITICO" and Raridades.texto_afixo("defesa", 3.0) == "+3 DEFESA", Raridades.texto_afixo("critico", 0.04))

	# Salvar e carregar
	var item = _novo("machado", "arma", "epico", 3, {"critico": 0.05, "vitalidade": 2.0})
	item.encantamento = "fogo"
	item.nivel_encantamento = 1
	var copia = DadosItemScript.de_dict(item.para_dict())
	_verificar("dict: raridade e afixos fazem ida e volta", copia.raridade == "epico" and is_equal_approx(copia.afixo("critico"), 0.05) and is_equal_approx(copia.afixo("vitalidade"), 2.0) and copia.nivel == 3, str(copia.para_dict()))
	var json = JSON.parse_string(JSON.stringify(item.para_dict()))
	var de_json = DadosItemScript.de_dict(json)
	_verificar("o JSON (como no save) preserva os afixos", is_equal_approx(de_json.afixo("critico"), 0.05) and de_json.afixos.size() == 2, str(de_json.afixos))
	var antigo = DadosItemScript.de_dict({"id": "espada_basica", "tipo": "espada_basica", "categoria": "arma", "nivel": 2, "raridade": "comum", "duas_maos": false})
	_verificar("save antigo (sem afixos) carrega como comum sem afixos", antigo.raridade == "comum" and antigo.afixos.is_empty() and antigo.nivel == 2, "")
	var estranho = DadosItemScript.de_dict({"tipo": "espada_basica", "raridade": "mitico", "afixos": {"inventado": 9.0, "critico": 0.02}})
	_verificar("raridade e afixo desconhecidos sao descartados", estranho.raridade == "comum" and not estranho.afixos.has("inventado") and estranho.afixos.has("critico"), str(estranho.para_dict()))

	# Criação de drops
	var nivel_ok := true
	var chefe_ok := true
	var tipos_vistos := {}
	for i in 600:
		var onda := rng.randi_range(1, 30)
		var chefe := i % 3 == 0
		var novo = EquipamentoDrop.criar_item(rng, onda, false, chefe)
		nivel_ok = nivel_ok and novo.nivel >= 1 and novo.nivel <= Equipamentos.nivel_liberado(onda)
		chefe_ok = chefe_ok and (not chefe or Conjuntos.de_tipo(novo.tipo) != null or Raridades.indice(novo.raridade) >= Raridades.indice("raro"))
		if Equipamentos.TIPOS_DROP.has(novo.tipo):
			tipos_vistos[novo.tipo] = true
		else:
			var conjunto := Conjuntos.de_tipo(novo.tipo)
			nivel_ok = nivel_ok and conjunto != null and novo.raridade == conjunto.RARIDADE and onda >= conjunto.ONDA_MINIMA
		nivel_ok = nivel_ok and (novo.categoria == "escudo") == (novo.tipo == "escudo_basico")
		if novo.raridade == "lendario" and novo.categoria == "arma":
			nivel_ok = nivel_ok and novo.encantamento != "" and novo.nivel_encantamento == 1
	_verificar("drop: nivel dentro do que a onda libera e categoria certa", nivel_ok, "")
	_verificar("drop de chefe: piso RARO nas armas e raridade própria nos conjuntos", chefe_ok, "")
	_verificar("drop: sai todo tipo de arma e o escudo", tipos_vistos.size() == Equipamentos.TIPOS_DROP.size(), str(tipos_vistos.keys()))
	_verificar("nivel liberado pela onda (1, 2, 3, 4, 5)", Equipamentos.nivel_liberado(1) == 1 and Equipamentos.nivel_liberado(4) == 2 and Equipamentos.nivel_liberado(8) == 3 and Equipamentos.nivel_liberado(14) == 4 and Equipamentos.nivel_liberado(22) == 5, "")
	_verificar("chance de receita: comum < mutante < chefe, sem garantia", EquipamentoDrop.chance(false, false) < EquipamentoDrop.chance(true, false) and EquipamentoDrop.chance(true, false) < EquipamentoDrop.chance(true, true) and EquipamentoDrop.chance(true, true) == 0.20, "")

	# Preço de venda
	_verificar("venda: o nivel entra pelo custo das melhorias (400 + 200 + 500 = 1100 x 30%)", Equipamentos.preco_venda("espada_gemea", "comum", 3) == 330, str(Equipamentos.preco_venda("espada_gemea", "comum", 3)))
	_verificar("venda: um lendario nv4 nunca passa do que custou comprar e melhorar x3", Equipamentos.preco_venda("arco_longo", "lendario", 4) < 3 * (900 + 200 + 500 + 1000), str(Equipamentos.preco_venda("arco_longo", "lendario", 4)))
	var comum := Equipamentos.preco_venda("espada_gemea", "comum", 1)
	_verificar("venda: sobe com a raridade e com o nivel", Equipamentos.preco_venda("espada_gemea", "lendario", 1) > Equipamentos.preco_venda("espada_gemea", "raro", 1) \
			and Equipamentos.preco_venda("espada_gemea", "raro", 1) > comum and Equipamentos.preco_venda("espada_gemea", "comum", 3) > comum, "")
	_verificar("venda: espada gemea comum nv1 = 30% de 400", comum == 120, str(comum))
	_verificar("venda: o kit inicial tambem tem preco", Equipamentos.preco_venda("espada_basica", "comum", 1) == 45 and Equipamentos.preco_venda("escudo_basico", "comum", 1) == 90, "")

# --- Jogador ---------------------------------------------------------------------------------------------------------

func _testar_jogador() -> void:
	_inv.limpar()
	_kit_sem_maos()
	await _quadros(3)
	var base := _foto()

	# duas espadas do mesmo tipo
	var comum = _inv.buscar_por_tipo("espada_basica")
	var rara = _novo("espada_basica", "arma", "raro", 1, {"critico": 0.04, "vitalidade": 2.0, "velocidade": 4.0})
	_inv.adicionar(rara)
	_verificar("duas espadas do mesmo tipo convivem na mochila", _inv.mochila.has(comum) and _inv.mochila.has(rara), "")

	_inv.equipar(comum)
	await _quadros(3)
	var com_comum := _foto()
	_verificar("espada comum: dano 8 e nenhum afixo", com_comum["dano"] == 8 and com_comum["crit"] == 0.0 and com_comum["vit"] == base["vit"], str(com_comum))
	_inv.equipar(rara)
	await _quadros(3)
	var com_rara := _foto()
	_verificar("trocar pela espada rara (mesmo tipo) reaplica: dano x1,18", com_rara["dano"] == Raridades.escalar(8, "raro"), str(com_rara["dano"]))
	_verificar("afixos da rara entram: critico, vitalidade e velocidade", is_equal_approx(com_rara["crit"], 0.04) and com_rara["vit"] == base["vit"] + 2 and is_equal_approx(com_rara["vel"], base["vel"] + 4.0), str(com_rara))
	_verificar("o corpo continua com a espada em maos e a instancia certa equipada", _jogador.usando_espada and _inv.equipados["arma"] == rara, "")
	_verificar("o critico total do jogador sobe", is_equal_approx(_jogador.estatisticas.chance_critico, minf(0.05 + _jogador.estatisticas.sorte * 0.01 + 0.04, 0.6)), str(_jogador.estatisticas.chance_critico))
	_inv.equipar(comum)
	await _quadros(3)
	_verificar("voltar a comum devolve exatamente os numeros anteriores (sem sobra de afixos)", _igual(_foto(), com_comum), "%s x %s" % [str(_foto()), str(com_comum)])
	_inv.equipar(rara)
	await _quadros(3)
	_inv.desequipar("arma")
	await _quadros(3)
	_verificar("desequipar a arma deixa tudo como no inicio", _igual(_foto(), {"defesa": base["defesa"], "vit": base["vit"], "crit": 0.0, "dcrit": 0.0, "roubo": base["roubo"], "vel": base["vel"], "dano": 0}), "%s x %s" % [str(_foto()), str(base)])

	# escudo
	var escudo_comum = _inv.buscar_por_tipo("escudo_basico")
	var escudo_epico = _novo("escudo_basico", "escudo", "epico", 1, {"defesa": 3.0, "vitalidade": 1.0})
	_inv.adicionar(escudo_epico)
	_inv.equipar(escudo_comum)
	await _quadros(3)
	var escudo_c := _foto()
	_verificar("escudo comum nv1: defesa 4 e vitalidade 2", escudo_c["defesa"] == base["defesa"] + 4 and escudo_c["vit"] == base["vit"] + 2, str(escudo_c))
	_inv.equipar(escudo_epico)
	await _quadros(3)
	var escudo_e := _foto()
	var def_esperada: int = Raridades.escalar(4, "epico") + 3
	var vit_esperada: int = Raridades.escalar(2, "epico") + 1
	_verificar("escudo epico: defesa e vitalidade do nivel x1,32 + afixos", escudo_e["defesa"] == base["defesa"] + def_esperada and escudo_e["vit"] == base["vit"] + vit_esperada, "%s esperado def %d vit %d" % [str(escudo_e), def_esperada, vit_esperada])
	_inv.equipar(escudo_comum)
	await _quadros(3)
	_verificar("voltar ao escudo comum nao deixa bonus do epico", _igual(_foto(), escudo_c), str(_foto()))

	# forja por instância: o epico sobe de nivel, o comum nao
	_inv.equipar(escudo_epico)
	await _quadros(3)
	_jogador._on_forja_finalizada(escudo_epico)
	await _quadros(3)
	_verificar("forja sobe o nivel so da instancia que foi para a bigorna", escudo_epico.nivel == 2 and escudo_comum.nivel == 1, "%d %d" % [escudo_epico.nivel, escudo_comum.nivel])
	var def_nv2: int = Raridades.escalar(8, "epico") + 3
	var vit_nv2: int = Raridades.escalar(4, "epico") + 1
	_verificar("o pacote do escudo em uso acompanha o nivel novo", _jogador.bonus_defesa == base["defesa"] + def_nv2 and _jogador.bonus_vitalidade == base["vit"] + vit_nv2, "def %d (esperado %d) vit %d (esperado %d)" % [_jogador.bonus_defesa, base["defesa"] + def_nv2, _jogador.bonus_vitalidade, base["vit"] + vit_nv2])
	_inv.desequipar("escudo")
	await _quadros(3)
	_verificar("tirar o escudo forjado zera tudo de novo", _jogador.bonus_defesa == base["defesa"] and _jogador.bonus_vitalidade == base["vit"], "%d %d" % [_jogador.bonus_defesa, _jogador.bonus_vitalidade])

	# espada com afixo de roubo de vida, lanca e escudo juntos
	var espada_lend = _novo("espada_basica", "arma", "lendario", 2, {"roubo_vida": 2.0, "dano_critico": 0.15})
	_inv.adicionar(espada_lend)
	_inv.equipar(espada_lend)
	_inv.equipar(escudo_epico)
	await _quadros(3)
	_verificar("arma + escudo: os dois pacotes somam (dano nv2 x1,5 e roubo de vida)", _jogador.estatisticas.dano_arma == Raridades.escalar(12, "lendario") and _jogador.estatisticas.roubo_vida == base["roubo"] + 2, str(_foto()))
	var lanca = _inv.buscar_por_tipo("lanca_basica")
	_inv.equipar(lanca)
	await _quadros(3)
	_verificar("lanca (duas maos) tira o escudo e os pacotes dos dois", _inv.equipados["escudo"] == null and _jogador.bonus_defesa == base["defesa"] and _jogador.estatisticas.roubo_vida == base["roubo"] and _jogador.estatisticas.bonus_dano_critico == 0.0, str(_foto()))
	_inv.desequipar("arma")
	await _quadros(3)

# --- Hotbar ----------------------------------------------------------------------------------------------------------

func _testar_hotbar() -> void:
	_inv.limpar()
	_kit_sem_maos()
	await _quadros(2)
	# O nó do HUD se chama "assets/ui" (com barra no nome): get_node com esse caminho não o acha
	var barra: Control = get_nodes_in_group("hud")[0].barra_armas
	# a barra e a primeira linha da mochila: a lenda (casa 4) e a rara (casa 5) entram nas casas livres, como a espada comum (casa 1)
	var rara = _novo("espada_basica", "arma", "raro")
	var lend = _novo("espada_basica", "arma", "lendario")
	_inv.adicionar(rara)
	_inv.adicionar(lend)
	await _quadros(2)
	_verificar("hotbar: duas espadas do mesmo tipo em raridades diferentes ficam em casas diferentes da primeira linha", _inv.item_na_celula(3) == rara and _inv.item_na_celula(4) == lend, "")
	var bordas_ok := true
	for i in barra._casas.size():
		var item = _inv.item_na_celula(i)
		if item == null:
			continue
		var estilo: StyleBoxTexture = barra._casas[i].get_node("Conteudo/Slot/ItemUi/Panel").get_theme_stylebox("panel")
		var esperada: Color = Color.WHITE if item.raridade == "comum" else Raridades.cor(item.raridade).lightened(0.25)
		bordas_ok = bordas_ok and estilo.modulate_color == esperada and estilo.texture != null
	_verificar("hotbar: o sprite de slot de cada casa e tingido na cor da raridade do item", bordas_ok, "")
	_verificar("hotbar: lendario e laranja e a selecao e branca (nao se confundem)", barra.COR_ATIVA == Color(1, 1, 1, 1) and Raridades.cor("lendario") != barra.COR_ATIVA, "")
	barra.escolher(4)
	await _quadros(3)
	_verificar("hotbar: escolher a casa 5 equipa o lendario e ele continua na casa", _inv.equipados["arma"] == lend and _inv.item_na_celula(4) == lend and barra._casas[4].get_node("Conteudo/Marco").visible, "")
	barra.escolher(3)
	await _quadros(3)
	_verificar("hotbar: trocar para a rara (mesmo tipo) muda o dano", _inv.equipados["arma"] == rara and _jogador.estatisticas.dano_arma == Raridades.escalar(8, "raro"), str(_jogador.estatisticas.dano_arma))
	_verificar("hotbar: a lendaria voltou para a casa 5 (a que ocupava na mao)", _inv.mochila[4] == lend and _inv.item_na_celula(3) == rara, "")
	_inv.desequipar("arma")
	await _quadros(2)

# --- Drop, mochila cheia e venda -------------------------------------------------------------------------------------

func _testar_drop() -> void:
	_inv.limpar()
	_kit_sem_maos()
	await _quadros(2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var moedas0: int = root.get_node("DadosJogo").moedas

	# pegar: o drop nasce em cima do jogador e entra na mochila
	var item = _novo("machado", "arma", "epico", 2, {"critico": 0.03, "vitalidade": 1.0})
	var antes: int = _contar_mochila()
	var drop: Node2D = EquipamentoDrop.soltar_item(item, _jogador.global_position + Vector2(0, 11), _cena, rng)
	await _ms(1500)
	_verificar("drop: o equipamento e puxado e entra na mochila", _inv.mochila.has(item) and _contar_mochila() == antes + 1, "")
	_verificar("drop: o no sumiu do chao", not is_instance_valid(drop), "")

	# mochila cheia: nao pega, avisa, e o item fica no chao
	while _inv.tem_espaco():
		_inv.adicionar(_novo("maca", "arma", "comum"))
	var saque := root.get_node("Saque")
	saque.filtro = 0
	var para_sacola = _novo("machado", "arma", "raro")
	EquipamentoDrop.soltar_item(para_sacola, _jogador.global_position + Vector2(0, 11), _cena, rng)
	await _ms(1500)
	_verificar("mochila cheia encaminha o drop para o saque temporário", saque.contem(para_sacola) and not _inv.mochila.has(para_sacola), "")
	while saque.tem_espaco():
		saque.adicionar(_novo("maca", "arma", "comum"))
	var sobra = _novo("arco_curvo", "arma", "lendario", 3, {"critico": 0.04})
	var drop2: Node2D = EquipamentoDrop.soltar_item(sobra, _jogador.global_position + Vector2(0, 11), _cena, rng)
	await _ms(1500)
	_verificar("mochila cheia: o item nao e pego", is_instance_valid(drop2) and not _inv.mochila.has(sobra), "")
	# fim da onda: o que sobrou e vendido na hora
	var moedas1: int = root.get_node("DadosJogo").moedas
	get_nodes_in_group("equipamento_drop").map(func(d): d.atrair())
	await _quadros(3)
	var valor: int = saque.preco(sobra)
	_verificar("mochila cheia no fim da onda: o drop vira ouro", root.get_node("DadosJogo").moedas == moedas1 + valor and valor > 0, "%d + %d" % [moedas1, valor])
	_verificar("o drop vendido some do chao", get_nodes_in_group("equipamento_drop").is_empty(), str(get_nodes_in_group("equipamento_drop").size()))

	# venda no mercador
	var mercante: Control = _cena.get_node_or_null("assets/ui/TelaMercante")
	if mercante == null:
		mercante = get_first_node_in_group("tela_mercante")
	_verificar("a tela do mercador tem a aba de venda", mercante != null and mercante.get("_slot_venda") != null, "")
	if mercante == null:
		return
	var casa_ui: Control = load("res://cenas/ui/componentes/item_ui.tscn").instantiate()
	root.add_child(casa_ui)
	var para_vender = _inv.buscar_por_tipo("maca")
	casa_ui.exibir(para_vender)
	_verificar("o slot de venda aceita item da mochila", mercante._slot_venda.aceita_item(casa_ui), "")
	var equipado = _novo("espada_gemea", "arma", "raro")
	_inv.mochila[1] = null
	_inv.adicionar(equipado)
	_inv.equipar(equipado)
	await _quadros(2)
	var casa_equipada: Control = load("res://cenas/ui/componentes/item_ui.tscn").instantiate()
	root.add_child(casa_equipada)
	casa_equipada.exibir(equipado)
	_verificar("o slot de venda recusa o que esta equipado", not mercante._slot_venda.aceita_item(casa_equipada), "")
	_inv.desequipar("arma")
	mercante._slot_venda.colocar_item(casa_ui)
	await _quadros(2)
	var onda_vencida: int = root.get_node("Progresso").maior_onda_vencida
	var esperado: int = roundi(saque.preco_na_partida(para_vender.raridade, maxi(onda_vencida, 1)) * 1.5)
	_verificar("venda: o valor mostrado e o preco de venda", mercante._valor_venda.text == "VALE %d MOEDAS" % esperado and not mercante._botao_vender.disabled, mercante._valor_venda.text)
	var moedas2: int = root.get_node("DadosJogo").moedas
	mercante._ao_vender_pressionado()
	await _quadros(2)
	_verificar("venda: o item sai da mochila e o ouro entra", not _inv.mochila.has(para_vender) and root.get_node("DadosJogo").moedas == moedas2 + esperado, "")
	_verificar("venda: o slot esvazia e o botao desliga", mercante._slot_venda.item_atual == null and mercante._botao_vender.disabled, "")
	casa_ui.queue_free()
	casa_equipada.queue_free()
	root.get_node("DadosJogo").moedas = moedas0

func _contar_mochila() -> int:
	var n := 0
	for item in _inv.mochila:
		if item != null:
			n += 1
	return n

func _rodar() -> void:
	await process_frame
	EquipamentoDrop = load("res://codigo/logica/equipamento_drop.gd")
	root.get_node("Progresso").caminho_save = "user://teste_raridade_progresso.json"
	root.get_node("Fazenda").caminho_save = "user://teste_raridade_fazenda.json"
	root.get_node("Progresso").apagar()
	root.get_node("Fazenda").apagar()
	_inv = root.get_node("InventarioJogador")
	_testar_dados()
	_inv.limpar()
	_kit_sem_maos()
	_cena = load("res://cenas/cenario.tscn").instantiate()
	root.add_child(_cena)
	current_scene = _cena
	await _quadros(10)
	await _ms(200)
	_jogador = _cena.get_node("Jogador")
	_cena.get_node("enemySpawner/GerenciadorOndas").parar_ondas()
	await _testar_jogador()
	await _testar_hotbar()
	await _testar_drop()
	print("--- teste_raridade: ", "TUDO OK" if _falhas == 0 else "%d FALHAS" % _falhas)
	print("FALHAS: ", _falhas)
	quit(_falhas)
