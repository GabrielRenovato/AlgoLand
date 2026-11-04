extends SceneTree
const Controlador := preload("res://codigo/campanha/controlador_campanha.gd")
const Catalogo := preload("res://codigo/campanha/catalogo_campanha.gd")
var falhas := 0
func _initialize() -> void: rodar.call_deferred()
func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ",nome)
	if not ok: falhas += 1
func rodar() -> void:
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"):
		quit(1); return
	await process_frame
	if "--verificar-parcial" in OS.get_cmdline_user_args():
		var parcial := Controlador.new()
		verificar("novo processo restaura objetivo parcial", parcial.iniciar("user://controlador", "alfa") == OK and parcial.progresso.objetivos_cumpridos("sobreviver_queda") == ["espada"] and not parcial.progresso.missao_concluida("sobreviver_queda"))
		quit(falhas); return
	var c := Controlador.new()
	verificar("iniciar controlador", c.iniciar("user://controlador", "alfa") == OK)
	verificar("não entra em destino de campanha bloqueado", c.definir_regiao("pomar") == ERR_UNAUTHORIZED)
	verificar("não confunde andar com região", c.definir_regiao("andar_01") == ERR_INVALID_PARAMETER)
	verificar("definir contexto de chegada", c.definir_regiao("chegada") == OK)
	verificar("recusa interação inventada", c.interagir("conversar","inexistente") == ERR_UNAVAILABLE)
	verificar("recusa saída antes de combater", c.interagir("descobrir","marco_estrada") == ERR_UNAVAILABLE)
	verificar("não aceita vitória antes do equipamento", c.interagir("vencer","criatura_inicial") == ERR_UNAVAILABLE)
	verificar("baú novo inicia fechado",not c.progresso.bau_resgate_aberto)
	verificar("abertura do baú é persistida sem conceder equipamento",c.progresso.registrar_abertura_bau()==OK and c.progresso.objetivos_cumpridos("sobreviver_queda").is_empty())
	var bau_reaberto := Controlador.new()
	verificar("novo controlador restaura baú aberto",bau_reaberto.iniciar("user://controlador","alfa")==OK and bau_reaberto.progresso.bau_resgate_aberto)
	verificar("registrar coleta de espada", c.interagir("coletar","espada_inicial") == OK)
	var saida: Array = []
	var retorno := OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://testes/teste_controlador_campanha.gd", "--", "--verificar-parcial"], saida, true)
	verificar("objetivo parcial persiste entre processos", retorno == 0)
	var reaberto := Controlador.new()
	verificar("reabrir objetivos incompletos", reaberto.iniciar("user://controlador", "alfa") == OK)
	verificar("coleta sobrevive sem concluir missão", reaberto.progresso.objetivos_cumpridos("sobreviver_queda") == ["espada"] and not reaberto.progresso.missao_concluida("sobreviver_queda"))
	c = reaberto
	c.definir_regiao("chegada")
	verificar("repetição não registra objetivo duas vezes", c.interagir("coletar","espada_inicial") == ERR_UNAVAILABLE and c.progresso.objetivos_cumpridos("sobreviver_queda").size() == 1)
	var dados := Catalogo.dados()
	for id in ["sobreviver_queda","estrada_interrompida","acolhimento","pomar_sulcos"]:
		for objetivo in dados.missoes[id].objetivos:
			if objetivo.id in c.progresso.objetivos_cumpridos(id): continue
			if id=="estrada_interrompida":
				verificar("cidade bloqueada antes de encontrar trabalhador "+objetivo.id,c.definir_regiao("vila")==ERR_UNAUTHORIZED)
			verificar("abrir região do objetivo " + objetivo.id, c.definir_regiao(objetivo.regiao) == OK)
			if id=="sobreviver_queda" and objetivo.id=="saida":
				c.progresso.tempos_regioes.chegada=59.9
				verificar("não conclui fase antes de um minuto ativo",c.interagir(objetivo.tipo,objetivo.alvo)==ERR_BUSY)
			c.contar_tempo(60)
			verificar("interação real do percurso " + id + ":" + objetivo.id, c.interagir(objetivo.tipo,objetivo.alvo) == OK)
		verificar("último objetivo confirma missão " + id, c.progresso.missao_concluida(id))
		if id=="estrada_interrompida":
			verificar("estrada concluída libera cidade e acolhimento",c.progresso.acesso_liberado("vila") and c.objetivo_atual().alvo=="dara")
	verificar("defesa fica elegível sem vitória fabricada", c.progresso.pode_concluir("defesa_da_vila") and not c.progresso.missao_concluida("defesa_da_vila"))
	verificar("percurso não pula chefe nem concede relíquia", not c.progresso.possui_reliquia("reliquia_primeira_raiz"))
	var limitado := Controlador.new()
	verificar("perfil isolado para limite de estágios",limitado.iniciar("user://limite_estagios","alfa")==OK)
	# Simula um save avançado sem apagar conquistas nem mudar seus requisitos.
	limitado.progresso._concluidas = dados.missoes.keys()
	for destino in dados.destinos:
		if dados.destinos[destino].tipo=="andar": continue
		if destino in Catalogo.REGIOES_HABILITADAS:
			verificar("estágios 1 a 4 continuam acessíveis: "+destino,limitado.definir_regiao(destino)==OK)
		else:
			var regiao_antes := limitado.regiao
			verificar("estágio 5 em diante bloqueado mesmo com save avançado: "+destino,limitado.definir_regiao(destino)==ERR_UNAUTHORIZED and limitado.regiao==regiao_antes)
	var duracao_invalida := dados.duplicate(true)
	duracao_invalida.destinos.chegada.duracao.minima=59
	verificar("catálogo recusa fase abaixo de um minuto",not Catalogo.validar(duracao_invalida))
	duracao_invalida = dados.duplicate(true)
	duracao_invalida.destinos.bastiao.duracao.prevista[1]=3601
	verificar("catálogo limita previsão a uma hora",not Catalogo.validar(duracao_invalida))
	var dados_invalidos := dados.duplicate(true)
	dados_invalidos.missoes.sobreviver_queda.objetivos[0].apos = ["saida"]
	verificar("ciclo dentro dos objetivos recusado", not Catalogo.validar(dados_invalidos))
	dados_invalidos = dados.duplicate(true)
	dados_invalidos.missoes.sobreviver_queda.objetivos[0].regiao = "inexistente"
	verificar("região desconhecida no objetivo recusada", not Catalogo.validar(dados_invalidos))
	var caminho: String = c.progresso.caminho_save()
	var bytes := FileAccess.get_file_as_string(caminho)
	var inconsistente := c.progresso.retrato()
	inconsistente.objetivos.pomar_sulcos = ["pedido"]
	var quebrado := FileAccess.open(caminho,FileAccess.WRITE)
	quebrado.store_string(JSON.stringify(inconsistente)); quebrado.close()
	var recusa := Controlador.new()
	verificar("conclusão com objetivos pela metade recusada", recusa.iniciar("user://controlador","alfa") == ERR_FILE_CORRUPT)
	quebrado = FileAccess.open(caminho,FileAccess.WRITE)
	quebrado.store_string(bytes); quebrado.close()
	var no_local_errado := Controlador.new()
	no_local_errado.iniciar("user://controlador_outra_regiao", "alfa")
	no_local_errado.progresso.confirmar_conclusao("sobreviver_queda")
	no_local_errado.progresso.confirmar_conclusao("estrada_interrompida")
	no_local_errado.definir_regiao("estrada")
	verificar("falar com Dara exige contexto da vila", no_local_errado.interagir("conversar","dara") == ERR_UNAUTHORIZED)
	var legado := c.progresso.retrato()
	legado.objetivos.sobreviver_queda=["espada","escudo","combate","saida"]
	var legado_arq := FileAccess.open(c.progresso.caminho_save(),FileAccess.WRITE)
	legado_arq.store_string(JSON.stringify(legado));legado_arq.close()
	var migrado := Controlador.new()
	verificar("conclusão antiga preservada com novos objetivos",migrado.iniciar("user://controlador","alfa")==OK and migrado.progresso.missao_concluida("sobreviver_queda") and "vigilia" in migrado.progresso.objetivos_cumpridos("sobreviver_queda"))
	verificar("tempo ativo persiste",migrado.tempo_ativo("chegada")>=60)
	# Versão anterior: a missão da estrada ainda incluía o relato na cidade.
	for fase in ["visita_antecipada","carreto","trabalhador","dara","retorno","acolhimento","acolhimento_concluido","sem_objetivos"]:
		var base: String = "user://migracao_cidade_"+fase
		var fixture := Controlador.new()
		fixture.iniciar(base,"alfa")
		fixture.progresso.confirmar_conclusao("sobreviver_queda")
		var dados_antigos := fixture.progresso.retrato()
		dados_antigos.versao_conteudo = 1
		var estrada_antiga: Array = []
		for passo in ["carreto","trabalhador","dara","retorno"]:
			if fase=="visita_antecipada": break
			estrada_antiga.append(passo)
			if fase==passo: break
		if not estrada_antiga.is_empty(): dados_antigos.objetivos.estrada_interrompida=estrada_antiga
		if "retorno" in estrada_antiga: dados_antigos.concluidas.append("estrada_interrompida")
		if fase=="acolhimento": dados_antigos.objetivos.acolhimento=["lia"]
		if fase=="acolhimento_concluido":
			dados_antigos.objetivos.acolhimento=["lia","estela","oficio"]
			dados_antigos.concluidas.append("acolhimento")
		if fase=="sem_objetivos": dados_antigos.objetivos.erase("estrada_interrompida")
		dados_antigos.retorno={"regiao":"vila","posicao":[0,0]}
		var arq := FileAccess.open(fixture.progresso.caminho_save(),FileAccess.WRITE)
		var bytes_legados := JSON.stringify(dados_antigos)
		arq.store_string(bytes_legados);arq.close()
		var restaurado := Controlador.new()
		verificar("migra sequência antiga "+fase,restaurado.iniciar(base,"alfa")==OK)
		verificar("migração não sobrescreve save ao abrir "+fase,FileAccess.get_file_as_string(fixture.progresso.caminho_save())==bytes_legados)
		verificar("cidade exige trabalhador após migração "+fase,restaurado.progresso.acesso_liberado("vila")==("trabalhador" in estrada_antiga))
		verificar("remove relato da missão da estrada "+fase,restaurado.progresso.objetivos_cumpridos("estrada_interrompida")==([] if fase=="sem_objetivos" else estrada_antiga.filter(func(p):return p in ["carreto","trabalhador"])))
		var acolhimento_esperado: Array = estrada_antiga.filter(func(p):return p in ["dara","retorno"])
		if fase=="acolhimento": acolhimento_esperado.append("lia")
		if fase=="acolhimento_concluido": acolhimento_esperado.append_array(["lia","estela","oficio"])
		verificar("preserva relato no acolhimento "+fase,restaurado.progresso.objetivos_cumpridos("acolhimento")==acolhimento_esperado)
		if not "trabalhador" in estrada_antiga:
			verificar("visita antecipada não restaura além do bloqueio "+fase,restaurado.progresso.ponto_retorno().is_empty())
		else:
			restaurado.definir_regiao("vila")
			verificar("grava progresso migrado "+fase,restaurado.progresso.salvar_retorno("vila",Vector2.ZERO)==OK)
			var segunda_abertura := Controlador.new()
			verificar("reabre conteúdo novo "+fase,segunda_abertura.iniciar(base,"alfa")==OK and segunda_abertura.progresso.retrato()==restaurado.progresso.retrato())
	var antigo := c.progresso.retrato()
	antigo.erase("objetivos")
	var arquivo := FileAccess.open(c.progresso.caminho_save(),FileAccess.WRITE)
	arquivo.store_string(JSON.stringify(antigo)); arquivo.close()
	verificar("compatível com conclusões salvas antes dos objetivos", c.iniciar("user://controlador", "alfa") == OK and c.progresso.missao_concluida("pomar_sulcos"))
	print("FALHAS: ",falhas)
	quit(falhas)
