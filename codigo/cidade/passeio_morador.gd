extends RefCounted

## Tempo livre com interesses, ritmo, paradas e memória próprios de cada morador.
const Dados := preload("res://codigo/cidade/dados_cidade.gd")
const Perfis := preload("res://codigo/cidade/perfis_rotina.gd")
const Clima := preload("res://codigo/dados/estados_clima.gd")
var rng := RandomNumberGenerator.new()
var recentes: Array[String] = []
var atual := ""
var espera := -1.0
var velocidade := 26.0
var _olhar_em := 0.0

func _init() -> void:
	rng.randomize()

func reiniciar() -> void:
	atual = ""
	espera = -1.0

func atualizar(npc: Node2D, delta: float) -> void:
	if not npc.agenda.get("livre", false) or npc.vila.local not in ["cidade","praia"] or npc._saindo or npc.dormindo:
		return
	if not npc.caminho.is_empty() or not Perfis.PERFIS.has(npc.id): return
	var perfil: Dictionary = Perfis.PERFIS[npc.id]
	if espera < 0:
		var pausa: Vector2 = perfil["pausa"]
		espera = rng.randf_range(8.0,22.0) if atual == "" else rng.randf_range(pausa.x,pausa.y)
		if Clima.Estado.CHUVA_FORTE == npc.vila.clima_atual() or Clima.Estado.NEVE_FORTE == npc.vila.clima_atual():
			espera *= 0.35
		_olhar_em = rng.randf_range(4.0,9.0)
	espera -= delta
	_olhar_em -= delta
	if _olhar_em <= 0:
		npc.olhar_para(npc.position+Vector2.DOWN.rotated(rng.randf_range(-0.6,0.6))*12)
		_olhar_em = rng.randf_range(5.0,12.0)
	if espera > 0: return
	var atividades: Array = perfil[npc.vila.local]
	var candidatas: Array[int] = []
	for indice in atividades.size():
		var chave := "%s:%s:%d" % [npc.id,npc.vila.local,indice]
		if chave not in recentes: candidatas.append(indice)
	while not candidatas.is_empty():
		var sorteado := rng.randi_range(0,candidatas.size()-1)
		var indice: int = candidatas[sorteado]
		candidatas.remove_at(sorteado)
		var atividade: Array = atividades[indice]
		var desejado: Vector2 = Dados.ponto(atividade[0]) if npc.vila.local == "cidade" else atividade[0]
		# Pequenas diferenças de apoio sem transformar a rotina numa caminhada aleatória.
		desejado += Vector2(rng.randf_range(-5,5),rng.randf_range(-3,3))
		var rota: PackedVector2Array = npc.vila.caminho_morador(npc.position,desejado,npc.id)
		if rota.size() < 2 or rota[-1].distance_to(npc.position) < 18: continue
		atual = "%s:%s:%d" % [npc.id,npc.vila.local,indice]
		recentes.append(atual)
		if recentes.size() > 3: recentes.pop_front()
		var ritmo: Vector2 = perfil["ritmo"]
		velocidade = rng.randf_range(ritmo.x,ritmo.y)
		npc.agenda["atividade"] = atividade[1]
		npc._alvo = rota[-1]
		npc.caminho = rota
		espera = -1.0
		return
	espera = 8.0
