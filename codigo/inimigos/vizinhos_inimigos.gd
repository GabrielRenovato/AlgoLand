extends RefCounted
## Índice compartilhado por passo de física; evita copiar a lista do andar por mob.
const CELULA := 64.0
# Margem para corpos que já se moveram neste passo, inclusive recuos/investidas.
const MARGEM_MOVIMENTO := CELULA
static var _quadro := -1
static var _arvore: WeakRef
static var _mundos: Dictionary = {}

static func invalidar() -> void:
	_quadro=-1
	_mundos.clear()

static func proximos(inimigo: Node2D, alcance: float) -> Array[Node2D]:
	var arvore := inimigo.get_tree()
	var quadro := Engine.get_physics_frames()
	if quadro!=_quadro or _arvore==null or _arvore.get_ref()!=arvore:
		_mundos.clear()
		_quadro=quadro
		_arvore=weakref(arvore)
		for no in arvore.get_nodes_in_group("enemy"):
			if not is_instance_valid(no) or not no is Node2D:continue
			var mundo: int=no.get_world_2d().get_instance_id()
			var chave := Vector2i(floori(no.global_position.x/CELULA),floori(no.global_position.y/CELULA))
			if not _mundos.has(mundo):_mundos[mundo]={}
			if not _mundos[mundo].has(chave):_mundos[mundo][chave]=[]
			_mundos[mundo][chave].append(no)
	var mundo := inimigo.get_world_2d().get_instance_id()
	var resultado: Array[Node2D]=[]
	if not _mundos.has(mundo):return resultado
	var raio := alcance+MARGEM_MOVIMENTO
	var p := inimigo.global_position
	var minimo := Vector2i(floori((p.x-raio)/CELULA),floori((p.y-raio)/CELULA))
	var maximo := Vector2i(floori((p.x+raio)/CELULA),floori((p.y+raio)/CELULA))
	for y in range(minimo.y,maximo.y+1):
		for x in range(minimo.x,maximo.x+1):
			for no in _mundos[mundo].get(Vector2i(x,y),[]):
				if is_instance_valid(no) and no.is_inside_tree():resultado.append(no)
	return resultado
