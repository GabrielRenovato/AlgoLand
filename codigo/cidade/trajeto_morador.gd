extends RefCounted

## Coordena as cópias de um morador nos ambientes: porta de saída, caminhada na rua e porta de entrada.
## O ator real termina a etapa; se o mapa foi descarregado, conserva o tempo restante do trajeto.
const Dados := preload("res://codigo/cidade/dados_cidade.gd")

static func _precisa_rua(origem: String, destino: String) -> bool:
	return origem != "cidade" and destino != "cidade" and not (origem in ["praia", "palafita"] and destino in ["praia", "palafita"])

static func _porta_na_rua(local: String) -> Vector2:
	return Vector2(48,272) if local == "fazenda" else Vector2(336, 520) if local == "praia" else Dados.PREDIOS.get(local, {}).get("base", Vector2(336, 272))

## Se o destino atualiza primeiro no cooperativo, registra a saída do ator que ainda está na origem.
static func preparar_chegada(npc: Node2D, origem: String) -> void:
	for outro in npc.get_tree().get_nodes_in_group("moradores_cidade"):
		if outro != npc and outro.id == npc.id and outro.vila.local == origem and outro.visible:
			outro.atualizar_rotina()

static func _duracao(npc: Node2D) -> float:
	var de: Vector2 = npc.position
	var distancia := 0.0
	for ponto in npc.caminho:
		distancia += de.distance_to(ponto)
		de = ponto
	return distancia / (18.0 if npc.id=="helena" else 26.0) + 0.5

static func registrar(npc: Node2D) -> void:
	Cidade.trajetos_moradores[npc.id] = {"origem": npc.vila.local, "destino": npc.agenda["local"],
		"fase": "saindo", "ator": weakref(npc), "chegada": Cidade.tempo_moradores + _duracao(npc)}
	# Se o mapa for descarregado, mãe e filha mantêm a mesma previsão de chegada.
	if npc.id=="clara":
		var mae: Dictionary = Cidade.trajetos_moradores.get("helena",{})
		if mae.get("fase","")=="saindo" and mae.origem==npc.vila.local and mae.destino==npc.agenda.local:
			Cidade.trajetos_moradores.clara.chegada = mae.chegada

static func concluir(npc: Node2D) -> void:
	var registro: Dictionary = Cidade.trajetos_moradores.get(npc.id, {})
	if registro.is_empty() or registro["ator"].get_ref() != npc:
		return
	if _precisa_rua(npc.vila.local, registro["destino"]):
		registro["fase"] = "rua"
		var de := _porta_na_rua(registro["origem"])
		var ate := _porta_na_rua(registro["destino"])
		registro["chegada"] = Cidade.tempo_moradores + de.distance_to(ate) / 26.0 + 2.0
	else:
		registro["fase"] = "chegou"

static func aguardar(npc: Node2D) -> bool:
	var registro: Dictionary = Cidade.trajetos_moradores.get(npc.id, {})
	if registro.is_empty() or registro["destino"] != npc.vila.local or registro["fase"] in ["chegou", "presente"]:
		return false
	var ator: Node = registro["ator"].get_ref()
	if is_instance_valid(ator) and ator.visible:
		return true
	return Cidade.tempo_moradores < float(registro["chegada"])

static func sincronizar(npc: Node2D) -> void:
	if npc.visible:
		return
	var registro: Dictionary = Cidade.trajetos_moradores.get(npc.id, {})
	if registro.is_empty():
		return
	var ator: Node = registro["ator"].get_ref()
	if registro["fase"] == "saindo" and not is_instance_valid(ator) and Cidade.tempo_moradores >= float(registro["chegada"]):
		if _precisa_rua(registro["origem"], registro["destino"]):
			registro["fase"] = "rua"
			var de := _porta_na_rua(registro["origem"])
			var ate := _porta_na_rua(registro["destino"])
			registro["chegada"] = Cidade.tempo_moradores + de.distance_to(ate) / 26.0 + 2.0
		else:
			registro["fase"] = "chegou"
	if npc.vila.local == "cidade" and registro["fase"] == "rua":
		npc.position = npc.vila.porta_do_local(registro["origem"])
		npc.visible = true
		npc._saindo = true
		npc._ir_ate(npc.vila.porta_do_local(registro["destino"]))
		registro["fase"] = "saindo"
		registro["ator"] = weakref(npc)
		registro["chegada"] = Cidade.tempo_moradores + _duracao(npc)
		npc._atualizar_colisao()
	elif registro["destino"] == npc.vila.local and not aguardar(npc) and registro["fase"] != "presente":
		npc.position = npc.vila.porta_do_local(registro["origem"])
		npc.visible = true
		npc._saindo = false
		npc._ir_ate(npc.agenda["ponto"])
		registro["fase"] = "presente"
		npc._atualizar_colisao()

static func iniciar_rua(npc: Node2D, origem: String) -> void:
	if origem == "cidade" or origem == npc.agenda["local"] or (not Dados.PREDIOS.has(origem) and origem not in ["praia","fazenda"]):
		return
	for outro in npc.get_tree().get_nodes_in_group("moradores_cidade"):
		# Ao carregar a rua no coop, quem já chegou ao destino não deve surgir outra vez na porta de casa.
		if outro != npc and outro.id == npc.id and outro.vila.local in [origem, npc.agenda["local"]] and outro.visible:
			return
	var existente: Dictionary = Cidade.trajetos_moradores.get(npc.id, {})
	if not existente.is_empty() and existente["destino"] == npc.agenda["local"]:
		return
	npc.position = npc.vila.porta_do_local(origem)
	npc.visible = true
	npc._saindo = true
	npc._ir_ate(npc.vila.porta_do_local(npc.agenda["local"]))
	registrar(npc)
