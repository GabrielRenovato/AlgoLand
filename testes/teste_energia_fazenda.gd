extends SceneTree

## Rendimento diário, independência no coop e migração da barra antiga de 100 pontos.
var falhas := 0

func _initialize() -> void:
	rodar.call_deferred()

func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ", nome)
	if not ok: falhas += 1

func rodar() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AlgoLand testes"):
		quit(1)
		return
	await process_frame
	root.get_node("Introducao").pular_prologo()
	var faz: Node = root.get_node("Fazenda")
	var inv: Node = root.get_node("InventarioJogador")
	inv.limpar()
	inv.criar_itens_iniciais()
	faz.caminho_save = "user://teste_energia_fazenda.json"
	for acao in ["enxada", "regar", "machado", "picareta"]:
		faz._definir_energia(1, faz.ENERGIA_MAXIMA)
		faz._definir_energia(2, faz.ENERGIA_MAXIMA)
		var usos := 0
		while usos < 300 and faz.gastar_energia(acao):
			usos += 1
		verificar("dia rende 135 usos de " + acao, usos == 135 and faz.energia_de(1) == 0)
		verificar("esgotamento de P1 preserva P2 " + acao, faz.energia_de(2) == 270)
		verificar("energia insuficiente nao fica negativa " + acao, not faz.gastar_energia(acao) and faz.energia_de(1) == 0)
	for acao in ["plantar", "colher", "encher"]:
		verificar("acao gratuita mesmo sem energia " + acao, faz.gastar_energia(acao) and faz.energia_de(1) == 0)
	faz._definir_energia(2, 0)
	faz._ao_dia_passou(2)
	verificar("sono recupera os dois jogadores", faz.energia_de(1) == 270 and faz.energia_de(2) == 270)
	for acao in ["enxada", "regar", "machado", "picareta"]:
		var melhorias := preload("res://codigo/dados/melhorias_ferramentas.gd")
		var item = inv.buscar_por_tipo(melhorias.POR_ACAO[acao])
		for grau in [1, 2, 3]:
			item.nivel = grau
			var custo: int = faz.custo_energia(acao)
			verificar("melhoria e descricao concordam " + acao + str(grau), custo == (2 if grau == 1 else 1) and melhorias.descricao(item.tipo, grau).contains("ENERGIA: %d POR USO" % custo))
	var arquivo := FileAccess.open(faz.caminho_save, FileAccess.WRITE)
	arquivo.store_string(JSON.stringify({"energia_p1": 50, "energia_p2": 0}))
	arquivo.close()
	verificar("save antigo preserva meia barra e esgotamento", faz.carregar() and faz.energia_de(1) == 135 and faz.energia_de(2) == 0)
	faz._definir_energia(2, 269)
	verificar("novo formato salva energia", faz.salvar())
	faz._definir_energia(1, 0)
	verificar("recarregar nao reaplica migracao", faz.carregar() and faz.energia_de(1) == 135 and faz.energia_de(2) == 269)
	arquivo = FileAccess.open(faz.caminho_save, FileAccess.WRITE)
	arquivo.store_string("{}")
	arquivo.close()
	verificar("save sem energia comeca cheio", faz.carregar() and faz.energia_de(1) == 270 and faz.energia_de(2) == 270)
	print("Energia fazenda: %d falhas" % falhas)
	quit(1 if falhas else 0)
