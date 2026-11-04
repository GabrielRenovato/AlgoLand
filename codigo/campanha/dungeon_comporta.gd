extends Node2D
## Galerias da campanha: terreno reutilizado, ocupação goblin e mecanismo final.
signal guardiao_vencido
const PLANTA := preload("res://codigo/fendas/plantas/andar_04.json")
const Objeto := preload("res://codigo/campanha/objeto_caverna.gd")
const Rotina := preload("res://codigo/campanha/rotina_goblin_acampamento.gd")
const LORDE := preload("res://cenas/inimigos/lorde_goblin.tscn")
const GOBLINS := [preload("res://cenas/inimigos/goblin_pomar.tscn"),preload("res://cenas/inimigos/goblin_machado_fenda.tscn")]
const PONTO_ALAVANCA := Vector2(1144,32)
const PONTO_GUARDIAO := Vector2(1200,56)
var terreno:Node2D
var decoracao:Node2D
var alavanca:Node2D
var objetos:Array[Node2D]=[]
var inimigos:Array[Node2D]=[]
var guardiao:Node2D
var guardiao_derrotado:=false
var aberta:=false
var pronta:=false
var acampamentos:Array[Dictionary]=[]

func _ready() -> void:
	name="GaleriasDaComporta"
	terreno=preload("res://cenas/fendas/terreno_04.tscn").instantiate();add_child(terreno)
	terreno.get_node("Chegada_portal").remove_from_group("chegada")
	decoracao=Node2D.new();decoracao.name="ObjetosDaHistoria";add_child(decoracao)
	_montar_objetos()
	var estacoes:Node=terreno.get_node("Estacoes")
	estacoes.estacao_mudou.connect(definir_estacao);definir_estacao(estacoes.estacao_atual)
	_preparar.call_deferred()

func limites() -> Rect2:
	var d:Array=PLANTA.data.limites
	return Rect2(global_position+Vector2(d[0],d[1]),Vector2(d[2],d[3]))

func entrada() -> Vector2:
	return to_global(Vector2(PLANTA.data.entrada[0],PLANTA.data.entrada[1]))

func alvo_final() -> Vector2:
	if aberta or guardiao_derrotado:return to_global(PONTO_ALAVANCA+Vector2(0,28))
	return guardiao.global_position if is_instance_valid(guardiao) else to_global(PONTO_GUARDIAO)

func vincular_guardiao(inimigo:Node2D) -> void:
	guardiao=inimigo
	inimigo.inimigo_morreu.connect(registrar_guardiao_derrotado,CONNECT_ONE_SHOT)

func registrar_guardiao_derrotado() -> void:
	guardiao_derrotado=true;guardiao_vencido.emit()

func abrir() -> bool:
	if not guardiao_derrotado and not aberta:return false
	aberta=true;alavanca.definir_aberta(true)
	return true

func restaurar_aberta() -> void:
	guardiao_derrotado=true
	if is_instance_valid(guardiao):guardiao.queue_free()
	abrir()

func definir_estacao(indice:int) -> void:
	for objeto in objetos:objeto.definir_estacao(indice)

func _objeto(tipo:String,ponto:Vector2,base:Vector2) -> Node2D:
	var objeto:=Objeto.new();objeto.tipo=tipo;objeto.position=ponto;objeto.base=base
	objeto.name=tipo.capitalize()+str(objetos.size());decoracao.add_child(objeto);objetos.append(objeto)
	return objeto

func _montar_objetos() -> void:
	alavanca=_objeto("alavanca",PONTO_ALAVANCA,Vector2(20,12))
	# O portão isolado foi retirado. O comando da água permanece na câmara final.
	for setor in PLANTA.data.setores:
		if int(setor.grupos)==0:continue
		var centro:=Vector2(setor.centro[0],setor.centro[1])
		var cozinha:bool=setor.id in ["area_1","area_4","area_6","area_8"]
		var refeicao:bool=setor.id in ["area_2","area_5","area_7"]
		var pontos:Array[Vector2]
		var foco:=centro
		var no_foco:Node2D
		if cozinha:
			foco=centro+Vector2(-40,-32)
			no_foco=_objeto("fogueira_panela",foco,Vector2(30,18))
			_objeto("mesa",centro+Vector2(56,56),Vector2(44,18))
			_objeto("cadeira",centro+Vector2(56,96),Vector2(12,10))
			_objeto("suprimentos",centro+Vector2(-88,96),Vector2(36,20))
			pontos=[Vector2(-88,-8),Vector2(8,-32),Vector2(16,96),Vector2(-112,64),Vector2(112,-40),Vector2(40,-112)]
		elif refeicao:
			foco=centro+Vector2(-24,0)
			no_foco=_objeto("mesa",foco,Vector2(44,18))
			for deslocamento in [Vector2(-56,40),Vector2(8,40)]:_objeto("cadeira",centro+deslocamento,Vector2(12,10))
			_objeto("suprimentos",centro+Vector2(88,-80),Vector2(36,20))
			pontos=[Vector2(-96,0),Vector2(56,12),Vector2(-72,88),Vector2(64,92),Vector2(-24,-104),Vector2(112,-12)]
		else:
			_objeto("barricada",centro+Vector2(-88,-64),Vector2(48,12))
			_objeto("suprimentos",centro+Vector2(72,64),Vector2(36,20))
			if setor.id!="area_10":_objeto("suprimentos",centro+Vector2(72,-64),Vector2(36,20))
			pontos=[Vector2(-112,24),Vector2(-32,-96),Vector2(104,16),Vector2(8,104),Vector2(-72,96),Vector2(104,-104)]
		acampamentos.append({"id":setor.id,"centro":centro,"cozinha":cozinha,"refeicao":refeicao,"foco":foco,"no_foco":no_foco,"pontos":pontos})

func _preparar() -> void:
	await get_tree().physics_frame
	await get_tree().process_frame
	_acomodar_objetos()
	await get_tree().physics_frame
	terreno.get_node("Navegacao").atualizar_mineracao(decoracao)
	await get_tree().physics_frame
	NavigationServer2D.map_force_update(get_world_2d().navigation_map)
	_povoar()
	if not guardiao_derrotado:
		var chefe:Node2D=LORDE.instantiate()
		chefe.position=NavigationServer2D.map_get_closest_point(get_world_2d().navigation_map,to_global(PONTO_GUARDIAO))-global_position
		chefe.set_meta("subsolo_bacia",true)
		add_child(chefe);vincular_guardiao(chefe)
	pronta=true

func _acomodar_objetos() -> void:
	# A rocha nativa varia entre câmaras: a base do móvel precisa caber de verdade.
	var reservados:Array[Rect2]=[]
	var mapa:=get_world_2d().navigation_map
	for objeto in objetos:
		var folga:=Vector2(40,80) if objeto.tipo=="cadeira" else Vector2(8,8)
		var forma:=RectangleShape2D.new();forma.size=objeto.base+folga
		var consulta:=PhysicsShapeQueryParameters2D.new();consulta.shape=forma;consulta.collision_mask=64
		consulta.exclude=[objeto.get_node("BaseFisica").get_rid()]
		var candidatos:Array[Vector2]=[objeto.global_position]
		if objeto!=alavanca:
			for raio in [16,32,48,64,80]:
				for i in 8:candidatos.append(objeto.global_position+Vector2.from_angle(i*TAU/8)*raio)
		var acomodado:=false
		for candidato in candidatos:
			if NavigationServer2D.map_get_closest_point(mapa,candidato).distance_to(candidato)>3:continue
			var ret:=Rect2(candidato-forma.size*.5,forma.size)
			if reservados.any(func(outro):return outro.intersects(ret)):continue
			consulta.transform=Transform2D(0,candidato)
			if not get_world_2d().direct_space_state.intersect_shape(consulta,1).is_empty():continue
			objeto.global_position=candidato
			objeto.sprite.z_index=objeto.Profundidade.z_de(candidato.y)
			reservados.append(ret);acomodado=true;break
		if not acomodado:push_error("Objeto sem base livre: "+objeto.name)

func _povoar() -> void:
	var mapa:=get_world_2d().navigation_map
	var usados:Array[Vector2]=[]
	var consulta:=PhysicsShapeQueryParameters2D.new();var forma:=CircleShape2D.new();forma.radius=12
	consulta.shape=forma;consulta.collision_mask=64
	for acampamento in acampamentos:
		for indice in acampamento.pontos.size():
			var desejado:Vector2=to_global(acampamento.centro+acampamento.pontos[indice])
			var ponto:=Vector2.INF
			var candidatos:Array[Vector2]=[desejado]
			for raio in [16,32,48,64]:
				for i in 8:candidatos.append(desejado+Vector2.from_angle(i*TAU/8)*raio)
			for candidato in candidatos:
				if usados.any(func(outro):return outro.distance_to(candidato)<32):continue
				if NavigationServer2D.map_get_closest_point(mapa,candidato).distance_to(candidato)>3:continue
				consulta.transform=Transform2D(0,candidato)
				if not get_world_2d().direct_space_state.intersect_shape(consulta,1).is_empty():continue
				ponto=candidato;break
			if not ponto.is_finite():push_error("Sem posição para goblin em "+str(acampamento.id));continue
			var mob:Node2D=GOBLINS[(indice+acampamentos.find(acampamento))%2].instantiate()
			var atividade:="cozinhar" if acampamento.cozinha and indice<2 else "refeicao" if acampamento.refeicao and indice<4 else "vigiar"
			mob.ia_habilitada=false;mob.armadura_goblin=true
			mob.vida=96 if mob.arma_goblin=="machado" else 70
			mob.dano=8.0 if mob.arma_goblin=="machado" else 5.0
			mob.position=to_local(ponto);mob.set_meta("subsolo_bacia",true)
			mob.set_meta("grupo_andar",str(acampamento.id)+"_0");mob.set_meta("atividade_acampamento",atividade);add_child(mob)
			var roteiro=get_parent().get("roteiro")
			if is_instance_valid(roteiro) and is_instance_valid(roteiro.cena.saque_inicial):roteiro.cena.saque_inicial.registrar(mob)
			var rotina:=Rotina.new();rotina.atividade=atividade
			rotina.alvo_atividade=acampamento.no_foco.global_position if atividade!="vigiar" and is_instance_valid(acampamento.no_foco) else to_global(acampamento.centro)
			mob.add_child(rotina)
			inimigos.append(mob);usados.append(ponto)
