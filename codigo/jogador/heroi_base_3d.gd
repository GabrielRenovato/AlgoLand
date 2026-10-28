extends Node2D
## Personagem low poly sobre o rig3D CC0 da Quaternius (Universal Animation
## Library) com proporção chibi, roupas/cabelo independentes e acabamento de
## paleta opcional. Corte e plantio próprios; demais ações vêm dos clipes prontos.
## A espada é presa a um osso: nas costas fora do golpe, na mão no golpe.
## Ações ainda sem animação voltam ao Raven 2D.
const CENA_EDITAVEL := "res://cenas/personagem/base_3d/personagem.tscn"
const CENA_COMPILADA := "res://cenas/personagem/base_3d/personagem.scn"
const ARQUIVO := "res://assets/personagens/base_3d/manequim_ual1.glb"
const Profundidade := preload("res://codigo/globais/profundidade.gd")
const ProporcaoChibi := preload("res://codigo/jogador/proporcao_chibi.gd")
const PELE_PIXEL := preload("res://codigo/jogador/pele_pixel_3d.gd")
const ROUPAS_PIXEL := preload("res://codigo/jogador/roupas_pixel_3d.gd")
var _pele_pixel := false # O CorpoBase recebeu o UV da pele em pixel art.
const TAMANHO := Vector2i(80, 80) # Área em pixels de mundo.
const NITIDEZ := 16 # Detalhe da pintura em alta resolução; mesmo tamanho no mundo.
const TAMANHO_CAMERA := 4.0 # Metros na altura do viewport: define o tamanho no mundo.
const INCLINACAO_CAMERA := 20.0 # Graus abaixo da horizontal.
const ALVO_CAMERA := Vector3(0, 0.75, 0)
const PASSADA := 47.0 # Pixels por ciclo da corrida Mixamo (Standard Run): 42 px valiam 0,43 m de apoio; esta desliza 0,48 m (medir_passada_mixamo.gd).
const MISTURA := 0.12 # Segundos de transição entre animações.
## false: o jogador para de andar enquanto golpeia (teste pedido em 26/10); true: anda devagar no golpe, como o Raven 2D.
const ANDAR_NO_GOLPE := false
# Parado da Quaternius: corpo ereto e mãos relaxadas (o Idle do Mixamo curvava o tronco e projetava a cabeça).
const ANIMACOES := {"parado":"Idle_Loop", "correr":"mixamo/Running", "espada":"Sword_Attack",
	"avanco":"mixamo/Dodge", "ferido":"mixamo/HitReaction", "morrer":"mixamo/Dying", "guarda_livre":"mixamo/BlockIdle",
	"sentar":"Sitting_Enter", "sentado":"Sitting_Idle_Loop", "levantar":"Sitting_Exit",
	"guarda":"mixamo/SwordBlockIdle", "escudada":"melee/HumanM_AttackShield01"}
# Cores por região do corpo (o osso dominante de cada vértice decide a região).
const PALETA := {"pele_sombra":"9e5d53","pele_meio":"cd8c72","pele_base":"edb393","pele_luz":"ffdbb2",
	"short_sombra":"2c354c","short_base":"526074","short_luz":"79879a","cor_rosto":"302b38","branco_olho":"fff1d0"}
const ROUPAS = preload("res://codigo/jogador/roupas_base_3d.gd")
const CATALOGO_ROUPAS := preload("res://codigo/dados/roupas_base_3d.gd")
var roupas_3d: Dictionary=CATALOGO_ROUPAS.padrao()
var _moldes_roupas: Array[ArrayMesh]=[]
var _cache_roupas: Dictionary={}
@export var demonstrar_combate_na_fazenda := false
@export_enum("Espada","Lança") var arma_demonstracao := 0
## Facetas reais dos triângulos, renderizadas sobre o mesmo mundo 2D.
@export var acabamento_low_poly := false:
	set(valor):
		acabamento_low_poly=valor
		_atualizar_renderizacao()
@export var roupas_pixel_art := true:
	set(valor):
		roupas_pixel_art=valor
		_atualizar_texturas_roupas()
## Visual padrão: desenho na pele/cabelo do rig, independente do filtro da tela.
@export var rosto_cabelo_pixel_art := true:
	set(valor):
		rosto_cabelo_pixel_art = valor
		_atualizar_desenho_cabeca()
@export var acabamento_pixel_art := true:
	set(valor):
		acabamento_pixel_art = valor
		_atualizar_renderizacao()
@export_range(1,4,1) var amostras_pixel_art := 2: # Metade do pixel do cenário: nítido e ainda pixel art.
	set(valor):
		amostras_pixel_art=clampi(valor,1,4)
		_atualizar_renderizacao()
@export_flags("Camisa","Calça","Botas","Cabelo") var pecas_visiveis := 0:
	set(valor):
		pecas_visiveis = valor & 15
		_atualizar_pecas()
var _pecas: Array[MeshInstance3D] = []
var _molde_cabelo: ArrayMesh
var _acabamento_armas: RefCounted
var _armaduras: RefCounted
var _molde_rosto: ArrayMesh
var _rosto_arredondado: ArrayMesh
var _cabeca_referencia: BoneAttachment3D
# Encaixes da espada nos ossos (posição em metros e rotação em graus, no espaço do osso).
const OSSO_COSTAS := "DEF-spine.003"
const COSTAS_POSICAO := Vector3(-0.24, 0.38, -0.16)
const COSTAS_COM_ESCUDO_POSICAO := Vector3(-0.33,0.30,-0.16)
const COSTAS_ROTACAO := Vector3(0, 0, -145)
const LANCA_COSTAS_POSICAO := Vector3(-0.05,0.02,-0.20)
const LANCA_COSTAS_ROTACAO := Vector3(-18,0,-15)
const ESCUDO_COSTAS_POSICAO := Vector3(0,0.03,-0.24)
const ESCUDO_COSTAS_ROTACAO := Vector3(0,180,0)
const ESCUDO_MAO_POSICAO := Vector3(0,0.10,0)
const ESCUDO_ESCALA_MAO := 1.0/(0.85*1.4)
const OSSO_MAO := "DEF-hand.R"
const MAO_POSICAO := Vector3(0.0, 0.08, 0.0)
const MAO_ROTACAO := Vector3(0, 0, 0)
## Lâminas (largura, comprimento) relativas ao desenho original; o rastro do golpe acompanha a ponta.
const ESPADA_TAMANHO := Vector2(1.15, 1.3)
const MONTANTE_TAMANHO := Vector2(1.6, 1.25)
var _jogador: Node2D
var _vp: SubViewport
var _sol: DirectionalLight3D
var _iluminacao_mapa: Node
var _camera: Camera3D
var _modelo: Node3D
var _player: AnimationPlayer
var _esqueleto: Skeleton3D
var _pose_guarda: SkeletonModifier3D
var _empunhadura_lanca: SkeletonModifier3D
var _lanca: Node3D
var _machado_arma: Node3D
var _maca: Node3D
## Trecho útil dos golpes Mixamo de machado/maça (fração do clipe): sem a espera inicial e a volta longa.
const JANELA_PESADA := Vector2(0.18, 0.72)
const JANELA_DASH := Vector2(0.10, 0.70)
var _espada: Node3D
var _espada_uma_mao: Node3D
var _montante: Node3D
var _costas: BoneAttachment3D
var _mao_esquerda: BoneAttachment3D
var _escudo: Node3D
var _mao: BoneAttachment3D
var _sprite: Sprite2D
var _rastro: MeshInstance3D
var _progresso_golpe := 0.0
var _golpe_visual_espada := 1
var _restante_recuperacao_espada := 0.0
const TEMPO_RECUPERACAO_ESPADA := 0.28
var _delta_rastro := 0.0
var _quadro_rastro := -1
var _transformacao_rastro := Transform3D.IDENTITY
const FAZENDA := {"regar":["Farm_Watering",0.05,0.23,0.95],"encher":["Farm_Watering",0.05,0.18,0.20],"plantar":["Farm_PlantSeed",0.05,0.55,0.95],"colher":["Farm_Harvest",0.03,0.40,0.97],"machado":["TreeChopping_Loop",0.0,0.24,1.0]}
const TEMPO_SENTAR := 0.32
const TEMPO_LEVANTAR := 0.24
var _acoes_manuais: SkeletonModifier3D
var _pose_trabalho: SkeletonModifier3D
var _pega_kaykit: Node3D
var _arco_visual: Node3D
var _pose_arco: SkeletonModifier3D
var _ferramentas: Node3D
var _estava_sentado := false
var _restante_levantar := 0.0
var _acao := ""
var _inicio_acao := 0.0
var _tempo := 0.0
var _guinada := 0.0
const COMBO_LANCA := preload("res://codigo/jogador/combo_lanca_base_3d.gd")
const COMBO := preload("res://codigo/jogador/combo_espada_base_3d.gd")
const COMBO_MONTANTE := preload("res://codigo/jogador/combo_montante_base_3d.gd")
var _golpe_demonstracao := 1
var _demonstracao := false
var _tempo_demonstracao := 0.0
var _fila_demonstracao := false
var _direcao_demonstracao := Vector2.DOWN

func _ready() -> void:
	name = "HeroiBase3D"
	_jogador = get_parent()
	position.y = Profundidade.PES_JOGADOR
	z_index = 3
	process_priority = 110 # Decide antes do compositor Raven (120).
	_montar_cena()
	_carregar_modelo()
	# Modo pixel: pele em pixel art pintada no modelo; os outros modos usam a pintura projetada.
	if acabamento_pixel_art and not acabamento_low_poly and ResourceLoader.exists(PELE_PIXEL.TEXTURA):
		PELE_PIXEL.aplicar(_modelo.find_child("CorpoBase",true,false),_esqueleto)
		_pele_pixel=true
	else:
		preload("res://codigo/jogador/pintura_corpo_3d.gd").aplicar(_modelo.find_child("CorpoBase",true,false))
	for i in 3:
		_moldes_roupas.append(_pecas[i].mesh)
		_pecas[i].material_override=_pecas[i].material_override.duplicate()
	_molde_cabelo=_pecas[3].mesh
	_pecas[3].material_override=_pecas[3].material_override.duplicate()
	_atualizar_desenho_cabeca()
	_atualizar_texturas_roupas()
	var dados_personagem: Dictionary=_jogador.carregar_de_json()
	if not dados_personagem.has("roupas_3d") and _jogador.has_method("aplicar_dados_carregados"):
		_migrar_visual_antigo(dados_personagem)
	else:
		definir_roupas_3d(dados_personagem.get("roupas_3d",{}))
	if bool(dados_personagem.get("aviso_visual_3d", false)) and _jogador.has_method("aplicar_dados_carregados"):
		_mostrar_aviso_visual.call_deferred()
	_aplicar_cores()
	var mixamo: AnimationLibrary=load("res://assets/personagens/base_3d/mixamo.res").duplicate()
	mixamo.add_animation("AxeTreeChop",preload("res://codigo/jogador/corte_machado_mixamo.gd").gerar(mixamo.get_animation("AxeHorizontal")))
	_player.add_animation_library("mixamo",mixamo)
	_player.add_animation_library("quaternius",load("res://assets/personagens/base_3d/quaternius_ual2.res"))
	_player.add_animation_library("melee",load("res://assets/personagens/base_3d/kevin_melee_free.res"))
	_player.add_animation_library("fazenda",load("res://assets/personagens/base_3d/acoes_fazenda.res"))
	_pega_kaykit=Node3D.new()
	_pega_kaykit.name="PegaKayKit"
	_player.get_node(_player.root_node).add_child(_pega_kaykit)
	_player.add_animation_library("ferramentas",load("res://assets/personagens/base_3d/kaykit_ferramentas.res"))
	_completar_rotacoes_de_retorno()
	COMBO.instalar(_player)
	COMBO_LANCA.instalar(_player)
	COMBO_MONTANTE.instalar(_player)
	_espada_uma_mao=_espada
	_montante=_montar_montante()
	_costas.add_child(_montante)
	_montante.visible=false
	_lanca = _montar_lanca()
	_costas.add_child(_lanca)
	_machado_arma = _montar_arma_pesada(false)
	_costas.add_child(_machado_arma)
	_maca = _montar_arma_pesada(true)
	_costas.add_child(_maca)
	_mao_esquerda = BoneAttachment3D.new()
	_mao_esquerda.bone_name="DEF-hand.L"
	_esqueleto.add_child(_mao_esquerda)
	_escudo = _montar_escudo()
	_mao_esquerda.add_child(_escudo)
	_rastro = preload("res://codigo/jogador/rastro_espada_3d.gd").new()
	_rastro.ponta_espada = 0.79+0.62*(ESPADA_TAMANHO.y-1.0)
	_rastro.ponta_montante = 1.02+0.88*(MONTANTE_TAMANHO.y-1.0)
	_modelo.add_child(_rastro)
	_ferramentas=preload("res://codigo/jogador/ferramentas_fazenda_3d.gd").new()
	_modelo.add_child(_ferramentas)
	_arco_visual=preload("res://codigo/jogador/arco_base_3d.gd").new()
	_arco_visual.heroi=self
	_modelo.add_child(_arco_visual)
	_acoes_manuais=preload("res://codigo/jogador/acoes_manuais_fazenda_3d.gd").new()
	_acoes_manuais.heroi=self
	_esqueleto.add_child(_acoes_manuais)
	_pose_trabalho=preload("res://codigo/jogador/pose_trabalho_base_3d.gd").new()
	_pose_trabalho.heroi=self
	_esqueleto.add_child(_pose_trabalho)
	_pose_guarda=preload("res://codigo/jogador/pose_guarda_base_3d.gd").new()
	_pose_guarda.heroi=self
	_esqueleto.add_child(_pose_guarda)
	_pose_arco=preload("res://codigo/jogador/pose_arco_base_3d.gd").new()
	_pose_arco.heroi=self
	_esqueleto.add_child(_pose_arco)
	var encaixe_machado = preload("res://codigo/jogador/encaixe_machado_3d.gd").new()
	encaixe_machado.heroi=self
	_esqueleto.add_child(encaixe_machado)
	_empunhadura_lanca = preload("res://codigo/jogador/empunhadura_lanca_3d.gd").new()
	_empunhadura_lanca.heroi = self
	_esqueleto.add_child(_empunhadura_lanca)
	_esqueleto.skeleton_updated.connect(_sincronizar_linha_pesca)
	_armaduras=preload("res://codigo/jogador/armaduras_base_3d.gd").new(self)
	_acabamento_armas=preload("res://codigo/jogador/acabamento_armas_3d.gd").new(self)
	_atualizar_materiais_pixel()
	_player.play("Idle_Loop",0.0)
	_player.seek(0.0,true)
	for modificador in _esqueleto.get_children():
		if modificador is ProporcaoChibi:modificador._aplicar()
	_cabeca_referencia=preload("res://codigo/jogador/cabeca_referencia_3d.gd").new()
	_cabeca_referencia.montar(self)
	_atualizar_pecas()

func definir_roupas_3d(dados: Dictionary) -> void:
	roupas_3d=CATALOGO_ROUPAS.normalizar(dados)
	if _moldes_roupas.size()!=3: return
	for i in 3:
		var categoria: String=CATALOGO_ROUPAS.CATEGORIAS[i]
		var modelo: Dictionary=CATALOGO_ROUPAS.modelo(categoria,roupas_3d[categoria])
		if not _cache_roupas.has(modelo.id):
			if categoria=="calca" and modelo.forma>=3:
				var corpo_saia: MeshInstance3D=_modelo.find_child("CorpoBase",true,false)
				_cache_roupas[modelo.id]=preload("res://codigo/jogador/visuais_femininos_3d.gd").saia(_moldes_roupas[i],corpo_saia,_esqueleto,modelo.forma)
			else:
				_cache_roupas[modelo.id]=CATALOGO_ROUPAS.malha(_moldes_roupas[i],categoria,modelo.forma)
		# Modo pixel: a peça ganha o UV de cilindro e a pintura própria do modelo.
		var textura_pixel: String=ROUPAS_PIXEL.caminho(modelo.id)
		var usar_pixel: bool=_pele_pixel and ResourceLoader.exists(textura_pixel)
		if usar_pixel and not _cache_roupas.has(modelo.id+"#pixel"):
			_cache_roupas[modelo.id+"#pixel"]=PELE_PIXEL.com_uv_pixel(_cache_roupas[modelo.id],_pecas[i],_esqueleto)
		_pecas[i].mesh=_cache_roupas[modelo.id+"#pixel"] if usar_pixel else _cache_roupas[modelo.id]
		var material: ShaderMaterial=_pecas[i].material_override
		material.set_shader_parameter("roupa_pixel",usar_pixel)
		if usar_pixel: material.set_shader_parameter("textura_roupa_pixel",load(textura_pixel))
		material.set_shader_parameter("cor",Color(modelo.cor))
		material.set_shader_parameter("acabamento_roupa",i+1)
		material.set_shader_parameter("modelo_roupa",modelo.estilo)
	var corpo: MeshInstance3D=_modelo.find_child("CorpoBase",true,false)
	var cabelo: Dictionary=CATALOGO_ROUPAS.modelo("cabelo",roupas_3d.cabelo)
	if not _cache_roupas.has(cabelo.id):
		_cache_roupas[cabelo.id]=preload("res://codigo/jogador/visuais_femininos_3d.gd").cabelo(_molde_cabelo,corpo,_esqueleto,cabelo.forma)
	var textura_cabelo_pixel: String=ROUPAS_PIXEL.caminho(cabelo.id)
	var cabelo_pixel: bool=_pele_pixel and ResourceLoader.exists(textura_cabelo_pixel) and (_cache_roupas[cabelo.id] as ArrayMesh).get_surface_count()>0
	if cabelo_pixel and not _cache_roupas.has(cabelo.id+"#pixel"):
		_cache_roupas[cabelo.id+"#pixel"]=PELE_PIXEL.com_uv_pixel(_cache_roupas[cabelo.id],_pecas[3],_esqueleto)
	_pecas[3].mesh=_cache_roupas[cabelo.id+"#pixel"] if cabelo_pixel else _cache_roupas[cabelo.id]
	var material_cabelo: ShaderMaterial=_pecas[3].material_override
	material_cabelo.set_shader_parameter("cabelo_pixel",cabelo_pixel)
	if cabelo_pixel: material_cabelo.set_shader_parameter("textura_roupa_pixel",load(textura_cabelo_pixel))
	if _armaduras!=null:_armaduras.ajustar_cabelo()
	corpo.material_override.set_shader_parameter("raspado", cabelo.forma==4)
	corpo.material_override.set_shader_parameter("altura_botas",CATALOGO_ROUPAS.modelo("calcado",roupas_3d.calcado).altura)
	if _armaduras!=null:
		_armaduras.invalidar()
		_armaduras.atualizar()

## Save de antes do personagem 3D: veste o equivalente do Raven (cores e roupa) e grava uma vez.
## Pele, cor do cabelo e olhos já vêm de aparencia_raven. Marca o aviso de "visual novo".
func _migrar_visual_antigo(dados: Dictionary) -> void:
	definir_roupas_3d(roupas_do_raven(_jogador.aparencia_raven))
	var caminho: String = get_node("/root/Saves").caminho_personagem(_jogador.eh_p2)
	# Sem arquivo ainda (personagem nunca criado): não grava, para não fingir um personagem salvo.
	if not FileAccess.file_exists(caminho): return
	if salvar_roupas_3d(caminho):
		var gravado = JSON.parse_string(FileAccess.get_file_as_string(caminho))
		if gravado is Dictionary:
			gravado["aviso_visual_3d"] = true
			preload("res://codigo/modelos/modelo_inventario.gd").gravar_dados(caminho, gravado)
			dados["aviso_visual_3d"] = true

## Roupa Raven (1..8: azul/verde × marrom/jeans, com ou sem capa) → peças 3D de mesma cor.
static func roupas_do_raven(aparencia: Dictionary) -> Dictionary:
	return CATALOGO_ROUPAS.do_visual_antigo(aparencia)

func _mostrar_aviso_visual() -> void:
	if not is_inside_tree(): return
	await get_tree().create_timer(1.5).timeout
	if not is_inside_tree() or get_tree().root.get_node("Introducao").ativa(): return
	get_tree().root.add_child(preload("res://codigo/ui/editor_visual.gd").aviso(_jogador))

func salvar_roupas_3d(caminho: String="") -> bool:
	if caminho.is_empty(): caminho=get_node("/root/Saves").caminho_personagem(_jogador.eh_p2)
	var dados: Dictionary={}
	if FileAccess.file_exists(caminho):
		var existente=JSON.parse_string(FileAccess.get_file_as_string(caminho))
		if not existente is Dictionary: return false
		dados=existente
	dados["roupas_3d"]=roupas_3d.duplicate()
	return preload("res://codigo/modelos/modelo_inventario.gd").gravar_dados(caminho,dados)

func _montar_cena() -> void:
	_vp = SubViewport.new()
	_vp.size = TAMANHO*NITIDEZ
	_vp.transparent_bg = true
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_WHEN_PARENT_VISIBLE
	add_child(_vp)
	var mundo := Node3D.new()
	_vp.add_child(mundo)
	var ambiente := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("e6e6ee")
	env.ambient_light_energy = 0.65
	ambiente.environment = env
	mundo.add_child(ambiente)
	_sol = DirectionalLight3D.new()
	_sol.name = "LuzDoAmbiente"
	_sol.light_color = Color("fff3e3")
	_sol.shadow_enabled = false
	mundo.add_child(_sol)
	_atualizar_iluminacao()
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = TAMANHO_CAMERA
	mundo.add_child(_camera)
	var angulo := deg_to_rad(INCLINACAO_CAMERA)
	_camera.look_at_from_position(ALVO_CAMERA+Vector3(0, sin(angulo), cos(angulo))*10.0, ALVO_CAMERA)
	_modelo = Node3D.new()
	mundo.add_child(_modelo)
	_sprite = Sprite2D.new()
	_sprite.centered = false
	_sprite.texture_filter = TEXTURE_FILTER_LINEAR
	_sprite.texture = _vp.get_texture()
	_sprite.scale = Vector2.ONE/NITIDEZ
	add_child(_sprite)
	# Os pés (origem do modelo) caem no pivô do jogador.
	_sprite.offset = -_camera.unproject_position(Vector3.ZERO)
	_atualizar_renderizacao()

## Low poly mantém as facetas em alta resolução e o mesmo tamanho no mundo 2D.
func _atualizar_renderizacao() -> void:
	if _vp == null or _sprite == null:return
	var pixel := acabamento_pixel_art and not acabamento_low_poly
	var suave := 8 if OS.has_feature("mobile") else NITIDEZ
	var amostras := amostras_pixel_art if pixel else suave
	_vp.size = TAMANHO*amostras
	_vp.msaa_3d = Viewport.MSAA_DISABLED if pixel else Viewport.MSAA_4X
	_sprite.texture_filter = TEXTURE_FILTER_NEAREST if pixel else TEXTURE_FILTER_LINEAR
	_sprite.scale = Vector2.ONE/amostras
	_sprite.offset = -_camera.unproject_position(Vector3.ZERO)
	if acabamento_low_poly:
		_sprite.material = null
	elif acabamento_pixel_art:
		var efeito := ShaderMaterial.new()
		efeito.shader = preload("res://codigo/jogador/contorno_pixel_base_3d.gdshader")
		_sprite.material = efeito
	else:
		var contorno := ShaderMaterial.new()
		contorno.shader = preload("res://codigo/jogador/contorno_suave_base_3d.gdshader")
		contorno.set_shader_parameter("raio", float(NITIDEZ) * 1.1)
		_sprite.material = contorno
	_atualizar_materiais_pixel()

func _atualizar_materiais_pixel() -> void:
	if _modelo==null:return
	for instancia in _modelo.find_children("*","MeshInstance3D",true,false):
		var material=instancia.material_override
		if material is ShaderMaterial and material.get_shader_parameter("facetado")!=null:
			material.set_shader_parameter("facetado",acabamento_low_poly)
		if material is ShaderMaterial and material.get_shader_parameter("luz_em_blocos")!=null:
			material.set_shader_parameter("luz_em_blocos",acabamento_pixel_art and not acabamento_low_poly)
		if material is ShaderMaterial and material.get_shader_parameter("luz_dura")!=null:
			material.set_shader_parameter("luz_dura",acabamento_pixel_art and not acabamento_low_poly)
		# Em grades grossas (1–2) a pintura de músculos vira ruído; a forma vem das faixas de luz.
		if instancia.name=="CorpoBase" and material is ShaderMaterial:
			# Com a pele em pixel art o UV mudou: a pintura projetada não serve mais.
			material.set_shader_parameter("pele_pixel",_pele_pixel and acabamento_pixel_art and not acabamento_low_poly)
			material.set_shader_parameter("desenho_pixel_corpo",not _pele_pixel and (acabamento_low_poly or not acabamento_pixel_art or amostras_pixel_art>2))
			material.set_shader_parameter("forca_desenho_corpo",.4 if acabamento_pixel_art and not acabamento_low_poly else 1.0)

## A luz pertence à cena e acompanha o horário; nenhum sombreado é pintado no asset.
func _atualizar_iluminacao() -> void:
	if _sol == null:return
	if not is_instance_valid(_iluminacao_mapa):
		_iluminacao_mapa = get_tree().get_first_node_in_group("iluminacao")
	var hora: float = float(_iluminacao_mapa.hora) if is_instance_valid(_iluminacao_mapa) else 12.0
	var arco := clampf((hora-6.0)/12.0,0.0,1.0)*PI
	var dia := smoothstep(5.5,7.0,hora)*(1.0-smoothstep(17.0,18.5,hora))
	_sol.light_energy = lerpf(0.20,0.95,dia)
	_sol.look_at_from_position(Vector3(-0.45+cos(arco)*0.8,0.65+sin(arco)*0.65,0.85),Vector3.ZERO)

func _carregar_modelo() -> void:
	if not ResourceLoader.exists(CENA_EDITAVEL):
		_construir_modelo()
		return
	var recurso: PackedScene = ResourceLoader.load(CENA_EDITAVEL,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	var cena: Node3D = recurso.instantiate()
	_modelo.add_child(cena)
	var corpo = cena.find_child("CorpoBase",true,false)
	corpo.material_override = corpo.material_override.duplicate()
	_esqueleto = cena.find_children("*","Skeleton3D",true,false)[0]
	_player = cena.find_children("*","AnimationPlayer",true,false)[0]
	for nome in ROUPAS.NOMES:
		_pecas.append(cena.find_child(nome,true,false))
	_costas = cena.find_child("EncaixeCostas",true,false)
	_mao = cena.find_child("EncaixeMao",true,false)
	_espada = cena.find_child("Espada",true,false)
	_atualizar_pecas()
	_player.play("Idle_Loop",0.0)
	var maos := preload("res://codigo/jogador/maos_relaxadas_3d.gd").new()
	maos.name = "MaosRelaxadas"
	maos.capturar(_esqueleto, _player.get_animation("Idle_Loop"))
	_esqueleto.add_child(maos)

## Compilador da fonte CC0. O jogo prefere a cena editável já preparada.
func _construir_modelo() -> void:
	var doc := GLTFDocument.new()
	var estado := GLTFState.new()
	if doc.append_from_file(ProjectSettings.globalize_path(ARQUIVO), estado) != OK:
		push_error("HeroiBase3D: não abriu "+ARQUIVO)
		return
	var cena := doc.generate_scene(estado)
	_modelo.add_child(cena)
	_esqueleto = cena.find_children("*", "Skeleton3D", true, false)[0]
	_player = cena.find_children("*", "AnimationPlayer", true, false)[0]
	for nome in _player.get_animation_list():
		if nome.ends_with("_Loop"):
			_player.get_animation(nome).loop_mode = Animation.LOOP_LINEAR
	var tecido := _material(Color.WHITE)
	tecido.set_shader_parameter("usar_cor_do_vertice", true)
	for malha in cena.find_children("*", "MeshInstance3D", true, false):
		_pintar_regioes(malha)
		preload("res://codigo/jogador/bracos_base_3d.gd").construir(malha,_esqueleto)
		(malha as MeshInstance3D).material_override = tecido
		(malha as MeshInstance3D).name = "CorpoBase"
		_pecas.append_array(ROUPAS.construir(malha,_esqueleto))
	for i in _pecas.size():
		_pecas[i].material_override = _material(Color(["4a6b88","846047","633f3b","a87848"][i]))
		_pecas[i].material_override.set_shader_parameter("tingir_roupa",true)
		_pecas[i].material_override.set_shader_parameter("acabamento_roupa",i+1 if i<3 else 0)
		if i==3:
			var textura:=ImageTexture.create_from_image(Image.load_from_file("res://assets/personagens/base_3d/cabelo_pintado.png"))
			_pecas[i].material_override.set_shader_parameter("usar_textura_cabelo",true)
			_pecas[i].material_override.set_shader_parameter("textura_cabelo",textura)
	_atualizar_pecas()
	_esqueleto.add_child(ProporcaoChibi.new())
	# O GLB tem esqueleto Z-up. Compensar a altura no nó do modelo (Y do mundo),
	# sem acumular deslocamentos sobre a pose animada do quadril.
	cena.position.y = -ProporcaoChibi.DESCIDA_QUADRIL
	_costas = BoneAttachment3D.new()
	_costas.name = "EncaixeCostas"
	_costas.bone_name = OSSO_COSTAS
	_esqueleto.add_child(_costas)
	_mao = BoneAttachment3D.new()
	_mao.name = "EncaixeMao"
	_mao.bone_name = OSSO_MAO
	_esqueleto.add_child(_mao)
	_espada = _montar_espada()
	_costas.add_child(_espada)
	_player.play("Idle_Loop",0.0)

## Preserva a malha e os pesos, grava a região de pele/short e as coordenadas do rosto.
func _pintar_regioes(instancia: MeshInstance3D) -> void:
	var malha := instancia.mesh as ArrayMesh
	var pele: Skin = instancia.skin
	var nova := ArrayMesh.new()
	for superficie in malha.get_surface_count():
		var arrays := malha.surface_get_arrays(superficie)
		var ossos: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var pesos: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var total: int = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		var por_vertice := ossos.size()/total
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normais: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var ligacao_pescoco := -1
		var transformacoes := []
		var fatores := []
		for ligacao in pele.get_bind_count():
			var osso := pele.get_bind_bone(ligacao)
			var nome_osso := String(pele.get_bind_name(ligacao))
			if not nome_osso.is_empty():
				osso = _esqueleto.find_bone(nome_osso)
			else:
				nome_osso = _esqueleto.get_bone_name(osso)
			if nome_osso=="DEF-neck":ligacao_pescoco=ligacao
			transformacoes.append(instancia.global_transform.affine_inverse()*_esqueleto.global_transform*_esqueleto.get_bone_global_rest(osso))
			fatores.append(1.8 if nome_osso.begins_with("DEF-thigh") or nome_osso.begins_with("DEF-shin") else (1.4 if nome_osso.begins_with("DEF-upper_arm") or nome_osso.begins_with("DEF-forearm") else 1.0))
		var cobertura := PackedVector2Array()
		cobertura.resize(total)
		var cores := PackedColorArray()
		cores.resize(total)
		for v in total:
			var melhor := 0
			for k in por_vertice:
				if pesos[v*por_vertice+k] > pesos[v*por_vertice+melhor]:
					melhor = k
			var indice := ossos[v*por_vertice+melhor]
			var nome := String(pele.get_bind_name(indice)) if pele != null and indice < pele.get_bind_count() else ""
			if nome.is_empty() and pele != null and indice < pele.get_bind_count():
				nome = _esqueleto.get_bone_name(pele.get_bind_bone(indice))
			var ponto: Vector3 = arrays[Mesh.ARRAY_VERTEX][v]
			var nucleo_pescoco := nome=="DEF-neck" and absf(ponto.x)<0.075 and ponto.z> -0.055
			if nucleo_pescoco:
				# A cabeça ampliada e os ombros puxavam lados diferentes do pescoço.
				# O tubo central acompanha seu próprio osso, sem essa torção residual.
				for k in por_vertice:
					ossos[v*por_vertice+k]=ligacao_pescoco if k==0 else 0
					pesos[v*por_vertice+k]=1.0 if k==0 else 0.0
			# Distância contínua à borda da roupa. Um booleano por vértice
			# cortava os triângulos do pescoço em dentes, visíveis nos perfis.
			var cobertura_camisa := -1.0
			if nome.begins_with("DEF-spine"):
				cobertura_camisa = ponto.y-0.99
			if nome=="DEF-neck":
				cobertura_camisa = 0.10
				if nucleo_pescoco:
					# Com a cabeça erguida (proporcao_chibi.DESLOCAMENTO_CABECA) o tubo central
					# fica à mostra acima da gola; o corte em degraus aparecia sob o queixo.
					# A gola da camisa está por fora: só a base, já dentro dela, some.
					cobertura_camisa = 1.470-ponto.y
			if nome.begins_with("DEF-shoulder"):
				cobertura_camisa = 0.10
			if nome.begins_with("DEF-upper_arm"):
				cobertura_camisa = 0.245-(transformacoes[indice].affine_inverse()*ponto).y
			var regiao_inferior := nome.begins_with("DEF-hips") or nome.begins_with("DEF-thigh") or nome.begins_with("DEF-shin") or nome.begins_with("DEF-foot") or nome.begins_with("DEF-toe")
			cobertura[v] = Vector2(cobertura_camisa,ponto.y if regiao_inferior else 2.0)
			var short := (nome.begins_with("DEF-hips") or nome.begins_with("DEF-thigh")) and ponto.y > 0.69
			cores[v] = Color.WHITE if short else Color.BLACK
			if nome == "DEF-head":
				var cabeca := _esqueleto.find_bone("DEF-head")
				var para_cabeca := (_esqueleto.global_transform*_esqueleto.get_bone_global_rest(cabeca)).affine_inverse()*instancia.global_transform
				var p_cabeca := para_cabeca*ponto
				# Coordenadas da pele em repouso: o rosto acompanha a mesma malha e ossos.
				cores[v] = Color(0.4,(p_cabeca.x+0.15)/0.30,(p_cabeca.y+0.03)/0.32,(p_cabeca.z+0.16)/0.32)
			# Recupera volume nos membros encurtados, com os mesmos pesos da pele.
			# A deformação ocorre uma vez na malha de repouso, sem acumular por quadro.
			var novo_ponto := Vector3.ZERO
			var nova_normal := Vector3.ZERO
			for k in por_vertice:
				var peso: float = pesos[v*por_vertice+k]
				if peso <= 0.0:
					continue
				var ligacao: int = ossos[v*por_vertice+k]
				var t: Transform3D = transformacoes[ligacao]
				var fator: float = fatores[ligacao]
				var local := t.affine_inverse()*ponto
				local *= Vector3(fator,1,fator)
				novo_ponto += (t*local)*peso
				var normal_local := t.basis.inverse()*normais[v]
				nova_normal += (t.basis*(normal_local/Vector3(fator,1,fator)))*peso
			vertices[v] = novo_ponto
			normais[v] = nova_normal.normalized()
		arrays[Mesh.ARRAY_BONES] = ossos
		arrays[Mesh.ARRAY_WEIGHTS] = pesos
		arrays[Mesh.ARRAY_TEX_UV2] = cobertura
		arrays[Mesh.ARRAY_COLOR] = cores
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normais
		nova.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, malha.surface_get_format(superficie) | Mesh.ARRAY_FORMAT_COLOR | Mesh.ARRAY_FORMAT_TEX_UV2)
	instancia.mesh = nova

func _atualizar_pecas() -> void:
	for i in _pecas.size():
		_pecas[i].visible = (pecas_visiveis & (1 << i)) != 0
	if _modelo == null:return
	var corpo = _modelo.find_child("CorpoBase",true,false)
	if corpo == null:return
	var material: ShaderMaterial = corpo.material_override
	material.set_shader_parameter("esconder_camisa",(pecas_visiveis & 1)!=0)
	material.set_shader_parameter("esconder_calca",(pecas_visiveis & 2)!=0)
	material.set_shader_parameter("esconder_botas",(pecas_visiveis & 4)!=0)
	if _cabeca_referencia!=null:
		var usar: bool=(pecas_visiveis & 8)!=0 and roupas_3d.get("cabelo","")=="cabelo_curto" and (_armaduras==null or (_armaduras.mascara & 1)==0)
		_cabeca_referencia.aplicar_aparencia(_jogador.aparencia_raven,PELES,OLHOS)
		_cabeca_referencia.visible=usar
		material.set_shader_parameter("substituir_cabeca",usar)
		if usar:_pecas[3].visible=false

func _atualizar_texturas_roupas() -> void:
	if _pecas.size()<3:return
	for i in 3:
		var material := _pecas[i].material_override as ShaderMaterial
		material.set_shader_parameter("desenho_pixel_roupas",roupas_pixel_art)
		if roupas_pixel_art:
			var categoria: String=CATALOGO_ROUPAS.CATEGORIAS[i]
			material.set_shader_parameter("desenho_roupa",load("res://assets/personagens/base_3d/roupas_pixel/"+categoria+".png"))

func _atualizar_desenho_cabeca() -> void:
	if _modelo == null or _pecas.size() < 4:return
	var corpo := _modelo.find_child("CorpoBase",true,false) as MeshInstance3D
	if corpo == null:return
	var pele := corpo.material_override as ShaderMaterial
	var cabelo := _pecas[3].material_override as ShaderMaterial
	var textura_original = cabelo.get_shader_parameter("textura_cabelo")
	cabelo.shader = preload("res://codigo/jogador/cabelo_base_3d.gdshader")
	cabelo.set_shader_parameter("textura_cabelo", textura_original)
	if _molde_rosto==null:_molde_rosto=corpo.mesh
	if rosto_cabelo_pixel_art and _rosto_arredondado==null:
		var cabeca_para_malha := corpo.global_transform.affine_inverse()*_esqueleto.global_transform*_esqueleto.get_bone_global_rest(_esqueleto.find_bone("DEF-head"))
		_rosto_arredondado=preload("res://codigo/jogador/ajuste_rosto_base_3d.gd").construir(_molde_rosto,cabeca_para_malha)
	corpo.mesh=_rosto_arredondado if rosto_cabelo_pixel_art else _molde_rosto
	pele.set_shader_parameter("desenho_pixel_cabeca",rosto_cabelo_pixel_art)
	cabelo.set_shader_parameter("desenho_pixel_cabeca",rosto_cabelo_pixel_art)
	if rosto_cabelo_pixel_art:
		# Recursos importados sem mipmaps, também disponíveis no jogo exportado.
		pele.set_shader_parameter("desenho_rosto",load("res://assets/personagens/base_3d/rosto_cabelo_pixel/rosto.png"))
		cabelo.set_shader_parameter("desenho_cabelo",load("res://assets/personagens/base_3d/rosto_cabelo_pixel/cabelo.png"))

func _material(cor: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://codigo/jogador/acabamento_base_3d.gdshader")
	m.set_shader_parameter("cor", cor)
	m.set_shader_parameter("facetado",acabamento_low_poly)
	m.set_shader_parameter("luz_em_blocos",acabamento_pixel_art)
	for parametro in PALETA:
		m.set_shader_parameter(parametro,Color(PALETA[parametro]))
	return m

func _montar_espada() -> Node3D:
	var espada := Node3D.new()
	espada.name = "Espada"
	var c := ESPADA_TAMANHO.y
	var l := ESPADA_TAMANHO.x
	var pecas := [
		[BoxMesh.new(), Vector3(0.07*l, 0.62*c, 0.02), Vector3(0, 0.13+0.31*c, 0), Color("d9dee6")],
		[BoxMesh.new(), Vector3(0.22*l, 0.04, 0.06), Vector3(0, 0.11, 0), Color("c8963e")],
		[BoxMesh.new(), Vector3(0.045, 0.16, 0.045), Vector3(0, 0.01, 0), Color("6b4429")],
		[BoxMesh.new(), Vector3(0.07, 0.06, 0.07), Vector3(0, -0.09, 0), Color("c8963e")],
	]
	for p in pecas:
		var malha := MeshInstance3D.new()
		(p[0] as BoxMesh).size = p[1]
		malha.mesh = p[0]
		malha.position = p[2]
		malha.material_override = _material(p[3])
		espada.add_child(malha)
	return espada

## O F3 permite experimentar o golpe na fazenda sem equipar itens nem atingir o solo.
func pedir_golpe_na_fazenda() -> void:
	if not _jogador.modo_fazenda or _acao_do_jogador() not in ["parado", "correr", "espada", "lanca"]:
		return
	if _demonstracao:
		_fila_demonstracao = true
		return
	_iniciar_demonstracao()

func _iniciar_demonstracao(golpe: int = 1) -> void:
	_golpe_demonstracao = golpe
	_demonstracao = true
	_tempo_demonstracao = 0.0
	_direcao_demonstracao = direcao_em_oito(_jogador.direcao_apontada())
	get_node("/root/Sons").tocar("golpe_lanca" if _arma_de_lanca() else "golpe_espada")

func _tem_espada() -> bool:
	return _jogador.usando_espada and not _jogador.usando_lanca and not _jogador.usando_arco \
		and _jogador.id_arma_atual not in ["machado", "maca"]

## Ação a mostrar, ou "" quando ela ainda não tem animação (volta ao Raven 2D).
func _acao_do_jogador() -> String:
	if _jogador.estaMorto or _jogador.caido:
		return "morrer"
	if _jogador.esta_sentado:
		return "sentar" if _jogador._tempo_sentado<TEMPO_SENTAR else "sentado"
	if _jogador.esta_forjando: return ""
	if _jogador.esta_em_acao_fazenda:
		var acao: String=_jogador.no_fazenda.acao_atual
		if acao in ["enxada","picareta"]: return "fazenda_"+acao
		return "fazenda_"+acao if FAZENDA.has(acao) else ""
	if _restante_levantar>0.0 and not _jogador._esta_atacando and _jogador.velocity.length()<2.0: return "levantar"
	var pesca := _jogador.get_node_or_null("AnimacaoPesca")
	if pesca!=null and _jogador.has_node("SessaoPesca"): return "pesca"
	if _jogador.no_arco.esta_disparando():
		return "arco"
	if _jogador.defesa.escudando(): return "escudada"
	if _jogador.defesa.em_guarda():
		if _tem_espada() and (_jogador.usando_escudo or _arma_de_duas_maos()): return "guarda"
		return "guarda_livre" if _jogador.usando_espada or _jogador.usando_lanca else ""
	if _jogador.esta_em_dash:
		return "avanco"
	if _jogador.no_reacao.visible and _jogador.no_reacao.pose_atual == "ferido":
		return "ferido"
	if _demonstracao:
		return "lanca" if _arma_de_lanca() else "espada"
	if _jogador._esta_atacando:
		if _jogador.usando_lanca: return "lanca"
		if _arma_pesada() != null: return "pesada"
		return "espada" if _tem_espada() else ""
	return "correr" if _jogador.velocity.length() > 2.0 else "parado"

## Cores da personalização (aparencia_raven): tom de pele 0..2, cor do cabelo e dos olhos.
const PELES := [Color("edb393"), Color("c98a62"), Color("8d5a3d")]
const OLHOS := [Color("4a3833"), Color("2f6fb0"), Color("3f8a4a"), Color("8a6a2c"), Color("6f6f78"), Color("7a3f9a")]
var _chave_cores := 0

func _aplicar_cores() -> void:
	var aparencia: Dictionary = _jogador.aparencia_raven
	var chave := hash([aparencia.get("pele",0), aparencia.get("cor",[1,1,1,1]), aparencia.get("olhos",0), aparencia.get("cor_cabelo_personalizada",false)])
	if chave == _chave_cores: return
	_chave_cores = chave
	var corpo = _modelo.find_child("CorpoBase",true,false)
	if corpo != null:
		var m: ShaderMaterial = corpo.material_override
		m.set_shader_parameter("pele_base", PELES[clampi(int(aparencia.get("pele",0)),0,2)])
		m.set_shader_parameter("cor_olhos", OLHOS[clampi(int(aparencia.get("olhos",0)),0,OLHOS.size()-1)])
	var cor: Array = aparencia.get("cor",[1,1,1,1])
	var tinta_cabelo := Color(cor[0],cor[1],cor[2])
	var manter_pintura: bool = tinta_cabelo.is_equal_approx(Color.WHITE) and not aparencia.get("cor_cabelo_personalizada", false)
	var material_cabelo := _pecas[3].material_override as ShaderMaterial
	material_cabelo.set_shader_parameter("cor_cabelo", tinta_cabelo)
	material_cabelo.set_shader_parameter("usar_cor_pintada", manter_pintura)
	if corpo != null:
		# Raspado pinta a pele com o tom médio do cabelo (branco = castanho original).
		var tinta := Color(cor[0],cor[1],cor[2])
		var media := Color(0.36,0.24,0.16) if manter_pintura else tinta*0.62
		corpo.material_override.set_shader_parameter("cor_raspado", Color(media.r,media.g,media.b,1.0))
	if _cabeca_referencia!=null:_atualizar_pecas()

func _process(delta: float) -> void:
	_armaduras.atualizar()
	_acabamento_armas.atualizar()
	_aplicar_cores()
	_atualizar_iluminacao()
	_delta_rastro = delta
	_tempo += delta
	if _estava_sentado and not _jogador.esta_sentado: _restante_levantar=TEMPO_LEVANTAR
	else: _restante_levantar=maxf(0.0,_restante_levantar-delta)
	_estava_sentado=_jogador.esta_sentado
	if _demonstracao:
		_tempo_demonstracao += delta
		if _tempo_demonstracao >= _duracoes_combo()[_golpe_demonstracao-1]:
			_demonstracao = false
			if _fila_demonstracao:
				_fila_demonstracao = false
				_iniciar_demonstracao(_golpe_demonstracao % _duracoes_combo().size()+1)
	_restante_recuperacao_espada=maxf(0.0,_restante_recuperacao_espada-delta)
	var acao := _acao_do_jogador() if _player != null else ""
	# Recuperação apenas visual após soltar o ataque: andar, atacar ou defender interrompe imediatamente.
	if acao=="parado" and _tem_espada() and not _arma_de_duas_maos():
		if _acao=="espada" and _golpe_visual_espada in [1,2]:
			_restante_recuperacao_espada=TEMPO_RECUPERACAO_ESPADA
		if _restante_recuperacao_espada>0.0:acao="recuperar_espada"
	else:
		_restante_recuperacao_espada=0.0
	if _demonstracao and acao not in ["espada","lanca"]:
		_demonstracao=false
		_fila_demonstracao=false
	visible = not acao.is_empty()
	if not visible:
		_acao = ""
		_demonstracao = false
		_fila_demonstracao = false
		_rastro.limpar()
		return
	var original: CanvasItem = _jogador.get_node("CompositeSprites")
	modulate = original.modulate*original.self_modulate
	if acao != _acao:
		_inicio_acao = _tempo
	# Oito orientações do mesmo rig, com passos de 45 graus.
	var velocidade: Vector2 = _jogador.velocity
	var olhar: Vector2 = velocidade if acao in ["correr", "avanco"] else _jogador._direcao_ataque
	if acao in ["guarda","escudada"]: olhar=_jogador.defesa.direcao_guarda
	if acao=="pesca": olhar=_jogador.get_node("SessaoPesca")._frente
	if acao=="arco": olhar=_jogador.no_arco._direcao_disparo
	if acao in ["espada","lanca"] and _jogador._esta_atacando:
		olhar=_jogador._direcao_golpe_3d
	if _jogador.esta_sentado:
		olhar=Vector2(0,_jogador._frente_sentado) if _jogador._frente_sentado!=0 else Vector2(_jogador._lado_sentado,0)
	if _demonstracao:
		olhar = _direcao_demonstracao
	if olhar.length() > 0.01:
		var direcao:=direcao_em_oito(olhar)
		_guinada=atan2(direcao.x,direcao.y)
	_modelo.rotation.y = _guinada
	var duracao: float = _player.get_animation(_nome_animacao(acao)).length
	match acao:
		"correr":
			# Um ciclo da animação a cada PASSADA pixels percorridos.
			_tocar(acao, velocidade.length()/PASSADA*duracao)
		"pesada":
			var relogio: Timer = _jogador._temporizador
			var fracao := 1.0-relogio.time_left/relogio.wait_time if not relogio.is_stopped() else 1.0
			_tocar(acao, 0.0)
			_player.seek(lerpf(JANELA_PESADA.x, JANELA_PESADA.y, clampf(fracao, 0.0, 1.0))*duracao, true)
		"espada", "lanca":
			var temporizador: Timer = _jogador._temporizador
			var progresso := 1.0-temporizador.time_left/temporizador.wait_time if not temporizador.is_stopped() else 1.0
			if _demonstracao:
				progresso = _tempo_demonstracao/_duracoes_combo()[_golpe_demonstracao-1]
			_progresso_golpe = progresso
			if acao=="espada":_golpe_visual_espada=clampi(_golpe_demonstracao if _demonstracao else _jogador._fase_combo,1,3)
			_tocar(acao, 0.0)
			_player.seek(clampf(progresso, 0.0, 0.999)*duracao, true)
		"recuperar_espada":
			_tocar(acao,0.0)
			_player.seek(clampf(1.0-_restante_recuperacao_espada/TEMPO_RECUPERACAO_ESPADA,0.0,1.0)*duracao,true)
		"arco":
			_tocar(acao,0.0)
			# Puxada até 40% do disparo; depois o coice da soltura (Standing Aim Recoil).
			var p_arco := progresso_arco()
			_player.seek((minf(p_arco/.40,1.0) if p_arco<.40 else clampf((p_arco-.40)/.60,0.0,0.999))*duracao,true)
		"guarda", "guarda_livre":
			_tocar(acao,0.0)
			_player.seek(fposmod(_tempo-_inicio_acao,duracao),true)
		"pesca":
			_tocar(acao,0.0)
			_player.seek(_instante_pesca(duracao),true)
		"escudada":
			_tocar(acao,0.0)
			var instante: float=_jogador.defesa._tempo
			for q in _jogador.defesa._indice: instante+=_jogador.defesa.QUADROS_ESCUDADA[q][1]
			_player.seek(clampf(instante/0.5,0.0,0.999)*duracao,true)
		"avanco":
			_tocar(acao,0.0)
			var f_dash := clampf((_tempo-_inicio_acao)/maxf(float(_jogador.duracao_dash),0.05),0.0,1.0)
			_player.seek(lerpf(JANELA_DASH.x,JANELA_DASH.y,f_dash)*duracao,true)
		"sentar":
			_tocar(acao,0.0)
			_player.seek(clampf(_jogador._tempo_sentado/TEMPO_SENTAR,0.0,0.999)*duracao,true)
		"levantar":
			_tocar(acao,0.0)
			_player.seek(clampf(1.0-_restante_levantar/TEMPO_LEVANTAR,0.0,0.999)*duracao,true)
		_:
			if acao.begins_with("fazenda_"):
				_tocar(acao,0.0)
				var instante: float=0.0 if acao=="fazenda_plantar" else _progresso_fazenda()*duracao
				if acao in ["fazenda_picareta","fazenda_enxada"]: instante=_instante_picareta(duracao)
				if acao=="fazenda_machado": instante=_instante_machado()
				_player.seek(instante,true)
			else: _tocar(acao, 1.0)
	_acao = acao
	if _cabeca_referencia!=null:_cabeca_referencia.orientar(_modelo.rotation.y)
	_encaixar_espada(acao in ["espada","lanca","guarda","escudada","recuperar_espada"] or (acao=="guarda_livre" and _tem_espada()))
	_encaixar_arma_pesada(acao=="pesada" or (acao=="guarda_livre" and _arma_pesada()!=null))

func usa_combo_espada() -> bool:
	return _tem_espada()

func _nome_animacao(acao: String) -> String:
	if acao=="recuperar_espada":return "quaternius/Sword_Regular_%s_Rec" % ("A" if _golpe_visual_espada==1 else "B")
	if acao=="guarda" and _arma_de_duas_maos(): return "mixamo/GreatSwordBlocking"
	if acao=="arco": return "mixamo/BowDraw" if progresso_arco()<.40 else "mixamo/BowRecoil"
	if acao=="pesada": return "mixamo/MaceAttack" if _jogador.id_arma_atual=="maca" else "mixamo/AxeAttack"
	if acao=="fazenda_machado": return "mixamo/AxeTreeChop"
	if acao in ["fazenda_picareta","fazenda_enxada"]: return "ferramentas/Pickaxing"
	if acao=="pesca": return _clipe_pesca()
	if acao=="fazenda_plantar": return "Idle_Loop"
	if acao.begins_with("fazenda_"): return "fazenda/"+FAZENDA[acao.trim_prefix("fazenda_")][0]
	if acao in ["espada","lanca"]:
		var golpe: int = _golpe_demonstracao if _demonstracao else clampi(_jogador._fase_combo,1,_duracoes_combo().size())
		if acao=="lanca": return COMBO_LANCA.NOMES[golpe-1]
		return COMBO_MONTANTE.NOMES[golpe-1] if _arma_de_duas_maos() else COMBO.NOMES[golpe-1]
	return ANIMACOES[acao]

func _tocar(acao: String, velocidade: float) -> void:
	var nome := _nome_animacao(acao)
	if _player.assigned_animation != nome or acao != _acao:
		_player.play(nome, 0.0 if acao in ["espada","lanca","guarda","guarda_livre","pesada","escudada","avanco","sentar","levantar","pesca","arco"] or acao.begins_with("fazenda_") else MISTURA)
	_player.speed_scale = velocidade

func _encaixar_espada(na_mao: bool) -> void:
	_espada_uma_mao.visible=false
	_montante.visible=false
	_espada=_montante if _arma_de_duas_maos() else _espada_uma_mao
	_espada.visible = not _arma_de_lanca() and (_tem_espada() or _demonstracao)
	_escudo.visible = not _arma_de_lanca() and not _arma_de_duas_maos() and _jogador.usando_escudo and _tem_espada()
	var pai_escudo: Node3D=_mao_esquerda if na_mao else _costas
	if _escudo.get_parent()!=pai_escudo: _escudo.reparent(pai_escudo,false)
	_escudo.position=ESCUDO_MAO_POSICAO if na_mao else ESCUDO_COSTAS_POSICAO
	_escudo.rotation_degrees=Vector3.ZERO if na_mao else ESCUDO_COSTAS_ROTACAO
	_escudo.scale=Vector3.ONE*(ESCUDO_ESCALA_MAO if na_mao else 1.0)
	_lanca.visible = _arma_de_lanca()
	if _acao in ["sentar","sentado","levantar","pesca"]:
		_espada.visible=false
		_lanca.visible=false
		_escudo.visible=false
	var mao: Node3D=_mao
	var pai: Node3D = (_modelo if _arma_de_duas_maos() and _acao in ["espada","guarda"] else mao) if na_mao else _costas
	if _espada.get_parent() != pai:
		_espada.reparent(pai, false)
	_espada.position = MAO_POSICAO if na_mao else (COSTAS_COM_ESCUDO_POSICAO if _escudo.visible else COSTAS_POSICAO)
	_espada.rotation_degrees = MAO_ROTACAO if na_mao else COSTAS_ROTACAO
	if na_mao and _acao in ["espada","guarda","guarda_livre","escudada","recuperar_espada"]:
		var animacao := _player.get_animation(_nome_animacao(_acao))
		_espada.quaternion=animacao.get_meta("rotacao_arma",Quaternion.IDENTITY)
	var pai_lanca: Node3D = _modelo if na_mao else _costas
	if _lanca.get_parent()!=pai_lanca: _lanca.reparent(pai_lanca,false)
	if pai_lanca==_costas:
		_lanca.position=LANCA_COSTAS_POSICAO
		_lanca.rotation_degrees=LANCA_COSTAS_ROTACAO

func _atualizar_rastro(pela_lanca: bool = false) -> void:
	if _arma_de_lanca() and not pela_lanca: return
	if _rastro == null or not visible or _quadro_rastro == Engine.get_process_frames():
		return
	_quadro_rastro = Engine.get_process_frames()
	var na_mao := _acao in ["espada","lanca"]
	var transformacao := _lanca.transform if _arma_de_lanca() else _transformacao_rastro
	var fase: int = _golpe_demonstracao if _demonstracao else _jogador._fase_combo
	_rastro.atualizar(_delta_rastro,transformacao,_nome_animacao(_acao) if na_mao else "",_progresso_golpe,fase,_arma_de_lanca(),_arma_de_duas_maos())

## Machado ou maça usados como arma (não a ferramenta da fazenda); null com outras armas.
func _arma_pesada() -> Node3D:
	if not _jogador.usando_espada or _jogador.usando_lanca or _jogador.usando_arco: return null
	if _jogador.id_arma_atual == "machado": return _machado_arma
	if _jogador.id_arma_atual == "maca": return _maca
	return null

func _encaixar_arma_pesada(na_mao: bool) -> void:
	var ativa := _arma_pesada()
	for arma in [_machado_arma, _maca]:
		arma.visible = arma == ativa and _acao not in ["sentar","sentado","levantar","pesca"]
	if ativa == null: return
	var pai: Node3D = _mao if na_mao else _costas
	if ativa.get_parent() != pai: ativa.reparent(pai, false)
	ativa.position = MAO_POSICAO if na_mao else COSTAS_POSICAO
	ativa.rotation_degrees = MAO_ROTACAO if na_mao else COSTAS_ROTACAO
	if na_mao:
		ativa.quaternion = _player.get_animation(_nome_animacao(_acao)).get_meta("rotacao_arma", Quaternion.IDENTITY)

## Cabo de madeira com cabeça de ferro: lâmina larga (machado) ou bola com cravos (maça).
func _montar_arma_pesada(maca: bool) -> Node3D:
	var arma := Node3D.new()
	arma.name = "MacaArma" if maca else "MachadoArma"
	var pecas := [[BoxMesh.new(), Vector3(.05,.62,.05), Vector3(0,.20,0), Color("6b4429")],
		[BoxMesh.new(), Vector3(.07,.06,.07), Vector3(0,-.12,0), Color("c8963e")]]
	if maca:
		var bola := SphereMesh.new()
		bola.radius = .10
		bola.height = .20
		bola.radial_segments = 10
		bola.rings = 5
		pecas.append([bola, Vector3.ZERO, Vector3(0,.55,0), Color("8d929c")])
		for d in [Vector3(1,0,0),Vector3(-1,0,0),Vector3(0,0,1),Vector3(0,0,-1),Vector3(0,1,0)]:
			pecas.append([BoxMesh.new(), Vector3(.035,.035,.035), Vector3(0,.55,0)+d*.11, Color("c9ced6")])
	else:
		pecas.append([BoxMesh.new(), Vector3(.20,.16,.03), Vector3(.09,.47,0), Color("aeb4bf")])
		pecas.append([BoxMesh.new(), Vector3(.03,.20,.035), Vector3(.19,.47,0), Color("e3e7ec")])
	for p in pecas:
		var malha := MeshInstance3D.new()
		if p[0] is BoxMesh: (p[0] as BoxMesh).size = p[1]
		malha.mesh = p[0]
		malha.position = p[2]
		malha.material_override = _material(p[3])
		arma.add_child(malha)
	arma.visible = false
	return arma

func _arma_de_lanca() -> bool:
	return _jogador.usando_lanca or (_jogador.modo_fazenda and arma_demonstracao==1)

func _duracoes_combo() -> Array:
	if _arma_de_lanca(): return COMBO_LANCA.DURACOES
	return COMBO_MONTANTE.DURACOES if _arma_de_duas_maos() else COMBO.DURACOES

func _arma_de_duas_maos() -> bool:
	return _tem_espada() and (_jogador.id_arma_atual=="espada_gemea" or preload("res://codigo/dados/armas_montantes.gd").MODELOS.has(_jogador.id_arma_atual))

func _montar_montante() -> Node3D:
	var arma:=Node3D.new()
	arma.name="Montante"
	var c := MONTANTE_TAMANHO.y
	var l := MONTANTE_TAMANHO.x
	for p in [[Vector3(.10*l,.88*c,.025),Vector3(0,.14+.44*c,0),Color("d9dee6")],
		[Vector3(.30*l,.045,.065),Vector3(0,.13,0),Color("c8963e")],
		[Vector3(.05,.42,.05),Vector3(0,-.10,0),Color("6b4429")],
		[Vector3(.075,.06,.075),Vector3(0,-.34,0),Color("c8963e")]]:
		var m:=MeshInstance3D.new()
		var caixa:=BoxMesh.new()
		caixa.size=p[0]
		m.mesh=caixa
		m.position=p[1]
		m.material_override=_material(p[2])
		arma.add_child(m)
	return arma

func usa_combo_lanca() -> bool:
	return _jogador.usando_lanca

func _montar_lanca() -> Node3D:
	var lanca := Node3D.new()
	lanca.name = "LancaBase"
	# Haste, empunhadura e anéis independentes. A ponta tem uma crista central.
	for dados in [[Vector3(.035,1.12,.035),Vector3(0,.20,0),Color("8c5a3c")],
		[Vector3(.049,.22,.049),Vector3(0,.03,0),Color("443642")],
		[Vector3(.055,.055,.055),Vector3(0,.75,0),Color("bf8950")],
		[Vector3(.048,.06,.048),Vector3(0,-.35,0),Color("e6d5b8")]]:
		var peca := MeshInstance3D.new()
		var caixa := BoxMesh.new()
		caixa.size = dados[0]
		peca.mesh = caixa
		peca.position = dados[1]
		peca.material_override = _material(dados[2])
		lanca.add_child(peca)
	var ponta := MeshInstance3D.new()
	var malha := ImmediateMesh.new()
	malha.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var topo := Vector3(0,1.04,0)
	var lados := [Vector3(-.075,.82,0),Vector3(0,.76,.028),Vector3(.075,.82,0),Vector3(0,.76,-.028)]
	for i in 4:
		var a: Vector3 = lados[i]
		var b: Vector3 = lados[(i+1)%4]
		malha.surface_set_normal((b-a).cross(topo-a).normalized())
		for v in [a,b,topo]: malha.surface_add_vertex(v)
	malha.surface_end()
	ponta.mesh = malha
	ponta.material_override = _material(Color("e6d5b8"))
	lanca.add_child(ponta)
	return lanca

func _montar_escudo() -> Node3D:
	return preload("res://codigo/jogador/escudo_madeira_3d.gd").construir()

## A animação acompanha os tempos e o impacto do controlador existente.
func _progresso_fazenda() -> float:
	var controlador: Node=_jogador.no_fazenda
	var acao: String=controlador.acao_atual
	if not FAZENDA.has(acao) or controlador._quadros.is_empty(): return 0.0
	var instante: float=controlador._tempo
	var total := 0.0
	var impacto := 0.0
	var indice_impacto: int=controlador.ACOES[acao]["quadro_impacto"]
	for q in controlador._quadros.size():
		var tempo: float=controlador._quadros[q][1]
		total+=tempo
		if q<controlador._indice: instante+=tempo
		if q<indice_impacto: impacto+=tempo
	var pontos: Array=FAZENDA[acao]
	var valor: float=lerpf(pontos[1],pontos[2],clampf(instante/maxf(impacto,0.001),0,1)) if instante<impacto else lerpf(pontos[2],pontos[3],clampf((instante-impacto)/maxf(total-impacto,0.001),0,1))
	return clampf(valor,0.0,0.999)

static func direcao_em_oito(dir: Vector2) -> Vector2:
	if dir.length_squared()<0.0001: return Vector2.DOWN
	return Vector2.from_angle(snappedf(dir.angle(),PI/4.0)).normalized()

func criar_rastro() -> Sprite2D:
	var copia:=Sprite2D.new()
	copia.texture=ImageTexture.create_from_image(_vp.get_texture().get_image())
	copia.centered=false
	copia.offset=_sprite.offset
	copia.scale=_sprite.scale
	copia.material=_sprite.material
	copia.texture_filter=_sprite.texture_filter
	return copia

## Converte o alvo 2D da ferramenta para o chão do viewport em qualquer direção.
func destino_ferramenta_3d() -> Vector3:
	var amostras: float=float(_vp.size.x)/TAMANHO.x
	var pixel: Vector2=_camera.unproject_position(Vector3.ZERO)+direcao_em_oito(_jogador._direcao_ataque)*_jogador.ALCANCE_ACAO_FAZENDA*amostras
	var origem:=_camera.project_ray_origin(pixel)
	var raio:=_camera.project_ray_normal(pixel)
	var contato = Plane(Vector3.UP,0).intersects_ray(origem,raio)
	return _modelo.to_local(contato) if contato is Vector3 else Vector3.ZERO

## Relógio da ação real; não adianta nem repete o sinal de impacto.
func progresso_acao_fazenda() -> float:
	var c: Node=_jogador.no_fazenda
	if c._quadros.is_empty(): return 0.0
	var instante: float=c._tempo
	var total:=0.0
	for i in c._quadros.size():
		var duracao: float=c._quadros[i][1]
		total+=duracao
		if i<c._indice: instante+=duracao
	return clampf(instante/maxf(total,0.001),0,1)

## Clipes originais omitem ossos imóveis (como DEF-spine.001). Os ataques
## importados animam esses ossos: sem uma trilha de retorno, a última pose fica.
func _completar_rotacoes_de_retorno() -> void:
	var retornos: Dictionary={}
	for biblioteca in ["melee","fazenda","mixamo","quaternius"]:
		for nome in _player.get_animation_library(biblioteca).get_animation_list():
			var animacao:=_player.get_animation_library(biblioteca).get_animation(nome)
			for trilha in animacao.get_track_count():
				if animacao.track_get_type(trilha)!=Animation.TYPE_ROTATION_3D: continue
				var caminho:=animacao.track_get_path(trilha)
				if caminho.get_subname_count()!=1: continue
				var osso:=_esqueleto.find_bone(caminho.get_subname(0))
				if osso>=0: retornos[caminho]=_esqueleto.get_bone_pose_rotation(osso)
	var originais:=_player.get_animation_library("")
	for nome in originais.get_animation_list():
		var animacao:=originais.get_animation(nome)
		for caminho in retornos:
			if animacao.find_track(caminho,Animation.TYPE_ROTATION_3D)>=0: continue
			var trilha:=animacao.add_track(Animation.TYPE_ROTATION_3D)
			animacao.track_set_path(trilha,caminho)
			animacao.rotation_track_insert_key(trilha,0.0,retornos[caminho])

## A face do escudo acompanha a estocada do antebraço no contra-ataque,
## compensando o giro do punho do clipe importado.
func orientar_escudo_3d(s: Skeleton3D) -> void:
	if _escudo.get_parent()!=_mao_esquerda: return
	var clipe:=_player.get_animation(_player.assigned_animation)
	var mixamo: bool=_player.assigned_animation.begins_with("mixamo/") or str(clipe.get_meta("fonte","")).begins_with("mixamo/")
	var quaternius := _player.assigned_animation.begins_with("quaternius/") or str(clipe.get_meta("fonte","")).begins_with("quaternius/")
	if _acao!="escudada" and not ((mixamo or quaternius) and _acao in ["espada","guarda","recuperar_espada"]): return
	var mao:=s.get_bone_global_pose(s.find_bone("DEF-hand.L"))
	var cotovelo:=s.get_bone_global_pose(s.find_bone("DEF-forearm.L")).origin
	var normal: Vector3=((mao.origin-cotovelo).normalized()+Vector3.BACK*(0.5 if _acao=="espada" else 2.0)).normalized()
	var lateral:=Vector3.UP.cross(normal).normalized()
	if lateral.length()<0.1: lateral=Vector3.RIGHT
	var base:=Basis(lateral,normal.cross(lateral),normal)
	_escudo.quaternion=(mao.basis.orthonormalized().inverse()*base).get_rotation_quaternion()

## Os clipes seguem o relógio da sessão, sem mudar força, captura ou inventário.
func _clipe_pesca() -> String:
	var sessao=_jogador.get_node("SessaoPesca")
	match sessao.estado:
		sessao.Estado.CARREGANDO, sessao.Estado.LANCANDO: return "mixamo/FishingCast"
		sessao.Estado.BELISCANDO: return "ferramentas/Fishing_Bite"
		sessao.Estado.PUXANDO:
			return "ferramentas/Fishing_Reeling"
		sessao.Estado.PEGOU: return "ferramentas/Fishing_Catch"
	return "mixamo/FishingIdle"

func _instante_pesca(duracao: float) -> float:
	var sessao=_jogador.get_node("SessaoPesca")
	if sessao.estado==sessao.Estado.CARREGANDO: return 1.05
	if sessao.estado==sessao.Estado.LANCANDO:
		var saida: float=sessao.INICIO_ARREMESSO/sessao.DURACAO_LANCE
		var p:=clampf(sessao._tempo/sessao.DURACAO_LANCE,0,1)
		return lerpf(1.05,2.0,p/saida) if p<=saida else lerpf(2.0,2.90,(p-saida)/(1.0-saida))
	if sessao.estado in [sessao.Estado.ESPERANDO,sessao.Estado.PUXANDO]: return fposmod(sessao._tempo,duracao)
	return minf(sessao._tempo,duracao-0.001)

func ponta_pesca_3d() -> Vector2:
	var mundo: Vector3=_ferramentas._vara.to_global(_ferramentas.PONTA_VARA)
	return _jogador.to_local(_sprite.to_global(_camera.unproject_position(mundo)+_sprite.offset))

## Pickaxing contém dois golpes iguais; cada pedido do jogo reproduz somente um.
## O contato do clipe (0,31 s) coincide com o sinal de impacto do controlador.
func _instante_picareta(duracao: float) -> float:
	var t:=progresso_acao_fazenda()
	var impacto:=0.30/0.68
	var contato:=0.31
	if t<=impacto: return lerpf(0.0,contato,t/impacto)
	return lerpf(contato,duracao*0.5,(t-impacto)/(1.0-impacto))

func _sincronizar_linha_pesca() -> void:
	if not visible or _acao!="pesca": return
	var sessao:=_jogador.get_node_or_null("SessaoPesca")
	if sessao!=null: sessao.sincronizar_linha_3d()

func progresso_arco() -> float:
	var c: Node=_jogador.no_arco
	var total:=0.0
	var instante: float=c._tempo
	for i in c.DURACAO_DISPARO.size():
		var d: float=c.DURACAO_DISPARO[i]*c._escala_tempo
		total+=d
		if i<c._indice:instante+=d
	return clampf(instante/maxf(total,.001),0,1)

func _instante_machado() -> float:
	return progresso_acao_fazenda()*preload("res://codigo/jogador/corte_machado_mixamo.gd").DURACAO

## Parte cortante no mesmo espaço 2D do jogador; não inclui cabo, cabelo ou rastro.
## Chamado após os modificadores do esqueleto terminarem o encaixe da arma.
func geometria_golpe_2d() -> Dictionary:
	var mundo := Transform3D.IDENTITY
	var vertices: Array[Vector3] = []
	var janela := Vector2(.25,.75)
	var progresso := _progresso_golpe
	if _acao in ["espada","lanca"]:
		if _acao=="lanca":
			mundo = _lanca.global_transform
			vertices = [Vector3(-.075,.76,0),Vector3(.075,.82,0),Vector3(0,1.04,0)]
		else:
			mundo = _modelo.global_transform*_transformacao_rastro
			var ponta: float = _rastro.ponta_montante if _arma_de_duas_maos() else _rastro.ponta_espada
			vertices = [Vector3(0,.31,0),Vector3(0,ponta,0)]
			janela = _rastro.JANELAS[clampi(_jogador._fase_combo,1,3)-1]
	elif _acao=="pesada":
		var arma := _arma_pesada()
		if arma==null: return {}
		mundo = _esqueleto.global_transform*_esqueleto.get_bone_global_pose(_esqueleto.find_bone(OSSO_MAO))*arma.transform
		var maca: bool = _jogador.id_arma_atual=="maca"
		for x in ([-.14,.14] if maca else [-.02,.21]):
			for y in ([.41,.69] if maca else [.37,.57]):
				vertices.append(Vector3(x,y,0))
		var duracao: float = _player.get_animation(_player.assigned_animation).length
		progresso = clampf((_player.current_animation_position/duracao-JANELA_PESADA.x)/(JANELA_PESADA.y-JANELA_PESADA.x),0.0,1.0)
	else: return {}
	var pontos := PackedVector2Array()
	for vertice in vertices:
		var pixel := _camera.unproject_position(mundo*vertice)
		pontos.append(_jogador.to_local(_sprite.to_global(pixel+_sprite.offset)))
	# A varredura do UAL2 reserva quatro pixels para a espessura e a passagem entre quadros.
	var margem := 4.0 if _acao=="espada" and not _arma_de_duas_maos() else 2.0
	return {"pontos":pontos,"janela":janela,"progresso":progresso,"margem":margem}
