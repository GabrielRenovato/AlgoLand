extends SceneTree

# Valida as folhas do protótipo e a troca reversível pelo F3 sem abrir a partida.
var _falhas := 0
class JogadorTeste extends Node2D:
	var roupa_atual := 2
	var cabelo_atual := 1
	func definir_aparencia(cabelo: int, roupa: int) -> void:
		cabelo_atual = cabelo
		roupa_atual = roupa

func _initialize() -> void:
	_rodar()

func _verificar(nome: String, condicao: bool) -> void:
	print("OK " if condicao else "FALHA ", nome)
	if not condicao:
		_falhas += 1

func _rodar() -> void:
	await process_frame
	var aparencia = load("res://codigo/dados/aparencia.gd")
	var indice: int = -1
	for i in aparencia.total_roupas():
		if aparencia.roupas()[i]["id"] == "armadura_teste":
			indice = i
	_verificar("protótipo é acrescentado sem deslocar as roupas existentes", aparencia.roupas()[indice]["id"] == "armadura_teste" and aparencia.roupas()[2]["id"] == "pfpn_v05")
	for pagina in aparencia.PAGINAS_ANDAR + aparencia.PAGINAS_COMBATE:
		var original: Image = aparencia.roupa(2, pagina).get_image()
		var armadura: Image = aparencia.roupa(indice, pagina).get_image()
		_verificar(pagina + ": tamanho e grade das poses preservados", original.get_size() == armadura.get_size())
		var pixels_preservados := true
		for y in original.get_height():
			for x in original.get_width():
				if original.get_pixel(x, y).a > 0.5 and armadura.get_pixel(x, y).a < 0.5:
					pixels_preservados = false
		_verificar(pagina + ": armadura não apaga pixels da roupa e expõe o corpo", pixels_preservados)
	var andar: Image = aparencia.roupa(indice, "andar").get_image()
	var peito_fechado := true
	for y in range(27, 35):
		for x in range(28, 36):
			if andar.get_pixel(x, y).a < 0.5:
				peito_fechado = false
	_verificar("frente: tórax coberto inclusive nos vãos dos suspensórios", peito_fechado)
	var cabeca_livre := true
	var base: Image = aparencia.roupa(2, "andar").get_image()
	for linha in 4:
		for y in 26:
			for x in 64:
				if andar.get_pixel(x, linha * 64 + y).a > 0.5 and andar.get_pixel(x, linha * 64 + y) != base.get_pixel(x, linha * 64 + y):
					cabeca_livre = false
	_verificar("quatro vistas: peitoral não invade a cabeça", cabeca_livre)
	var cena := Node2D.new()
	root.add_child(cena)
	current_scene = cena
	var jogador := JogadorTeste.new()
	jogador.name = "Jogador"
	cena.add_child(jogador)
	var painel := root.get_node("PainelDebug")
	painel._ao_armadura_teste()
	_verificar("F3 veste peitoral e botas preservando o cabelo", jogador.roupa_atual == indice and jogador.cabelo_atual == 1)
	painel._ao_armadura_teste()
	_verificar("segundo clique restaura a roupa anterior", jogador.roupa_atual == 2 and jogador.cabelo_atual == 1)
	print("Falhas: ", _falhas)
	quit(_falhas)
