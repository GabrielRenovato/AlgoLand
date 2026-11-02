extends RefCounted
## Serviços da vila na campanha: loja de Tomás e cuidados de Rosa. Tudo em ouro; sem Brasas nem moeda de forja.
const Forja := preload("res://codigo/dados/forja_armas.gd")
const PRECOS_COMPRA := {"ferro": 12, "madeira": 6, "fibra": 5}
const PRECOS_VENDA := {"ferro": 5, "madeira": 2, "fibra": 2, "pedra": 2}
const RESERVA := 5 ## Tomás só compra o que passa disso, para não levar o material que o jogador precisa
const CUSTO_TRATAMENTO := 10
const PRECO_CURA := 20

static func nome_material(id: String) -> String:
	return str(Forja.MATERIAIS[id].nome).capitalize()

static func comprar(jogador: Node, id: String) -> String:
	if not PRECOS_COMPRA.has(id):
		return "Isso eu não tenho."
	var preco: int = PRECOS_COMPRA[id]
	if DadosJogo.moedas_de(jogador) < preco:
		return "Ouro insuficiente."
	if not jogador.inventario.receber_materiais({id: 1}):
		return "Sua mochila está cheia."
	jogador.gastar_moedas(preco)
	return "Comprado: 1 %s por %d de ouro." % [nome_material(id), preco]

static func vender_excedentes(jogador: Node) -> String:
	var mochila = jogador.inventario
	var total := 0
	var vendidos: Array[String] = []
	for id in PRECOS_VENDA:
		var extra: int = mochila.quantidade_tipo("material:" + id) - RESERVA
		if extra > 0 and mochila.gastar_tipo("material:" + id, extra):
			total += extra * int(PRECOS_VENDA[id])
			vendidos.append("%d %s" % [extra, nome_material(id)])
	if total <= 0:
		return "Não sobra nada além do que você precisa guardar (%d de cada)." % RESERVA
	mochila.salvar()
	jogador.adicionar_moedas(total)
	return "Vendido: %s. Recebido: %d de ouro." % [", ".join(vendidos), total]

static func tratar(jogador: Node) -> String:
	var falta := int(jogador.estatisticas.hp_maximo) - int(jogador.hp_atual)
	if falta <= 0 and jogador.stamina >= jogador.stamina_maxima:
		return "Você já está inteiro."
	if DadosJogo.moedas_de(jogador) < CUSTO_TRATAMENTO:
		return "Ouro insuficiente."
	jogador.gastar_moedas(CUSTO_TRATAMENTO)
	jogador.curar(maxi(falta, 0))
	jogador.stamina = jogador.stamina_maxima
	return "Rosa cuida dos seus ferimentos por %d de ouro." % CUSTO_TRATAMENTO

static func comprar_cura(jogador: Node) -> String:
	if DadosJogo.moedas_de(jogador) < PRECO_CURA:
		return "Ouro insuficiente."
	var mochila = jogador.inventario
	var antes: Array = mochila.fotografar_mochila()
	if not mochila.adicionar_coletavel("pocao", "cura", 1) or not mochila.salvar():
		mochila.restaurar_mochila(antes)
		return "Sua mochila está cheia."
	jogador.gastar_moedas(PRECO_CURA)
	return "Comprado: 1 poção de cura por %d de ouro." % PRECO_CURA
