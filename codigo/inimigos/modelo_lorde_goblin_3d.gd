extends Node3D
## Visual 3D com eventos de combate. O ator consumidor decide quem recebe dano.
signal impacto(acao: StringName, indice: int, centro_local: Vector3, raio_m: float)
signal aviso_area(acao: StringName, centro_local: Vector3, raio_m: float)
signal acao_concluida(acao: StringName)

const DADOS_ATAQUES = preload("res://assets/inimigos/lorde_goblin_3d/animacoes.json")
@export var exibir_efeitos := true
var _aneis: Array[MeshInstance3D] = []
var _tornado: MeshInstance3D
var _material_tornado: StandardMaterial3D
var animador: AnimationPlayer
var _acao: StringName = &""
var _proximo_evento := 0
var _sequencia := 0

func _ready() -> void:
	for instancia in find_children("*", "MeshInstance3D", true, false):
		# O martelo sai dos limites do repouso durante a varrida e o giro.
		instancia.extra_cull_margin = 12.0
		for indice in instancia.mesh.get_surface_count():
			var material = instancia.mesh.surface_get_material(indice)
			if material is BaseMaterial3D:
				material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	animador = find_children("*", "AnimationPlayer", true, false)[0]
	animador.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	animador.get_animation("parado").loop_mode = Animation.LOOP_LINEAR
	if animador.has_animation("andar"):animador.get_animation("andar").loop_mode=Animation.LOOP_LINEAR
	animador.animation_finished.connect(_ao_terminar)
	_criar_efeitos()
	animador.play("parado")
	animador.advance(0.0)

## Os clipes do Mixamo são lentos para um chefe de ação (golpe de 2 s, giro de 3,8 s): tocar mais rápido encurta
## a anticipação sem mexer nos eventos, que seguem a posição da animação e não o relógio.
@export var velocidade_ataque := 1.4
@export var velocidade_andar := 1.3

func _process(delta: float) -> void:
	var anterior := _acao
	var fator := velocidade_ataque if not _acao.is_empty() else (velocidade_andar if animador.current_animation == &"andar" else 1.0)
	animador.advance(delta*fator)
	if not _acao.is_empty() and anterior == _acao:
		_emitir_eventos(animador.current_animation_position)
	amostrar_efeitos(_acao, animador.current_animation_position if not _acao.is_empty() else 0.0)

func tocar_ataque(nome: StringName) -> bool:
	if not _acao.is_empty() or not DADOS_ATAQUES.data.has(String(nome)) or not animador.has_animation(nome):
		return false
	_sequencia += 1
	_acao = nome
	_proximo_evento = 0
	animador.play(nome, 0.10)
	animador.advance(0.0)
	return true

func cancelar_ataque() -> void:
	_sequencia += 1
	amostrar_efeitos(&"", 0.0)
	_acao = &""
	_proximo_evento = 0
	animador.play("parado", 0.0)
	animador.advance(0.0)

func _emitir_eventos(tempo: float) -> void:
	var acao := _acao
	var sequencia := _sequencia
	var eventos: Array = DADOS_ATAQUES.data[String(acao)]["eventos"]
	while _proximo_evento < eventos.size() and _acao == acao and _sequencia == sequencia:
		var evento: Dictionary = eventos[_proximo_evento]
		if float(evento["tempo_s"]) > tempo + .00001:
			break
		var indice := _proximo_evento
		_proximo_evento += 1
		var ponto: Array = evento["centro_local_m"]
		var centro := Vector3(ponto[0], ponto[1], ponto[2])
		if evento["tipo"] == "aviso":
			aviso_area.emit(acao, centro, float(evento["raio_m"]))
		else:
			impacto.emit(acao, indice, centro, float(evento["raio_m"]))

func _ao_terminar(nome: StringName) -> void:
	if _acao.is_empty() or nome != _acao:
		return
	var concluida := _acao
	var sequencia := _sequencia
	_emitir_eventos(animador.get_animation(nome).length)
	if _acao != concluida or _sequencia != sequencia:
		return
	_acao = &""
	animador.play("parado", 0.18)
	acao_concluida.emit(concluida)

func _criar_efeitos() -> void:
	for cor in [Color("e7a75a"),Color("dfd6bd"),Color("91c7bc")]:
		var anel := MeshInstance3D.new()
		var malha := TorusMesh.new()
		malha.inner_radius = .965
		malha.outer_radius = 1.0
		malha.rings = 64
		malha.ring_segments = 8
		anel.mesh = malha
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = cor
		anel.material_override = material
		anel.visible = false
		add_child(anel)
		_aneis.append(anel)
	_criar_tornado()

## Amostra determinística: reprodução e revisão usam os mesmos efeitos e tempos.
func amostrar_efeitos(acao: StringName, tempo: float) -> void:
	for anel in _aneis: anel.visible = false
	if is_instance_valid(_tornado):_tornado.visible = false
	if not exibir_efeitos or _aneis.size()!=3:
		return
	if acao == &"impacto_area":
		var evento: Dictionary = DADOS_ATAQUES.data["impacto_area"]["eventos"][1]
		var ponto: Array = evento["centro_local_m"]
		var centro := Vector3(ponto[0],.035,ponto[2])
		var impacto_s := float(evento["tempo_s"])
		var aviso_s := float(DADOS_ATAQUES.data["impacto_area"]["eventos"][0]["tempo_s"])
		if tempo >= aviso_s and tempo < impacto_s:
			_exibir_anel(0,centro,float(evento["raio_m"]),.45+.2*sin(tempo*24.0))
		elif tempo >= impacto_s and tempo < impacto_s+.53:
			var fase := (tempo-impacto_s)/.53
			_exibir_anel(1,centro,lerpf(.30,float(evento["raio_m"]),fase),1.0-fase)
	elif acao == &"giro_area":
		var evento: Dictionary = DADOS_ATAQUES.data["giro_area"]["eventos"][0]
		var ponto: Array = evento["centro_local_m"]
		var janela: Array = DADOS_ATAQUES.data["giro_area"]["pegada_dupla"]
		if tempo < float(janela[0]) or tempo >= float(janela[1]):return
		var intensidade := minf((tempo-float(janela[0]))/.15,(float(janela[1])-tempo)/.15)
		_exibir_anel(2,Vector3(ponto[0],.035,ponto[2]),float(evento["raio_m"]),.26*clampf(intensidade,0.0,1.0))
		_tornado.visible = true
		_tornado.position = Vector3(ponto[0],0.0,ponto[2])
		_tornado.rotation.y = -(tempo-float(janela[0]))*13.0
		var forca := clampf(intensidade,0.0,1.0)
		_tornado.scale = Vector3.ONE*lerpf(.72,1.0,forca)
		var fase := clampf((tempo-float(janela[0]))/(float(janela[1])-float(janela[0])),0.0,1.0)
		var elevacao := float(DADOS_ATAQUES.data["giro_area"].get("elevacao_max_m",0.0))*pow(sin(PI*fase),2.0)
		# A base continua junto ao chão; o funil cresce com a subida do chefe.
		_tornado.scale.y *= 1.0+elevacao/3.2
		_material_tornado.albedo_color.a = .42*forca

func _exibir_anel(indice: int, centro: Vector3, raio: float, opacidade: float) -> void:
	var anel := _aneis[indice]
	anel.visible = true
	anel.position = centro
	anel.scale = Vector3(raio,.35,raio)
	var material: StandardMaterial3D = anel.material_override
	material.albedo_color.a = opacidade

## Fitas de vento em espiral: geometria leve e contínua, sem cobrir a silhueta.
func _criar_tornado() -> void:
	_tornado = MeshInstance3D.new()
	_tornado.name = "TornadoDoMartelo"
	var superficie := SurfaceTool.new()
	superficie.begin(Mesh.PRIMITIVE_TRIANGLES)
	for fita in 3:
		for segmento in 96:
			var quad: Array[Vector3] = []
			var cores: Array[Color] = []
			for ponta in 2:
				var u := (segmento+ponta)/96.0
				var angulo := u*TAU*1.20+fita*TAU/3.0
				var raio := lerpf(.80,3.35,pow(u,.72))
				var altura := .12+u*3.20
				var largura := lerpf(.065,.18,u)
				var opacidade := pow(sin(PI*u),.65)
				for borda in [-1.0,1.0]:
					quad.append(Vector3(cos(angulo)*raio,altura+borda*largura,sin(angulo)*raio))
					cores.append(Color(.78+.17*u,.86+.11*u,.86+.12*u,opacidade))
			for indice in [0,2,1,1,2,3]:
				superficie.set_color(cores[indice])
				superficie.add_vertex(quad[indice])
	_tornado.mesh = superficie.commit()
	_material_tornado = StandardMaterial3D.new()
	_material_tornado.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material_tornado.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material_tornado.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	_material_tornado.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material_tornado.vertex_color_use_as_albedo = true
	_material_tornado.albedo_color = Color(.70,.81,.80,.42)
	_tornado.material_override = _material_tornado
	_tornado.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_tornado.visible = false
	add_child(_tornado)

func definir_andando(andando: bool) -> void:
	if not _acao.is_empty():return
	var clipe := "andar" if andando and animador.has_animation("andar") else "parado"
	if animador.current_animation!=clipe:
		animador.play(clipe,.12)
