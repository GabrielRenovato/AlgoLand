extends SceneTree

const Padrao := preload("res://Codigos/DadosLocais/padrao_armadura.gd")
const Base := preload("res://Codigos/DadosLocais/base_conjunto_armadura.gd")
const Carrasco := preload("res://Codigos/DadosLocais/conjunto_carrasco.gd")
const Aparencia := preload("res://Codigos/DadosLocais/aparencia.gd")
const Dados := preload("res://Codigos/Modelos/dados_item.gd")
var _falhas := 0

func _initialize() -> void:
	_rodar()

func _verificar(nome: String, condicao: bool) -> void:
	print("OK " if condicao else "FALHA ", nome)
	if not condicao:
		_falhas += 1

func _rodar() -> void:
	await process_frame
	var config := Padrao.carregar("res://ferramentas/armaduras/modelos/carrasco.json")
	_verificar("manifesto real segue o contrato", Padrao.validar(config).is_empty())
	var invalido := config.duplicate(true)
	invalido["bonus"]["recarga"] = "ontem"
	_verificar("recarga com tipo inválido é recusada", not Padrao.validar(invalido).is_empty())
	invalido = config.duplicate(true)
	invalido["destino"] = "res://CharacterSprites/../fora/"
	_verificar("destino fora da pasta é recusado", not Padrao.validar(invalido).is_empty())
	invalido = config.duplicate(true)
	invalido["bases"]["cabeca"]["defesa"] = [1, 2]
	_verificar("falta de níveis é recusada", not Padrao.validar(invalido).is_empty())
	invalido = config.duplicate(true)
	invalido["chances_drop"]["normal"] = 1.2
	_verificar("chance acima de 100% é recusada", not Padrao.validar(invalido).is_empty())
	_verificar("nome é convertido para a fonte pixel", Padrao.nome_pixel("Guardião") == "GUARDIAO")
	_verificar("cadastro do Carrasco lê os dados gerados", Carrasco.ID == config["id"] and Carrasco.RARIDADE == config["raridade"] and Carrasco.RAIZ_SPRITES == config["destino"] and Carrasco.PRECO_BASE == int(config["preco_base"]))
	_verificar("bônus e drop não mudaram", Carrasco.CHANCE_RAIO == float(config["bonus"]["chance"]) and Carrasco.chance_drop(13, false, true) == 0.0 and Carrasco.chance_drop(14, false, true) == 0.2)
	var equipados := {}
	for tipo in Carrasco.TIPOS:
		var item := Dados.new()
		item.tipo = tipo
		item.categoria = Carrasco.TIPOS[tipo]["slot"]
		equipados[item.categoria] = item
		for nivel in range(1, 6):
			var dados := Carrasco.dados(tipo, nivel)
			var base: Dictionary = config["bases"][item.categoria]
			_verificar(tipo + ": status do manifesto no nível " + str(nivel), dados["bonus_defesa"] == int(base["defesa"][nivel - 1]) and dados["bonus_vitalidade"] == int(base["vitalidade"][nivel - 1]))
	_verificar("base ativa quatro peças do mesmo set", Base.pode_ativar(Carrasco.TIPOS, equipados, 0.0, 0.0, 0.1))
	equipados["botas"].tipo = "botas_guardiao"
	_verificar("mistura de sets não libera bônus completo", not Base.pode_ativar(Carrasco.TIPOS, equipados, 0.0, 0.0, 0.1))
	var raiz: String = config["destino"]
	var completo := Aparencia.compor_armadura("andar", 15, 34, raiz).get_image()
	var mistura := Aparencia.compor_pecas_armadura("andar", 34, {
		"elmo": raiz, "peitoral": raiz + "./", "luvas": raiz, "botas": raiz + "./",
	}).get_image()
	var igual := true
	for y in completo.get_height():
		for x in completo.get_width():
			var a := completo.get_pixel(x, y)
			var b := mistura.get_pixel(x, y)
			# A importação preenche RGB de texels transparentes; esse RGB não é desenhado.
			if a.a != b.a or (a.a > 0.0 and a != b):
				igual = false
	_verificar("compositor por peça preserva o set e remove a capa de baixo", igual)
	_verificar("sem peças mantém a roupa escolhida", Aparencia.compor_pecas_armadura("andar", 34, {}).get_image().get_data() == Aparencia.roupa(34, "andar").get_image().get_data())
	print("Falhas: ", _falhas)
	quit(_falhas)
