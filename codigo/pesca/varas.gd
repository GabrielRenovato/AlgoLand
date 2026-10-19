extends RefCounted

## Refinamento individual: P1 e P2 mantêm nível e pedras separados no save do mundo.
const MAXIMO := 5
const CHANCE_PEDRA := 0.0025
const CAPTURAS_INICIAIS := 30
const INTERVALO_PEDRAS := 50
const CUSTOS := {2:1,3:2,4:4,5:6}
const CORES := [Color("cfab78"),Color("71d781"),Color("65b9ef"),Color("c48af4"),Color("ffd15e")]

static func chave(jogador: Node) -> String:
	return "p2" if jogador != null and jogador.get("eh_p2") == true else "p1"

## Nível da vara do dono deste inventário (InventarioJogador = P1, InventarioJogador2 = P2)
static func nivel_do_inventario(inventario: Node) -> int:
	var id := "p2" if inventario == (Engine.get_main_loop() as SceneTree).root.get_node("InventarioJogador2") else "p1"
	return clampi(int(_estado().varas_pesca.get(id,1)),1,MAXIMO)

## Põe o item da vara de cada jogador no nível/cor do refinamento (depois de carregar ou de refinar)
static func sincronizar_itens() -> void:
	var raiz := (Engine.get_main_loop() as SceneTree).root
	for nome in ["InventarioJogador","InventarioJogador2"]:
		var inventario := raiz.get_node_or_null(nome)
		if inventario != null:
			inventario.sincronizar_vara()

static func nivel(jogador: Node) -> int:
	return clampi(int(_estado().varas_pesca.get(chave(jogador),1)),1,MAXIMO)

static func pedras(jogador: Node) -> int:
	return _estado().mochila_pesca(jogador).quantidade_tipo("material:pedra_vara")

static func custo(jogador: Node) -> int:
	return int(CUSTOS.get(nivel(jogador)+1,0))

static func melhorar(jogador: Node) -> bool:
	if _estado().mochila_pesca(jogador).buscar_por_tipo("vara_pesca") == null:
		return false
	var necessario := custo(jogador)
	if necessario == 0 or pedras(jogador) < necessario:
		return false
	var id := chave(jogador)
	_estado().mochila_pesca(jogador).gastar_tipo("material:pedra_vara",necessario)
	_estado().mochila_pesca(jogador).salvar()
	_estado().varas_pesca[id] = nivel(jogador)+1
	sincronizar_itens()
	_estado().salvar()
	_estado().bolsas_alteradas.emit()
	return true

static func receber_pedra(jogador: Node) -> bool:
	if not _estado().mochila_pesca(jogador).adicionar_coletavel("material","pedra_vara"):
		return false
	_estado().mochila_pesca(jogador).salvar()
	_estado().pesca_ultima_pedra[chave(jogador)] = capturas(jogador)
	_estado().salvar()
	_estado().bolsas_alteradas.emit()
	return true

static func sortear_pedra(rng: RandomNumberGenerator = null) -> bool:
	return (rng.randf() if rng != null else randf()) < CHANCE_PEDRA

## Diferença de equipamento altera janela, velocidade, ganho e punição; sem bloqueio artificial de espécie.
static func parametros(dificuldade: float, recomendado: int, nv: int) -> Dictionary:
	var defasagem := maxi(0,recomendado-nv)
	return {"dificuldade":clampf(dificuldade-8*(nv-1),5,100),
		"zona":pow(0.53,defasagem), "velocidade":1.0+0.38*defasagem,
		"ganho":maxf(0.20,1.0-0.22*defasagem), "perda":1.0+0.45*defasagem}

static func _estado() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("Fazenda")

static func capturas(jogador: Node) -> int:
	return maxi(0,int(_estado().pesca_capturas_jogador.get(chave(jogador),0)))

static func registrar_peixe(jogador: Node) -> void:
	_estado().pesca_capturas_jogador[chave(jogador)] = capturas(jogador)+1
	_estado()._agendar_salvamento()

static func pode_pescar_pedra(jogador: Node) -> bool:
	var ultimo := int(_estado().pesca_ultima_pedra.get(chave(jogador),-1))
	return capturas(jogador)>=CAPTURAS_INICIAIS and (ultimo<0 or capturas(jogador)-ultimo>=INTERVALO_PEDRAS)

static func sortear_pedra_para(jogador: Node, rng: RandomNumberGenerator = null) -> bool:
	return pode_pescar_pedra(jogador) and sortear_pedra(rng)
