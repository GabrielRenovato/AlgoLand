extends Node2D

## Luz do selo restaurado sob a fonte nativa. Sem sprite, colisão ou mudança na navegação.
const Jornada := preload("res://codigo/cidade/jornada_limiar.gd")
const CORES := [Color("a3df6b"), Color("ffd875"), Color("e78b3e"), Color("d3f4ff")]
var _tempo := 0.0
var _estacao := 0
var _luz: PointLight2D

class Fonte extends "res://codigo/logica/interagivel.gd":
	func pode_interagir() -> bool:
		return Jornada.concluida(Cidade) and super.pode_interagir()
	func pode_interagir_para(quem: Node2D) -> bool:
		return Jornada.concluida(Cidade) and super.pode_interagir_para(quem)
	func abrir_tela() -> void:
		get_parent().recuperar(Cooperativo._jogador1())
	func abrir_tela_p2() -> void:
		get_parent().recuperar(Cooperativo.jogador2())

func _ready() -> void:
	z_index = 1
	var luz := CanvasItemMaterial.new()
	luz.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = luz
	_luz = PointLight2D.new()
	_luz.position = Vector2(0,-35)
	_luz.energy = 0.35
	var gradiente := Gradient.new()
	gradiente.set_color(0,Color(1,1,1,0.8))
	gradiente.set_color(1,Color(1,1,1,0))
	var textura := GradientTexture2D.new()
	textura.gradient = gradiente
	textura.width = 128
	textura.height = 128
	textura.fill = GradientTexture2D.FILL_RADIAL
	textura.fill_from = Vector2(0.5,0.5)
	textura.fill_to = Vector2(1,0.5)
	_luz.texture = textura
	add_child(_luz)
	var zona := Fonte.new()
	zona.name = "InteracaoFonte"
	zona.nome_tela = "fonte_limiar"
	zona.so_entre_ondas = false
	zona.deslocamento_aviso = Vector2(0,-105)
	var forma := CollisionShape2D.new()
	var circulo := CircleShape2D.new()
	circulo.radius = 56
	forma.shape = circulo
	zona.add_child(forma)
	add_child(zona)
	var estacoes := get_parent().get_node_or_null("Terrains/Estacoes")
	if estacoes != null:
		_estacao = estacoes.estacao_atual
		estacoes.estacao_mudou.connect(definir_estacao)
	Cidade.alterado.connect(_atualizar)
	definir_estacao(_estacao)
	_atualizar()

func definir_estacao(indice: int) -> void:
	_estacao = clampi(indice, 0, 3)
	if _luz != null: _luz.color = CORES[_estacao]
	queue_redraw()

func _atualizar() -> void:
	visible = Jornada.concluida(Cidade)

func _process(delta: float) -> void:
	if not visible: return
	_tempo += delta
	_luz.energy = 0.35 + 0.05 * sin(_tempo * 1.5)
	queue_redraw()

func _draw() -> void:
	if not Jornada.concluida(Cidade): return
	var cor: Color = CORES[_estacao]
	cor.a = 0.55 + 0.15 * sin(_tempo * 1.5)
	for i in 12:
		var p := (Vector2.from_angle(i * TAU/12) * Vector2(49,23)).round()
		draw_rect(Rect2(p,Vector2(2,2)),cor)
		draw_rect(Rect2(p+Vector2(0,-3),Vector2(1,2)),cor)

func recuperar(quem: Node) -> bool:
	if quem == null or not Jornada.concluida(Cidade): return false
	var lado: int = Fazenda.lado_de(quem)
	var chave := "fonte_limiar_p%d" % lado
	if int(Cidade.memoria.get(chave,-1)) == Calendario.dia or Fazenda.energia_de(lado) >= Fazenda.ENERGIA_MAXIMA:
		get_tree().call_group(quem.grupo_hud(),"avisar_barra","A FONTE DESCANSA. VOLTE AMANHA" if int(Cidade.memoria.get(chave,-1)) == Calendario.dia else "SUA ENERGIA ESTA CHEIA")
		return false
	var antes: int = Fazenda.energia_de(lado)
	Cidade.memoria[chave] = Calendario.dia
	if not Cidade.salvar():
		Cidade.memoria.erase(chave)
		return false
	Fazenda._definir_energia(lado,antes+30)
	if not Fazenda.salvar():
		Fazenda._definir_energia(lado,antes)
		Cidade.memoria.erase(chave)
		Cidade.salvar()
		return false
	Sons.tocar("reviver",0.0)
	get_tree().call_group(quem.grupo_hud(),"avisar_barra","O SELO RECUPEROU %d DE ENERGIA" % (Fazenda.energia_de(lado)-antes))
	return true
