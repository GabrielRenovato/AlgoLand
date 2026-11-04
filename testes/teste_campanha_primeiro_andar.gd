extends SceneTree

const Catalogo := preload("res://codigo/campanha/catalogo_campanha.gd")
const Progresso := preload("res://codigo/campanha/progresso_campanha.gd")
const RELIQUIA := "reliquia_primeira_raiz"
const BASE := "user://prototipo_campanha/"
const ORDEM := ["sobreviver_queda", "estrada_interrompida", "acolhimento", "pomar_sulcos", "defesa_da_vila",
	"moinho_vazao", "pedreira_veios", "tuneis_resgate", "mata_rastro", "observatorio_registros", "jardins_circuito", "bastiao_intervencao"]
var falhas := 0

func _initialize() -> void:
	rodar.call_deferred()

func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ", nome)
	if not ok:
		falhas += 1

func escrever(caminho: String, texto: String) -> void:
	DirAccess.make_dir_recursive_absolute(caminho.get_base_dir())
	var arquivo := FileAccess.open(caminho, FileAccess.WRITE)
	if arquivo == null:
		verificar("escrever fixture isolada", false)
		return
	arquivo.store_string(texto)
	arquivo.close()

func caso_save(nome: String, texto: String, esperado: Error) -> void:
	var pasta := BASE.path_join(nome)
	var estado := Progresso.new()
	verificar(nome + ": preparar caminho", estado.iniciar(pasta, "alfa") == OK)
	var caminho: String = estado.caminho_save()
	escrever(caminho, texto)
	verificar(nome + ": carregar recusa dado incompatível", estado.iniciar(pasta, "alfa") == esperado)
	verificar(nome + ": objeto não permite escrita após recusa", estado.confirmar_conclusao("sobreviver_queda") == ERR_UNCONFIGURED)
	verificar(nome + ": bytes preservados", FileAccess.get_file_as_string(caminho) == texto)

func rodar() -> void:
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"):
		print("FALHA saves precisam ser isolados")
		quit(1)
		return
	await process_frame
	if "--verificar-reabertura" in OS.get_cmdline_user_args():
		var reaberto := Progresso.new()
		verificar("novo processo lê campanha", reaberto.iniciar(BASE, "alfa") == OK)
		verificar("novo processo preserva relíquia", reaberto.possui_reliquia(RELIQUIA))
		verificar("novo processo preserva desbloqueio", reaberto.acesso_liberado("andar_02"))
		verificar("novo processo não promete mapa inexistente", reaberto.estado_destino("andar_02") == "em_preparacao")
		quit(falhas)
		return

	var dados := Catalogo.dados()
	verificar("catálogo válido", Catalogo.validar(dados))
	verificar("12 territórios e dois andares catalogados", dados.destinos.size() == 14)
	verificar("19 missões catalogadas", dados.missoes.size() == 19)
	var alterado := dados.duplicate(true)
	alterado.missoes.sobreviver_queda.requisitos = ["ativar_reliquia"]
	verificar("ciclo de campanha recusado", not Catalogo.validar(alterado))
	alterado = dados.duplicate(true)
	alterado.destinos.chegada.requisitos = ["inexistente"]
	verificar("dependência desconhecida recusada", not Catalogo.validar(alterado))
	alterado = dados.duplicate(true)
	alterado.destinos.bastiao.grupo_minimo = 5
	verificar("grupo incompatível recusado", not Catalogo.validar(alterado))
	alterado = dados.duplicate(true)
	alterado.destinos.chegada.conteudo = "jogavel"
	verificar("conteúdo jogável sem cena recusado", not Catalogo.validar(alterado))
	alterado = dados.duplicate(true)
	alterado.reliquias[RELIQUIA].ativada_em = "sobreviver_queda"
	verificar("ativação que pula o chefe recusada", not Catalogo.validar(alterado))

	var antigo := "user://partida_legada_fixture.json"
	escrever(antigo, '{"inventario":"preservado","versao":2}')
	var bytes_antigos := FileAccess.get_file_as_string(antigo)
	var estado := Progresso.new()
	verificar("sem pasta implícita nem escrita antes de iniciar", estado.confirmar_conclusao("sobreviver_queda") == ERR_UNCONFIGURED)
	verificar("perfil não pode escapar da pasta", estado.iniciar(BASE, "../outro") == ERR_INVALID_PARAMETER)
	verificar("não escreve em res", estado.iniciar("res://", "alfa") == ERR_INVALID_PARAMETER)
	verificar("não aceita travessia na base", estado.iniciar("user://../outro", "alfa") == ERR_INVALID_PARAMETER)
	verificar("iniciar perfil novo", estado.iniciar(BASE, "alfa") == OK)
	verificar("abrir perfil não cria arquivo nem migra partida", not FileAccess.file_exists(estado.caminho_save()))
	verificar("chegada liberada apenas na lógica", estado.acesso_liberado("chegada") and estado.estado_destino("chegada") == "em_preparacao")
	verificar("andar 2 bloqueado", not estado.acesso_liberado("andar_02"))
	verificar("destino inválido não vira cena", estado.estado_destino("inexistente") == "desconhecido")
	verificar("não ativa relíquia antes do chefe", estado.ativar_reliquia(RELIQUIA) == ERR_UNAUTHORIZED)
	verificar("não pula direto para o chefe", estado.confirmar_conclusao("bastiao_intervencao") == ERR_UNAUTHORIZED)
	verificar("não conclui missão desconhecida", estado.confirmar_conclusao("inexistente") == ERR_INVALID_PARAMETER)
	for id in ORDEM:
		verificar("concluir e gravar " + id, estado.confirmar_conclusao(id) == OK and estado.missao_concluida(id))
	verificar("ramo das várzeas não bloqueia relíquia", not estado.missao_concluida("varzea_amostras") and estado.possui_reliquia(RELIQUIA))
	verificar("vitória não ativa próximo andar sozinha", not estado.acesso_liberado("andar_02"))
	verificar("relíquia inexistente recusada", estado.ativar_reliquia("outra") == ERR_INVALID_PARAMETER)
	verificar("ativar relíquia fixa", estado.ativar_reliquia(RELIQUIA) == OK)
	verificar("destino certo revelado mas ainda em preparação", estado.acesso_liberado("andar_02") and estado.estado_destino("andar_02") == "em_preparacao")
	var caminho: String = estado.caminho_save()
	var texto := FileAccess.get_file_as_string(caminho)
	verificar("vitória repetida é idempotente", estado.confirmar_conclusao("bastiao_intervencao") == OK and FileAccess.get_file_as_string(caminho) == texto)
	verificar("ativação repetida é idempotente", estado.ativar_reliquia(RELIQUIA) == OK and FileAccess.get_file_as_string(caminho) == texto)
	var copia := estado.retrato()
	copia.concluidas.clear()
	verificar("consulta não expõe estado mutável", estado.possui_reliquia(RELIQUIA))
	verificar("temporário fechado e renomeado", not FileAccess.file_exists(caminho + ".tmp"))

	escrever(caminho + ".tmp", '{"escrita_interrompida":')
	var restaurado := Progresso.new()
	verificar("temporário incompleto não substitui confirmação", restaurado.iniciar(BASE, "alfa") == OK and restaurado.acesso_liberado("andar_02"))
	DirAccess.remove_absolute(caminho + ".tmp")
	DirAccess.make_dir_absolute(caminho + ".tmp")
	verificar("falha real de escrita não confirma objetivo", estado.confirmar_conclusao("varzea_amostras") != OK and not estado.missao_concluida("varzea_amostras"))
	verificar("falha real de escrita preserva último save", FileAccess.get_file_as_string(caminho) == texto)
	DirAccess.remove_absolute(caminho + ".tmp")
	var outro := Progresso.new()
	verificar("outro perfil começa independente", outro.iniciar(BASE, "beta") == OK and not outro.possui_reliquia(RELIQUIA))
	var outro_mundo := Progresso.new()
	verificar("outra pasta não mistura progresso", outro_mundo.iniciar(BASE.path_join("outro_mundo"), "alfa") == OK and not outro_mundo.acesso_liberado("andar_02"))

	var atrasado := Progresso.new()
	var atual := Progresso.new()
	verificar("abrir dois leitores", atrasado.iniciar(BASE.path_join("concorrencia"), "alfa") == OK and atual.iniciar(BASE.path_join("concorrencia"), "alfa") == OK)
	verificar("um escritor avança", atual.confirmar_conclusao("sobreviver_queda") == OK)
	verificar("leitor antigo não sobrescreve avanço", atrasado.confirmar_conclusao("sobreviver_queda") == ERR_BUSY and not atrasado.missao_concluida("sobreviver_queda"))
	verificar("reabrir leitor permite continuar", atrasado.iniciar(BASE.path_join("concorrencia"), "alfa") == OK and atrasado.confirmar_conclusao("estrada_interrompida") == OK)

	var retorno := Progresso.new()
	verificar("preparar retorno isolado", retorno.iniciar(BASE.path_join("retorno"),"alfa") == OK)
	verificar("não salva retorno em região bloqueada", retorno.salvar_retorno("pomar",Vector2.ZERO) == ERR_INVALID_PARAMETER)
	verificar("não salva retorno fora do domínio numérico", retorno.salvar_retorno("chegada",Vector2(INF,0)) == ERR_INVALID_PARAMETER and retorno.salvar_retorno("chegada",Vector2(100001,0)) == ERR_INVALID_PARAMETER)
	verificar("salva retorno da chegada", retorno.salvar_retorno("chegada",Vector2(-320,220)) == OK)
	var restaurar_retorno := Progresso.new()
	verificar("reabre ponto de retorno", restaurar_retorno.iniciar(BASE.path_join("retorno"),"alfa") == OK and restaurar_retorno.ponto_retorno() == retorno.ponto_retorno())
	var retrato_retorno := retorno.ponto_retorno()
	retrato_retorno.posicao[0] = 999
	verificar("consulta do retorno não expõe memória", retorno.ponto_retorno().posicao[0] == -320)
	DirAccess.make_dir_absolute(retorno.caminho_save()+".tmp")
	verificar("falha de checkpoint preserva posição anterior", retorno.salvar_retorno("chegada",Vector2.ZERO) != OK and retorno.ponto_retorno().posicao[0] == -320)
	DirAccess.remove_absolute(retorno.caminho_save()+".tmp")
	for caso in ["retorno_tipo","retorno_regiao","retorno_posicao"]:
		var invalido := retorno.retrato()
		match caso:
			"retorno_tipo": invalido.retorno = []
			"retorno_regiao": invalido.retorno.regiao = "pomar"
			"retorno_posicao": invalido.retorno.posicao = ["texto",1]
		caso_save(caso,JSON.stringify(invalido),ERR_FILE_CORRUPT)

	var instancia := Progresso.new()
	verificar("prepara instancia isolada", instancia.iniciar(BASE.path_join("instancia"),"alfa") == OK)
	verificar("instancia recusa regiao bloqueada", instancia.iniciar_instancia("pomar") == ERR_UNAUTHORIZED)
	verificar("instancia inicia chegada", instancia.iniciar_instancia("chegada") == OK)
	verificar("instancia registra primeiro objetivo", instancia.registrar_objetivo("sobreviver_queda","espada") == OK)
	var leitor := Progresso.new()
	verificar("tentativa reabre no save", leitor.iniciar(BASE.path_join("instancia"),"alfa") == OK and leitor.objetivos_cumpridos("sobreviver_queda") == ["espada"])
	DirAccess.make_dir_absolute(instancia.caminho_save()+".tmp")
	verificar("falha ao resetar preserva tentativa", instancia.iniciar_instancia("chegada") != OK and instancia.objetivos_cumpridos("sobreviver_queda") == ["espada"])
	verificar("falha ao avancar preserva tentativa", instancia.registrar_objetivo("sobreviver_queda","escudo") != OK and instancia.objetivos_cumpridos("sobreviver_queda") == ["espada"])
	DirAccess.remove_absolute(instancia.caminho_save()+".tmp")
	verificar("reset nao apaga historico", instancia.iniciar_instancia("chegada") == OK and instancia.objetivos_cumpridos("sobreviver_queda").is_empty() and instancia.retrato().objetivos.sobreviver_queda == ["espada"])
	for invalida in [[], {"inexistente":[]}, {"sobreviver_queda":["saida"]}, {"sobreviver_queda":["espada","espada"]}]:
		var invalido := instancia.retrato()
		invalido.tentativas = invalida
		caso_save("tentativa_invalida_"+str(hash(invalida)),JSON.stringify(invalido),ERR_FILE_CORRUPT)

	caso_save("truncado", "{", ERR_FILE_CORRUPT)
	caso_save("lista", "[]", ERR_FILE_CORRUPT)
	var valido: Dictionary = JSON.parse_string(texto)
	for caso in ["versao_futura", "catalogo_futuro", "outro_perfil", "outra_campanha", "missao_desconhecida", "duplicada", "sem_pre_requisito", "tipo_invalido"]:
		var invalido := valido.duplicate(true)
		var esperado: Error = ERR_FILE_CORRUPT
		match caso:
			"versao_futura": invalido.versao = 99; esperado = ERR_UNAVAILABLE
			"catalogo_futuro": invalido.versao_conteudo = 99; esperado = ERR_UNAVAILABLE
			"outro_perfil": invalido.perfil = "beta"
			"outra_campanha": invalido.campanha = "outra"
			"missao_desconhecida": invalido.concluidas.append("inexistente")
			"duplicada": invalido.concluidas.append("sobreviver_queda")
			"sem_pre_requisito": invalido.concluidas = ["bastiao_intervencao"]
			"tipo_invalido": invalido.versao = true
		caso_save(caso, JSON.stringify(invalido), esperado)
	verificar("partida legada permanece intacta", FileAccess.get_file_as_string(antigo) == bytes_antigos)
	var saida: Array = []
	var codigo := OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://testes/teste_campanha_primeiro_andar.gd", "--", "--verificar-reabertura"], saida, true)
	for trecho in saida:
		print(trecho)
	verificar("save reaberto num processo novo do Godot", codigo == 0)
	print("FALHAS: ", falhas)
	quit(falhas)
