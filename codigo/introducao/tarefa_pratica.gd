extends Node2D

## Lições aceitam ações reais em qualquer local permitido; o progresso atravessa recargas.
signal concluida
const Icones := preload("res://codigo/ui/icones_fazenda.gd")
const DADOS := {
	"cortar": {"texto": "CORTE UMA ARVORE", "ferramenta": "machadinha", "acao": "machado", "tipo": "arvore"},
	"quebrar": {"texto": "QUEBRE UMA PEDRA", "ferramenta": "picareta", "acao": "picareta", "tipo": "pedra"},
	"arar": {"texto": "ARE UM QUADRADO DE TERRA", "ferramenta": "enxada", "acao": "enxada"},
	"plantar": {"texto": "PLANTE UMA CENOURA", "ferramenta": "semente:cenoura", "acao": "plantar"},
	"regar": {"texto": "REGUE UM CANTEIRO PLANTADO", "ferramenta": "regador", "acao": "regar"},
	"colher": {"texto": "COLHA UMA CENOURA MADURA", "ferramenta": "", "acao": "colher"},
}
var cena: Node2D
var id := ""
var ativa := false
var ponto := Vector2.ZERO
var recurso: Dictionary = {}
var celula := Vector2i.ZERO

func _ready() -> void:
	Fazenda.acao_realizada.connect(_ao_solo)
	cena.get_node("Terrains/Extracao").recurso_extraido.connect(_ao_extrair)

func ferramenta() -> String:
	return str(DADOS[id].ferramenta) if DADOS.has(id) else ""

func icone() -> Texture2D:
	return Icones.item_colhido("cenoura") if id == "colher" else Icones.da_ferramenta(ferramenta())

func iniciar(qual: String) -> bool:
	id = qual
	ativa = false
	recurso = {}
	if Introducao.tarefas.has(id):
		return false
	var extracao: Node = cena.get_node("Terrains/Extracao")
	if id in ["cortar", "quebrar"]:
		var distancia := INF
		for candidato in extracao.recursos:
			if candidato.tipo == DADOS[id].tipo and not Fazenda.recurso_removido(candidato.chave):
				var d: float = candidato.pos.distance_to(cena.get_node("Jogador").position)
				if d < distancia:
					distancia = d
					recurso = candidato
		if recurso.is_empty():
			push_error("INTRODUCAO: RECURSO DE TREINO AUSENTE: " + id)
			return false
		Introducao.alvos_tarefas[id] = recurso.chave
		ponto = extracao.to_global(recurso.pos)
	else:
		var chave := "demonstracao" if id == "colher" else "horta"
		if not Introducao.alvos_tarefas.has(chave):
			celula = _escolher_celula()
			Introducao.alvos_tarefas[chave] = [celula.x, celula.y]
			if id == "colher":
				# Uma planta de exemplo, separada da semente recém-plantada pelo jogador.
				Fazenda.solo[celula] = {"molhado": true, "planta": "cenoura", "dias": 99, "murcha": false}
				Fazenda.solo_alterado.emit(celula)
				Fazenda.salvar()
		else:
			var coordenadas: Array = Introducao.alvos_tarefas[chave]
			celula = Vector2i(coordenadas[0], coordenadas[1])
		ponto = cena.get_node("Terrains/Plantio").to_global(Vector2(celula) * 16 + Vector2(8, 8))
	ativa = true
	Introducao.salvar()
	equipar()
	return true

func _escolher_celula() -> Vector2i:
	var plantio: Node = cena.get_node("Terrains/Plantio")
	var melhor := Vector2i(25, 23)
	var distancia := INF
	for y in range(22, 35):
		for x in range(7, 37):
			var candidata := Vector2i(x, y)
			if Fazenda.entulho.has(candidata) or Fazenda.esta_arado(candidata) or plantio.avaliar_terreno("enxada", candidata) != "":
				continue
			var d := candidata.distance_squared_to(Vector2i(25, 23))
			if d < distancia:
				distancia = d
				melhor = candidata
	return melhor

func equipar() -> void:
	var tipo := ferramenta()
	if tipo == "":
		return
	if tipo.begins_with("semente:") and InventarioJogador.quantidade_sementes("cenoura") == 0:
		# Gastar as sementes em outro quadrado não pode prender o tutorial.
		InventarioJogador.adicionar_sementes("cenoura", 1)
	Fazenda.definir_ferramenta(tipo)

func _ao_solo(acao: String, onde: Vector2i) -> void:
	if not ativa or id in ["cortar", "quebrar"] or acao != DADOS[id].acao:
		return
	if id == "plantar" and Fazenda.planta_em(onde) != "cenoura":
		return
	if id == "regar" and Fazenda.planta_em(onde) == "":
		return
	celula = onde
	if id in ["arar", "plantar"]:
		Introducao.alvos_tarefas.horta = [onde.x, onde.y]
	_confirmar()

func _ao_extrair(chave: String, _tipo: String) -> void:
	if not ativa:
		return
	if id == "cortar" and (_tipo == "arvoreta" or (_tipo == "arvore" and Fazenda.tem_toco(chave))):
		_confirmar()
	elif id == "quebrar" and _tipo == "pedra":
		_confirmar()

func _confirmar() -> void:
	ativa = false
	Introducao.tarefas[id] = true
	Fazenda.salvar()
	Introducao.salvar()
	concluida.emit()

