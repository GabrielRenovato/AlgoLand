extends SceneTree

# Rodar: godot --headless --path . --script res://testes/tabela_balanceamento.gd
# Imprime a tabela de balanceamento por onda (1 a ONDA_MAX): inimigos, ouro, jogador (sem e com melhorias
# permanentes), loja/bigorna e chefes. Só lê os dados reais do jogo (cenas, Gerenciador-de-ondas, slime_spawner,
# Equipamentos, Status-do-jogador, Progresso); não grava nada. Passe "-- resumo" para só as ondas-chave
# e "-- antigo" para usar os parâmetros de antes do balanceamento da Etapa 4 (comparação ANTES x DEPOIS).
#
# Premissas do jogador (constantes abaixo): kit inicial (espada básica, escudo básico, armadura nv 1), ataca
# GOLPES_POR_SEGUNDO golpes/s e acerta em UPTIME do tempo (esquiva, reposicionamento). O ouro é gasto em
# "arma antes de escudo antes de totens", respeitando a onda mínima de cada nível da bigorna; totens só com o
# ouro que sobra além do próximo upgrade de arma. Eventos, estágio bônus e o "saque" não entram na conta.

# Os scripts do jogo usam os autoloads (Progresso, Sons...): só compilam depois do primeiro quadro, por isso load() e não preload()
const CAMINHO_GERENCIADOR := "res://codigo/logica/gerenciador_de_ondas.gd"
const CAMINHO_SPAWNER := "res://codigo/logica/slime_spawner.gd"
const CAMINHO_EQUIPAMENTOS := "res://codigo/dados/equipamentos.gd"
const CAMINHO_ESTATISTICAS := "res://codigo/jogador/status_do_jogador.gd"

const ONDA_MAX := 40
const ONDAS_CHAVE := [1, 3, 5, 10, 15, 20, 30, 40]
const GOLPES_POR_SEGUNDO := 2.5
const UPTIME := 0.7
# Nas lutas de chefe o jogador gasta boa parte do tempo se afastando dos golpes avisados (a tela de impacto do golem etc.)
const UPTIME_CHEFE := 0.55
const TEMPO_SPAWN := 0.6
# Totens da loja na ordem em que o jogador os compraria
const TOTENS_ORDEM := ["item_5", "item_4", "item_1"]
# "Melhorias permanentes médias": nível 3 em vigor, força e couraça (65 Brasas cada; ~6 a 8 partidas até a onda 10)
const MELHORIAS_MEDIAS := {"vigor": 3, "forca": 3, "couraca": 3}
# Parâmetros de antes da Etapa 4: contagem 5 + 3/onda, vida +15% e dano +8% por onda (sem trecho suave), ouro final 25 + 15/onda
const PARAMETROS_ANTIGOS := {"max_inimigos": 5, "inimigos_extra_por_onda": 3, "recompensa_ouro_por_onda": 15,
	"ondas_iniciais": 1, "vida_por_onda": 0.15, "dano_por_onda": 0.08}
const MULT_VIDA_CHEFES_ANTIGOS := {"golem": 1.0, "rei_slime": 11.0, "caranguejo": 6.0, "cogumelo": 6.5}
const ALVO_CHEFE_MIN := 30.0
const ALVO_CHEFE_MAX := 60.0

var _gerenciador
var _spawner
var _equipamentos
var _progresso
var _dados_itens
var _base_cena: Dictionary = {}
var _resumo := false
var _antigo := false
var _script_estatisticas: GDScript

func _initialize() -> void:
	_resumo = OS.get_cmdline_user_args().has("resumo")
	_antigo = OS.get_cmdline_user_args().has("antigo")
	await process_frame
	_progresso = root.get_node("Progresso")
	_dados_itens = root.get_node("DadosDosItems")
	_gerenciador = load(CAMINHO_GERENCIADOR).new()
	_spawner = load(CAMINHO_SPAWNER).new()
	_equipamentos = load(CAMINHO_EQUIPAMENTOS).new()
	_script_estatisticas = load(CAMINHO_ESTATISTICAS)
	if _antigo:
		for chave in PARAMETROS_ANTIGOS:
			_gerenciador.set(chave, PARAMETROS_ANTIGOS[chave])
	var melhorias_reais: Dictionary = _progresso.melhorias.duplicate()
	var linhas := _simular()
	_imprimir(linhas)
	# O Progresso é o autoload real: devolve o que estava lá (nada foi salvo)
	_progresso.melhorias = melhorias_reais
	_gerenciador.free()
	_spawner.free()
	_equipamentos.free()
	quit(0)

# ---------------------------------------------------------------------------
# Dados das cenas
# ---------------------------------------------------------------------------

func _base_da_cena(cena: PackedScene) -> Dictionary:
	if _base_cena.has(cena.resource_path):
		return _base_cena[cena.resource_path]
	var inst = cena.instantiate()
	var dados := {"vida": float(inst.vida), "dano": float(inst.dano), "velocidade": float(inst.velocidade),
		"mut_escala": inst.MUTANTE_ESCALA, "mut_vida": inst.MUTANTE_MULT_VIDA, "mut_dano": inst.MUTANTE_MULT_DANO,
		"nome": inst.name}
	if "dano_impacto" in inst:
		dados["dano_impacto"] = float(inst.dano_impacto)
	inst.free()
	_base_cena[cena.resource_path] = dados
	return dados

# Vida, dano e velocidade médios de um inimigo comum sorteado na onda (média das espécies do estágio, com mutantes)
func _inimigo_medio(onda: int) -> Dictionary:
	var pool = _spawner.obter_pool_especies(onda)
	var vida := 0.0
	var dano := 0.0
	var velocidade := 0.0
	var p_mut: float = _spawner.chance_mutante(onda, 1.0)
	var mv: float = _gerenciador.mult_vida_onda(onda)
	var md: float = _gerenciador.mult_dano_onda(onda)
	for cena in pool:
		var b := _base_da_cena(cena)
		vida += b["vida"] * mv * (1.0 + p_mut * (b["mut_vida"] - 1.0))
		dano += b["dano"] * md * (1.0 + p_mut * (b["mut_dano"] - 1.0))
		velocidade += _spawner.velocidade_na_onda(int(b["velocidade"]), onda)
	var n := float(pool.size())
	return {"vida": vida / n, "dano": dano / n, "velocidade": velocidade / n, "p_mut": p_mut, "especies": pool.size()}

func _dados_chefe(onda: int) -> Dictionary:
	var chefe: Dictionary = _gerenciador.chefe_da_onda(onda)
	var b := _base_da_cena(chefe["cena"])
	var mult: float = chefe.get("mult_vida", 1.0)
	if _antigo:
		mult = MULT_VIDA_CHEFES_ANTIGOS[chefe["id"]]
	var mult_dano: float = chefe.get("mult_dano", 1.0)
	var mv: float = _gerenciador.mult_vida_onda(onda)
	var md: float = _gerenciador.mult_dano_onda(onda)
	var dano_contato: float = b["dano"] * mult_dano * md
	# O golem causa mais dano no impacto do que no toque
	var dano_forte := dano_contato
	if b.has("dano_impacto"):
		dano_forte = b["dano_impacto"] * (b["dano"] * md) / 15.0
	return {"nome": chefe["nome"], "id": chefe["id"], "vida": b["vida"] * mult * mv, "dano": dano_contato,
		"dano_forte": dano_forte, "recompensa": 250}

# ---------------------------------------------------------------------------
# Jogador
# ---------------------------------------------------------------------------

func _nivel_arma(id: String, nivel: int) -> Dictionary:
	return _equipamentos.armas[id]["niveis"].get(nivel, {})

# Estado do jogador numa onda: arma/escudo nv, totens comprados e ouro livre
func _estatisticas(arma_nv: int, escudo_nv: int, totens: Dictionary, melhorias: Dictionary) -> Dictionary:
	_progresso.melhorias = melhorias.duplicate()
	var est = _script_estatisticas.new()
	var arma := _nivel_arma("espada_basica", arma_nv)
	var escudo := _nivel_arma("escudo_basico", escudo_nv)
	var vit_armadura := 0
	var def_armadura := 0
	for id in _equipamentos.armaduras:
		var d: Dictionary = _equipamentos.armaduras[id]["niveis"][1]
		vit_armadura += d.get("bonus_vitalidade", 0)
		def_armadura += d.get("bonus_defesa", 0)
	est.vitalidade = 5 + vit_armadura + escudo.get("bonus_vitalidade", 0) + 4 * totens.get("item_5", 0)
	est.defesa = def_armadura + escudo.get("bonus_defesa", 0) + 6 * totens.get("item_4", 0)
	est.forca = 5 + 3 * totens.get("item_1", 0)
	est.dano_arma = arma.get("dano", 0)
	est.calcular_estatisticas_derivadas(true)
	var critico_medio: float = 1.0 + est.chance_critico * (est.dano_critico - 1.0)
	var resultado := {
		"hp": est.hp_maximo, "dano": float(est.dano_ataque) * critico_medio, "reducao": est.reducao_dano(),
		"arma_nv": arma_nv, "escudo_nv": escudo_nv, "totens": totens.duplicate(),
	}
	return resultado

func _golpes_para_matar(vida: float, dano_golpe: float) -> int:
	return maxi(ceili(vida / maxf(dano_golpe, 1.0)), 1)

func _golpes_para_morrer(hp: float, dano_inimigo: float, reducao: float) -> float:
	var recebido := maxf(1.0, roundf(dano_inimigo * (1.0 - reducao)))
	return hp / recebido

# Simula as compras onda a onda; devolve uma linha de dados por onda
func _simular() -> Array:
	var linhas: Array = []
	var arma_nv := 1
	var escudo_nv := 1
	var totens := {"item_5": 0, "item_4": 0, "item_1": 0}
	var preco_totem := {}
	for id in TOTENS_ORDEM:
		preco_totem[id] = float(_dados_itens.itens[id]["preco_base"])
	var ouro_livre := 0.0
	var acumulado := 0.0
	var compras_log: Array = []
	for onda in range(1, ONDA_MAX + 1):
		# --- compras antes da onda (loja aberta entre as ondas)
		var comprou := true
		while comprou:
			comprou = false
			var prox_arma := _nivel_arma("espada_basica", arma_nv + 1)
			if not prox_arma.is_empty() and onda >= prox_arma["onda_necessaria"] and ouro_livre >= prox_arma["custo"]:
				ouro_livre -= prox_arma["custo"]
				arma_nv += 1
				compras_log.append("onda %d: espada nv%d (%d)" % [onda, arma_nv, prox_arma["custo"]])
				comprou = true
				continue
			var prox_escudo := _nivel_arma("escudo_basico", escudo_nv + 1)
			var reserva_arma: float = prox_arma.get("custo", 0) if not prox_arma.is_empty() else 0.0
			if not prox_escudo.is_empty() and onda >= prox_escudo["onda_necessaria"] \
					and ouro_livre - reserva_arma >= prox_escudo["custo"]:
				ouro_livre -= prox_escudo["custo"]
				escudo_nv += 1
				compras_log.append("onda %d: escudo nv%d (%d)" % [onda, escudo_nv, prox_escudo["custo"]])
				comprou = true
				continue
			# Totens: só com o ouro que sobra além do próximo upgrade de arma e de escudo
			var reserva := reserva_arma + float(prox_escudo.get("custo", 0))
			for id in TOTENS_ORDEM:
				if ouro_livre - reserva >= roundf(preco_totem[id]):
					ouro_livre -= roundf(preco_totem[id])
					compras_log.append("onda %d: totem %s (%d)" % [onda, _dados_itens.itens[id]["nome"], roundi(preco_totem[id])])
					preco_totem[id] *= _dados_itens.FATOR_PRECO_RECOMPRA
					totens[id] += 1
					comprou = true
					break
		# --- a onda
		var chefe: bool = _gerenciador.eh_onda_chefe(onda)
		var medio := _inimigo_medio(onda)
		var qtd: int = 1 + _gerenciador.escolta_chefe if chefe else _gerenciador.quantidade_inimigos_onda(onda)
		var ouro_abate: int = _gerenciador.ouro_por_abate(onda)
		var dados_chefe := _dados_chefe(onda) if chefe else {}
		var ouro_onda: float = qtd * ouro_abate + _gerenciador.ouro_fim_onda(onda)
		if chefe:
			ouro_onda += dados_chefe["recompensa"]
		acumulado += ouro_onda
		var sem := _estatisticas(arma_nv, escudo_nv, totens, {})
		var com := _estatisticas(arma_nv, escudo_nv, totens, MELHORIAS_MEDIAS)
		var vida_total: float = medio["vida"] * (qtd - 1 if chefe else qtd)
		if chefe:
			vida_total += dados_chefe["vida"]
		linhas.append({
			"onda": onda, "chefe": chefe, "qtd": qtd, "medio": medio, "ouro_abate": ouro_abate,
			"ouro_onda": ouro_onda, "acumulado": acumulado, "sem": sem, "com": com, "vida_total": vida_total,
			"ouro_livre_antes": ouro_livre, "chefe_dados": dados_chefe, "gasto_total": acumulado - ouro_livre - ouro_onda,
		})
		ouro_livre += ouro_onda
	# Brasas por partida que morre na onda n (ondas concluídas = n - 1)
	for linha in linhas:
		var n: int = linha["onda"]
		var concluidas := n - 1
		var chefes: int = concluidas / _gerenciador.intervalo_chefe
		linha["brasas"] = _progresso.BRASAS_POR_ONDA * concluidas + _progresso.BRASAS_POR_CHEFE * chefes
	linhas.append({"compras": compras_log})
	return linhas

# ---------------------------------------------------------------------------
# Saída
# ---------------------------------------------------------------------------

func _dps(est: Dictionary) -> float:
	return est["dano"] * GOLPES_POR_SEGUNDO * UPTIME

func _dps_chefe(est: Dictionary) -> float:
	return est["dano"] * GOLPES_POR_SEGUNDO * UPTIME_CHEFE

func _imprimir(linhas: Array) -> void:
	var compras: Array = linhas.pop_back()["compras"]
	print("=== BALANCEAMENTO (ondas 1 a %d)%s ===" % [ONDA_MAX, " - PARAMETROS ANTIGOS" if _antigo else ""])
	print("Premissas: %.1f golpes/s, %d%% de acerto efetivo; gasto: espada > escudo > totens (so o que sobra do proximo upgrade)." % [GOLPES_POR_SEGUNDO, roundi(UPTIME * 100)])
	print("Melhorias medias = vigor/forca/couraca nv 3 (+24%% vida, +18%% dano, +12%% reducao). Jogador com i-frames de %.1f s: 1 golpe recebido por vez." % 0.6)
	print("")
	print("--- A) INIMIGOS E OURO ---")
	print("onda | qtd | vida  | dano | vel | mut% | ouro/abate | ouro/onda | acumulado | brasas se morrer")
	for l in linhas:
		if _resumo and not ONDAS_CHAVE.has(l["onda"]):
			continue
		var m: Dictionary = l["medio"]
		print("%4d%s| %3d | %5.0f | %4.1f | %3.0f | %3.0f | %10d | %9.0f | %9.0f | %d" % [
			l["onda"], "*" if l["chefe"] else " ", l["qtd"], m["vida"], m["dano"], m["velocidade"], m["p_mut"] * 100.0,
			l["ouro_abate"], l["ouro_onda"], l["acumulado"], l["brasas"]])
	print("(* onda de chefe: qtd = chefe + escolta; a vida media e a dos comuns)")
	print("")
	print("--- B) JOGADOR SEM MELHORIAS PERMANENTES (equipamento esperado pelo ouro) ---")
	print("onda | espada/escudo | HP  | dano/golpe | reducao | golpes p/ matar | golpes p/ morrer | dps | tempo da onda (s)")
	_imprimir_jogador(linhas, "sem")
	print("")
	print("--- C) JOGADOR COM MELHORIAS MEDIAS (vigor/forca/couraca nv 3) ---")
	print("onda | espada/escudo | HP  | dano/golpe | reducao | golpes p/ matar | golpes p/ morrer | dps | tempo da onda (s)")
	_imprimir_jogador(linhas, "com")
	print("")
	print("--- D) LOJA/BIGORNA x OURO ---")
	print("Custos: espada nv2..5 = 200/500/1000/2000 (ondas 4/8/14/22); escudo nv2..5 = 150/400/800/1600; totens %s" % _precos_totens())
	print("onda | ouro acumulado | gasto simulado | ouro livre p/ a proxima onda")
	for l in linhas:
		if _resumo and not ONDAS_CHAVE.has(l["onda"]):
			continue
		print("%4d | %14.0f | %14.0f | %10.0f" % [l["onda"], l["acumulado"] - l["ouro_onda"], l["gasto_total"], l["ouro_livre_antes"]])
	print("Compras simuladas: " + ("; ".join(PackedStringArray(compras.slice(0, 14))) if not compras.is_empty() else "nenhuma"))
	print("")
	print("--- E) CHEFES (alvo: %d a %d s de luta com o equipamento esperado; %.0f%% de acerto efetivo contra chefe) ---" % [ALVO_CHEFE_MIN, ALVO_CHEFE_MAX, UPTIME_CHEFE * 100.0])
	print("onda | chefe                | vida   | dano toque/forte | luta sem melhorias (s) | luta com melhorias (s) | golpes p/ morrer (forte)")
	for l in linhas:
		if not l["chefe"]:
			continue
		var c: Dictionary = l["chefe_dados"]
		var sem: Dictionary = l["sem"]
		var com: Dictionary = l["com"]
		var t_sem: float = c["vida"] / _dps_chefe(sem)
		var t_com: float = c["vida"] / _dps_chefe(com)
		print("%4d | %-20s | %6.0f | %5.1f / %5.1f    | %22.1f | %22.1f | %.1f / %.1f" % [
			l["onda"], c["nome"], c["vida"], c["dano"], c["dano_forte"], t_sem, t_com,
			_golpes_para_morrer(sem["hp"], c["dano_forte"], sem["reducao"]), _golpes_para_morrer(com["hp"], c["dano_forte"], com["reducao"])])

func _precos_totens() -> String:
	var partes: Array = []
	for id in TOTENS_ORDEM:
		partes.append("%s %d" % [_dados_itens.itens[id]["nome"], _dados_itens.itens[id]["preco_base"]])
	return ", ".join(partes)

func _imprimir_jogador(linhas: Array, chave: String) -> void:
	for l in linhas:
		if _resumo and not ONDAS_CHAVE.has(l["onda"]):
			continue
		var est: Dictionary = l[chave]
		var m: Dictionary = l["medio"]
		var dps := _dps(est)
		print("%4d%s| %d / %d         | %3d | %10.1f | %6.0f%% | %15d | %16.1f | %3.0f | %8.1f" % [
			l["onda"], "*" if l["chefe"] else " ", est["arma_nv"], est["escudo_nv"], est["hp"], est["dano"],
			est["reducao"] * 100.0, _golpes_para_matar(m["vida"], est["dano"]),
			_golpes_para_morrer(est["hp"], m["dano"], est["reducao"]), dps,
			maxf(l["vida_total"] / dps, l["qtd"] * TEMPO_SPAWN)])
