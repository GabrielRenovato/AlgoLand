extends Node2D

## Marca mágica no chão: sem colisão, grade de 1px, elipse de 36x14 e centro nos pés.
## A cor segue as quatro estações; não substitui um prop físico por um ícone.
const Escolha := preload("res://codigo/ui/escolha_jornada.gd")
const CORES := [Color("a3df6b"), Color("ffd875"), Color("e78b3e"), Color("d3f4ff")]
var gerente: Node
var usado := false
var _tempo := 0.0
var _painel: Node
var _estacao := 0
var _zona: Area2D

class Zona extends "res://codigo/logica/interagivel.gd":
	func pode_interagir() -> bool:
		return get_parent().disponivel() and super.pode_interagir()
	func pode_interagir_para(quem: Node2D) -> bool:
		return get_parent().disponivel() and super.pode_interagir_para(quem)
	func abrir_tela() -> void:
		get_parent().abrir(Cooperativo._jogador1())
	func abrir_tela_p2() -> void:
		get_parent().abrir(Cooperativo.jogador2())

func _ready() -> void:
	name = "EcoDoLimiar"
	z_index = 1
	var luz := CanvasItemMaterial.new()
	luz.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = luz
	_zona = Zona.new()
	_zona.nome_tela = "eco_limiar"
	_zona.so_entre_ondas = false
	_zona.deslocamento_aviso = Vector2(0, -30)
	var forma := CollisionShape2D.new()
	var circulo := CircleShape2D.new()
	circulo.radius = 30
	forma.shape = circulo
	_zona.add_child(forma)
	add_child(_zona)
	var estacoes := gerente.get_parent().get_parent().get_node_or_null("Terrains/Estacoes")
	if estacoes != null:
		_estacao = estacoes.estacao_atual
		estacoes.estacao_mudou.connect(definir_estacao)
	var escolha: String = Progresso.encontros_andares.get(str(gerente.onda_atual), "")
	if escolha != "": aplicar(escolha, false)

func definir_estacao(indice: int) -> void:
	_estacao = clampi(indice, 0, 3)
	queue_redraw()

func disponivel() -> bool:
	return not usado and not is_instance_valid(_painel) and is_instance_valid(gerente) and gerente.etapa == gerente.Etapa.EXPLORANDO and not Transicao.ocupada

func _process(delta: float) -> void:
	_tempo += delta
	visible = not usado and gerente.etapa == gerente.Etapa.EXPLORANDO
	queue_redraw()

func _draw() -> void:
	var cor: Color = CORES[_estacao]
	cor.a = 0.65 + 0.2 * sin(_tempo * 2)
	for i in 24:
		var a := (Vector2.from_angle(i * TAU / 24) * Vector2(18, 7)).round()
		var b := (Vector2.from_angle((i+1) * TAU / 24) * Vector2(18, 7)).round()
		draw_line(a, b, cor, 1, false)
	for x in [-8, 0, 8]:
		draw_line(Vector2(x-2,-2), Vector2(x,1), cor, 1, false)
		draw_line(Vector2(x,1), Vector2(x+2,-2), cor, 1, false)

func abrir(quem: Node) -> void:
	if quem == null or not disponivel(): return
	var tipo: int = gerente.onda_atual % 3
	var titulos := ["PACTO DO LIMIAR", "ECO DE UM VIAJANTE", "CAMINHOS DA FENDA"]
	var textos := ["O eco oferece riqueza em troca de perigo. Vale apenas neste andar.", "Uma antiga reserva ainda guarda forca. Escolha como aproveita-la.", "Voce pode apressar a chegada do guardiao ou prolongar a cacada."]
	var opcoes: Array = [
		[{"id":"pacto", "nome":"PACTO: +15% DANO INIMIGO / +50% OURO"}],
		[{"id":"descanso", "nome":"DESCANSAR: RECUPERAR 30% DE VIDA"}, {"id":"fragmento", "nome":"INVESTIGAR: 1 FRAGMENTO DA ARENA"}],
		[{"id":"atalho", "nome":"ATALHO: -15% META / -20% OURO"}, {"id":"cacada", "nome":"CACADA: +10% META / +40% OURO"}]
	][tipo].duplicate(true)
	opcoes.append({"id":"ignorar", "nome":"SEGUIR SEM ACEITAR"})
	_painel = Escolha.new()
	_painel.abrir(quem, titulos[tipo], textos[tipo], opcoes)
	_painel.escolhida.connect(_ao_escolher)

func _ao_escolher(id: String) -> void:
	if id != "" and is_instance_valid(gerente) and gerente.etapa == gerente.Etapa.EXPLORANDO:
		aplicar(id, true)

func aplicar(id: String, premiar := true) -> void:
	if usado or not id in ["pacto", "descanso", "fragmento", "atalho", "cacada", "ignorar"]: return
	usado = true
	Progresso.encontros_andares[str(gerente.onda_atual)] = id
	var evento: Dictionary = gerente.evento_atual.duplicate(true)
	if id == "pacto":
		evento["dano"] = float(evento.get("dano",1.0)) * 1.15
		evento["ouro"] = float(evento.get("ouro",1.0)) * 1.50
		for inimigo in gerente.gerador._populacao:
			if is_instance_valid(inimigo): inimigo.dano *= 1.15
	elif id in ["atalho", "cacada"]:
		var fator := 0.85 if id == "atalho" else 1.10
		gerente.META_PROGRESSO = maxi(gerente.pontos + 1, ceili(gerente.META_PROGRESSO * fator))
		evento["ouro"] = float(evento.get("ouro",1.0)) * (0.80 if id == "atalho" else 1.40)
	elif premiar and id == "fragmento":
		preload("res://codigo/logica/drops_forja.gd").soltar_material("fragmento",1,global_position,get_parent())
	elif premiar and id == "descanso":
		for quem in get_tree().get_nodes_in_group("jogadores"):
			if quem.get_world_2d() == get_world_2d() and not quem.estaMorto: quem.curar(maxi(1,roundi(quem.estatisticas.hp_maximo*0.30)))
	if id in ["pacto", "atalho", "cacada"]:
		evento["nome"] = "PACTO" if id == "pacto" else ("ATALHO" if id == "atalho" else "CACADA")
		evento["resumo"] = "ESCOLHA DO GRUPO"
		evento["cor"] = Color("ffd875")
		gerente._definir_evento(evento)
	gerente.progresso_andar_alterado.emit()
	if premiar: Sons.tocar("melhoria", 0.0)
