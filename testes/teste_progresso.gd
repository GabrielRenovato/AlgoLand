extends SceneTree

# Rodar: godot --headless --path . --script res://testes/teste_progresso.gd
# Usa instâncias isoladas do Progresso e do modelo de inventário (sem tocar nos saves reais)

var ScriptProgresso: GDScript
var ScriptModelo: GDScript

const CAMINHO_TESTE := "user://teste_progresso.json"

var _falhas: int = 0

func _initialize() -> void:
	_rodar()

func _rodar() -> void:
	await process_frame
	ScriptProgresso=load("res://codigo/globais/progresso.gd")
	ScriptModelo = load("res://codigo/modelos/modelo_inventario.gd")
	_testar_comprar_melhoria()
	_testar_custos_e_maximo()
	_testar_brasas_insuficientes()
	_testar_bonus()
	_testar_salvar_carregar()
	_testar_encerrar_partida()
	_testar_bonus_do_bardo()
	_testar_recorde()
	_testar_chefe_conta_uma_vez()
	_testar_checkpoint_da_mistica()
	_testar_contratar_morador()
	_testar_reset_do_inventario()
	_testar_reviver_da_curandeira()
	_testar_apagar()
	if FileAccess.file_exists(CAMINHO_TESTE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CAMINHO_TESTE))
	quit(_falhas)

func _verificar(nome: String, condicao: bool, detalhe: String = "") -> void:
	if condicao:
		print("OK ", nome)
	else:
		_falhas += 1
		print("FALHA ", nome, ": ", detalhe)

func _novo():
	var progresso = ScriptProgresso.new()
	progresso.caminho_save = CAMINHO_TESTE
	return progresso

func _testar_comprar_melhoria() -> void:
	var progresso = _novo()
	progresso.brasas = 50
	_verificar("comprar melhoria sobe o nivel", progresso.comprar_melhoria("vigor") and progresso.nivel("vigor") == 1, "nivel=%d" % progresso.nivel("vigor"))
	_verificar("comprar melhoria desconta o custo do nivel 1", progresso.brasas == 25, "brasas=%d" % progresso.brasas)
	_verificar("id inexistente nao compra", not progresso.comprar_melhoria("inexistente") and progresso.brasas == 25, "brasas=%d" % progresso.brasas)
	progresso.free()

func _testar_custos_e_maximo() -> void:
	var progresso = _novo()
	progresso.brasas = 1000
	progresso.maior_onda_vencida = 30
	var gastos: Array[int] = []
	for i in 5:
		var antes: int = progresso.brasas
		var comprou: bool = progresso.comprar_melhoria("forca")
		gastos.append(antes - progresso.brasas if comprou else -1)
	_verificar("custos 25/60/120/220/360", gastos == [25, 60, 120, 220, 360], str(gastos))
	_verificar("nivel maximo 5", progresso.nivel("forca") == 5, "nivel=%d" % progresso.nivel("forca"))
	var brasas_antes: int = progresso.brasas
	_verificar("nao compra acima do maximo", not progresso.comprar_melhoria("forca") and progresso.nivel("forca") == 5 and progresso.brasas == brasas_antes, "nivel=%d brasas=%d" % [progresso.nivel("forca"), progresso.brasas])
	_verificar("custo_proximo no maximo e -1", progresso.custo_proximo("forca") == -1, str(progresso.custo_proximo("forca")))
	progresso.free()

func _testar_brasas_insuficientes() -> void:
	var progresso = _novo()
	progresso.brasas = 24
	_verificar("brasas insuficientes nao compra", not progresso.comprar_melhoria("couraca") and progresso.nivel("couraca") == 0 and progresso.brasas == 24, "nivel=%d brasas=%d" % [progresso.nivel("couraca"), progresso.brasas])
	progresso.brasas = 25
	_verificar("brasas exatas compram", progresso.comprar_melhoria("couraca") and progresso.brasas == 0, "brasas=%d" % progresso.brasas)
	progresso.brasas = 59
	_verificar("nivel 2 exige mais Brasas e exploração", not progresso.comprar_melhoria("couraca") and progresso.nivel("couraca") == 1, "nivel=%d" % progresso.nivel("couraca"))
	progresso.free()

func _testar_bonus() -> void:
	var progresso = _novo()
	progresso.melhorias = {"vigor": 3, "forca": 2, "couraca": 5, "folego": 1, "bolsa": 4, "saque": 5}
	var ok: bool = is_equal_approx(progresso.bonus("vigor"), 0.09) and is_equal_approx(progresso.bonus("forca"), 0.04) \
			and is_equal_approx(progresso.bonus("couraca"), 0.05) and is_equal_approx(progresso.bonus("folego"), 0.04) \
			and is_equal_approx(progresso.bonus("bolsa"), 80.0) and is_equal_approx(progresso.bonus("saque"), 0.20)
	_verificar("bonus limitados por nivel", ok, "vigor=%f bolsa=%f" % [progresso.bonus("vigor"), progresso.bonus("bolsa")])
	_verificar("ouro inicial vem da bolsa", progresso.ouro_inicial() == 80, str(progresso.ouro_inicial()))
	_verificar("bonus de id inexistente e 0", progresso.bonus("xyz") == 0.0, "")
	progresso.free()

func _testar_salvar_carregar() -> void:
	var progresso = _novo()
	progresso.brasas = 77
	progresso.recorde_onda = 14
	progresso.checkpoint_max = 20
	progresso.melhorias = {"vigor": 2, "bolsa": 5}
	progresso.moradores = {"bardo": true}
	_verificar("salvar", progresso.salvar(), "falhou")
	var outro = _novo()
	_verificar("carregar", outro.carregar(), "falhou")
	var igual: bool = outro.brasas == 77 and outro.recorde_onda == 14 and outro.checkpoint_max == 20 \
			and outro.nivel("vigor") == 2 and outro.nivel("bolsa") == 5 and outro.tem_morador("bardo") and not outro.tem_morador("mistica")
	_verificar("salvar/carregar ida e volta", igual, "brasas=%d recorde=%d cp=%d" % [outro.brasas, outro.recorde_onda, outro.checkpoint_max])
	var vazio = _novo()
	vazio.caminho_save = "user://nao_existe_progresso.json"
	_verificar("carregar sem arquivo zera", not vazio.carregar() and vazio.brasas == 0 and vazio.melhorias.is_empty(), "")
	progresso.free()
	outro.free()
	vazio.free()

func _testar_encerrar_partida() -> void:
	var progresso = _novo()
	progresso.brasas = 0
	progresso.recorde_onda = 0
	progresso.iniciar_partida()
	for onda in range(1, 6):
		progresso.registrar_onda_iniciada(onda)
		progresso.registrar_onda_concluida(onda, false, false)
	progresso.registrar_onda_iniciada(5)
	progresso.registrar_onda_concluida(5, false, true)
	progresso.registrar_onda_concluida(5, false, true)
	for i in 12:
		progresso.registrar_abate()
	progresso.registrar_ouro(100)
	progresso.registrar_ouro(50)
	progresso.registrar_ouro(-5)
	progresso.registrar_chefe(5)
	# 5 ondas (10) + 1 chefe (15) + 2 bonus (10) = 35
	var resultado: Dictionary = progresso.encerrar_partida()
	_verificar("formula das brasas 2/onda + 15/chefe + 5/bonus", resultado["brasas"] == 35 and progresso.brasas == 35, str(resultado))
	_verificar("resultado traz onda, abates, ouro e chefes", resultado["onda"] == 5 and resultado["abates"] == 12 and resultado["ouro"] == 150 and resultado["chefes"] == 1 and resultado["bonus"] == 2, str(resultado))
	var de_novo: Dictionary = progresso.encerrar_partida()
	_verificar("encerrar duas vezes nao duplica", progresso.brasas == 35 and de_novo["brasas"] == 35, "brasas=%d" % progresso.brasas)
	progresso.registrar_abate()
	_verificar("estatistica ignorada com a partida encerrada", progresso.abates == 12, "abates=%d" % progresso.abates)
	progresso.free()

func _testar_bonus_do_bardo() -> void:
	var progresso = _novo()
	progresso.brasas = 0
	progresso.moradores = {"bardo": true}
	progresso.iniciar_partida()
	for onda in range(1, 6):
		progresso.registrar_onda_concluida(onda, false, false)
	progresso.registrar_chefe(5)
	progresso.registrar_onda_concluida(5, false, true)
	progresso.registrar_onda_concluida(5, false, true)
	# base 35, +25% = 43,75 -> 44
	var resultado: Dictionary = progresso.encerrar_partida()
	_verificar("bardo da +25% de brasas (35 -> 44)", resultado["brasas"] == 44 and resultado["brasas_base"] == 35 and resultado["brasas_bardo"] == 9 and progresso.brasas == 44, str(resultado))
	var sem_bardo = _novo()
	sem_bardo.iniciar_partida()
	for onda in range(1, 5):
		sem_bardo.registrar_onda_concluida(onda, false, false)
	_verificar("sem bardo nao ha bonus", sem_bardo.encerrar_partida()["brasas"] == 8, "")
	progresso.free()
	sem_bardo.free()

func _testar_recorde() -> void:
	var progresso = _novo()
	progresso.recorde_onda = 8
	progresso.iniciar_partida()
	progresso.registrar_onda_iniciada(6)
	var abaixo: Dictionary = progresso.encerrar_partida()
	_verificar("onda abaixo do recorde nao e recorde", not abaixo["novo_recorde"] and progresso.recorde_onda == 8, str(abaixo))
	progresso.iniciar_partida()
	progresso.registrar_onda_iniciada(8)
	var igual: Dictionary = progresso.encerrar_partida()
	_verificar("onda igual ao recorde nao e novo recorde", not igual["novo_recorde"], str(igual))
	progresso.iniciar_partida()
	progresso.registrar_onda_iniciada(12)
	var acima: Dictionary = progresso.encerrar_partida()
	_verificar("onda acima do recorde e novo recorde", acima["novo_recorde"] and progresso.recorde_onda == 12 and acima["recorde"] == 12, str(acima))
	progresso.free()

func _testar_chefe_conta_uma_vez() -> void:
	var progresso = _novo()
	progresso.iniciar_partida()
	progresso.registrar_chefe(10)
	progresso.registrar_onda_concluida(10, true, false)
	_verificar("chefe registrado na morte e na onda conta uma vez", progresso.chefes == 1 and progresso.checkpoint_max == 10, "chefes=%d cp=%d" % [progresso.chefes, progresso.checkpoint_max])
	progresso.registrar_onda_concluida(20, true, false)
	_verificar("segundo chefe soma e sobe o checkpoint", progresso.chefes == 2 and progresso.checkpoint_max == 20, "chefes=%d cp=%d" % [progresso.chefes, progresso.checkpoint_max])
	progresso.free()

func _testar_checkpoint_da_mistica() -> void:
	var progresso = _novo()
	progresso.iniciar_partida()
	progresso.maior_onda_vencida = 49
	_verificar("checkpoints de 5 em 5 ate o andar alcancado (1, 5 ... 50)", progresso.checkpoints_disponiveis() == [1, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50], str(progresso.checkpoints_disponiveis()))
	progresso.maior_onda_vencida = 3
	_verificar("sem alcancar o 5 so o andar 1", progresso.checkpoints_disponiveis() == [1], str(progresso.checkpoints_disponiveis()))
	progresso.maior_onda_vencida = 49
	_verificar("qualquer jogador escolhe antes do andar 1 (sem a mistica)", progresso.pode_escolher_checkpoint(), "")
	var ouro_50: int = progresso.ouro_checkpoint(50)
	var normal_50: float = progresso.ouro_estimado_ate(50)
	_verificar("andar 50 da menos ouro que jogar do 1 (40%)", ouro_50 > 0 and ouro_50 < normal_50 and absf(ouro_50 - normal_50 * 0.4) <= 1.0, "ouro=%d normal=%d" % [ouro_50, normal_50])
	_verificar("ouro cresce com o andar", progresso.ouro_checkpoint(5) < progresso.ouro_checkpoint(25) and progresso.ouro_checkpoint(25) < ouro_50, "")
	var ouro: int = progresso.definir_checkpoint(50)
	_verificar("checkpoint 50 define o andar e da o ouro", ouro == ouro_50 and progresso.onda_inicial == 50, "ouro=%d onda=%d" % [ouro, progresso.onda_inicial])
	var troca: int = progresso.definir_checkpoint(25)
	_verificar("trocar de checkpoint devolve so a diferenca", troca == progresso.ouro_checkpoint(25) - ouro_50 and progresso.onda_inicial == 25, "troca=%d" % troca)
	var volta: int = progresso.definir_checkpoint(1)
	_verificar("voltar para o andar 1 tira a compensacao inteira", volta == -progresso.ouro_checkpoint(25) and progresso.onda_inicial == 1, "volta=%d" % volta)
	_verificar("andar nao liberado e recusado", progresso.definir_checkpoint(55) == 0 and progresso.definir_checkpoint(12) == 0 and progresso.onda_inicial == 1, "")
	progresso.definir_checkpoint(10)
	progresso.registrar_onda_iniciada(10)
	_verificar("depois do primeiro andar nao escolhe mais", not progresso.pode_escolher_checkpoint() and progresso.definir_checkpoint(20) == 0 and progresso.onda_inicial == 10, "onda_inicial=%d" % progresso.onda_inicial)
	progresso.iniciar_partida()
	_verificar("nova partida volta o checkpoint para o andar 1", progresso.onda_inicial == 1 and not progresso.onda_comecou and progresso.pode_escolher_checkpoint(), "onda_inicial=%d" % progresso.onda_inicial)
	for andar in [5, 10, 25, 50]:
		print("   ouro andar %d: checkpoint %d | jogando do 1 ~%d" % [andar, progresso.ouro_checkpoint(andar), progresso.ouro_estimado_ate(andar)])
	progresso.free()

func _testar_contratar_morador() -> void:
	var progresso = _novo()
	progresso.brasas = 30
	_verificar("morador caro demais nao contrata", not progresso.contratar("curandeira") and not progresso.tem_morador("curandeira") and progresso.brasas == 30, "")
	_verificar("contratar o bardo (25)", progresso.contratar("bardo") and progresso.tem_morador("bardo") and progresso.brasas == 5, "brasas=%d" % progresso.brasas)
	_verificar("compra unica", not progresso.contratar("bardo") and progresso.brasas == 5, "")
	progresso.free()

# O reset roguelite do Jogador usa limpar() + criar_itens_iniciais(): o inventário volta ao kit inicial
func _testar_reset_do_inventario() -> void:
	var modelo = ScriptModelo.new()
	modelo.criar_itens_iniciais()
	var espada = modelo.buscar_por_tipo("espada_basica")
	var escudo = modelo.buscar_por_tipo("escudo_basico")
	espada.nivel = 4
	modelo.equipar(espada)
	modelo.equipar(escudo)
	modelo.adicionar_arma_nova("machado")
	_verificar("antes do reset ha arma e escudo equipados", modelo.equipados["arma"] == espada and modelo.equipados["escudo"] == escudo, "")
	modelo.limpar()
	modelo.criar_itens_iniciais()
	var kit_ok: bool = modelo.equipados["arma"] != null and modelo.equipados["arma"].tipo == "espada_basica" and modelo.equipados["escudo"] != null \
			and modelo.equipados["cabeca"] == null and modelo.equipados["corpo"] == null \
			and modelo.equipados["luvas"] == null and modelo.equipados["botas"] == null and modelo.equipados["secundaria"] == null
	_verificar("reset: espada e escudo sem liberar armaduras", kit_ok, str(modelo.equipados))
	var na_mochila: bool = modelo.buscar_por_tipo("lanca_basica") == null and modelo.indice_de(modelo.buscar_por_tipo("enxada")) != -1 \
			and modelo.indice_de(modelo.buscar_por_tipo("regador")) != -1 and modelo.indice_de(modelo.buscar_por_tipo("machadinha")) != -1 and modelo.indice_de(modelo.buscar_por_tipo("picareta")) != -1 and modelo.buscar_por_tipo("vara_pesca") != null
	_verificar("reset: ferramentas na mochila; lança depende de fabricação", na_mochila, "")
	_verificar("reset: itens voltam ao nivel 1 e sem extras", modelo.buscar_por_tipo("espada_basica").nivel == 1 and modelo.buscar_por_tipo("machado") == null, "")
	var contagem := 0
	for item in modelo.mochila:
		if item != null:
			contagem += 1
	_verificar("reset: mochila com quatro ferramentas e vara", contagem == 5, "itens=%d" % contagem)
	modelo.free()

func _testar_reviver_da_curandeira() -> void:
	var progresso = _novo()
	progresso.iniciar_partida()
	_verificar("sem curandeira nao revive", not progresso.usar_reviver(), "")
	progresso.moradores = {"curandeira": true}
	_verificar("curandeira revive na primeira queda", progresso.usar_reviver(), "")
	_verificar("so 1 reviver por partida", not progresso.usar_reviver(), "")
	progresso.iniciar_partida()
	_verificar("nova partida libera o reviver de novo", progresso.usar_reviver(), "")
	progresso.encerrar_partida()
	_verificar("sem partida ativa nao revive", not progresso.usar_reviver(), "")
	progresso.free()

func _testar_apagar() -> void:
	var progresso = _novo()
	progresso.brasas = 12
	progresso.moradores = {"bardo": true}
	progresso.salvar()
	progresso.apagar()
	_verificar("apagar remove o arquivo e zera a memoria", not FileAccess.file_exists(CAMINHO_TESTE) and progresso.brasas == 0 and not progresso.tem_morador("bardo"), "")
	progresso.free()
