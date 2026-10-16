extends SceneTree

# Rodar: godot --headless --path . --script res://testes/teste_plantio.gd
# Mecanica de plantio da fazenda (Etapa B): o autoload Fazenda (arar so na area de plantio, regar, plantar so no arado, crescer
# so regado, chuva rega, murchar na troca de estacao, colher, sementes dos inimigos, caldeirao (colheita -> pocao),
# salvar/carregar, troca de ferramenta) e a cena de verdade (fazenda.tscn): ataque desviado para a ferramenta, animacao +
# efeito no tile certo, teclas Q/E e LB/RB, barra do HUD, solo e plantas desenhados, clima do dia, a tela do caldeirao
# (mouse e controle), painel de debug. As pocoes na arena (cinto, efeitos, drop das sementes) ficam em teste_pocoes.gd.
# Usa arquivos de teste em user:// (apagados no final); a cena da fazenda nao grava inventario nem progresso.

const CAMINHO_FAZENDA := "user://teste_plantio_fazenda.json"
const CAMINHO_CALENDARIO := "user://teste_plantio_calendario.json"
const CAMINHO_PROGRESSO := "user://teste_plantio_progresso.json"

# Celulas de teste dentro da area de plantio (17..31 x 22..30) e uma fora dela
const A := Vector2i(20, 24)
const B := Vector2i(21, 24)
const C := Vector2i(22, 24)
const FORA := Vector2i(5, 5)

var _falhas: int = 0
var _f: Node            # autoload Fazenda
var _cal: Node
var _dados: Node        # DadosJogo
var _progresso: Node
var _plantio_gd: GDScript
var _clima_gd: GDScript   # carregado depois do 1o quadro: clima.gd usa autoloads (Sons) que ainda nao existem ao compilar o teste
var _barra_gd: GDScript
var _inv: Node          # InventarioJogador: ferramentas e sementes moram na mochila

func _initialize() -> void:
	_rodar()

func _verificar(nome: String, condicao: bool, detalhe: String = "") -> void:
	if condicao:
		print("OK ", nome)
	else:
		_falhas += 1
		print("FALHA ", nome, ": ", detalhe)

func _quadros(n: int) -> void:
	for i in n:
		await process_frame

func _fisica(n: int) -> void:
	for i in n:
		await physics_frame

func _rodar() -> void:
	await process_frame
	_f = root.get_node("Fazenda")
	_cal = root.get_node("Calendario")
	_dados = root.get_node("DadosJogo")
	_progresso = root.get_node("Progresso")
	_clima_gd = load("res://codigo/cenario/clima.gd")
	_plantio_gd = load("res://codigo/logica/plantio.gd")
	_barra_gd = load("res://codigo/ui/barra_armas.gd")
	_inv = root.get_node("InventarioJogador")
	var caminho_fazenda: String = _f.caminho_save
	var caminho_calendario: String = _cal.caminho_save
	var caminho_progresso: String = _progresso.caminho_save
	var moedas_antes: int = _dados.moedas
	_f.caminho_save = CAMINHO_FAZENDA
	_cal.caminho_save = CAMINHO_CALENDARIO
	_progresso.caminho_save = CAMINHO_PROGRESSO
	_zerar()

	_testar_dados_das_plantas()
	_testar_arar_so_na_area()
	_testar_regar()
	_testar_plantar_so_no_arado()
	_testar_crescer_so_regado()
	_testar_quadros_das_plantas()
	_testar_chuva_rega()
	_testar_sorteio_do_clima()
	_testar_murchar_na_troca_de_estacao()
	_testar_colher()
	_testar_dar_sementes()
	_testar_caldeirao()
	_testar_salvar_carregar()
	_testar_arquivos_invalidos()
	_testar_troca_de_ferramenta()
	_testar_mapa_de_teclas()
	await _testar_cena_da_fazenda()
	await _testar_arena_sem_barra()

	# Limpeza: o que ficou agendado grava no arquivo de teste, que e apagado depois
	_zerar()
	await _quadros(2)
	for caminho in [CAMINHO_FAZENDA, CAMINHO_CALENDARIO, CAMINHO_PROGRESSO]:
		if FileAccess.file_exists(caminho):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(caminho))
	_f.caminho_save = caminho_fazenda
	_cal.caminho_save = caminho_calendario
	_progresso.caminho_save = caminho_progresso
	_dados.moedas = moedas_antes
	print("FALHAS: ", _falhas)
	quit(_falhas)

# Fazenda vazia, calendario no dia `dia` (sem sinais), sem ouro; mochila no kit inicial (com enxada, regador e mao, sem sementes)
func _zerar(dia := 1) -> void:
	_f.apagar()
	_cal.apagar()
	_cal.dia = dia
	_dados.moedas = 0
	_inv.limpar()
	_inv.criar_itens_iniciais()

## Deixa exatamente `quantos` sementes da planta na mochila
func _definir_sementes(id: String, quantos: int) -> void:
	for i in _inv.mochila.size():
		var item = _inv.mochila[i]
		if item != null and item.categoria == "semente" and item.planta() == id:
			_inv.mochila[i] = null
	_inv.mochila_alterada.emit()
	if quantos > 0:
		_f.dar_sementes(id, quantos)

## {planta: quantidade} das pilhas de semente da mochila
func _sementes_na_mochila() -> Dictionary:
	var tabela := {}
	for item in _inv.mochila:
		if item != null and item.categoria == "semente":
			tabela[item.planta()] = item.quantidade
	return tabela

# Araa a celula e, se pedido, planta (semente da estacao atual; ganha uma de graca)
func _arar(celula: Vector2i) -> String:
	return _f.aplicar("enxada", celula)

func _plantar(celula: Vector2i, id: String) -> String:
	_f.dar_sementes(id)
	return _f.aplicar("plantar", celula, id)

# --- Dados -------------------------------------------------------------------------------------------------

func _testar_dados_das_plantas() -> void:
	_verificar("area de plantio 6,21 32x16", _f.AREA_PLANTIO == Rect2i(6, 21, 32, 16), str(_f.AREA_PLANTIO))
	_verificar("12 plantas, 4 por estacao (inverno sem plantio)",
			_f.PLANTAS.size() == 12 and _f.ORDEM_PLANTAS.size() == 12 and _f.plantas_da_estacao(0).size() == 4
			and _f.plantas_da_estacao(1).size() == 4 and _f.plantas_da_estacao(2).size() == 4 and _f.plantas_da_estacao(3).is_empty(), "")
	var problemas: Array = []
	var folha: Texture2D = load(_f.FOLHA_ICONES)
	for id in _f.PLANTAS:
		var d: Dictionary = _f.PLANTAS[id]
		var tira: Texture2D = load(_f.TIRAS + d["tira"])
		if tira == null:
			problemas.append("%s: tira nao carrega" % id)
			continue
		var altura := 32 if d["alta"] else 16
		if tira.get_height() != altura:
			problemas.append("%s: altura da tira %d != %d" % [id, tira.get_height(), altura])
		var n := int(tira.get_width() / 16)
		for q in d["quadros"]:
			if int(q) >= n:
				problemas.append("%s: quadro %d fora da tira (%d)" % [id, q, n])
		# o quadro 0 e o ultimo nao podem ser vazios (semente e planta madura aparecem)
		var img := tira.get_image()
		for q in [d["quadros"][0], d["quadros"][d["quadros"].size() - 1]]:
			var visivel := false
			for y in img.get_height():
				for x in 16:
					if img.get_pixel(int(q) * 16 + x, y).a > 0.0:
						visivel = true
			if not visivel:
				problemas.append("%s: quadro %d vazio" % [id, q])
		for chave in ["saco", "item"]:
			var cel: Vector2i = d[chave]
			if cel.x * 16 + 16 > folha.get_width() or cel.y * 16 + 16 > folha.get_height():
				problemas.append("%s: %s fora do All Crops" % [id, chave])
		if int(d["dias"]) < 3 or int(d["dias"]) > 6:
			problemas.append("%s: dias %d fora de 3..6 (a estacao tem 7)" % [id, d["dias"]])
		if d.has("venda") or d.has("semente"):
			problemas.append("%s: plantas nao tem mais preco (sementes caem dos inimigos, colheita vira pocao)" % id)
		if not (d["nome"] as String).to_upper() == d["nome"]:
			problemas.append("%s: nome nao e maiusculo" % id)
	_verificar("cada planta: tira, quadros, icones e dias validos (sem preco)", problemas.is_empty(), str(problemas))
	var ordem_ok := true
	for id in _f.ORDEM_PLANTAS:
		ordem_ok = ordem_ok and _f.PLANTAS.has(id)
	_verificar("ORDEM_PLANTAS so tem ids que existem", ordem_ok, "")

# --- Solo ------------------------------------------------------------------------------------------------------

func _testar_arar_so_na_area() -> void:
	_zerar()
	_verificar("dentro_da_area: cantos da area sim, vizinhas nao",
			_f.dentro_da_area(Vector2i(6, 21)) and _f.dentro_da_area(Vector2i(37, 36)) and not _f.dentro_da_area(Vector2i(5, 21))
			and not _f.dentro_da_area(Vector2i(38, 36)) and not _f.dentro_da_area(Vector2i(6, 20)) and not _f.dentro_da_area(Vector2i(6, 37)), "")
	_verificar("celula_do_ponto converte px em tile", _f.celula_do_ponto(Vector2(328, 386)) == A and _f.celula_do_ponto(Vector2(-1, -1)) == Vector2i(-1, -1), "")
	_verificar("enxada fora da area: recusa", _f.aplicar("enxada", FORA) == _f.MSG_FORA and not _f.esta_arado(FORA), "")
	_verificar("enxada na borda de fora da area: recusa", _f.aplicar("enxada", Vector2i(38, 24)) == _f.MSG_FORA, "")
	var emitidos: Array = []
	_f.solo_alterado.connect(func(c): emitidos.append(c))
	_verificar("enxada dentro da area: ara", _f.aplicar("enxada", A) == "" and _f.esta_arado(A) and not _f.esta_molhado(A), "")
	_verificar("arar emite solo_alterado da celula", emitidos == [A], str(emitidos))
	_verificar("arar de novo: ja esta arado", _f.aplicar("enxada", A) == _f.MSG_JA_ARADO and emitidos.size() == 1, "")
	_verificar("avaliar nao muda nada", _f.avaliar("enxada", B) == "" and not _f.esta_arado(B), "")
	_cal.dia = 22   # inverno
	_verificar("inverno: solo congelado, nao ara", _f.aplicar("enxada", B) == _f.MSG_CONGELADO and not _f.esta_arado(B), "")
	_cal.dia = 1
	_verificar("acao desconhecida nao faz nada", _f.avaliar("martelar", A) != "", "")

func _testar_regar() -> void:
	_zerar()
	_verificar("regar sem arar: recusa", _f.aplicar("regar", A) == _f.MSG_ARAR_ANTES and not _f.esta_arado(A), "")
	_verificar("regar fora da area: recusa", _f.aplicar("regar", FORA) == _f.MSG_FORA, "")
	_arar(A)
	_verificar("regar o arado: molha", _f.aplicar("regar", A) == "" and _f.esta_molhado(A), "")
	_verificar("regar de novo: ja esta molhado", _f.aplicar("regar", A) == _f.MSG_JA_MOLHADO, "")
	_verificar("so a celula regada molha", not _f.esta_molhado(B), "")

func _testar_plantar_so_no_arado() -> void:
	_zerar()
	_definir_sementes("cenoura", 2)
	_verificar("plantar sem arar: recusa", _f.aplicar("plantar", A, "cenoura") == _f.MSG_ARAR_ANTES and _f.planta_em(A) == "", "")
	_arar(A)
	_verificar("plantar sem semente (id vazio): recusa", _f.aplicar("plantar", A, "") == _f.MSG_SEM_SEMENTE, "")
	_verificar("plantar semente que nao tem: recusa", _f.aplicar("plantar", A, "batata") == _f.MSG_SEM_SEMENTE, "")
	_definir_sementes("tomate", 1)
	_verificar("semente de verao na primavera: recusa", _f.aplicar("plantar", A, "tomate") == _f.MSG_FORA_ESTACAO and _f.quantidade_sementes("tomate") == 1, "")
	_verificar("plantar fora da area: recusa", _f.aplicar("plantar", FORA, "cenoura") == _f.MSG_FORA, "")
	_verificar("plantar no arado: planta e gasta 1 semente", _f.aplicar("plantar", A, "cenoura") == "" and _f.planta_em(A) == "cenoura" and _f.quantidade_sementes("cenoura") == 1, "")
	_verificar("planta recem plantada: 0 dias, viva, nao madura", _f.dias_crescidos(A) == 0 and not _f.esta_murcha(A) and not _f.esta_madura(A), "")
	_arar(B)
	_verificar("segunda semente em outro arado", _f.aplicar("plantar", B, "cenoura") == "" and _f.quantidade_sementes("cenoura") == 0, "")
	_verificar("a semente zerada some da mochila (a casa esvazia)", not _sementes_na_mochila().has("cenoura"), str(_sementes_na_mochila()))
	_verificar("plantar onde ja tem planta: recusa", _plantar(A, "cenoura") == _f.MSG_TEM_PLANTA, "")
	_verificar("enxada em cima da planta viva: recusa", _f.aplicar("enxada", A) == _f.MSG_TEM_PLANTA and _f.planta_em(A) == "cenoura", "")
	_cal.dia = 22
	_arar_forcado(C)
	_definir_sementes("morango", 1)
	_verificar("inverno: nenhuma semente planta", _f.aplicar("plantar", C, "morango") == _f.MSG_FORA_ESTACAO, "")
	_cal.dia = 1

# Solo arado sem passar pela regra da estacao (para montar cenarios de inverno)
func _arar_forcado(celula: Vector2i) -> void:
	_f.solo[celula] = {"molhado": false, "planta": "", "dias": 0, "murcha": false}

func _testar_crescer_so_regado() -> void:
	_zerar()
	_arar(A)
	_arar(B)
	_plantar(A, "cenoura")   # 3 dias
	_plantar(B, "cenoura")
	_f.aplicar("regar", A)
	_f.avancar_dia(_clima_gd.Estado.LIMPO)
	_verificar("regada cresce 1 dia", _f.dias_crescidos(A) == 1, "dias=%d" % _f.dias_crescidos(A))
	_verificar("nao regada nao cresce", _f.dias_crescidos(B) == 0, "dias=%d" % _f.dias_crescidos(B))
	_verificar("as regas zeram no fim do dia", not _f.esta_molhado(A) and not _f.esta_molhado(B), "")
	_f.avancar_dia(_clima_gd.Estado.LIMPO)
	_verificar("sem regar de novo nao cresce mais", _f.dias_crescidos(A) == 1, "dias=%d" % _f.dias_crescidos(A))
	for i in 2:
		_f.aplicar("regar", A)
		_f.avancar_dia(_clima_gd.Estado.LIMPO)
	_verificar("3 dias regados: madura (cenoura = 3)", _f.dias_crescidos(A) == 3 and _f.esta_madura(A), "dias=%d" % _f.dias_crescidos(A))
	_verificar("a outra continua verde", _f.dias_crescidos(B) == 0 and not _f.esta_madura(B), "")
	_f.aplicar("regar", A)
	_f.avancar_dia(_clima_gd.Estado.LIMPO)
	_verificar("madura nao passa do limite de dias", _f.dias_crescidos(A) == 3, "")
	# o fim do dia passa pelo Calendario de verdade (dormir = estacao_mudou + dia_passou)
	_zerar(3)
	_arar(A)
	_plantar(A, "cenoura")
	_f.aplicar("regar", A)
	_cal.dormir()
	_verificar("Calendario.dormir faz a planta regada crescer (sinal dia_passou)", _cal.dia == 4 and _f.dias_crescidos(A) == 1, "dia=%d dias=%d" % [_cal.dia, _f.dias_crescidos(A)])
	_verificar("dormir grava user://fazenda.json (arquivo de teste)", FileAccess.file_exists(CAMINHO_FAZENDA), "")
	var restante := 7 - 3
	_verificar("da_tempo_de_crescer: cenoura (3) no dia 4 da estacao sim, morango (6) nao",
			_f.da_tempo_de_crescer("cenoura") and not _f.da_tempo_de_crescer("morango"), "restante=%d" % restante)

func _testar_quadros_das_plantas() -> void:
	var ok := true
	var detalhe := ""
	for id in _f.PLANTAS:
		var d: Dictionary = _f.PLANTAS[id]
		var quadros: Array = d["quadros"]
		if _f.quadro_da_planta(id, 0) != quadros[0] or _f.quadro_da_planta(id, d["dias"]) != quadros[quadros.size() - 1]:
			ok = false
			detalhe += " %s extremos;" % id
		var anterior := -1
		for dia in range(0, int(d["dias"]) + 1):
			var indice: int = quadros.find(_f.quadro_da_planta(id, dia))
			if indice < anterior or indice < 0:
				ok = false
				detalhe += " %s dia %d volta;" % [id, dia]
			anterior = indice
		# antes de amadurecer nunca mostra o quadro maduro (so o ultimo dia mostra)
		if int(d["dias"]) > 1 and _f.quadro_da_planta(id, int(d["dias"]) - 1) == quadros[quadros.size() - 1]:
			ok = false
			detalhe += " %s maduro cedo;" % id
	_verificar("quadro_da_planta: 0 = semente, ultimo dia = madura, nunca volta", ok, detalhe)

func _testar_chuva_rega() -> void:
	_zerar()
	_arar(A)
	_arar(B)
	_arar(C)
	_plantar(A, "cenoura")
	_f.avancar_dia(_clima_gd.Estado.CHUVA_LEVE)
	_verificar("chuva no dia seguinte: todo o solo arado amanhece molhado", _f.esta_molhado(A) and _f.esta_molhado(B) and _f.esta_molhado(C), "")
	_verificar("o clima do dia fica guardado", _f.clima_hoje == _clima_gd.Estado.CHUVA_LEVE, "clima=%d" % _f.clima_hoje)
	_verificar("celula nao arada nao aparece molhada", not _f.esta_molhado(Vector2i(25, 28)), "")
	_f.avancar_dia(_clima_gd.Estado.LIMPO)
	_verificar("planta molhada pela chuva cresce na noite seguinte sem o jogador regar", _f.dias_crescidos(A) == 1, "dias=%d" % _f.dias_crescidos(A))
	_verificar("dia limpo: tudo seco de novo", not _f.esta_molhado(A) and not _f.esta_molhado(B), "")
	_f.avancar_dia(_clima_gd.Estado.TEMPESTADE)
	_verificar("tempestade tambem molha", _f.esta_molhado(B), "")
	_f.avancar_dia(_clima_gd.Estado.NEVE_FORTE)
	_verificar("neve nao molha", not _f.esta_molhado(B), "")
	var avisos: Array = []
	_f.clima_do_dia_mudou.connect(func(e): avisos.append(e))
	_f.avancar_dia(_clima_gd.Estado.CHUVA_FORTE)
	_verificar("clima_do_dia_mudou avisa o clima novo", avisos == [_clima_gd.Estado.CHUVA_FORTE], str(avisos))

# O clima do dia sai da tabela da estacao (clima.gd): so estados da tabela, chuva so onde a tabela tem, e a chuva molha
func _testar_sorteio_do_clima() -> void:
	_f.rng.seed = 20261011
	var tabelas: Array = _clima_gd.SORTEIO_POR_ESTACAO
	for estacao in 4:
		_zerar(1 + estacao * 7)
		_arar_forcado(A)
		_arar_forcado(B)
		var permitidos: Array = []
		var tem_chuva := false
		for par in tabelas[estacao]:
			permitidos.append(int(par[0]))
			tem_chuva = tem_chuva or _clima_gd.eh_chuva(int(par[0]))
		var vistos := {}
		var inconsistente := 0
		for i in 80:
			_f.avancar_dia()
			vistos[_f.clima_hoje] = true
			if not permitidos.has(_f.clima_hoje):
				inconsistente += 1
			if _clima_gd.eh_chuva(_f.clima_hoje) != _f.esta_molhado(A):
				inconsistente += 1
		var todos_sorteados := true
		for estado in permitidos:
			todos_sorteados = todos_sorteados and vistos.has(estado)
		_verificar("estacao %d: 80 sorteios so da tabela, chuva <=> solo molhado" % estacao, inconsistente == 0, "inconsistentes=%d vistos=%s" % [inconsistente, str(vistos.keys())])
		_verificar("estacao %d: todos os climas da tabela saem" % estacao, todos_sorteados, str(vistos.keys()))
		if estacao == 3:
			_verificar("inverno: sem chuva (so neve)", not tem_chuva, "")

func _testar_murchar_na_troca_de_estacao() -> void:
	# primavera dia 7 -> verao: a cenoura (primavera) murcha; o tomate plantado no verao nao
	_zerar(7)
	_arar(A)
	_arar(B)
	_plantar(A, "cenoura")
	_plantar(B, "batata")
	_f.aplicar("regar", A)
	_f.aplicar("regar", B)
	_cal.dormir()
	_verificar("dormir no ultimo dia da primavera vira verao (calendario)", _cal.dia == 8 and _cal.estacao() == 1, "")
	_verificar("planta fora da estacao murcha", _f.esta_murcha(A) and _f.esta_murcha(B) and _f.planta_em(A) == "cenoura", "")
	_verificar("planta que murchou nao cresce nessa noite (mesmo regada)", _f.dias_crescidos(A) == 0 and _f.dias_crescidos(B) == 0, "")
	_verificar("murcha: nao amadurece e nao se colhe", not _f.esta_madura(A) and _f.avaliar("colher", A) == _f.MSG_MURCHA, "")
	_f.aplicar("regar", A)
	_f.avancar_dia(_clima_gd.Estado.LIMPO)
	_verificar("murcha continua sem crescer mesmo regada", _f.dias_crescidos(A) == 0 and _f.esta_murcha(A), "")
	_verificar("enxada nao e recusada no resto seco", _f.avaliar("enxada", A) == "", "")
	_verificar("enxada tira o resto seco e deixa o solo arado", _f.aplicar("enxada", A) == "" and _f.planta_em(A) == "" and _f.esta_arado(A) and not _f.esta_murcha(A), "")
	_verificar("o solo livre aceita semente da estacao nova", _plantar(A, "tomate") == "" and _f.planta_em(A) == "tomate" and not _f.esta_murcha(A), "")
	# planta da estacao nova sobrevive a uma troca para a mesma estacao (dentro do verao)
	_f.aplicar("regar", A)
	_cal.dormir()
	_verificar("planta da estacao em curso nao murcha e cresce", not _f.esta_murcha(A) and _f.dias_crescidos(A) == 1, "dias=%d" % _f.dias_crescidos(A))
	# a ultima noite do verao: o tomate tambem murcha (estacao seguinte = outono)
	_cal.dia = 14
	_f.aplicar("regar", A)
	_cal.dormir()
	_verificar("verao -> outono: o tomate murcha", _f.esta_murcha(A) and _cal.estacao() == 2, "")
	# inverno: tudo murcha
	_zerar(21)
	_arar(A)
	_plantar(A, "abobora")
	_cal.dormir()
	_verificar("outono -> inverno: a abobora murcha", _f.esta_murcha(A) and _cal.estacao() == 3, "")
	_verificar("inverno: o resto seco ainda sai com a enxada (o solo ja estava arado)", _f.avaliar("enxada", A) == "", _f.avaliar("enxada", A))
	# o sinal de recarga avisa quem desenha
	_zerar(7)
	_arar(A)
	_plantar(A, "cenoura")
	var recargas: Array = []
	_f.solo_recarregado.connect(func(): recargas.append(1))
	_cal.dormir()
	_verificar("troca de estacao e fim do dia avisam solo_recarregado", recargas.size() >= 1, "")

func _testar_colher() -> void:
	_zerar()
	_arar(A)
	_verificar("colher onde nao tem nada: recusa", _f.aplicar("colher", A) == _f.MSG_NADA_COLHER, "")
	_verificar("colher fora da area: recusa", _f.aplicar("colher", FORA) == _f.MSG_FORA, "")
	_plantar(A, "cenoura")
	_verificar("colher verde: recusa", _f.aplicar("colher", A) == _f.MSG_NAO_PRONTA and _f.planta_em(A) == "cenoura", "")
	for i in 3:
		_f.aplicar("regar", A)
		_f.avancar_dia(_clima_gd.Estado.LIMPO)
	_verificar("pronta depois de 3 dias regados", _f.esta_madura(A), "")
	var avisos: Array = []
	_f.bolsas_alteradas.connect(func(): avisos.append(1))
	_verificar("colher a madura: coloca na bolsa de colheita", _f.aplicar("colher", A) == "" and _f.quantidade_colhida("cenoura") == 1, str(_f.colheita))
	_verificar("colher libera a planta mas o solo continua arado", _f.planta_em(A) == "" and _f.esta_arado(A) and _f.dias_crescidos(A) == 0, "")
	_verificar("colher avisa bolsas_alteradas (HUD/telas)", avisos.size() >= 1, "")
	_verificar("colher de novo no mesmo lugar: nada para colher", _f.aplicar("colher", A) == _f.MSG_NADA_COLHER, "")
	_verificar("a bolsa de colheita nao e a mochila de equipamentos (so contadores)", _f.colheita == {"cenoura": 1}, str(_f.colheita))
	# replantar no mesmo solo e colher de novo soma
	_plantar(A, "cenoura")
	for i in 3:
		_f.aplicar("regar", A)
		_f.avancar_dia(_clima_gd.Estado.LIMPO)
	_f.aplicar("colher", A)
	_verificar("a segunda colheita soma na bolsa", _f.quantidade_colhida("cenoura") == 2, "")

func _testar_dar_sementes() -> void:
	_zerar()
	var sinais := {"n": 0}
	var contar := func(): sinais["n"] += 1
	_f.bolsas_alteradas.connect(contar)
	_f.dar_sementes("tomate")
	_f.dar_sementes("tomate", 2)
	_verificar("dar_sementes empilha na mochila (qualquer estacao: a semente fica guardada) e avisa a bolsa", _f.quantidade_sementes("tomate") == 3 and sinais["n"] == 2, "tem=%d sinais=%d" % [_f.quantidade_sementes("tomate"), sinais["n"]])
	_f.dar_sementes("nao_existe")
	_f.dar_sementes("cenoura", 0)
	_verificar("semente invalida ou quantidade 0: nada muda", _sementes_na_mochila() == {"tomate": 3} and sinais["n"] == 2, str(_sementes_na_mochila()))
	_f.bolsas_alteradas.disconnect(contar)
	var pilhas := 0
	for item in _inv.mochila:
		if item != null and item.tipo == "semente:tomate":
			pilhas += 1
	_verificar("uma casa so por planta (pilha com a quantidade)", pilhas == 1, str(pilhas))
	# mochila cheia: a semente nova nao cabe, mas a da pilha que ja existe sim
	while _inv.tem_espaco():
		_inv.adicionar(_inv._criar_item({"tipo": "maca", "categoria": "arma", "duas_maos": false}))
	_verificar("mochila cheia: semente sem pilha nao entra", not _f.dar_sementes("cenoura") and _f.quantidade_sementes("cenoura") == 0, "")
	_verificar("mochila cheia: a pilha que ja existe aumenta", _f.dar_sementes("tomate") and _f.quantidade_sementes("tomate") == 4, "")
	_verificar("a fazenda nao vende nem compra mais (sem funcoes de ouro)", not _f.has_method("comprar_semente") and not _f.has_method("vender_tudo") and not _f.has_method("vender"), "")

func _testar_caldeirao() -> void:
	_zerar()
	var pocoes: GDScript = load("res://codigo/dados/pocoes.gd")
	# receitas: 6 pocoes, 2 por estacao de plantio, so plantas da mesma estacao, icones dentro da folha
	var problemas: Array = []
	var por_estacao := {}
	var folha: Texture2D = pocoes.FOLHA
	for id in pocoes.ORDEM:
		var d: Dictionary = pocoes.POCOES[id]
		var estacoes := {}
		for planta in d["receita"]:
			if not _f.PLANTAS.has(planta):
				problemas.append("%s: ingrediente %s nao existe" % [id, planta])
				continue
			estacoes[int(_f.PLANTAS[planta]["estacao"])] = true
			if int(d["receita"][planta]) <= 0:
				problemas.append("%s: quantidade invalida" % id)
		if estacoes.size() != 1:
			problemas.append("%s: ingredientes de estacoes diferentes %s" % [id, estacoes.keys()])
		else:
			por_estacao[estacoes.keys()[0]] = int(por_estacao.get(estacoes.keys()[0], 0)) + 1
		var cel: Vector2i = d["icone"]
		if cel.x * 16 + 16 > folha.get_width() or cel.y * 16 + 16 > folha.get_height():
			problemas.append("%s: icone fora da folha" % id)
		if not String(d["nome"]) == String(d["nome"]).to_upper() or not String(d["descricao"]) == String(d["descricao"]).to_upper():
			problemas.append("%s: texto nao e maiusculo" % id)
	_verificar("6 pocoes validas (ingredientes existem, mesma estacao, icone na folha)", pocoes.ORDEM.size() == 6 and pocoes.POCOES.size() == 6 and problemas.is_empty(), str(problemas))
	_verificar("2 receitas por estacao de plantio (primavera, verao, outono)", por_estacao == {0: 2, 1: 2, 2: 2}, str(por_estacao))
	var usadas := {}
	for id in pocoes.ORDEM:
		for planta in pocoes.POCOES[id]["receita"]:
			usadas[planta] = true
	_verificar("toda planta entra em alguma receita (nenhuma colheita fica inutil)", usadas.size() == _f.PLANTAS.size(), "usadas=%d" % usadas.size())
	_verificar("texto do efeito: com duracao e instantanea", pocoes.texto_efeito("forca") == "+30% DE DANO (30S)" and pocoes.texto_efeito("cura") == "CURA 40% DA VIDA", pocoes.texto_efeito("forca"))
	# fazer: gasta a receita, soma a pocao
	_verificar("sem ingredientes: recusa e nao muda nada", _f.fazer_pocao("cura") == _f.MSG_FALTA_INGREDIENTE and _f.pocoes.is_empty(), "")
	_f.colheita = {"cenoura": 2, "morango": 0}
	_verificar("ingrediente faltando (morango 0/1): recusa", _f.motivo_para_nao_fazer("cura") == _f.MSG_FALTA_INGREDIENTE, "")
	_f.colheita = {"cenoura": 5, "morango": 1, "uva": 3}
	_verificar("com ingredientes: pode", _f.motivo_para_nao_fazer("cura") == "", "")
	_verificar("fazer: gasta 2 cenouras e 1 morango e soma 1 pocao", _f.fazer_pocao("cura") == "" and _f.quantidade_colhida("cenoura") == 3
			and _f.quantidade_colhida("morango") == 0 and not _f.colheita.has("morango") and _f.quantidade_pocoes("cura") == 1, "%s %s" % [_f.colheita, _f.pocoes])
	_verificar("acabou o morango: nao faz a segunda", _f.fazer_pocao("cura") == _f.MSG_FALTA_INGREDIENTE and _f.quantidade_pocoes("cura") == 1, "")
	_verificar("pocao invalida: recusa", _f.fazer_pocao("nao_existe") != "", "")
	_f.pocoes["vampiro"] = 2
	_verificar("pocoes_que_tem segue a ordem do cinto", _f.pocoes_que_tem() == ["cura", "vampiro"], str(_f.pocoes_que_tem()))
	_verificar("gastar: tira 1 e some do estoque no zero", _f.gastar_pocao("cura") and not _f.pocoes.has("cura") and not _f.gastar_pocao("cura")
			and _f.gastar_pocao("vampiro") and _f.quantidade_pocoes("vampiro") == 1, str(_f.pocoes))
	_verificar("as pocoes nao mexem no ouro", _dados.moedas == 0, "")

# --- Salvar / carregar ----------------------------------------------------------------------------------------

func _testar_salvar_carregar() -> void:
	_zerar()
	_arar(A)
	_arar(B)
	_arar(C)
	_plantar(A, "cenoura")
	_plantar(B, "batata")
	_f.aplicar("regar", A)
	_f.avancar_dia(_clima_gd.Estado.CHUVA_FORTE)   # A cresce 1 dia; tudo amanhece molhado; clima guardado
	_f.colheita = {"tomate": 2}
	_f.pocoes = {"forca": 3, "cura": 1}
	_f.solo[B]["murcha"] = true
	_verificar("salvar grava o arquivo", _f.salvar() and FileAccess.file_exists(CAMINHO_FAZENDA), "")
	var copia := {"solo": _f.solo.duplicate(true), "colheita": _f.colheita.duplicate(),
			"pocoes": _f.pocoes.duplicate(), "clima": _f.clima_hoje}
	_f.solo = {}
	_f.colheita = {}
	_f.pocoes = {}
	_f.clima_hoje = -1
	_verificar("carregar devolve true", _f.carregar(), "")
	_verificar("carregar: solo igual (arado, molhado, planta, dias, murcha)", _f.solo == copia["solo"], "%s != %s" % [_f.solo, copia["solo"]])
	_verificar("carregar: colheita, pocoes e clima do dia", _f.colheita == copia["colheita"]
			and _f.pocoes == copia["pocoes"] and _f.clima_hoje == copia["clima"], "%s" % _f.pocoes)
	_verificar("carregar: planta de A com 1 dia e B murcha", _f.planta_em(A) == "cenoura" and _f.dias_crescidos(A) == 1 and _f.esta_murcha(B) and _f.esta_molhado(C), "")
	# apagar
	_f.apagar()
	_verificar("apagar: esvazia a memoria e remove o arquivo", _f.solo.is_empty() and _f.colheita.is_empty() and _f.pocoes.is_empty() and _f.clima_hoje == -1 and not FileAccess.file_exists(CAMINHO_FAZENDA), "")
	_verificar("carregar sem arquivo: false e fazenda vazia", not _f.carregar() and _f.solo.is_empty(), "")
	# salvamento agendado: varias mudancas no mesmo quadro viram uma gravacao
	_arar(A)
	_arar(B)
	_verificar("mudancas agendam o salvamento (sem gravar na hora)", not FileAccess.file_exists(CAMINHO_FAZENDA), "")

func _testar_arquivos_invalidos() -> void:
	_zerar()
	var arquivo := FileAccess.open(CAMINHO_FAZENDA, FileAccess.WRITE)
	arquivo.store_string("isto nao e json {{{")
	arquivo.close()
	_verificar("arquivo corrompido: false e fazenda vazia", not _f.carregar() and _f.solo.is_empty(), "")
	arquivo = FileAccess.open(CAMINHO_FAZENDA, FileAccess.WRITE)
	arquivo.store_string(JSON.stringify({"versao": 1, "solo": {
		"20,24": {"molhado": true, "planta": "cenoura", "dias": 99, "murcha": false},
		"21,24": {"molhado": false, "planta": "planta_que_nao_existe", "dias": 4, "murcha": true},
		"5,5": {"molhado": true, "planta": "", "dias": 0, "murcha": false},
		"lixo": {"molhado": true},
		"22,24": 7,
	}, "sementes": {"morango": 3, "inexistente": 9, "batata": -2}, "colheita": {"uva": "x", "milho": 2},
		"pocoes": {"forca": 2, "cenoura": 4, "cura": 0}, "clima_hoje": 99}))
	arquivo.close()
	_verificar("arquivo com lixo: carrega o que presta", _f.carregar(), "")
	_verificar("celula fora da area e chaves invalidas sao descartadas", not _f.esta_arado(FORA) and _f.solo.size() == 2, "celulas=%s" % str(_f.solo.keys()))
	_verificar("dias acima do limite voltam ao limite da planta", _f.dias_crescidos(A) == int(_f.PLANTAS["cenoura"]["dias"]), "dias=%d" % _f.dias_crescidos(A))
	_verificar("planta desconhecida some (solo fica arado) e murcha sem planta e falsa", _f.esta_arado(B) and _f.planta_em(B) == "" and not _f.esta_murcha(B), "")
	_verificar("sementes antigas e colheita: so ids validos e quantidades positivas", _f._sementes_antigas == {"morango": 3} and _f.colheita == {"milho": 2}, "%s %s" % [_f._sementes_antigas, _f.colheita])
	# save antigo: as sementes guardadas na fazenda passam para a mochila (uma vez)
	_inv.limpar()
	_inv.criar_itens_iniciais()
	_f.migrar_sementes_antigas()
	_verificar("migracao: as sementes do save antigo vao para a mochila e saem da fazenda", _f.quantidade_sementes("morango") == 3 and _f._sementes_antigas.is_empty(), str(_sementes_na_mochila()))
	_verificar("pocoes: so ids de pocao (planta nao conta) e quantidades positivas", _f.pocoes == {"forca": 2}, str(_f.pocoes))
	_verificar("clima_hoje fora da faixa vira o limite", _f.clima_hoje == _clima_gd.Estado.NEVE_FORTE, "clima=%d" % _f.clima_hoje)

# --- Ferramentas ---------------------------------------------------------------------------------------------

func _testar_troca_de_ferramenta() -> void:
	_zerar()
	_verificar("ferramentas basicas: enxada, regador e mao da mochila (sem semente nao ha entrada de semente)", _f.ferramentas() == ["enxada", "regador", "machadinha", "picareta"], str(_f.ferramentas()))
	_verificar("comeca na enxada", _f.ferramenta == "enxada" and _f.acao_da_ferramenta() == "enxada", "")
	var avisos: Array = []
	_f.ferramenta_alterada.connect(func(nome): avisos.append(nome))
	_f.trocar_ferramenta(1)
	_verificar("proxima: regador (acao regar)", _f.ferramenta == "regador" and _f.acao_da_ferramenta() == "regar" and avisos == ["regador"], str(avisos))
	_f.trocar_ferramenta(1)
	_verificar("próxima: machadinha (cortar)", _f.ferramenta == "machadinha" and _f.acao_da_ferramenta() == "machado", "")
	_f.trocar_ferramenta(1)
	_verificar("próxima: picareta (minerar)", _f.ferramenta == "picareta" and _f.acao_da_ferramenta() == "picareta", "")
	_f.trocar_ferramenta(1)
	_verificar("proxima da a volta: enxada", _f.ferramenta == "enxada", "")
	_f.trocar_ferramenta(-1)
	_verificar("anterior dá a volta: picareta", _f.ferramenta == "picareta", "")
	_f.dar_sementes("cenoura", 1)
	_f.dar_sementes("morango", 2)
	_f.dar_sementes("tomate", 5)
	_verificar("sementes da estacao entram na lista (so as da primavera, na ordem das casas da mochila)", _f.ferramentas() == ["enxada", "regador", "machadinha", "picareta", "semente:cenoura", "semente:morango"], str(_f.ferramentas()))
	_f.trocar_ferramenta(1)
	_verificar("depois da picareta vem a primeira semente", _f.ferramenta == "semente:cenoura" and _f.semente_da_ferramenta() == "cenoura" and _f.acao_da_ferramenta() == "plantar", _f.ferramenta)
	_f.trocar_ferramenta(1)
	_verificar("proxima semente: morango", _f.ferramenta == "semente:morango", "")
	_f.trocar_ferramenta(1)
	_verificar("depois da ultima semente volta a enxada", _f.ferramenta == "enxada" and _f.semente_da_ferramenta() == "", "")
	_f.definir_ferramenta("semente:tomate")
	_verificar("ferramenta fora da lista (semente de outra estacao) e ignorada", _f.ferramenta == "enxada", "")
	_f.definir_ferramenta("martelo")
	_verificar("ferramenta inexistente e ignorada", _f.ferramenta == "enxada", "")
	# a semente que acaba tira a ferramenta: cai no regador
	_f.definir_ferramenta("semente:cenoura")
	_arar(A)
	_f.aplicar("plantar", A, "cenoura")
	_verificar("acabou a semente ativa: a barra cai no regador", _f.ferramenta == "regador" and not _f.ferramentas().has("semente:cenoura"), _f.ferramenta)
	# a estacao que vira tira as sementes da estacao anterior
	_f.definir_ferramenta("semente:morango")
	_cal.dia = 7
	_cal.dormir()
	_verificar("a estacao virou: as sementes da primavera saem da barra e a ferramenta cai no regador",
			_f.ferramenta == "regador" and _f.ferramentas() == ["enxada", "regador", "machadinha", "picareta", "semente:tomate"], "%s %s" % [_f.ferramenta, _f.ferramentas()])
	_verificar("as sementes da estacao passada continuam guardadas na mochila", _f.quantidade_sementes("morango") == 2, "")
	# a ferramenta que sai da mochila sai da lista; sem nenhuma, nao ha acao
	_cal.dia = 1
	_inv.limpar()
	_inv.mochila_alterada.emit()
	_verificar("sem ferramentas na mochila: lista vazia e sem acao", _f.ferramentas().is_empty() and _f.acao_da_ferramenta() == "", "%s %s" % [_f.ferramentas(), _f.ferramenta])
	_inv.criar_itens_iniciais()
	_verificar("ferramentas de volta: comeca na primeira da barra (enxada)", _f.ferramenta == "enxada", _f.ferramenta)

func _testar_mapa_de_teclas() -> void:
	for nome in ["ferramenta_anterior", "ferramenta_proxima"]:
		_verificar("acao %s existe" % nome, InputMap.has_action(nome), "")
	var teclas := {"ferramenta_anterior": [KEY_Q, JOY_BUTTON_LEFT_SHOULDER], "ferramenta_proxima": [KEY_E, JOY_BUTTON_RIGHT_SHOULDER]}
	for nome in teclas:
		var tem_tecla := false
		var tem_botao := false
		for evento in InputMap.action_get_events(nome):
			if evento is InputEventKey and evento.physical_keycode == teclas[nome][0]:
				tem_tecla = true
			if evento is InputEventJoypadButton and evento.button_index == teclas[nome][1]:
				tem_botao = true
		_verificar("%s: teclado %s e controle (botao %d)" % [nome, OS.get_keycode_string(teclas[nome][0]), teclas[nome][1]], tem_tecla and tem_botao, "")
	# nao quebra os mapeamentos existentes: nenhuma outra acao usa as mesmas teclas/botoes de ferramenta
	var conflito := []
	for nome in InputMap.get_actions():
		if String(nome).begins_with("ui_") or String(nome).begins_with("ferramenta_"):
			continue
		for evento in InputMap.action_get_events(nome):
			if evento is InputEventJoypadButton and (evento.button_index == JOY_BUTTON_LEFT_SHOULDER or evento.button_index == JOY_BUTTON_RIGHT_SHOULDER):
				conflito.append(nome)
			if evento is InputEventKey and (evento.physical_keycode == KEY_Q or evento.physical_keycode == KEY_E or evento.keycode == KEY_Q or evento.keycode == KEY_E):
				conflito.append(nome)
	_verificar("LB/RB e Q/E nao estavam em uso por outras acoes", conflito.is_empty(), str(conflito))
	_verificar("ataque continua em espaco, mouse, X e gatilho direito", _acao_tem("attack", KEY_SPACE) and _acao_tem_botao("attack", JOY_BUTTON_X), "")
	_verificar("rolar (dash) continua no shift e no B", _acao_tem_botao("rolar", JOY_BUTTON_B), "")

func _acao_tem(acao: String, tecla: int) -> bool:
	for evento in InputMap.action_get_events(acao):
		if evento is InputEventKey and (evento.keycode == tecla or evento.physical_keycode == tecla):
			return true
	return false

func _acao_tem_botao(acao: String, botao: int) -> bool:
	for evento in InputMap.action_get_events(acao):
		if evento is InputEventJoypadButton and evento.button_index == botao:
			return true
	return false

# --- A cena da fazenda --------------------------------------------------------------------------------------------

func _duracao(acao: String) -> float:
	var total := 0.0
	for q in load("res://codigo/jogador/fazenda_jogador.gd").ACOES[acao]["quadros"]:
		total += float(q[1])
	return total

# Posiciona o jogador com os pes logo acima da celula `celula`, virado para baixo (a ferramenta acerta a celula)
func _pos_jogador(jogador: Node, celula: Vector2i) -> void:
	jogador.global_position = Vector2(celula.x * 16 + 8, celula.y * 16 - 3) - Vector2(0, 11) + Vector2(0, 0)
	jogador._direcao_ataque = Vector2.DOWN
	jogador.velocity = Vector2.ZERO

func _usar_ferramenta(jogador: Node, acao: String) -> void:
	if acao == "colher":
		current_scene.get_node("Terrains/Plantio").pedir_coleta()
	else:
		jogador.ferramenta_pedida.emit()
	await create_timer(_duracao(acao) + 0.2).timeout

func _testar_cena_da_fazenda() -> void:
	_zerar()
	_dados.moedas = 500
	var fazenda: Node = load("res://cenas/fazenda.tscn").instantiate()
	root.add_child(fazenda)
	current_scene = fazenda
	await _quadros(10)
	var jogador: Node = fazenda.get_node("Jogador")
	var plantio: Node = fazenda.get_node("Terrains/Plantio")
	var hud: Node = get_nodes_in_group("hud")[0]
	_verificar("fazenda: no Plantio existe e liga o modo fazenda do jogador", plantio != null and plantio.get_script() == _plantio_gd and jogador.modo_fazenda, "")
	_verificar("fazenda: o HUD cria a barra de baixo (a mesma da arena) no modo fazenda", hud.barra_armas != null and hud.barra_armas.get_script() == _barra_gd and hud.barra_armas.modo_fazenda, "")
	_verificar("fazenda: sem cinto de pocoes (Q/E sao das ferramentas; so se bebe na arena)", hud.cinto_pocoes == null and not jogador._cinto_de_pocoes_ativo(), "")
	_verificar("fazenda: a area de plantio e toda de terra no mapa (camada Terra)", _area_toda_em_terra(fazenda), "")
	_verificar("poções são serviço da Rosa; sem zona antiga na fazenda", fazenda.get_node_or_null("Terrains/InteracaoCaldeirao") == null, "")

	# --- ataque desviado para a ferramenta (com arma equipada); o dash continua
	if not jogador.usando_espada:   # (o inventario real pode ja ter a espada equipada: equipar de novo desequipa)
		jogador.equipar_espada()
	await _quadros(2)
	_verificar("com espada equipada", jogador.usando_espada, "")
	jogador.invulneravel = true
	jogador.temporizador_invul = 9999.0
	var pedidos := {"n": 0}
	jogador.ferramenta_pedida.connect(func(): pedidos["n"] += 1)
	_pos_jogador(jogador, A)
	await _fisica(3)
	await _quadros(2)
	_verificar("o cursor marca o tile a frente (dentro da area e valido para a enxada)", plantio._cursor_visivel and plantio._celula_cursor == A and plantio._cursor_valido, "%s %s %s" % [plantio._cursor_visivel, plantio._celula_cursor, plantio._cursor_valido])
	var evento := InputEventAction.new()
	evento.action = "attack"
	evento.pressed = true
	Input.parse_input_event(evento)
	await _fisica(4)
	_verificar("fazenda: o ataque nao golpeia (sem combo, sem arma em uso)", not jogador._esta_atacando and jogador._fase_combo == 0, "atacando=%s fase=%d" % [jogador._esta_atacando, jogador._fase_combo])
	_verificar("fazenda: o ataque pediu a ferramenta (uma vez)", pedidos["n"] == 1, "pedidos=%d" % pedidos["n"])
	var solto := InputEventAction.new()
	solto.action = "attack"
	solto.pressed = false
	Input.parse_input_event(solto)
	await create_timer(_duracao("enxada") + 0.3).timeout
	_verificar("o pedido tocou a animacao da enxada e arou o tile a frente", _f.esta_arado(A), "")
	_verificar("a animacao terminou e o jogador esta livre", not jogador.esta_em_acao_fazenda, "")

	# --- fora da area: sem animacao, com aviso
	_pos_jogador(jogador, FORA)
	await _fisica(2)
	_f.definir_ferramenta("enxada")
	jogador.ferramenta_pedida.emit()
	await _quadros(2)
	_verificar("enxada fora da area: nao toca a animacao e nao ara", not jogador.esta_em_acao_fazenda and not _f.esta_arado(FORA), "")
	_verificar("enxada fora da area: aviso na barra", hud.barra_armas._nome.text == _f.MSG_FORA and hud.barra_armas._nome.modulate.a > 0.5, hud.barra_armas._nome.text)

	# --- regar, plantar, crescer, colher (a cena inteira, com animacao e efeitos)
	_pos_jogador(jogador, A)
	await _fisica(2)
	_f.definir_ferramenta("regador")
	await _usar_ferramenta(jogador, "regar")
	_verificar("regador: o tile fica molhado", _f.esta_molhado(A), "")
	_definir_sementes("cenoura", 3)
	_f.definir_ferramenta("semente:cenoura")
	await _usar_ferramenta(jogador, "plantar")
	_verificar("semente: planta no tile arado e gasta uma", _f.planta_em(A) == "cenoura" and _f.quantidade_sementes("cenoura") == 2, "")
	var sprite: Sprite2D = plantio._sprites.get(A)
	_verificar("a planta aparece no mapa (sprite com a tira da cenoura, quadro da semente)", sprite != null and sprite.frame == 0 and sprite.texture.resource_path.ends_with("Spring/Carrot.png"), "")
	_verificar("a planta fica na base do tile e na profundidade dele", sprite != null and sprite.global_position == Vector2(A.x * 16, (A.y + 1) * 16) and sprite.z_index == _z_da_planta(A), "")
	# o jogador colhe so quando pronta; sem pronta: aviso e sem animacao
	_f.definir_ferramenta("regador")
	plantio.pedir_coleta()
	await _quadros(2)
	_verificar("mao na planta verde: recusa com aviso e sem animacao", not jogador.esta_em_acao_fazenda and hud.barra_armas._nome.text == _f.MSG_NAO_PRONTA, hud.barra_armas._nome.text)
	for i in 3:
		_f.aplicar("regar", A)
		_f.avancar_dia(_clima_gd.Estado.LIMPO)
		await _quadros(1)
	_verificar("depois de 3 dias regados o sprite mostra a planta madura", plantio._sprites[A].frame == 5 and _f.esta_madura(A), "frame=%d" % plantio._sprites[A].frame)
	var colhidos_antes: int = _f.quantidade_colhida("cenoura")
	await _usar_ferramenta(jogador, "colher")
	_verificar("mao na madura: colhe para a bolsa e o sprite some", _f.quantidade_colhida("cenoura") == colhidos_antes + 1 and not plantio._sprites.has(A), "")
	_verificar("o solo continua arado depois da colheita", _f.esta_arado(A), "")

	# --- aparencia do solo: arado e molhado diferentes entre si e do chao
	var seco: Texture2D = _plantio_gd.textura_do_solo(0, false, A)
	var molhado: Texture2D = _plantio_gd.textura_do_solo(0, true, A)
	_verificar("solo arado: textura propria (16x16), molhada mais escura", seco.get_size() == Vector2(16, 16) and _brilho(molhado) < _brilho(seco) * 0.8, "seco=%.3f molhado=%.3f" % [_brilho(seco), _brilho(molhado)])
	var distintas := {}
	for estacao in 4:
		distintas[_plantio_gd.textura_do_solo(estacao, false, A)] = true
	_verificar("o solo acompanha o tom de cada estacao (4 texturas diferentes)", distintas.size() == 4, "")
	_verificar("solo isolado tem cantos transparentes e centro preenchido", seco.get_image().get_pixel(0, 0).a == 0.0 and seco.get_image().get_pixel(8, 8).a == 1.0, "")

	# --- chuva do dia na cena
	var meteoro: Node = fazenda.get_node("Terrains/Estacoes").meteorologia
	_verificar("primavera sem sorteio ainda: clima padrao (limpo)", meteoro.clima_atual == _clima_gd.Estado.LIMPO, "clima=%d" % meteoro.clima_atual)
	_f.aplicar("enxada", B)
	_f.avancar_dia(_clima_gd.Estado.CHUVA_LEVE)
	await _quadros(4)
	_verificar("chuva do dia: o clima da cena vira chuva e o solo amanhece molhado", meteoro.clima_atual == _clima_gd.Estado.CHUVA_LEVE and _f.esta_molhado(B), "clima=%d" % meteoro.clima_atual)
	# o clima do dia vale ao entrar de novo na fazenda (a cena e nova)
	fazenda.queue_free()
	await _quadros(3)
	fazenda = load("res://cenas/fazenda.tscn").instantiate()
	root.add_child(fazenda)
	current_scene = fazenda
	await _quadros(8)
	meteoro = fazenda.get_node("Terrains/Estacoes").meteorologia
	_verificar("fazenda recarregada: continua chovendo (clima do dia salvo)", meteoro.clima_atual == _clima_gd.Estado.CHUVA_LEVE, "clima=%d" % meteoro.clima_atual)
	jogador = fazenda.get_node("Jogador")
	plantio = fazenda.get_node("Terrains/Plantio")
	hud = get_nodes_in_group("hud")[0]
	_verificar("fazenda recarregada: o solo arado e os dados continuam (vem do autoload)", _f.esta_arado(A) and _f.esta_arado(B), "")
	# estacao do dia sem chuva possivel: o clima do dia que nao combina com a estacao e ignorado
	_cal.dia = 22
	fazenda.get_node("Terrains/Estacoes").definir_estacao(3, true)
	await _quadros(4)
	_verificar("chuva guardada nao vale no inverno (so neve): volta ao padrao da estacao", _clima_gd.eh_neve(meteoro.clima_atual), "clima=%d" % meteoro.clima_atual)
	_cal.dia = 1
	fazenda.get_node("Terrains/Estacoes").definir_estacao(0, true)
	await _quadros(4)
	_f.clima_hoje = _clima_gd.Estado.LIMPO

	# --- plantas guardadas voltam como sprites ao recarregar a cena
	_f.solo[C] = {"molhado": false, "planta": "morango", "dias": 3, "murcha": false}
	_f.solo[Vector2i(23, 24)] = {"molhado": false, "planta": "milho", "dias": 5, "murcha": true}
	_f.solo_recarregado.emit()
	await _quadros(2)
	plantio = fazenda.get_node("Terrains/Plantio")
	var s_morango: Sprite2D = plantio._sprites.get(C)
	var s_milho: Sprite2D = plantio._sprites.get(Vector2i(23, 24))
	_verificar("planta no meio do crescimento: quadro certo da tira", s_morango != null and s_morango.frame == _f.quadro_da_planta("morango", 3), "")
	_verificar("planta alta (16x32): sprite com 32 px e alinhamento do quadro atual", s_milho != null and s_milho.texture.get_height() == 32 and s_milho.offset == _plantio_gd.deslocamento_da_planta("milho", s_milho.frame), "")
	_verificar("planta murcha: aparencia seca (shader e tom); a viva nao tem", s_milho != null and s_milho.material is ShaderMaterial and s_milho.modulate != Color.WHITE
			and s_morango.material != s_milho.material and s_morango.modulate == Color.WHITE
			and s_milho.material.shader.code == _plantio_gd.CODIGO_SECO, "")
	_f.solo.erase(C)
	_f.solo.erase(Vector2i(23, 24))
	_f.solo_recarregado.emit()

	_testar_centralizacao_das_plantas(plantio)

	# --- troca de ferramenta pelas teclas (Q/E) na cena
	_definir_sementes("cenoura", 2)
	_f.definir_ferramenta("enxada")
	await _enviar_acao("ferramenta_proxima")
	_verificar("tecla E: proxima ferramenta (regador)", _f.ferramenta == "regador", _f.ferramenta)
	await _enviar_acao("ferramenta_anterior")
	_verificar("tecla Q: ferramenta anterior (enxada)", _f.ferramenta == "enxada", _f.ferramenta)
	await _enviar_acao("ferramenta_anterior")
	_verificar("Q na primeira: da a volta para a ultima (semente de cenoura)", _f.ferramenta == "semente:cenoura", _f.ferramenta)
	jogador.desabilitar_todas_acoes(true)
	await _enviar_acao("ferramenta_proxima")
	_verificar("com tela aberta (acoes desabilitadas) a troca e ignorada", _f.ferramenta == "semente:cenoura", _f.ferramenta)
	jogador.desabilitar_todas_acoes(false)
	_f.definir_ferramenta("enxada")

	# durante a animacao a troca e ignorada (a acao em andamento fica com a ferramenta que a comecou)
	_f.definir_ferramenta("enxada")
	_pos_jogador(jogador, Vector2i(25, 27))
	await _fisica(2)
	jogador.ferramenta_pedida.emit()
	await create_timer(0.1).timeout
	_verificar("animacao em andamento", jogador.esta_em_acao_fazenda, "")
	await _enviar_acao("ferramenta_proxima")
	_verificar("trocar de ferramenta no meio da animacao e ignorado", _f.ferramenta == "enxada", _f.ferramenta)
	await create_timer(_duracao("enxada") + 0.2).timeout
	_verificar("a animacao acabou arando o tile (com a ferramenta que a comecou)", _f.esta_arado(Vector2i(25, 27)) and not jogador.esta_em_acao_fazenda, "")

	# --- barra de baixo do HUD: a primeira linha da mochila (espada, escudo, enxada, regador, mao)
	var barra: Control = hud.barra_armas
	await _quadros(2)
	_verificar("barra: 8 casas da primeira linha da mochila", barra._casas.size() == 8 and barra._casas[2].get_node("Conteudo/Slot").item_atual.tipo == "enxada", "casas=%d" % barra._casas.size())
	_verificar("barra: mostra o nome da ferramenta ativa (fixo na fazenda)", barra._nome.text == "ENXADA" and barra._nome.modulate.a > 0.9, barra._nome.text)
	_verificar("barra: so a casa da ferramenta ativa em destaque", _casas_ativas(barra) == 1 and barra._casas[2].get_node("Conteudo/Marco").visible, "")
	_verificar("barra: escolher a casa 4 (tecla 4) ativa o regador", barra.escolher(3) and _f.ferramenta == "regador" and barra._casas[3].get_node("Conteudo/Marco").visible, _f.ferramenta)
	_verificar("barra: arma na fazenda nao faz nada (a espada continua sem virar ferramenta)", not barra.escolher(0) and _f.ferramenta == "regador", _f.ferramenta)
	# a semente vai para a primeira linha (casa 5 no lugar da mao) e mostra a quantidade e o tempo de crescimento
	var mao_item = _inv.mochila[4]
	var casa_semente: int = _inv.indice_de(_inv._pilha_de_semente("cenoura"))
	_inv.mochila[4] = _inv.mochila[casa_semente]
	_inv.mochila[casa_semente] = mao_item
	_inv.mochila_alterada.emit()
	await _quadros(2)
	_verificar("barra: escolher a semente mostra o nome com o tempo de crescimento", barra.escolher(4) and _f.ferramenta == "semente:cenoura" and barra._nome.text == "SEMENTE: CENOURA - CRESCE EM 3 DIAS", barra._nome.text)
	var quantidade: Label = barra._casas[4].get_node("Conteudo/Slot/ItemUi").get_node_or_null("Quantidade")
	_verificar("barra: a casa da semente mostra a quantidade", quantidade != null and quantidade.visible and quantidade.text == "2", "")
	hud.avisar_ferramenta("TESTE")
	_verificar("HUD.avisar_ferramenta mostra o aviso", barra._nome.text == "TESTE" and barra._nome.modulate.a > 0.9, "")
	_verificar("barra: dentro da tela (576x324)", _dentro_da_tela(barra._coluna), str(barra._coluna.get_global_rect()))
	_f.definir_ferramenta("enxada")

	# --- tela de sementes (mouse/teclado e controle)
	await _testar_tela_do_caldeirao(fazenda, jogador)

	# --- painel de debug
	await _testar_painel_debug()

	jogador.invulneravel = false
	fazenda.queue_free()
	await _quadros(3)

func _z_da_planta(celula: Vector2i) -> int:
	return load("res://codigo/globais/profundidade.gd").z_de(celula.y * 16 + 10.0)

func _testar_centralizacao_das_plantas(plantio: Node) -> void:
	for id in _f.PLANTAS:
		var dados: Dictionary = _f.PLANTAS[id]
		var imagem: Image = load("res://codigo/ui/icones_fazenda.gd").tira(id).get_image()
		for dias in range(int(dados["dias"]) + 1):
			_f.solo[C] = {"molhado": false, "planta": id, "dias": dias, "murcha": false}
			plantio._atualizar_planta(C)
			var sprite: Sprite2D = plantio._sprites[C]
			var area := imagem.get_region(Rect2i(sprite.frame * 16, 0, 16, imagem.get_height())).get_used_rect()
			var origem := sprite.position - Vector2(C) * 16 + sprite.offset + Vector2(area.position)
			var centro := origem + Vector2(area.size) * 0.5
			var alinhada := absf(centro.x - 8.0) <= 0.5
			if area.size.y <= 16:
				alinhada = alinhada and absf(centro.y - 8.0) <= 0.5 and origem.y >= 0 and origem.y + area.size.y <= 16
			else:
				alinhada = alinhada and absf(origem.y + area.size.y - 16.0) <= 0.5
			_verificar("arte centralizada: %s, dia %d" % [id, dias], alinhada, "centro=%s origem=%s" % [centro, origem])
			# A próxima espécie deve criar a própria tira; os dias da mesma planta reutilizam o sprite.
		_f.solo.erase(C)
		plantio._atualizar_planta(C)

func _brilho(textura: Texture2D) -> float:
	var img := textura.get_image()
	var soma := 0.0
	for y in 16:
		for x in 16:
			var c := img.get_pixel(x, y)
			soma += (c.r + c.g + c.b) / 3.0
	return soma / 256.0

func _area_toda_em_terra(fazenda: Node) -> bool:
	var terra: TileMapLayer = fazenda.get_node("Terrains/Terra")
	for y in range(_f.AREA_PLANTIO.position.y, _f.AREA_PLANTIO.end.y):
		for x in range(_f.AREA_PLANTIO.position.x, _f.AREA_PLANTIO.end.x):
			if terra.get_cell_source_id(Vector2i(x, y)) == -1:
				return false
	return true

func _enviar_acao(nome: String) -> void:
	var ev := InputEventAction.new()
	ev.action = nome
	ev.pressed = true
	Input.parse_input_event(ev)
	await _quadros(2)
	var solto := InputEventAction.new()
	solto.action = nome
	solto.pressed = false
	Input.parse_input_event(solto)
	await _quadros(1)

func _tem_rotulo(no: Node, texto: String) -> bool:
	for filho in no.get_children():
		if filho is Label and filho.text == texto:
			return true
	return false

func _casas_ativas(barra: Control) -> int:
	var n := 0
	for casa in barra._casas:
		var marco: Node = casa.get_node_or_null("Conteudo/Marco")
		if marco != null and marco.visible:
			n += 1
	return n

func _dentro_da_tela(no: Control) -> bool:
	var ret := no.get_global_rect()
	return ret.position.x >= 0.0 and ret.position.y >= 0.0 and ret.end.x <= root.get_visible_rect().size.x and ret.end.y <= root.get_visible_rect().size.y and ret.size.x > 10.0

func _testar_tela_do_caldeirao(fazenda: Node, jogador: Node) -> void:
	var interface: Node = fazenda.get_node("Interface")
	var tela: Control = interface.get_node("TelaCaldeirao")
	_verificar("tela do caldeirao existe e comeca fechada; as de compra e venda sairam", tela != null and not tela.visible
			and interface.get_node_or_null("TelaSementes") == null and interface.get_node_or_null("TelaColheita") == null, "")
	var painel: Control = tela.get_node("Painel")
	_verificar("painel na lateral direita (desliza da borda, nao e central)",
			tela.theme != null and painel.anchor_left == 1.0
			and not "caldeirao" in interface.TELAS_CENTRAIS and interface._paineis["caldeirao"] == painel, "")
	_f.apagar()
	_cal.dia = 1
	_dados.moedas = 77
	_f.colheita = {"cenoura": 4, "morango": 1, "tomate": 2}
	root.get_node("EventosJogo").abrir_tela_de(jogador, "caldeirao")
	await _quadros(3)
	_verificar("serviço de poções abre pela interface do jogador", tela.visible, "")
	_verificar("tela aberta trava as acoes do jogador", not jogador.movimento_habilitado, "")
	_verificar("grade com um frasco por pocao (6), na ordem", tela.casas.keys() == ["cura", "folego", "forca", "velocidade", "pedra", "vampiro"], str(tela.casas.keys()))
	_verificar("frasco apagado quando falta ingrediente (forca: falta melancia), aceso quando da (cura)",
			(tela.casas["forca"].get_node("Icone") as TextureRect).modulate != Color.WHITE and (tela.casas["cura"].get_node("Icone") as TextureRect).modulate == Color.WHITE, "")
	# escolher: o quadro mostra a poção, o efeito e os ingredientes
	tela.selecionar("forca")
	await _quadros(2)
	var detalhes: Node = tela.get_node("Painel/Linhas/Detalhe")
	var tilemap := (tela.get_node("Painel") as PanelContainer).get_theme_stylebox("panel") as StyleBoxTexture
	_verificar("mesmo visual da mochila e da loja: tema_sidebar, moldura do TileMap e casas BotaoSlot",
			tela.theme.resource_path.ends_with("tema_sidebar.tres") and tilemap != null and tilemap.texture.resource_path.ends_with("TileMap.png")
			and tilemap.region_rect == Rect2(96, 64, 48, 48) and tela.casas["cura"].theme_type_variation == &"BotaoSlot", "")
	_verificar("escolher mostra nome, texto, efeito com duracao e quantas tem", tela._nome.text == "POCAO DE FORCA" and tela._texto.text != ""
			and tela._efeito.text == "+30% DE DANO (30S)" and tela._info.text == "TEM 0" and tela.botao_fazer.text == "FAZER", "%s | %s | %s" % [tela._nome.text, tela._efeito.text, tela._info.text])
	var contagem_melancia: Label = detalhes.find_child("Ingrediente_melancia", true, false).find_child("Contagem", true, false)
	var contagem_tomate: Label = detalhes.find_child("Ingrediente_tomate", true, false).find_child("Contagem", true, false)
	_verificar("ingredientes: tem/precisa, verde quando da e vermelho quando falta", contagem_tomate.text == "2 / 2" and contagem_tomate.get_theme_color("font_color") == tela.COR_TEM
			and contagem_melancia.text == "0 / 1" and contagem_melancia.get_theme_color("font_color") == tela.COR_FALTA, "%s %s" % [contagem_tomate.text, contagem_melancia.text])
	_verificar("FAZER desativado sem ingredientes", tela.botao_fazer.disabled, "")
	tela.fazer()
	await _quadros(2)
	_verificar("fazer sem ingredientes: aviso e nada muda", tela.aviso.text == _f.MSG_FALTA_INGREDIENTE and _f.quantidade_pocoes("forca") == 0, tela.aviso.text)
	# fazer pelo frasco (clique / A)
	tela.casas["cura"].pressed.emit()
	await _quadros(3)
	_verificar("fazer pelo frasco: gasta a colheita, soma a pocao e avisa", _f.quantidade_pocoes("cura") == 1 and _f.quantidade_colhida("cenoura") == 2
			and _f.quantidade_colhida("morango") == 0 and tela.aviso.text == "+1 POCAO DE CURA" and tela.selecionada == "cura", tela.aviso.text)

	_verificar("o frasco mostra quantas tem e apaga (acabou o morango); o quadro mostra TEM 1 e o efeito NA HORA",
			(tela.casas["cura"].get_node("Quantidade") as Label).text == "1" and (tela.casas["cura"].get_node("Icone") as TextureRect).modulate != Color.WHITE
			and tela._info.text == "TEM 1" and tela._efeito.text == "CURA 40% DA VIDA NA HORA", tela._info.text)
	_verificar("a escolhida fica com a moldura dourada do slot (so ela)", tela.casas["cura"].get_theme_stylebox("normal") == tela.get_theme_stylebox("hover", &"BotaoSlot")
			and tela.casas["forca"].get_theme_stylebox("normal") == tela.get_theme_stylebox("normal", &"BotaoSlot"), "")
	_verificar("o ouro nao muda", _dados.moedas == 77, "")
	# controle: foco no primeiro frasco que dá para fazer; mover o foco escolhe; dicas A/B
	var controle := root.get_node("Controle")
	controle._definir(true)
	_f.colheita = {"tomate": 2, "melancia": 1}
	tela._atualizar()
	tela.focar_inicio()
	await _quadros(2)
	_verificar("controle: o foco comeca no primeiro frasco que da para fazer (forca)", tela.get_viewport().gui_get_focus_owner() == tela.casas["forca"] and tela.selecionada == "forca", str(tela.get_viewport().gui_get_focus_owner()))
	tela.casas["velocidade"].grab_focus()
	await _quadros(1)
	_verificar("controle: mover o foco escolhe a pocao", tela.selecionada == "velocidade" and tela._nome.text == "POCAO DE VELOCIDADE", tela.selecionada)
	_verificar("controle: frascos e o X alcancaveis por foco (FAZER nao: o A no frasco ja faz)", tela.casas.values().all(func(c): return c.focus_mode == Control.FOCUS_ALL)
			and tela.botao_fechar.focus_mode == Control.FOCUS_ALL and tela.botao_fazer.focus_mode == Control.FOCUS_NONE, "")
	tela.casas["forca"].grab_focus()
	tela.casas["forca"].pressed.emit()
	await _quadros(3)
	_verificar("A no frasco faz a pocao e o foco continua nele", _f.quantidade_pocoes("forca") == 1 and tela.get_viewport().gui_get_focus_owner() == tela.casas["forca"], "")
	controle._definir(false)
	tela.botao_fechar.pressed.emit()
	await _quadros(3)
	_verificar("o X devolve o controle ao jogador", not tela.visible and jogador.movimento_habilitado, "")
	jogador.global_position = Vector2(300, 300)

func _todos_focaveis(tela: Control) -> bool:
	for botao in tela.find_children("*", "BaseButton", true, false):
		if (botao as BaseButton).focus_mode != Control.FOCUS_ALL:
			return false
	return true

func _testar_painel_debug() -> void:
	var painel: Node = root.get_node_or_null("PainelDebug")
	if painel == null:
		print("OK painel de debug ausente (build sem debug): nada a conferir")
		return
	_zerar()
	_dados.moedas = 0
	painel._ao_ouro()
	_verificar("debug: +100 OURO", _dados.moedas == 100, "")
	painel._ao_sementes()
	_verificar("debug: SEMENTES da a estacao atual na mochila (5 de cada, 4 plantas na primavera)", _sementes_na_mochila().size() == 4 and _f.quantidade_sementes("cenoura") == 5 and _f.quantidade_sementes("tomate") == 0, str(_sementes_na_mochila()))
	painel._ao_colheita()
	_verificar("debug: COLHEITA da 5 de cada planta (todas as estacoes)", _f.colheita.size() == 12 and _f.quantidade_colhida("uva") == 5, str(_f.colheita.size()))
	painel._ao_pocoes()
	_verificar("debug: POCOES da 3 de cada pocao", _f.pocoes.size() == 6 and _f.quantidade_pocoes("forca") == 3, str(_f.pocoes))
	_arar(A)
	_plantar(A, "cenoura")
	painel._ao_crescer()
	_verificar("debug: CRESCER 1 DIA cresce sem regar", _f.dias_crescidos(A) == 1 and not _f.esta_molhado(A), "")
	painel._ao_regar_tudo()
	_verificar("debug: REGAR TUDO molha o solo arado", _f.esta_molhado(A), "")
	painel._ao_passar_dia()
	_verificar("debug: PASSAR DIA faz a planta regada crescer", _f.dias_crescidos(A) == 2 and _cal.dia == 2, "dias=%d dia=%d" % [_f.dias_crescidos(A), _cal.dia])
	await _quadros(1)

# A arena nao tem barra de ferramentas e o ataque continua sendo ataque
func _testar_arena_sem_barra() -> void:
	_zerar()
	var arena: Node = load("res://cenas/cenario.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	await _quadros(10)
	var hud: Node = get_nodes_in_group("hud")[0]
	var jogador: Node = arena.get_node("Jogador")
	_verificar("arena: a barra de baixo nao esta no modo fazenda", hud.barra_armas != null and not hud.barra_armas.modo_fazenda, "")
	_verificar("arena: o jogador nao esta em modo fazenda (ataque e ataque)", not jogador.modo_fazenda, "")
	arena.queue_free()
	await _quadros(3)
