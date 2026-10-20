extends Node2D

const Criacao := preload("res://codigo/fazenda/criacao_galinhas.gd")
const RAIZ := "res://assets/cenario/fazenda/galinheiro/"
var nivel := -1
var _pecas: Node2D
var largura := 192.0
var altura := 144.0
var _feno: Node2D
var _estacao := 0
var _ovos: Node2D
var _lancando := {}

func _ready() -> void:
	add_to_group("interiores_galinheiro")
	Fazenda.galinheiro_alterado.connect(_atualizar)
	_estacao = Calendario.estacao()
	Calendario.estacao_mudou.connect(_estacao_mudou)
	_atualizar()
	if has_node("Jogador"): $Jogador.modo_fazenda = true

func _sprite(pai: Node, caminho: String, regiao: Rect2, ponto: Vector2, profundidade: int) -> Sprite2D:
	var imagem := Sprite2D.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = load(RAIZ+caminho)
	atlas.region = regiao
	imagem.texture = atlas
	imagem.centered = false
	imagem.position = ponto
	imagem.z_index = profundidade
	imagem.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pai.add_child(imagem)
	return imagem

func _parede(retangulo: Rect2) -> void:
	var corpo := StaticBody2D.new()
	corpo.collision_layer = 64
	corpo.collision_mask = 0
	corpo.position = retangulo.get_center()
	var forma := CollisionShape2D.new()
	var caixa := RectangleShape2D.new()
	caixa.size = retangulo.size
	forma.shape = caixa
	corpo.add_child(forma)
	_pecas.add_child(corpo)

func _atualizar() -> void:
	var novo_nivel: int = maxi(1,int(Fazenda.galinheiro.nivel))
	if nivel == novo_nivel and _pecas != null:
		_repor_galinhas()
		_atualizar_feno()
		_atualizar_ovos()
		return
	nivel = novo_nivel
	if _pecas != null:
		remove_child(_pecas)
		_pecas.queue_free()
	_pecas = Node2D.new()
	_pecas.name = "Interior"
	add_child(_pecas)
	largura = [192,256,320][nivel-1]
	altura = [144,160,192][nivel-1]
	var fundo := _sprite(_pecas,_arquivo_interior(),Rect2(0,0,largura,altura),Vector2.ZERO,-1000)
	var recorte := ShaderMaterial.new()
	recorte.shader = preload("res://codigo/fazenda/recorte_saida_galinhas.gdshader")
	recorte.set_shader_parameter("abertura",Vector4(largura/2+28,altura-37,24,37))
	fundo.material = recorte
	_parede(Rect2(0,0,largura,28))
	_parede(Rect2(0,0,10,altura))
	_parede(Rect2(largura-10,0,10,altura))
	_parede(Rect2(0,altura-20,largura/2-16,20))
	_parede(Rect2(largura/2+16,altura-20,largura/2-16,20))
	_parede(Rect2(0,altura-2,largura,8))
	# Móveis têm base física; o corredor da portinha fica livre.
	_parede(Rect2(36,28,52,18))
	_parede(Rect2(18,49,13,14))
	_parede(Rect2(largura-26,38,11,12))
	_parede(Rect2(largura-49,50,34,22))
	_parede(Rect2(largura-87,24,70,24))
	# Reutiliza a entrada principal: vão, piso, postes e soleira em tamanho menor.
	# A folga ao lado da entrada mantém os postes das duas passagens separados.
	var portinha := preload("res://codigo/fazenda/portinha_galinhas.gd").new()
	portinha.name = "PortinhaFrontal"
	portinha.interna = true
	portinha.position = Vector2(largura/2+40,altura-28)
	portinha.z_index = -999
	_pecas.add_child(portinha)
	var passagem_pequena := _sprite(portinha,_arquivo_interior(),Rect2(largura/2-24,altura-46,48,46),Vector2(-12,-9),0)
	passagem_pequena.name = "PassagemPequena"
	passagem_pequena.scale = Vector2(0.5,37.0/46.0)
	_feno = Node2D.new()
	_feno.name = "FenoComedouro"
	_feno.z_index = -999
	_pecas.add_child(_feno)
	for i in 3:
		_sprite(_feno,"interior_vazio_1.png",Rect2(112,34,12,4),Vector2(43+i*12,36),0)
	_atualizar_feno()
	_sprite(_pecas,_arquivo_interior(),Rect2(38,40,48,6),Vector2(38,40),-998)
	_zona_cuidado("DepositoFeno",Vector2(largura-34,72),"preparar_feno","FENO NA MOCHILA: SELECIONE E JOGUE NO COMEDOURO")
	_zona_cuidado("Ninhos",Vector2(largura-54,55),"recolher","OVOS RECOLHIDOS")
	_zona_cuidado("Incubadora",Vector2(largura-35,55),"incubar","OVO NO NINHO: NASCE EM 3 DIAS")
	_zona_cuidado("TrincoPortinha",Vector2(largura/2+56,altura-33),"portinha","PORTINHA ALTERADA")
	_ovos = Node2D.new()
	_ovos.name = "OvosNosNinhos"
	_ovos.z_index = -998
	_pecas.add_child(_ovos)
	_atualizar_ovos()
	var saida := preload("res://codigo/logica/passagem.gd").new()
	saida.name = "Saida"
	saida.cena_destino = "res://cenas/fazenda.tscn"
	saida.ponto_chegada = "galinheiro"
	saida.so_entre_ondas = false
	saida.position = Vector2(largura/2,altura-5)
	var forma_saida := CollisionShape2D.new()
	var retangulo := RectangleShape2D.new()
	retangulo.size = Vector2(24,16)
	forma_saida.shape = retangulo
	saida.add_child(forma_saida)
	_pecas.add_child(saida)
	var chegada := get_node_or_null("Chegada_porta") as Marker2D
	if chegada == null:
		chegada = Marker2D.new()
		chegada.name = "Chegada_porta"
		chegada.add_to_group("chegada")
		add_child(chegada)
	chegada.position = Vector2(largura/2,altura-40)
	_repor_galinhas()
	for quem in get_tree().get_nodes_in_group("jogadores"):
		if quem.get_world_2d() != get_world_2d(): continue
		quem.camera.limit_left = 0
		quem.camera.limit_top = 0
		quem.camera.limit_right = int(largura)
		quem.camera.limit_bottom = int(altura)
		quem.camera.reset_smoothing()

func _repor_galinhas() -> void:
	for filho in _pecas.get_children():
		if filho.is_in_group("galinhas") and filho.indice >= Fazenda.galinheiro.aves.size():
			_pecas.remove_child(filho)
			filho.queue_free()
	for i in Fazenda.galinheiro.aves.size():
		if _pecas.has_node("Galinha%d" % i): continue
		var galinha := preload("res://codigo/fazenda/galinha.gd").new()
		galinha.indice = i
		galinha.area = Rect2(24,70,largura-48,altura-110)
		galinha.portinha = _pecas.get_node("PortinhaFrontal").position
		galinha.position = Vector2(48+(i%4)*24,80+(i/4)*16)
		_pecas.add_child(galinha)

func _atualizar_feno() -> void:
	if _feno != null:
		_feno.visible = Fazenda.galinheiro.get("feno_colocado",false) and Fazenda.galinheiro.racao > 0

func _zona_cuidado(nome: String, ponto: Vector2, acao: String, dica: String) -> void:
	var zona := preload("res://codigo/fazenda/acao_galinheiro.gd").new()
	zona.name = nome
	zona.position = ponto
	zona.acao = acao
	zona.dica = dica
	var alcance := CollisionShape2D.new()
	var forma := CircleShape2D.new()
	forma.radius = 17
	alcance.shape = forma
	zona.add_child(alcance)
	_pecas.add_child(zona)

func jogar_feno(quem: Node2D) -> void:
	if _lancando.get(quem.get_instance_id(),false): return
	var alvo := Vector2(62,42)
	var ponto := to_local(quem.global_position)+Vector2(0,10)
	if ponto.distance_to(alvo) > 66 or ponto.y < 40:
		get_tree().call_group(quem.grupo_hud(),"avisar_barra","APROXIME-SE DO COMEDOURO E JOGUE O FENO")
		return
	var erro := Criacao.executar(Fazenda,quem,"lancar_feno")
	if erro != "":
		get_tree().call_group(quem.grupo_hud(),"avisar_barra",erro)
		return
	_lancando[quem.get_instance_id()] = true
	var fardo := Sprite2D.new()
	fardo.texture = load(RAIZ+"racao.png")
	fardo.scale = Vector2(0.65,0.65)
	fardo.z_as_relative = false
	fardo.z_index = 900
	add_child(fardo)
	var inicio := ponto-Vector2(0,16)
	var tween := create_tween()
	tween.tween_method(func(t: float):
		fardo.position = inicio.lerp(alvo,t)-Vector2(0,sin(t*PI)*18)
		fardo.rotation = t*PI,0.0,1.0,0.42)
	tween.tween_callback(func():
		fardo.queue_free()
		_lancando.erase(quem.get_instance_id())
		_atualizar_feno())

## A folha Tiny contém dois ícones: apenas o primeiro é o ovo inteiro.
## Os centros estão nas cavidades dos móveis, antes da borda frontal.
func _ovo_no_ninho(nome: String, ponto: Vector2) -> void:
	var ovo := Sprite2D.new()
	ovo.name = nome
	var atlas := AtlasTexture.new()
	atlas.atlas = load(RAIZ+"ovo.png")
	atlas.region = Rect2(0,0,16,16)
	ovo.texture = atlas
	ovo.texture_filter = TEXTURE_FILTER_NEAREST
	ovo.position = ponto
	_ovos.add_child(ovo)

func _atualizar_ovos() -> void:
	if _ovos == null: return
	for filho in _ovos.get_children():
		_ovos.remove_child(filho)
		filho.queue_free()
	var quantidade := mini(4,Criacao.total_ovos(Fazenda))
	for i in quantidade:
		var centro := Vector2(largura-74+(i%2)*20,34)
		if quantidade > 2: centro.x += -3 if i < 2 else 3
		_ovo_no_ninho("Ovo%d" % i,centro)
	if Fazenda.galinheiro.incubacao >= 0:
		_ovo_no_ninho("OvoChocando",Vector2(largura-35,34))

func _arquivo_interior() -> String:
	return "interior_vazio_%d_%s.png" % [maxi(1,nivel),["primavera","verao","outono","inverno"][_estacao]]

func _estacao_mudou(estacao: int) -> void:
	_estacao = clampi(estacao,0,3)
	if _pecas == null: return
	# Reconstroi apenas o desenho; estado, aves e colisões conservam o contrato.
	nivel = -1
	_atualizar()
