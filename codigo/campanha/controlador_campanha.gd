extends RefCounted

## Recebe somente ações já verificadas pelo cenário/controlador da sessão.
## A sessão da expedição valida remetentes antes de entregar eventos de combate.
signal alterado
const Progresso := preload("res://codigo/campanha/progresso_campanha.gd")
const Catalogo := preload("res://codigo/campanha/catalogo_campanha.gd")
var progresso := Progresso.new()
var regiao := ""
var _catalogo := Catalogo.dados()

func iniciar(pasta: String, perfil: String) -> Error:
	regiao = ""
	return progresso.iniciar(pasta, perfil)

func definir_regiao(id: String) -> Error:
	if not _catalogo.destinos.has(id) or _catalogo.destinos[id].tipo == "andar":
		return ERR_INVALID_PARAMETER
	if not progresso.acesso_liberado(id):
		return ERR_UNAUTHORIZED
	regiao = id
	alterado.emit()
	return OK

func objetivos_disponiveis() -> Array[Dictionary]:
	var resultado: Array[Dictionary] = []
	for missao in _catalogo.missoes:
		if progresso.missao_concluida(missao) or not progresso.pode_concluir(missao):
			continue
		var cumpridos: Array = progresso.objetivos_cumpridos(missao)
		for objetivo in _catalogo.missoes[missao].get("objetivos", []):
			if objetivo.id in cumpridos or not Catalogo.requisitos_cumpridos(objetivo.apos, cumpridos):
				continue
			var item: Dictionary = objetivo.duplicate(true)
			item.missao = missao
			resultado.append(item)
	return resultado

func interagir(tipo: String, alvo: String) -> Error:
	for objetivo in objetivos_disponiveis():
		if objetivo.tipo == tipo and objetivo.alvo == alvo:
			if objetivo.regiao != regiao:
				return ERR_UNAUTHORIZED
			var missao: Dictionary = _catalogo.missoes[objetivo.missao]
			var faltantes: Array = missao.objetivos.filter(func(o):return not o.id in progresso.objetivos_cumpridos(objetivo.missao))
			if faltantes.size()==1 and _catalogo.destinos[missao.destino].tipo!="cidade" and tempo_ativo(missao.destino)<float(_catalogo.destinos[missao.destino].get("duracao",{}).get("minima",60)):
				return ERR_BUSY
			var erro := progresso.registrar_objetivo(objetivo.missao, objetivo.id)
			if erro == OK:
				alterado.emit()
			return erro
	return ERR_UNAVAILABLE

func objetivo_atual() -> Dictionary:
	var disponiveis := objetivos_disponiveis()
	for objetivo in disponiveis:
		if objetivo.regiao == regiao:
			return objetivo
	return disponiveis[0] if not disponiveis.is_empty() else {}

func contar_tempo(delta: float) -> void:
	if regiao.is_empty() or not is_finite(delta) or delta<=0: return
	progresso.tempos_regioes[regiao] = tempo_ativo(regiao)+delta

func tempo_ativo(id: String) -> float:
	return float(progresso.tempos_regioes.get(id,0.0))
