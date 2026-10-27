extends Node
## Perfil físico do rig 3D. A geometria dos golpes vem da arma renderizada,
## mantendo a base no chão e a área de dano presa ao corpo, sem depender da roupa.
const Profundidade := preload("res://codigo/globais/profundidade.gd")
const MARGEM_LAMINA := 2.0
var ativo := false
var jogador: Node2D
var heroi: Node2D
var pes: CollisionShape2D
var dano: CollisionShape2D
var golpe: CollisionShape2D
var area: Area2D
var _originais := {}
var _bibliotecas := {}
var _bibliotecas_3d := {}
var _poligono := ConvexPolygonShape2D.new()
var _anterior := PackedVector2Array()
var _chave_golpe := ""
var _tempo_anterior := -1.0

func _ready() -> void:
	name = "ColisoesBase3D"
	jogador = get_parent()
	pes = jogador.get_node("CollisionShape2D")
	dano = jogador.get_node("AreaDano/CollisionShape2D")
	area = jogador.get_node("AreaAtaque")
	golpe = area.get_node("CollisionShape2D")
	for forma in [pes,dano,golpe]:
		_originais[forma] = {"shape":forma.shape,"transform":forma.transform}
	_originais[area] = area.transform
	process_physics_priority = -100 # Ajusta o perfil antes do movimento do jogador.
	_sincronizar_perfil()

func _physics_process(_delta: float) -> void:
	_sincronizar_perfil()
	if ativo and (not jogador._esta_atacando or jogador.estaMorto or jogador.caido or jogador.esta_em_dash):
		_desativar_golpe()

func _sincronizar_perfil() -> void:
	var atual: Node2D = jogador.get_node_or_null("HeroiBase3D")
	var usar_3d: bool = atual != null and atual.visible
	if ativo and (not usar_3d or atual!=heroi): _restaurar()
	if not ativo and usar_3d:
		heroi = atual
		_ativar()

func _ativar() -> void:
	ativo = true
	_trocar_bibliotecas(true)
	var chao := CircleShape2D.new()
	chao.radius = 5.0
	pes.shape = chao
	pes.position = Vector2(0,Profundidade.PES_JOGADOR)
	var corpo := CapsuleShape2D.new()
	corpo.radius = 6.5
	corpo.height = 31.0
	dano.shape = corpo
	dano.position = Vector2(0,Profundidade.PES_JOGADOR-corpo.height/2.0)
	area.transform = Transform2D.IDENTITY
	golpe.transform = Transform2D.IDENTITY
	_poligono.points = PackedVector2Array([Vector2(-1,-1),Vector2(1,-1),Vector2(0,1)])
	golpe.shape = _poligono
	_desativar_golpe()
	if not heroi._esqueleto.skeleton_updated.is_connected(_atualizar_pose):
		heroi._esqueleto.skeleton_updated.connect(_atualizar_pose)

## Mantém as poses antigas para a lógica; só retira as trilhas que moviam a caixa 2D.
## Cada jogador recebe sua biblioteca, inclusive no cooperativo.
func _trocar_bibliotecas(usar_3d: bool) -> void:
	var player: AnimationPlayer = jogador.reprodutor_anim
	if _bibliotecas.is_empty():
		for nome in player.get_animation_library_list():
			var original := player.get_animation_library(nome)
			_bibliotecas[nome] = original
			var copia := AnimationLibrary.new()
			for acao in original.get_animation_list():
				var animacao: Animation = original.get_animation(acao).duplicate()
				for trilha in range(animacao.get_track_count()-1,-1,-1):
					if "AreaAtaque" in str(animacao.track_get_path(trilha)):
						animacao.remove_track(trilha)
				copia.add_animation(acao,animacao)
			_bibliotecas_3d[nome] = copia
	for nome in _bibliotecas:
		player.remove_animation_library(nome)
		player.add_animation_library(nome,_bibliotecas_3d[nome] if usar_3d else _bibliotecas[nome])

func _restaurar() -> void:
	if is_instance_valid(heroi) and heroi._esqueleto.skeleton_updated.is_connected(_atualizar_pose):
		heroi._esqueleto.skeleton_updated.disconnect(_atualizar_pose)
	_desativar_golpe()
	_trocar_bibliotecas(false)
	for forma in [pes,dano,golpe]:
		forma.shape = _originais[forma].shape
		forma.transform = _originais[forma].transform
	area.transform = _originais[area]
	ativo = false
	heroi = null

func _desativar_golpe() -> void:
	golpe.disabled = true
	_anterior.clear()
	_chave_golpe = ""
	_tempo_anterior = -1.0

## O chão não oscila com a animação; a cápsula de dano acompanha a inclinação do corpo.
func _atualizar_pose() -> void:
	if not ativo or not is_instance_valid(heroi): return
	if not heroi._camera.is_inside_tree(): return
	var s: Skeleton3D = heroi._esqueleto
	var cabeca: Transform3D = s.global_transform*s.get_bone_global_pose(s.find_bone("DEF-head"))
	var pixel: Vector2 = heroi._camera.unproject_position(cabeca*Vector3(0,.14,0))
	var topo: Vector2 = jogador.to_local(heroi._sprite.to_global(pixel+heroi._sprite.offset))
	var base := Vector2(0,Profundidade.PES_JOGADOR)
	var eixo := base-topo
	# topo e base são os extremos visíveis, não os centros das tampas da cápsula.
	dano.position = (topo+base)*.5
	dano.rotation = eixo.angle()-PI/2.0
	dano.shape.height = maxf(eixo.length(),2.0*dano.shape.radius)
	atualizar_golpe()

func atualizar_golpe() -> void:
	if not ativo or not is_instance_valid(heroi): return
	if not jogador._esta_atacando or jogador.estaMorto or jogador.caido or jogador.esta_em_dash or heroi._demonstracao:
		_desativar_golpe()
		return
	var geometria: Dictionary = heroi.geometria_golpe_2d()
	if geometria.is_empty():
		_desativar_golpe()
		return
	var p: float = geometria.progresso
	var janela: Vector2 = geometria.janela
	if p<janela.x or p>janela.y:
		_desativar_golpe()
		return
	var chave := str(heroi._player.assigned_animation)+":"+str(jogador._fase_combo)
	if chave!=_chave_golpe or p<_tempo_anterior: _anterior.clear()
	_chave_golpe = chave
	_tempo_anterior = p
	var pontos: PackedVector2Array = geometria.pontos
	var varredura := pontos.duplicate()
	varredura.append_array(_anterior)
	_anterior = pontos
	var expandidos := PackedVector2Array()
	for ponto in varredura:
		for canto in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
			expandidos.append(ponto+canto*MARGEM_LAMINA)
	var contorno := Geometry2D.convex_hull(expandidos)
	if contorno.size()>1 and contorno[0].is_equal_approx(contorno[-1]): contorno.remove_at(contorno.size()-1)
	area.transform = Transform2D.IDENTITY
	golpe.transform = Transform2D.IDENTITY
	golpe.shape = _poligono
	_poligono.points = contorno
	golpe.disabled = false

func _exit_tree() -> void:
	# O esqueleto também notifica ao desmontar; a câmera já pode ter saído do viewport.
	if is_instance_valid(heroi) and is_instance_valid(heroi._esqueleto):
		if heroi._esqueleto.skeleton_updated.is_connected(_atualizar_pose):
			heroi._esqueleto.skeleton_updated.disconnect(_atualizar_pose)
