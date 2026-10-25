extends RefCounted

## Habilidade individual, independente do refinamento da vara. XP só entra com peixe na mochila.
const MAXIMO := 99
const Peixes := preload("res://codigo/pesca/peixes.gd")
const Varas := preload("res://codigo/pesca/varas.gd")

static func custo_nivel(nv: int) -> int:
	return 80 + 20 * (nv - 1) + nv * nv

static func xp_para_nivel(nv: int) -> int:
	var total := 0
	for anterior in range(1, clampi(nv, 1, MAXIMO)):
		total += custo_nivel(anterior)
	return total

static func nivel_da_xp(total: int) -> int:
	var nv := 1
	var restante := maxi(0, total)
	while nv < MAXIMO and restante >= custo_nivel(nv):
		restante -= custo_nivel(nv)
		nv += 1
	return nv

static func _estado() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("Fazenda")

static func xp(quem: Node = null) -> int:
	return clampi(int(_estado().pesca_xp.get(Varas.chave(quem), 0)), 0, xp_para_nivel(MAXIMO))

static func nivel(quem: Node = null) -> int:
	return nivel_da_xp(xp(quem))

static func experiencia_peixe(id: String, perfeita := false, qualidade := 0) -> int:
	if not Peixes.existe(id): return 0
	var base := 20 + int(Peixes.DADOS[id]["dificuldade"]) + Peixes.nivel_pesca(id) * 2
	base += int({"comum": 0, "incomum": 20, "raro": 50, "epico": 90}.get(Peixes.raridade(id), 0))
	return roundi(base * (1.5 if perfeita else 1.0) * (1.0 + 0.1 * clampi(qualidade, 0, 3)))

static func receber(id: String, perfeita: bool, quem: Node, qualidade: int) -> void:
	_estado().pesca_xp[Varas.chave(quem)] = mini(xp_para_nivel(MAXIMO), xp(quem) + experiencia_peixe(id, perfeita, qualidade))

static func proximos(nv: int) -> Array[String]:
	var resultado: Array[String] = []
	var proximo := MAXIMO + 1
	for id in Peixes.DADOS:
		var requerido := Peixes.nivel_pesca(id)
		if requerido <= nv or requerido > proximo: continue
		if requerido < proximo:
			resultado.clear()
			proximo = requerido
		resultado.append(id)
	return resultado

static func resumo(quem: Node = null) -> String:
	var nv := nivel(quem)
	if nv == MAXIMO: return "PESCA NV 99 / 99 | MESTRE DAS AGUAS"
	return "PESCA NV %d / 99 | XP %d / %d" % [nv, xp(quem) - xp_para_nivel(nv), custo_nivel(nv)]

## Containers medem texto e quebram nomes longos, inclusive na metade da tela cooperativa.
static func painel(quem: Node = null) -> VBoxContainer:
	var coluna := VBoxContainer.new()
	coluna.name = "ProgressaoPesca"
	coluna.add_theme_constant_override("separation", 6)
	var titulo := Label.new()
	titulo.text = resumo(quem)
	titulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titulo.add_theme_color_override("font_color", Color("f6d879"))
	coluna.add_child(titulo)
	var barra := ProgressBar.new()
	barra.name = "BarraXP"
	barra.custom_minimum_size.y = 8
	barra.show_percentage = false
	var trilho := StyleBoxFlat.new()
	trilho.bg_color = Color("211c22")
	trilho.border_color = Color("805b3b")
	trilho.set_border_width_all(1)
	trilho.set_corner_radius_all(2)
	var preenchimento := StyleBoxFlat.new()
	preenchimento.bg_color = Color("5ab6ad")
	preenchimento.set_corner_radius_all(2)
	barra.add_theme_stylebox_override("background", trilho)
	barra.add_theme_stylebox_override("fill", preenchimento)
	var nv := nivel(quem)
	barra.max_value = custo_nivel(nv) if nv < MAXIMO else 1
	barra.value = xp(quem) - xp_para_nivel(nv) if nv < MAXIMO else 1
	coluna.add_child(barra)
	var dica := Label.new()
	dica.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var desbloqueios := proximos(nv)
	var nomes: PackedStringArray = []
	for id in desbloqueios: nomes.append(Peixes.nome(id))
	dica.text = "TODAS AS ESPECIES LIBERADAS" if desbloqueios.is_empty() else "NO NV %d: %s" % [Peixes.nivel_pesca(desbloqueios[0]), ", ".join(nomes)]
	dica.text += "\nCAPTURA PERFEITA: +50% XP"
	coluna.add_child(dica)
	return coluna
