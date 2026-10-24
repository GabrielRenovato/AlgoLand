extends Node2D

## Fauna da floresta (cenas/terreno_floresta.tscn, gerada por ferramentas/floresta/gerar_floresta.py): cria os bichos de
## animal_selvagem.gd e guarda o que eles precisam saber: onde ficam as árvores de abrigo (os troncos do Objetos3D que
## ainda estão de pé), as clareiras onde reaparecem e o que é lago.
const Animal := preload("res://codigo/floresta/animal_selvagem.gd")

## [espécie, variante, x, y]
@export var populacao: Array = []
## Clareiras livres onde os bichos voltam depois de fugir
@export var refugios: PackedVector2Array = PackedVector2Array()
## Limites do terreno, para o passeio não sair do mapa
@export var limites := Rect2(0, 0, 1408, 864)

var animais: Array[Node] = []
var _arvores: Array[Sprite2D] = []
var _lago: Node

func _ready() -> void:
	var terreno := get_parent()
	_lago = terreno.get_node_or_null("Lago")
	for no in terreno.get_node("Objetos3D").get_children():
		if no is Sprite2D and (String(no.name).begins_with("Abeto") or String(no.name).begins_with("Carvalho")):
			_arvores.append(no)
	for item: Array in populacao:
		var bicho := Animal.new()
		bicho.name = "%s%d" % [String(item[0]).capitalize(), animais.size() + 1]
		bicho.gerente = self
		bicho.configurar(String(item[0]), int(item[1]), Vector2(float(item[2]), float(item[3])))
		add_child(bicho)
		animais.append(bicho)
	var estacoes := terreno.get_node_or_null("Estacoes")
	if estacoes != null:
		estacoes.estacao_mudou.connect(_trocar_estacao)
		if estacoes.estacao_atual >= 0:
			_trocar_estacao(estacoes.estacao_atual)

func _trocar_estacao(indice: int) -> void:
	for bicho in animais:
		bicho.definir_estacao(indice)

## Bases (pés) das árvores de pé a menos de `raio` do ponto: as cortadas (invisíveis ou removidas) não servem de abrigo
func abrigos_perto(ponto: Vector2, raio: float) -> PackedVector2Array:
	var achadas := PackedVector2Array()
	var quadrado := raio * raio
	for arvore in _arvores:
		if not is_instance_valid(arvore) or not arvore.is_visible_in_tree():
			continue
		var base := arvore.global_position
		if base.distance_squared_to(ponto) <= quadrado:
			achadas.append(base)
	return achadas

## O passeio fica dentro do mapa e fora do lago
func ponto_livre(ponto_global: Vector2) -> bool:
	var local := to_local(ponto_global)
	if not limites.grow(-48.0).has_point(local):
		return false
	if _lago != null and _lago.contem(ponto_global):
		return false
	return true

## Clareira longe de todo jogador (para o bicho voltar sem aparecer do nada na frente de alguém)
func refugio_longe_dos_jogadores(bicho: Node2D) -> Vector2:
	var jogadores: Array[Node2D] = []
	for no in get_tree().get_nodes_in_group("jogadores"):
		if no is Node2D and no.get_world_2d() == get_world_2d():
			jogadores.append(no)
	var candidatos: Array[Vector2] = []
	var mais_longe := Vector2.ZERO
	var maior := -1.0
	for ponto in refugios:
		var menor := INF
		for jogador in jogadores:
			menor = minf(menor, jogador.global_position.distance_to(to_global(ponto)))
		if menor >= 330.0:
			candidatos.append(ponto)
		if menor > maior:
			maior = menor
			mais_longe = ponto
	var escolhido := candidatos[randi() % candidatos.size()] if not candidatos.is_empty() else mais_longe
	return to_global(escolhido) + Vector2(randf_range(-10.0, 10.0), randf_range(-10.0, 10.0))
