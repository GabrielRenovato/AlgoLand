extends Node
## A transmissão externa revela o bloqueio; a comporta principal só abre pelo subsolo.
const REGISTROS := ["registro_entrada","registro_desvio","registro_retorno"]
const ORIGEM_SUBSOLO := Vector2(4096,0)
const Dungeon := preload("res://codigo/campanha/dungeon_comporta.gd")
var cena:Node2D
var terreno:Node2D
var dentro:=false
var sala:Rect2
var limite_externo:Rect2
var guardioes:Array[Node2D]=[]
var dungeon:Node2D
var _alvo_externo:=Vector2.ZERO
var _saida_externa:=Vector2.ZERO

func iniciar(mundo:Node2D,mapa:Node2D) -> void:
	cena=mundo;terreno=mapa;limite_externo=terreno.limites
	atualizar()
	var retorno:Dictionary=cena.controlador.progresso.ponto_retorno()
	if retorno.get("regiao","")=="moinho":
		var p:Array=retorno.get("posicao",[])
		if p.size()==2 and float(p[0])>2704:_restaurar_interior.call_deferred(Vector2(p[0],p[1]))

func cumpridos() -> Array:
	return cena.controlador.progresso.objetivos_cumpridos("moinho_vazao")

func atualizar() -> void:
	if not is_instance_valid(cena) or not is_instance_valid(terreno):return
	var aberta:bool="dungeon" in cumpridos()
	for id in REGISTROS:
		if cena.alvos.has(id):cena.alvos[id].no.visible=false
	terreno.atualizar_fluxo_puzzle([2,0,2],aberta)
	if dentro:
		for id in ["margem_secura","comporta_moinho","roda_moinho"]:cena.alvos[id].no.visible=false
		cena.alvos.entrada_dungeon.no.visible=not aberta
		cena.alvos.entrada_dungeon.no.position=cena.to_local(dungeon.to_global(Dungeon.PONTO_ALAVANCA+Vector2(0,28)))
		if aberta and not dungeon.aberta:dungeon.restaurar_aberta()
	else:
		cena.alvos.entrada_dungeon.no.visible="eixo" in cumpridos()

func interagir(id:String) -> Dictionary:
	var feitos:=cumpridos()
	if id in REGISTROS:return {"texto":"O comando principal fica nas galerias sob a bacia."}
	if id=="comporta_moinho" and not "margem" in feitos:
		return {"texto":"Siga as marcas do nível da água na margem para descobrir onde a corrente foi represada."}
	if id=="roda_moinho" and not "comporta" in feitos:
		return {"texto":"A roda está parada. Examine a transmissão externa antes de seguir o mecanismo até a entrada antiga."}
	if id=="entrada_dungeon" and not dentro:
		if not "eixo" in feitos:return {"texto":"As marcas da transmissão revelam por onde alcançar o comando subterrâneo."}
		_entrar()
		return {"texto":"Os goblins ocuparam as galerias do canal. A alavanca principal fica na câmara ao fundo."}
	if id=="saida_regiao" and dentro:
		_sair();return {"texto":"Você voltou à bacia. A roda está girando novamente." if "dungeon" in feitos else "Você voltou à bacia. A água continua represada no subsolo."}
	if id=="entrada_dungeon" and dentro and not dungeon.guardiao_derrotado:
		return {"texto":"O guardião da câmara mantém o mecanismo travado. Derrote-o antes de puxar a alavanca."}
	# O controlador registra a abertura antes de atualizar sprites, corrente e roda.
	return {}

func alvo_do_puzzle() -> String:
	return "comporta_moinho"

func instrucao_do_puzzle() -> String:
	return "Examine a transmissão externa: a água está presa por um comando no subsolo."

func alvo_interno() -> Dictionary:
	if not dentro:return {}
	if "dungeon" in cumpridos():
		return {"base":cena.alvos.saida_regiao.no.global_position,"combate":false}
	return {"base":dungeon.alvo_final(),"combate":not dungeon.guardiao_derrotado}

func instrucao_interna() -> String:
	if "dungeon" in cumpridos():return "A água voltou ao moinho. Retorne pela entrada e leve a notícia a Nilo."
	if dungeon.guardiao_derrotado:return "Puxe a alavanca principal para liberar a comporta."
	return "Atravesse as galerias e encontre a câmara da comporta. Seu guardião protege a alavanca."

func _process(delta:float) -> void:
	if not is_instance_valid(cena) or not is_instance_valid(cena.jogador):return
	var camera:=cena.jogador.get_node("Camera2D") as Camera2D
	if dentro and is_instance_valid(dungeon) and is_instance_valid(dungeon.guardiao) and dungeon.guardiao.em_combate:
		# O chefe é maior que os guardas: manter cabeça, martelo e jogador no quadro.
		var rumo:Vector2=(dungeon.guardiao.global_position-cena.jogador.global_position)*.35
		camera.offset=camera.offset.lerp(rumo.clamp(Vector2(-60,-60),Vector2(60,60)),1.0-exp(-delta*3.0))
		return
	var perto:bool=not dentro and cena.jogador.position.distance_to(Vector2(-368,-128))<110
	camera.offset=camera.offset.lerp(Vector2(0,-72) if perto else Vector2.ZERO,1.0-exp(-delta*3.0))

func _montar_sala() -> void:
	if is_instance_valid(dungeon):return
	dungeon=Dungeon.new();dungeon.position=ORIGEM_SUBSOLO;terreno.add_child(dungeon)
	dungeon.terreno.get_node("Estacoes").definir_estacao(terreno.estacao_atual,true)
	sala=dungeon.limites()
	dungeon.guardiao_vencido.connect(cena._atualizar)
	if "dungeon" in cumpridos():dungeon.restaurar_aberta()

func _limitar_camera(ret:Rect2) -> void:
	var camera:Camera2D=cena.jogador.get_node("Camera2D")
	camera.limit_left=int(ret.position.x);camera.limit_top=int(ret.position.y)
	camera.limit_right=int(ret.end.x);camera.limit_bottom=int(ret.end.y)
	camera.reset_smoothing()

func _entrar() -> void:
	_montar_sala()
	dentro=true;dungeon.show();dungeon.process_mode=Node.PROCESS_MODE_INHERIT
	_alvo_externo=cena.alvos.entrada_dungeon.no.position
	_saida_externa=cena.alvos.saida_regiao.no.position
	cena.alvos.entrada_dungeon.nome="Alavanca principal"
	cena.alvos.entrada_dungeon.rotulo.text="Alavanca principal"
	cena.alvos.saida_regiao.no.position=cena.to_local(dungeon.entrada())
	cena.alvos.saida_regiao.nome="Voltar para a bacia"
	cena.alvos.saida_regiao.rotulo.text="Voltar para a bacia"
	cena.jogador.global_position=dungeon.entrada()+Vector2(32,0)
	cena.limites=sala;terreno.limites=sala;_limitar_camera(sala)
	cena._atualizar()

func _sair() -> void:
	dentro=false;dungeon.hide();dungeon.process_mode=Node.PROCESS_MODE_DISABLED
	cena.alvos.entrada_dungeon.no.position=_alvo_externo
	cena.alvos.entrada_dungeon.nome="Entrada das galerias"
	cena.alvos.entrada_dungeon.rotulo.text="Entrada das galerias"
	cena.alvos.saida_regiao.no.position=_saida_externa
	cena.alvos.saida_regiao.nome="Voltar ao mapa"
	cena.alvos.saida_regiao.rotulo.text="Voltar ao mapa"
	cena.jogador.position=Vector2(0,72)
	cena.limites=limite_externo;terreno.limites=limite_externo;_limitar_camera(limite_externo)
	cena._atualizar()

func _restaurar_interior(ponto:Vector2) -> void:
	_entrar()
	while not dungeon.pronta:await get_tree().physics_frame
	if terreno.ponto_seguro(ponto):cena.jogador.position=ponto
	cena.salvar_retorno()
