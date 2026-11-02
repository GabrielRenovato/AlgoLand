extends Node
## Fluxo da Bacia: registros locais, eixo protegido e uma sala sob a praça.
const REGISTROS := ["registro_entrada", "registro_desvio", "registro_retorno"]
const SOLUCAO := [2, 0, 2]
const NOMES_ESTADOS := ["fechado", "pela metade", "aberto"]
var cena: Node2D
var terreno: Node2D
var posicoes: Array[int] = [0, 2, 0]
var desenhos: Array[Node2D] = []
var dentro := false
var sala: Rect2
var limite_externo: Rect2
var guardioes: Array[Node2D] = []
var _alvo_externo := Vector2.ZERO
var _saida_externa := Vector2.ZERO
var _montado := false

func iniciar(mundo: Node2D, mapa: Node2D) -> void:
	cena = mundo
	terreno = mapa
	limite_externo = terreno.limites
	for id in REGISTROS:
		var p: Array = terreno.dados.alvos[id].p
		desenhos.append(terreno._construcoes.registro(Vector2(p[0], p[1])))
	terreno._montar_navegacao()
	atualizar()

func cumpridos() -> Array:
	return cena.controlador.progresso.objetivos_cumpridos("moinho_vazao")

func atualizar() -> void:
	if not is_instance_valid(cena) or not is_instance_valid(terreno): return
	var feitos := cumpridos()
	if "comporta" in feitos: posicoes.assign(SOLUCAO)
	for i in REGISTROS.size():
		if cena.alvos.has(REGISTROS[i]):
			var alvo: Dictionary = cena.alvos[REGISTROS[i]]
			alvo.no.visible = not dentro and "margem" in feitos and not "comporta" in feitos
			alvo.nome = ["Entrada", "Desvio", "Retorno"][i] + ": " + NOMES_ESTADOS[posicoes[i]]
			alvo.rotulo.text = ["Entrada", "Desvio", "Retorno"][i] + "\n" + NOMES_ESTADOS[posicoes[i]].capitalize()
			alvo.rotulo.position = Vector2(-22,-68)
			alvo.rotulo.size = Vector2(44,22)
			alvo.rotulo.add_theme_font_size_override("font_size",7)
			alvo.rotulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if i < desenhos.size(): desenhos[i].definir_estado(posicoes[i])
	terreno.atualizar_fluxo_puzzle(posicoes,"comporta" in feitos)
	if dentro and cena.alvos.has("entrada_dungeon"):
		cena.alvos.entrada_dungeon.no.visible = not "dungeon" in feitos

## Retorno vazio permite que o controlador registre a interação da missão.
func interagir(id: String) -> Dictionary:
	var feitos := cumpridos()
	if id in REGISTROS:
		if not "margem" in feitos or "comporta" in feitos: return {"texto": "Os registros já estão ajustados."}
		var i := REGISTROS.find(id)
		posicoes[i] = (posicoes[i] + 1) % 3
		atualizar()
		return {"texto": ["Entrada", "Desvio", "Retorno"][i] + " " + NOMES_ESTADOS[posicoes[i]] + (". Circuito pronto: acione a alavanca da comporta." if posicoes == SOLUCAO else ". A corrente mudou de direção no circuito.")}
	if id == "comporta_moinho" and not "comporta" in feitos:
		if not "margem" in feitos: return {"texto": "A placa da margem explica o circuito antigo."}
		terreno._comporta.reagir_tentativa(posicoes == SOLUCAO)
		if posicoes != SOLUCAO:
			return {"texto": "A pressão não se mantém. Entrada e retorno devem ficar abertos; o desvio precisa ficar fechado."}
	if id == "roda_moinho" and "comporta" in feitos and not "eixo" in feitos:
		for guarda in guardioes:
			if is_instance_valid(guarda) and not guarda.esta_morto:
				return {"texto": "Um goblin protege o acesso à transmissão. Derrote-o para inspecionar o eixo."}
	if id == "entrada_dungeon" and "eixo" in feitos and not dentro:
		_entrar()
		return {"texto": "Sala de manutenção antiga. As inscrições estão na parede ao norte."}
	if id == "saida_regiao" and dentro:
		_sair()
		return {"texto": "Você voltou à praça da bacia."}
	if id == "entrada_dungeon" and dentro:
		for inimigo in terreno.get_tree().get_nodes_in_group("enemy"):
			if inimigo.has_meta("subsolo_bacia") and not inimigo.esta_morto:
				return {"texto": "Os goblins guardam as inscrições. Limpe a sala para investigar."}
	return {}

func alvo_do_puzzle() -> String:
	if dentro or not "margem" in cumpridos() or "comporta" in cumpridos():
		return "comporta_moinho"
	for i in REGISTROS.size():
		if posicoes[i] != SOLUCAO[i]:
			return REGISTROS[i]
	return "comporta_moinho"

func instrucao_do_puzzle() -> String:
	var alvo := alvo_do_puzzle()
	if alvo == "registro_entrada": return "Abra o registro de entrada do circuito."
	if alvo == "registro_desvio": return "Feche o desvio para manter a água no circuito."
	if alvo == "registro_retorno": return "Abra o retorno para liberar a corrente."
	return "Circuito pronto. Acione a alavanca da comporta."

func _process(delta: float) -> void:
	if not is_instance_valid(cena) or not is_instance_valid(cena.jogador):
		return
	var camera := cena.jogador.get_node("Camera2D") as Camera2D
	var perto: bool = not dentro and cena.jogador.position.distance_to(Vector2(-368,-128)) < 110.0
	var enquadramento := Vector2(0,-72) if perto else Vector2.ZERO
	camera.offset = camera.offset.lerp(enquadramento,1.0-exp(-delta*3.0))

func _montar_sala() -> void:
	if _montado: return
	_montado = true
	sala = terreno._construcoes.sala_manutencao()
	# Malha própria, desconectada do exterior. A folga corresponde às paredes.
	var navegacao := NavigationRegion2D.new()
	var geometria := NavigationMeshSourceGeometryData2D.new()
	var r := sala.grow(-24)
	r.position.y += 32
	r.size.y -= 32
	geometria.add_traversable_outline(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]))
	var malha := NavigationPolygon.new()
	malha.agent_radius = 6.0
	NavigationServer2D.bake_from_source_geometry_data(malha, geometria)
	navegacao.navigation_polygon = malha
	terreno.add_child(navegacao)
	NavigationServer2D.map_force_update(terreno.get_world_2d().navigation_map)
	for p in [Vector2(2160, -10), Vector2(2320, -10)]:
		var mob := preload("res://cenas/inimigos/goblin_pomar.tscn").instantiate() as Node2D
		mob.position = p
		mob.set("velocidade", 55)
		mob.set("fator_velocidade_animacao", 1.35)
		mob.set("tempo_recarga_ataque", 1.1)
		mob.set_meta("subsolo_bacia", true)
		terreno.add_child(mob)

func _limitar_camera(rect: Rect2) -> void:
	var camera: Camera2D = cena.jogador.get_node("Camera2D")
	camera.limit_left = int(rect.position.x)
	camera.limit_top = int(rect.position.y)
	camera.limit_right = int(rect.end.x)
	camera.limit_bottom = int(rect.end.y)
	camera.reset_smoothing()

func _entrar() -> void:
	_montar_sala()
	dentro = true
	_alvo_externo = cena.alvos.entrada_dungeon.no.position
	_saida_externa = cena.alvos.saida_regiao.no.position
	cena.alvos.entrada_dungeon.no.position = Vector2(2240, -52)
	cena.alvos.entrada_dungeon.nome = "Inscrições antigas"
	cena.alvos.entrada_dungeon.rotulo.text = "Inscrições antigas"
	cena.alvos.saida_regiao.no.position = Vector2(2240, 78)
	cena.alvos.saida_regiao.nome = "Voltar para a bacia"
	cena.alvos.saida_regiao.rotulo.text = "Voltar para a bacia"
	cena.jogador.position = Vector2(2240, 56)
	cena.limites = sala
	terreno.limites = sala
	_limitar_camera(sala)
	atualizar()

func _sair() -> void:
	dentro = false
	cena.alvos.entrada_dungeon.no.position = _alvo_externo
	cena.alvos.entrada_dungeon.nome = "Entrada da manutenção antiga"
	cena.alvos.entrada_dungeon.rotulo.text = "Entrada da manutenção antiga"
	cena.alvos.saida_regiao.no.position = _saida_externa
	cena.alvos.saida_regiao.nome = "Voltar ao mapa"
	cena.alvos.saida_regiao.rotulo.text = "Voltar ao mapa"
	cena.jogador.position = Vector2(0, 72)
	cena.limites = limite_externo
	terreno.limites = limite_externo
	_limitar_camera(limite_externo)
	atualizar()
