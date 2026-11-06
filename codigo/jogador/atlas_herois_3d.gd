extends Node
## Álbum dos personagens 3D: todos moram num só mundo 3D, lado a lado, e saem de uma tela só.
## Antes cada `heroi_base_3d` redesenhava a própria tela a todo quadro (17 na vila da campanha); agora é uma passada.
## O herói mantém a tela e a câmera dele (paradas), então as contas de "onde fica a ponta da arma" não mudam:
## a câmera própria enxerga o mesmo recorte que a câmera do álbum desenha no quadradinho dele.
## A ordem de profundidade continua 2D: cada sprite mostra o próprio recorte e segue com o z de sempre.
const Heroi := preload("res://codigo/jogador/heroi_base_3d.gd")
const COLUNAS := 6
const LINHAS := 4
## Folga entre quadradinhos (fração da célula): arma ou capa que passe da borda não invade o vizinho.
const FOLGA := 0.2
var visor: SubViewport
var _camera: Camera3D
var _sol: DirectionalLight3D
var _ambiente: WorldEnvironment
var _celula_px := Vector2i.ZERO
var _passo_px := 0
var _passo_m := 0.0
var _ocupadas: Dictionary = {}
var _iluminacao_mapa: Node
## Só as linhas ocupadas entram na tela (com 1 ou 2 personagens não se limpa o álbum inteiro a cada quadro).
var _linhas_ativas := 0
var _camera_base := Vector3.ZERO

static func da_arvore(arvore: SceneTree) -> Node:
	return arvore.get_first_node_in_group("atlas_herois_3d") if arvore != null else null

func _ready() -> void:
	add_to_group("atlas_herois_3d")
	var amostras := 2
	_celula_px = Heroi.TAMANHO*amostras
	_passo_px = roundi(_celula_px.y*(1.0+FOLGA))
	_passo_m = Heroi.TAMANHO_CAMERA*float(_passo_px)/float(_celula_px.y)
	visor = SubViewport.new()
	visor.name = "AtlasHerois3D"
	visor.size = Vector2i(COLUNAS*_passo_px, _passo_px)
	visor.transparent_bg = true
	visor.own_world_3d = true
	visor.msaa_3d = Viewport.MSAA_DISABLED
	visor.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(visor)
	_ambiente = WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("e6e6ee")
	env.ambient_light_energy = 0.65
	_ambiente.environment = env
	visor.add_child(_ambiente)
	_sol = DirectionalLight3D.new()
	_sol.light_color = Color("fff3e3")
	_sol.shadow_enabled = false
	visor.add_child(_sol)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	visor.add_child(_camera)
	var angulo := deg_to_rad(Heroi.INCLINACAO_CAMERA)
	_camera.look_at_from_position(Heroi.ALVO_CAMERA+Vector3(0, sin(angulo), cos(angulo))*10.0, Heroi.ALVO_CAMERA)
	_camera.current = true
	_camera_base = _camera.position
	_ajustar_linhas()

## Células contam a partir do topo: crescer ou encolher o álbum não mexe no recorte de quem já está nele.
func _ajustar_linhas() -> void:
	var maior := -1
	for indice in _ocupadas: maior = maxi(maior, indice)
	var linhas := maxi(1, ceili(float(maior+1)/COLUNAS))
	if linhas == _linhas_ativas: return
	_linhas_ativas = linhas
	visor.size = Vector2i(COLUNAS*_passo_px, linhas*_passo_px)
	_camera.size = linhas*_passo_m
	_camera.position = _camera_base - _camera.global_basis.y*(linhas*_passo_m*0.5)

## Coloca o herói no álbum. Só entra quem desenha no tamanho padrão (pixel art, 2 amostras).
func registrar(heroi: Node) -> bool:
	if heroi._vp == null or heroi._vp.size != _celula_px: return false
	var indice := -1
	for i in COLUNAS*LINHAS:
		if not _ocupadas.has(i):
			indice = i
			break
	if indice < 0: return false
	var mundo: Node3D = heroi._camera.get_parent()
	# Luz e ambiente passam a ser os do álbum: vários no mesmo mundo somariam a luz.
	for filho in mundo.get_children():
		if filho is DirectionalLight3D or filho is WorldEnvironment: filho.queue_free()
	heroi._sol = null
	var coluna := indice % COLUNAS
	var linha := indice / COLUNAS
	var x := (coluna+0.5)*_passo_m - COLUNAS*_passo_m*0.5
	var y := -(linha+0.5)*_passo_m
	mundo.position = _camera.global_basis.x*x + _camera.global_basis.y*y
	# A troca gera um aviso inofensivo do servidor ("scenario is null"), uma vez por personagem; a ordem inversa dobra.
	heroi._vp.own_world_3d = false
	heroi._vp.world_3d = visor.find_world_3d()
	heroi._vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_religar_esqueletos.call_deferred(mundo)
	var folga := (_passo_px-_celula_px.x)/2
	var regiao := Rect2(coluna*_passo_px+folga, linha*_passo_px+folga, _celula_px.x, _celula_px.y)
	heroi._sprite.texture = visor.get_texture()
	heroi._sprite.region_enabled = true
	heroi._sprite.region_rect = regiao
	_ocupadas[indice] = {"heroi": heroi, "mundo": mundo}
	_ajustar_linhas()
	heroi.tree_exiting.connect(_liberar.bind(indice), CONNECT_ONE_SHOT)
	return true

## Trocar de mundo solta a malha do esqueleto (o corpo saía em pose de T, embora o esqueleto estivesse posado).
func _religar_esqueletos(mundo: Node3D) -> void:
	if not is_instance_valid(mundo): return
	for malha in mundo.find_children("*","MeshInstance3D",true,false):
		var caminho: NodePath = malha.skeleton
		if caminho.is_empty(): continue
		malha.skeleton = NodePath("")
		malha.skeleton = caminho

func _liberar(indice: int) -> void:
	_ocupadas.erase(indice)
	if is_inside_tree(): _ajustar_linhas.call_deferred()

## Recorte atual do herói no álbum (rastro, retrato, área aparente).
func imagem(heroi: Node) -> Image:
	var quadro := visor.get_texture().get_image()
	return quadro.get_region(Rect2i(heroi._sprite.region_rect))

func _process(_delta: float) -> void:
	_atualizar_iluminacao()
	# Quem está fora da tela ou escondido não entra na passada.
	for indice in _ocupadas:
		var dados: Dictionary = _ocupadas[indice]
		var heroi: Node = dados.heroi
		if not is_instance_valid(heroi) or not is_instance_valid(dados.mundo): continue
		dados.mundo.visible = heroi.is_visible_in_tree() and _na_tela(heroi)

func _na_tela(heroi: Node) -> bool:
	var sprite: Sprite2D = heroi._sprite
	var tela := sprite.get_viewport().get_visible_rect().grow(64)
	var area := sprite.get_global_transform_with_canvas()*Rect2(sprite.offset, sprite.region_rect.size)
	return tela.intersects(area)

## Mesma luz por horário que cada herói calculava sozinho.
func _atualizar_iluminacao() -> void:
	if not is_instance_valid(_iluminacao_mapa):
		_iluminacao_mapa = get_tree().get_first_node_in_group("iluminacao")
	var hora: float = float(_iluminacao_mapa.hora) if is_instance_valid(_iluminacao_mapa) else 12.0
	var arco := clampf((hora-6.0)/12.0,0.0,1.0)*PI
	var dia := smoothstep(5.5,7.0,hora)*(1.0-smoothstep(17.0,18.5,hora))
	_sol.light_energy = lerpf(0.20,0.95,dia)
	_sol.look_at_from_position(Vector3(-0.45+cos(arco)*0.8,0.65+sin(arco)*0.65,0.85),Vector3.ZERO)
