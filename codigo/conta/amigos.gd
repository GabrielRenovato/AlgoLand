extends Node
## Amigos e convites de sala da conta (ver ferramentas/conta/20261029220000_amigos.sql). Filho do ContaJogador.
## Os convites chegam por consulta a cada INTERVALO_CONVITES s (só logado e com rede); sem servidor de presença na fase 3.
signal mudou
signal convite_recebido(convite: Dictionary)

const INTERVALO_CONVITES := 25.0
const TEXTOS := {
	"enviado": "PEDIDO ENVIADO", "amigos": "VOCES AGORA SAO AMIGOS", "ja_amigos": "VOCES JA SAO AMIGOS",
	"ja_pedido": "PEDIDO JA ENVIADO, AGUARDE A RESPOSTA", "nao_encontrado": "CODIGO NAO ENCONTRADO",
	"proprio": "ESTE E O SEU PROPRIO CODIGO", "muitos_pedidos": "MUITOS PEDIDOS EM ABERTO",
	"lista_cheia": "SUA LISTA DE AMIGOS ESTA CHEIA", "nao_sao_amigos": "VOCES NAO SAO AMIGOS",
	"rapido": "AGUARDE UNS SEGUNDOS PARA CONVIDAR DE NOVO", "convite_invalido": "CONVITE INVALIDO", "sem_login": "ENTRE NA CONTA",
}
var codigo := ""
var lista: Array = []
var _vistos := {}
var _tempo := 10.0

func conta() -> Node:
	return get_parent()

func _process(delta: float) -> void:
	_tempo -= delta
	if _tempo > 0.0: return
	_tempo = INTERVALO_CONVITES
	if conta().logado() and not conta().offline: verificar_convites()

## Código de amigo e lista (amigos, pedidos recebidos e enviados). "" em sucesso ou o texto do erro.
func atualizar() -> String:
	var meu: Dictionary = await conta().chamar("meu_codigo_amigo")
	if not meu.has("erro"): codigo = str(meu.get("valor", codigo))
	var r: Dictionary = await conta().chamar("listar_amigos")
	if r.has("erro"): return str(r.erro)
	lista = r.get("lista", [])
	mudou.emit()
	return ""

func pedir(codigo_amigo: String) -> String:
	var r: Dictionary = await conta().chamar("pedir_amizade", {"p_codigo_amigo": codigo_amigo.strip_edges().to_upper()})
	if r.has("erro"): return str(r.erro)
	await atualizar()
	return TEXTOS.get(str(r.get("estado", "")), "NAO FOI POSSIVEL")

func responder(codigo_amigo: String, aceitar: bool) -> void:
	await conta().chamar("responder_amizade", {"p_codigo_amigo": codigo_amigo, "p_aceitar": aceitar})
	await atualizar()

func remover(codigo_amigo: String) -> void:
	await conta().chamar("remover_amizade", {"p_codigo_amigo": codigo_amigo})
	await atualizar()

func convidar(codigo_amigo: String, tipo: String, sala: String, andar: int) -> String:
	var r: Dictionary = await conta().chamar("enviar_convite", {"p_codigo_amigo": codigo_amigo, "p_tipo": tipo, "p_sala": sala, "p_andar": andar})
	if r.has("erro"): return str(r.erro)
	var estado := str(r.get("estado", ""))
	return "CONVITE ENVIADO" if estado == "ok" else str(TEXTOS.get(estado, "NAO FOI POSSIVEL CONVIDAR"))

func verificar_convites() -> void:
	var r: Dictionary = await conta().chamar("listar_convites")
	if r.has("erro"): return
	for convite in r.get("lista", []):
		if not convite is Dictionary: continue
		var id := int(convite.get("id", 0))
		if _vistos.has(id): continue
		_vistos[id] = true
		convite_recebido.emit(convite)

func descartar(id: int) -> void:
	await conta().chamar("descartar_convite", {"p_id": id})
