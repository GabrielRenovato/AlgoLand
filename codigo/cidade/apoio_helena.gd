extends Node

## Helena só se desloca com Clara nos apoios da cadeira. A dupla usa uma
## animação conjunta, evitando mãos soltas ou dois corpos sobrepostos.
const Trajeto := preload("res://codigo/cidade/trajeto_morador.gd")
const Dados := preload("res://codigo/cidade/dados_cidade.gd")
const FOLHA := "res://assets/npcs/cidade/clara_empurrando_helena.png"
const ATRAS := [Vector2(0,-8),Vector2(-20,0),Vector2(0,2),Vector2(18,0)]
var helena: Node2D
var clara: Node2D
var estado := "livre"
var _recalcular := 0.0
var _posicao_sprite := Vector2.ZERO
var _dupla: Texture2D

func _ready() -> void:
	name = "ApoioHelena"
	helena = get_parent().moradores.helena
	clara = get_parent().moradores.clara
	_posicao_sprite = helena.sprite.position
	_dupla = load(FOLHA)

func antes_de_mover(npc: Node2D, delta: float) -> bool:
	if npc == clara:
		if estado == "empurrando":
			_posicionar_filha()
			return true
		return false
	if npc != helena: return false
	if not helena.visible:
		if estado == "empurrando": _separar(true)
		return false
	var precisa_mover := false
	for ponto: Vector2 in helena.caminho:
		if ponto.distance_to(helena.position)>1:
			precisa_mover = true
			break
	if estado == "empurrando":
		if not precisa_mover and not helena._saindo:
			_separar(false)
		elif Cidade.em_conversa("clara"):
			depois_de_mover(false)
			return true
		return false
	if not precisa_mover:
		if estado == "aproximando":
			estado = "livre"
			helena.remove_collision_exception_with(clara)
			clara.remove_collision_exception_with(helena)
			clara._ir_ate(clara.agenda.ponto)
		return false
	# A cadeira espera: sem filha presente nunca há deslocamento autônomo.
	if not clara.visible: return true
	if Cidade.em_conversa("clara") or Cidade.em_conversa("helena"): return true
	if estado != "aproximando":
		estado = "aproximando"
		helena.add_collision_exception_with(clara)
		clara.add_collision_exception_with(helena)
		_recalcular = 0
	clara._saindo = false
	if clara.position.distance_to(helena.position) <= 24:
		estado = "empurrando"
		clara.caminho.clear()
		clara.calar()
		_posicionar_filha()
		return false
	_recalcular -= delta
	if _recalcular<=0:
		clara._ir_ate(helena.position + ATRAS[helena._linha])
		_recalcular = 0.5
	return true

func depois_de_mover(andando: bool) -> void:
	if estado != "empurrando": return
	if not helena.visible:
		_separar(true)
		return
	helena.sprite.texture = _dupla
	helena.sprite.hframes = 7
	helena.sprite.vframes = 4
	# Quadro 96x96; eixo da cadeira em (48,64), pés no mesmo chão do ator.
	helena.sprite.position = Vector2(0,-7)
	helena.sprite.frame = helena._linha*7 + (1+int(helena._tempo*8)%6 if andando else 0)
	_posicionar_filha()

func _posicionar_filha() -> void:
	clara.position = helena.position+ATRAS[helena._linha]
	clara.sprite.visible = false
	clara.get_node("SombraChao").visible = false
	clara.collision_layer = 0
	clara.collision_mask = 0

func _separar(saindo: bool) -> void:
	estado = "livre"
	helena.sprite.texture = load(Dados.caminho_sprite("helena"))
	helena.sprite.hframes = 7
	helena.sprite.vframes = 4
	helena.sprite.position = _posicao_sprite
	helena.sprite.frame = helena._linha*7
	clara.sprite.visible = true
	clara.get_node("SombraChao").visible = true
	clara.collision_mask = 64 | 2
	helena.remove_collision_exception_with(clara)
	clara.remove_collision_exception_with(helena)
	clara._saindo = false
	if saindo:
		Trajeto.concluir(clara)
		clara.visible = false
		clara.caminho.clear()
	else:
		clara._ir_ate(clara.agenda.ponto)
	clara._atualizar_colisao()
