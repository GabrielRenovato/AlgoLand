extends CharacterBody2D
## Mesmo rig do personagem, com vestuário independente. Não lê/grava inventário ou save.
const Gerador=preload("res://codigo/dados/gerador_npcs.gd")
@export var semente: int=1
@export_enum("aventureiro","guarda","ferreiro","agricultor","herbalista","mercador","camponesa") var perfil: String="aventureiro"
@export var nome_personagem: String=""
@export var rota: PackedVector2Array=PackedVector2Array()
@export var velocidade: float=22.0
var ficha:Dictionary={}
var rotina:Array=[]
var atividade_atual:String=""
var falas_atividade:Array=[]
var _recolher:=false
var _hora_pendente:=-1.0
var visual:Node2D
var _tempo:=0.0
var distancia_andada:=0.0
var _direcao:=0
var _alvo:=0
var _espera:=0.0
var _pausa:=1.2
var conversando:=false
var _aviso:VisibleOnScreenNotifier2D
var _agente:NavigationAgent2D

func _ready() -> void:
	ficha=Gerador.gerar(semente,perfil) if ficha.is_empty() else Gerador.normalizar(ficha)
	if ficha.is_empty():ficha=Gerador.gerar(semente,perfil)
	perfil=ficha.perfil
	semente=ficha.semente
	if not nome_personagem.is_empty():ficha.nome=nome_personagem
	collision_layer=32 if visible else 0
	collision_mask=64
	var col:=CollisionShape2D.new()
	var forma:=CircleShape2D.new()
	forma.radius=6
	col.shape=forma
	col.position=Vector2(0,8)
	add_child(col)
	if ficha.get("faixa_etaria","")=="crianca":
		visual=preload("res://codigo/npcs/manequim_infantil_3d.gd").new()
		visual.traje_infantil=ficha.traje_infantil
		visual.cabelo_infantil=ficha.cabelo_infantil
	else:
		visual=preload("res://codigo/jogador/representacao_heroi_3d.gd").new()
	visual.aparencia=ficha.aparencia
	visual.armadura_npc=ficha.get("armadura_npc","")
	visual.perfil_movimento=ficha.movimento
	add_child(visual)
	preload("res://codigo/npcs/acessorios_npc_3d.gd").aplicar(visual,ficha)
	_aviso=VisibleOnScreenNotifier2D.new()
	_aviso.rect=Rect2(-32,-64,64,80)
	add_child(_aviso)
	_agente=NavigationAgent2D.new()
	_agente.path_desired_distance=4
	_agente.target_desired_distance=5
	add_child(_agente)
	_agente.target_position=global_position
	visual.renderizado.connect(_atualizar_nome,CONNECT_ONE_SHOT)

func _atualizar_nome() -> void:
	var etiqueta:=Label.new()
	etiqueta.name="NomeNPC"
	etiqueta.text=ficha.nome
	etiqueta.add_theme_font_size_override("font_size",8)
	etiqueta.add_theme_color_override("font_outline_color",Color("24202a"))
	etiqueta.add_theme_constant_override("outline_size",2)
	etiqueta.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	etiqueta.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	etiqueta.tooltip_text=preload("res://codigo/dados/variacao_npcs.gd").nome_completo(ficha)
	etiqueta.size=Vector2(96,14)
	add_child(etiqueta)
	etiqueta.size.y=maxf(14,etiqueta.get_combined_minimum_size().y)
	etiqueta.position=Vector2(-48,visual.topo_aparente()-etiqueta.size.y-6)

func _physics_process(delta: float) -> void:
	if visual==null:return
	_tempo+=delta
	velocity=Vector2.ZERO
	if not conversando and not rota.is_empty() and _espera<=0.0 and NavigationServer2D.map_get_iteration_id(_agente.get_navigation_map())>0:
		var destino:=rota[_alvo]
		if global_position.distance_to(destino)<7:
			_alvo=(_alvo+1)%rota.size()
			_espera=_pausa*randf_range(.7,1.3)
			if _recolher:
				visible=false
				collision_layer=0
		else:
			if not _agente.target_position.is_equal_approx(destino):_agente.target_position=destino
			var proximo:=_agente.get_next_path_position()
			if not _agente.is_navigation_finished():velocity=global_position.direction_to(proximo)*velocidade
	_espera=maxf(0,_espera-delta)
	var antes:=global_position
	move_and_slide()
	var deslocamento:=global_position.distance_to(antes)
	distancia_andada+=deslocamento
	if velocity.length()>1:_direcao=_indice_direcao(velocity)
	z_index=preload("res://codigo/globais/profundidade.gd").z_de(global_position.y+8)
	if _aviso.is_on_screen():
		var andando:=deslocamento>.001
		var duracao:float=visual.duracao_caminhada()
		if conversando:visual.pose_conversa(_direcao,_tempo)
		else:visual.pose_caminhada(andando,_direcao,distancia_andada/visual.passada_caminhada()*duracao if andando else _tempo)

func _indice_direcao(v: Vector2) -> int:
	if absf(v.x)>absf(v.y):return 1 if v.x>0 else 3
	return 0 if v.y>0 else 2

func iniciar_conversa(posicao_jogador: Vector2) -> void:
	conversando=true
	velocity=Vector2.ZERO
	_direcao=_indice_direcao(posicao_jogador-global_position)
	visual.pose_conversa(_direcao,_tempo)

func encerrar_conversa() -> void:
	conversando=false
	_espera=.6
	if _hora_pendente>=0:atualizar_rotina(_hora_pendente)

## A cena resolve os pontos pela navegação antes de entregar a agenda.
func atualizar_rotina(hora: float,inicial: bool=false) -> void:
	if rotina.is_empty():return
	_hora_pendente=hora
	if conversando:return
	var periodo:Dictionary=rotina[0]
	for trecho in rotina:
		if float(trecho.hora)<=fposmod(hora,24):periodo=trecho
	if atividade_atual==periodo.id:return
	atividade_atual=periodo.id
	falas_atividade=periodo.falas
	if periodo.has("velocidade"):velocidade=float(periodo.velocidade)
	_recolher=periodo.get("em_casa",false)
	_pausa=float(periodo.get("pausa",1.2))
	rota=periodo.rota
	_alvo=0
	# Ao entrar na vila cada morador sai num instante diferente, para não andarem em fila;
	# nas trocas de atividade ao longo do dia ele parte na hora.
	_espera=randf_range(.3,2.5) if inicial else 0.0
	visible=true
	collision_layer=32
	if inicial:
		position=rota[0]
		# Quem já nasce no primeiro ponto parte para o seguinte, sem cumprir a pausa de chegada.
		if rota.size()>1:_alvo=1
		visible=not _recolher
		collision_layer=32 if visible else 0
