extends SceneTree

const Versao := preload("res://codigo/dados/versao_save.gd")
const OPCOES := "[opcoes]\nvolume=0.37\nescala_interface=1.25\n\n[jogador2]\nescala_interface=0.75\n"
var falhas := 0

func _initialize() -> void:
	_rodar.call_deferred()

func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ", nome)
	if not ok:
		falhas += 1

func escrever(caminho: String, dados: String) -> void:
	var arquivo := FileAccess.open(caminho, FileAccess.WRITE)
	arquivo.store_string(dados)
	arquivo.close()

func _rodar() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AlgoLand testes"):
		push_error("Use saves isolados.")
		quit(1)
		return
	await process_frame
	var argumentos := OS.get_cmdline_user_args()
	if "--verificar-inicio" in argumentos:
		_verificar_inicio()
		quit(falhas)
		return
	if "--verificar-reabertura" in argumentos:
		for pasta in ["user://", "user://coop/"]:
			verificar("reabertura preserva partida nova em " + pasta,
				FileAccess.get_file_as_string(pasta + "configuracao_jogador.json") == '{"apelido":"NOVO"}')
		quit(falhas)
		return
	# Executa duas inicializações reais: limpeza antes dos autoloads e reabertura sem apagar de novo.
	for pasta in ["user://", "user://coop/"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(pasta))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(pasta + Versao.MARCADOR))
		for nome in Versao.ARQUIVOS:
			escrever(pasta + nome, '{"legado":true,"brasas":777}')
		escrever(pasta + "opcoes.cfg", OPCOES)
		escrever(pasta + "arquivo_do_jogador.txt", "preservado")
	verificar("reinicio limpa os dois mundos antes de carregar progresso", _reiniciar("--verificar-inicio") == 0)
	verificar("segunda inicializacao preserva a nova partida", _reiniciar("--verificar-reabertura") == 0)
	var pasta := "user://casos_versao/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(pasta))
	var marcador := pasta + Versao.MARCADOR
	escrever(pasta + "progresso.json", "preservar em caso de erro")
	escrever(marcador, '{"versao":%d}' % (Versao.ATUAL + 1))
	verificar("executavel antigo recusa versao futura", Versao.preparar(pasta) == ERR_UNAVAILABLE)
	verificar("versao futura mantem os dados", FileAccess.file_exists(pasta + "progresso.json"))
	for invalido in ['{', '{}', '{"versao":"1"}', '{"versao":1.5}', '{"versao":-1}']:
		escrever(marcador, invalido)
		verificar("marcador invalido nao apaga progresso: " + invalido,
			Versao.preparar(pasta) == ERR_PARSE_ERROR and FileAccess.file_exists(pasta + "progresso.json"))
	escrever(marcador, '{"versao":0}')
	verificar("versao anterior reinicia e registra a atual", Versao.preparar(pasta) == OK and not FileAccess.file_exists(pasta + "progresso.json"))
	# Um diretório no lugar de um arquivo impede a limpeza: não confirmar a versão.
	var bloqueada := "user://versao_bloqueada/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(bloqueada + "progresso.json"))
	verificar("limpeza incompleta nao confirma versao", Versao.preparar(bloqueada) != OK and not FileAccess.file_exists(bloqueada + Versao.MARCADOR))
	print("Versao do save: %d falhas" % falhas)
	quit(falhas)

func _reiniciar(argumento: String) -> int:
	var saida: Array = []
	var resultado := OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://testes/teste_versao_save.gd", "--", argumento], saida, true)
	for trecho in saida:
		print(trecho)
	return resultado

func _verificar_inicio() -> void:
	for pasta in ["user://", "user://coop/"]:
		for nome in Versao.ARQUIVOS:
			if nome=="ranking.json" and pasta=="user://":
				var perfil = JSON.parse_string(FileAccess.get_file_as_string(pasta+nome))
				verificar("ranking inicia zerado na temporada nova",perfil is Dictionary and perfil.get("pendente")==0 and perfil.get("armas_usadas")=={} and perfil.get("temporada")==1 and not perfil.has("legado"))
			else:
				verificar("remove legado " + pasta + nome, not FileAccess.file_exists(pasta + nome))
		var dados = JSON.parse_string(FileAccess.get_file_as_string(pasta + Versao.MARCADOR))
		verificar("marca versao em " + pasta, dados is Dictionary and dados.get("versao") == Versao.ATUAL)
		verificar("preserva opcoes em " + pasta, FileAccess.get_file_as_string(pasta + "opcoes.cfg") == OPCOES)
		verificar("preserva outros arquivos em " + pasta, FileAccess.get_file_as_string(pasta + "arquivo_do_jogador.txt") == "preservado")
	verificar("menu nao encontra mundos antigos", not root.get_node("Saves").existe_mundo("solo") and not root.get_node("Saves").existe_mundo("coop"))
	for pasta in ["user://", "user://coop/"]:
		escrever(pasta + "configuracao_jogador.json", '{"apelido":"NOVO"}')
	verificar("progresso inicia zerado na memoria", root.get_node("Progresso").brasas == 0)
	var opcoes = load("res://codigo/globais/opcoes_jogo.gd")
	verificar("preferencias continuam disponiveis aos dois jogadores", is_equal_approx(opcoes.carregar()["volume"], 0.37)
		and opcoes.carregar()["escala_interface"] == 1.25 and opcoes.carregar(2)["escala_interface"] == 0.75)
