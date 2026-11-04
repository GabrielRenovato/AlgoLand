extends SceneTree
## Regressões locais do protocolo; não substitui um teste com latência da internet.
class SessaoTeste extends Node:
	var host := false
	var rejeitar_mundo := false
	var rejeitar_texturas := false
	var pacotes: Array[Dictionary] = []
	func sou_host() -> bool: return host
	func enviar_para(_peer: String, dados: Dictionary, _estado := false) -> bool:
		pacotes.append(dados.duplicate(true))
		return not ((rejeitar_mundo and dados.t == "mundo") or (rejeitar_texturas and dados.t == "texturas"))
	func enviar(_dados: Dictionary, _estado := false) -> bool: return true
class AlvoTeste extends Node2D:
	var vida := 50
	var ultimo: Array = []
	var estado: Dictionary = {}
	func aplicar(e: Array) -> void: ultimo = e.duplicate(true)
	func aplicar_estado(e: Dictionary) -> void: estado = e.duplicate(true)
	func esta_congelado() -> bool: return false
class GerenteTeste extends Node:
	enum Etapa { EM_ANDAMENTO, CONCLUIDO }
	var etapa := Etapa.EM_ANDAMENTO
	var META_PROGRESSO := 100
	var pontos := 0
	var inimigos_vivos := 16
	var total_inimigos_onda := 16
var falhas := 0
var verificacoes := 0

func _initialize() -> void: rodar.call_deferred()
func conferir(nome: String, ok: bool) -> void:
	verificacoes += 1
	if not ok: falhas += 1
	print("OK " if ok else "FALHA ",nome)

func rodar() -> void:
	if not OS.get_user_data_dir().contains("AlgoLand testes"):
		quit(1)
		return
	var mundo := Node2D.new()
	root.add_child(mundo)
	var sessao := SessaoTeste.new()
	mundo.add_child(sessao)
	var controle: Node = load("res://codigo/coop_online/andar_coop.gd").new()
	mundo.add_child(controle)
	controle.set_process(false)
	controle.sessao = sessao
	controle.cena = mundo
	for i in range(1,101):
		var alvo := AlvoTeste.new()
		mundo.add_child(alvo)
		controle._inimigos[i] = alvo
	var lotes: Array[Dictionary] = []
	for inicio in range(1,101,8):
		var estados: Array = []
		for i in range(inicio,mini(inicio+8,101)): estados.append([i,float(i),0.0,50,[]])
		lotes.append({"t":"mundo","seq":lotes.size()+1,"inimigos":estados})
	lotes.reverse()
	for lote in lotes: controle._receber(lote)
	var recebidos := 0
	for alvo in controle._inimigos.values():
		if not alvo.ultimo.is_empty(): recebidos += 1
	print("DIAGNOSTICO pacotes invertidos: ",recebidos,"/100 inimigos atualizados")
	conferir("lotes fora de ordem atualizam todos os inimigos",recebidos == 100)
	controle._receber({"t":"mundo","seq":1000,"inimigos":[[1,999.0,0.0,50,[]]]})
	controle._receber({"t":"mundo","seq":999,"inimigos":[[1,123.0,0.0,50,[]],[2,888.0,0.0,50,[]]]})
	conferir("estado antigo nao faz o mesmo inimigo voltar",controle._inimigos[1].ultimo.size() > 1 and controle._inimigos[1].ultimo[1] == 999.0)
	conferir("lote antigo ainda atualiza outro inimigo",controle._inimigos[2].ultimo.size() > 1 and controle._inimigos[2].ultimo[1] == 888.0)
	var aliado := AlvoTeste.new()
	mundo.add_child(aliado)
	controle.parceiros["aliado"] = aliado
	controle._receber({"t":"jogador","de":"aliado","seq":5,"e":{"x":100.0,"y":0.0}})
	controle._receber({"t":"jogador","de":"aliado","seq":4,"e":{"x":10.0,"y":0.0}})
	conferir("estado fora de ordem nao puxa aliado para tras",aliado.estado.get("x") == 100.0)
	controle._receber({"t":"jogador","de":"aliado","e":{"x":110.0,"y":0.0}})
	conferir("estados de cliente antigo continuam aceitos",aliado.estado.get("x") == 110.0)
	# O canal confiável também pode rejeitar um envio quando o buffer está cheio.
	controle._catalogo_tex[42] = ["res://assets/inimigos/exemplo.png"]
	sessao.rejeitar_texturas = true
	controle._enviar_texturas_novas("peer",[[1,0,0,50,[],50,[42]]])
	conferir("textura rejeitada nao e marcada como enviada",not controle._tex_enviadas.get("peer",{}).has(42))
	sessao.pacotes.clear()
	sessao.rejeitar_texturas = false
	controle._enviar_texturas_novas("peer",[[1,0,0,50,[],50,[42]]])
	conferir("textura rejeitada e tentada novamente",sessao.pacotes.any(func(m): return m.t == "texturas"))
	# Verificar o delta de um host cujo canal descartou o lote por contrapressão.
	sessao.host = true
	controle.gerente = GerenteTeste.new()
	mundo.add_child(controle.gerente)
	controle._inimigos.clear()
	for i in range(1,17):
		var alvo := AlvoTeste.new()
		mundo.add_child(alvo)
		controle._inimigos[i] = alvo
		controle._enviados[i] = true
	var parceiro := Node2D.new()
	mundo.add_child(parceiro)
	controle.parceiros["peer"] = parceiro
	controle._prontos.assign(["peer"])
	controle._refresco["peer"] = Time.get_ticks_msec()+60000
	sessao.rejeitar_mundo = true
	controle._enviar_mundo()
	conferir("lote rejeitado nao confirma delta no host",controle._ultimo_enviado.get("peer",{}).is_empty())
	sessao.pacotes.clear()
	sessao.rejeitar_mundo = false
	controle._enviar_mundo()
	var reenviados := 0
	for m in sessao.pacotes:
		if m.t == "mundo": reenviados += m.inimigos.size()
	conferir("proximo tick reenvia os 16 estados rejeitados",reenviados == 16)
	print("COOP_PACOTES ",JSON.stringify({"verificacoes":verificacoes,"falhas":falhas,"inimigos_atualizados":recebidos}))
	mundo.free()
	quit(1 if falhas else 0)
