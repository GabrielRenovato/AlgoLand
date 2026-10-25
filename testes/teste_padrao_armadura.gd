extends SceneTree

const Padrao := preload("res://codigo/dados/padrao_armadura.gd")
const Base := preload("res://codigo/dados/base_conjunto_armadura.gd")
const Carrasco := preload("res://codigo/dados/conjunto_carrasco.gd")
const Aparencia := preload("res://codigo/dados/aparencia.gd")
const Dados := preload("res://codigo/modelos/dados_item.gd")
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
	invalido["destino"] = "res://assets/personagens/../fora/"
	_verificar("destino fora da pasta é recusado", not Padrao.validar(invalido).is_empty())
	invalido = config.duplicate(true)
	invalido["bases"]["cabeca"]["defesa"] = [1, 2]
	_verificar("falta de níveis é recusada", not Padrao.validar(invalido).is_empty())
	invalido = config.duplicate(true)
	invalido["chances_drop"]["normal"] = 1.2
	_verificar("chance acima de 100% é recusada", not Padrao.validar(invalido).is_empty())
	_verificar("nome é convertido para a fonte pixel", Padrao.nome_pixel("Guardião") == "GUARDIAO")
	_verificar("cadastro do Carrasco lê os dados gerados", Carrasco.ID == config["id"] and Carrasco.RARIDADE == config["raridade"] and Carrasco.RAIZ_SPRITES == config["destino"] and Carrasco.PRECO_BASE == int(config["preco_base"]))
	_verificar("bônus e drops seguem o manifesto", Carrasco.CHANCE_RAIO == float(config["bonus"]["chance"]) and Carrasco.chance_drop(0, false, true) == 0.0 and Carrasco.chance_drop(1, false, true) == 0.1 and Carrasco.chance_drop(1, false, false) == 0.05)
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
	_verificar("três peças dão metade do bônus", Base.fator_pecas(Carrasco.TIPOS, equipados) == 0.5 and Base.pode_ativar(Carrasco.TIPOS, equipados, 0.0, 0.0, 0.1) and not Base.pode_ativar(Carrasco.TIPOS, equipados, 0.0, 0.075, 0.1))
	var raiz: String = config["destino"]
	# Raven usa camadas independentes; o compositor antigo de roupa foi retirado.
	# As combinações e a roupa-base são conferidas no renderizador em teste_f3_equipar_conjuntos.
	for pagina in Padrao.CORPOS:
		var completa := Image.load_from_file(raiz+pagina+".png")
		var recomposta := Image.create(512,512,false,Image.FORMAT_RGBA8)
		for peca in Padrao.PECAS:
			var imagem := Image.load_from_file(raiz+peca+"/"+pagina+".png")
			recomposta.blend_rect(imagem,Rect2i(0,0,512,512),Vector2i.ZERO)
		_verificar("camadas Raven recompõem a página: "+pagina, completa.get_data() == recomposta.get_data())
	print("Falhas: ", _falhas)
	quit(_falhas)
