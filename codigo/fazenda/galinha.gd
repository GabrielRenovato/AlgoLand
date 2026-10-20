extends CharacterBody2D

const Criacao := preload("res://codigo/fazenda/criacao_galinhas.gd")
const CORES := ["white","brown_white","black"]
var indice := 0
var exterior := false
var portinha := Vector2.ZERO
var area := Rect2(32,56,128,48)
var sprite: Sprite2D
var _tempo := 0.0
var _carinho_ate := 0.0
var _coracao: Sprite2D
var _era_visivel := false
var _tipo_visual := ""

class Carinho extends "res://codigo/logica/interagivel.gd":
	func pode_interagir() -> bool: return get_parent().visible and super.pode_interagir()
	func abrir_tela() -> void: get_parent().acariciar(Cooperativo._jogador1())
	func abrir_tela_p2() -> void: get_parent().acariciar(Cooperativo.jogador2())

func _ready() -> void:
	visible = false
	name = "Galinha%d" % indice
	add_to_group("galinhas")
	collision_layer = 0
	collision_mask = 64
	var forma := CollisionShape2D.new()
	var circulo := CircleShape2D.new()
	circulo.radius = 3
	forma.shape = circulo
	add_child(forma)
	sprite = Sprite2D.new()
	_atualizar_ave()
	sprite.hframes = 4
	sprite.vframes = 7
	sprite.offset.y = -5
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var material_recorte := ShaderMaterial.new()
	material_recorte.shader = preload("res://codigo/fazenda/recorte_portinha.gdshader")
	sprite.material = material_recorte
	add_child(sprite)
	_coracao = Sprite2D.new()
	_coracao.texture = preload("res://assets/ui/craftpix-net-420010-pixel-game-user-interface-for-platformer/4 Bars/13.png")
	_coracao.position = Vector2(0,-22)
	_coracao.visible = false
	add_child(_coracao)
	var zona := Carinho.new()
	zona.name = "Carinho"
	zona.nome_tela = "galinha"
	zona.so_entre_ondas = false
	zona.deslocamento_aviso = Vector2(0,-26)
	var alcance := CollisionShape2D.new()
	var perto := CircleShape2D.new()
	perto.radius = 16
	alcance.shape = perto
	zona.add_child(alcance)
	add_child(zona)

func _physics_process(delta: float) -> void:
	_tempo += delta
	if indice >= Fazenda.bando.aves.size() or indice >= Fazenda.galinheiro.aves.size():
		visible = false
		return
	var ave: Dictionary = Fazenda.bando.aves[indice]
	var anterior := position
	var cruzando: bool = ave.estado in ["saindo","entrando"]
	_atualizar_ave()
	var alvo: Vector2
	if exterior:
		visible = ave.estado in ["fora","voltando"] or (cruzando and ave.passagem >= 0.5)
		alvo = portinha+Vector2(0,lerpf(-10,18,(ave.passagem-0.5)*2)) if cruzando else portinha+ave.ponto
	else:
		visible = ave.estado == "dentro" or (cruzando and ave.passagem < 0.5)
		alvo = portinha+Vector2(0,lerpf(-12,42,ave.passagem*2)) if cruzando else area.position+Vector2(ave.ponto.x,1-ave.ponto.y)*area.size
	if not _era_visivel and visible: position = alvo
	_era_visivel = visible
	if visible:
		if cruzando:
			position = alvo
		else:
			velocity = position.direction_to(alvo)*minf(60,position.distance_to(alvo)/maxf(delta,0.001))
			# Desvia das outras aves; não empurra jogador nem atravessa móveis.
			for outra in get_tree().get_nodes_in_group("galinhas"):
				if outra == self or not outra.visible or outra.get_parent() != get_parent(): continue
				var distancia: float = global_position.distance_to(outra.global_position)
				if distancia < 12:
					var afastar: Vector2 = outra.global_position.direction_to(global_position) if distancia > 0.01 else Vector2.from_angle(indice * 2.4)
					velocity += afastar * (12-distancia) * 2.5
			move_and_slide()
	sprite.material.set_shader_parameter("recortar",cruzando)
	sprite.material.set_shader_parameter("topo",get_parent().global_position.y+portinha.y-11 if exterior else -100000.0)
	sprite.material.set_shader_parameter("base",100000.0 if exterior else get_parent().global_position.y+portinha.y+28)
	get_node("Carinho").set_deferred("monitoring",visible)
	get_node("Carinho").set_deferred("monitorable",visible)
	velocity = (position-anterior)/maxf(delta,0.001) if visible else Vector2.ZERO
	z_as_relative = false
	if absf(velocity.x)>0.1: sprite.flip_h = velocity.x < 0
	sprite.frame = (4 if velocity.length()>1 else 8 if ave.get("atividade","") == "bicar" else 0) + int(_tempo/(0.14 if velocity.length()>1 else 0.3))%4
	z_index = preload("res://codigo/globais/profundidade.gd").z_de(global_position.y)
	if exterior: z_index = maxi(z_index,preload("res://codigo/globais/profundidade.gd").z_de(get_parent().global_position.y)+1)
	_coracao.visible = _carinho_ate > _tempo
	_coracao.position.y = -22-(_tempo-(_carinho_ate-1.5))*3 if _coracao.visible else -22
	queue_redraw()

func acariciar(quem: Node) -> void:
	if quem == null or not visible: return
	var erro := Criacao.executar(Fazenda,quem,"carinho",indice)
	get_tree().call_group(quem.grupo_hud(),"avisar_barra",erro if erro != "" else Fazenda.galinheiro.aves[indice].nome+" GOSTOU DO CARINHO!")
	if erro == "":
		_carinho_ate = _tempo+1.5
		Fazenda.bando.aves[indice].espera = 2
		Fazenda.bando.aves[indice].pausa_ate = 2
		Fazenda.bando.aves[indice].destino = Fazenda.bando.aves[indice].ponto

func _atualizar_ave() -> void:
	if sprite == null: return
	var dados: Dictionary = Fazenda.galinheiro.aves[indice]
	var filhote := not Criacao.adulta(dados,Calendario.dia)
	var caminho := "pintinho" if filhote else "galo" if dados.get("sexo","") == "galo" else "galinha_%s" % CORES[int(dados.cor)]
	if caminho == _tipo_visual: return
	_tipo_visual = caminho
	var textura: Texture2D = load("res://assets/cenario/fazenda/galinheiro/%s.png" % caminho)
	if sprite.texture != textura: sprite.texture = textura
