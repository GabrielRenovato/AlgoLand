extends RefCounted

## Escolhas durante o tempo livre: cada morador prefere afazeres diferentes e evita repetir os últimos destinos.
const Dados := preload("res://codigo/cidade/dados_cidade.gd")
const Clima := preload("res://codigo/dados/estados_clima.gd")
const ATIVIDADES := {
	"mural": ["mural", "Lendo os pedidos do mural", 15.0, 30.0],
	"fonte": ["rosa_praca", "Fazendo uma pausa junto a fonte", 22.0, 48.0],
	"jardim": ["rosa_jardim", "Olhando os canteiros", 25.0, 55.0],
	"flores": ["estela_flores", "Observando as flores", 20.0, 50.0],
	"coreto": ["bardo_coreto", "Descansando perto do coreto", 30.0, 65.0],
	"praca": ["lia_praca", "Procurando companhia na praca", 18.0, 40.0],
	"venda": ["bento_praca", "Conferindo o movimento da venda", 15.0, 35.0],
}
const PREFERENCIAS := {
	"mercador": ["venda", "mural", "praca"],
	"curandeira": ["jardim", "fonte", "flores"],
	"bardo": ["coreto", "praca", "venda"],
	"mistica": ["flores", "fonte", "jardim"],
	"lia": ["mural", "praca", "coreto"],
	"bento": ["jardim", "flores", "venda"],
}
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
	if not npc.agenda.get("livre", false) or npc.vila.local != "cidade" or npc._saindo or npc.dormindo:
		return
	if not npc.caminho.is_empty():
		return
	if espera < 0:
		# A primeira chegada também tem uma pausa; não emenda uma rota em outra.
		espera = rng.randf_range(8.0, 22.0) if atual == "" else rng.randf_range(ATIVIDADES[atual][2], ATIVIDADES[atual][3])
		if Clima.Estado.CHUVA_FORTE == npc.vila.clima_atual() or Clima.Estado.NEVE_FORTE == npc.vila.clima_atual():
			espera *= 0.35
		_olhar_em = rng.randf_range(4.0, 9.0)
	espera -= delta
	_olhar_em -= delta
	if _olhar_em <= 0:
		npc.olhar_para(npc.position + Vector2.RIGHT.rotated(rng.randf_range(0, TAU)))
		_olhar_em = rng.randf_range(5.0, 12.0)
	if espera > 0:
		return
	var candidatas: Array[String] = []
	for chave in ATIVIDADES:
		if chave in recentes:
			continue
		candidatas.append(chave)
		if chave in PREFERENCIAS[npc.id]:
			candidatas.append(chave)
			candidatas.append(chave)
	# O rng do morador também pode ser fixado nos testes.
	for tentativa in candidatas.size():
		var chave: String = candidatas[rng.randi_range(0, candidatas.size() - 1)]
		candidatas.erase(chave)
		var dados: Array = ATIVIDADES[chave]
		var desejado := Dados.ponto(dados[0]) + Vector2(rng.randf_range(-10, 10), rng.randf_range(-6, 6))
		var rota: PackedVector2Array = npc.vila.caminho_entre(npc.position, desejado)
		if rota.size() < 2 or rota[-1].distance_to(npc.position) < 18.0:
			continue
		atual = chave
		recentes.append(chave)
		if recentes.size() > 3:
			recentes.pop_front()
		velocidade = rng.randf_range(22.0, 30.0)
		npc.agenda["atividade"] = dados[1]
		npc._alvo = rota[-1]
		npc.caminho = rota
		espera = -1.0
		return
	espera = 8.0
