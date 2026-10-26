extends Node
## Leva o save do mundo solo de um aparelho para outro (PC <-> celular) por um código curto de uso único.
## Enviar: empacota os arquivos do mundo solo, manda ao Supabase e recebe o código (15 minutos).
## Receber: baixa o pacote pelo código, guarda uma cópia do save atual em user://backups/ e grava o novo.
## O código secreto do ranking/mercado vai junto: os dois aparelhos passam a ser o mesmo jogador.

const FORMATO := 1
const VersaoSave := preload("res://codigo/dados/versao_save.gd")
## Arquivos do mundo solo (user://). Opções (volume, tela) ficam em cada aparelho.
const ARQUIVOS := ["progresso.json", "calendario.json", "cidade.json", "fazenda.json", "introducao.json",
	"bau.json", "comercio.json", "inventario.json", "configuracao_jogador.json",
	"inventario_introducao_checkpoint.json", "ranking.json", "mercado.json",
	"versao_save.json", "reequilibrio_progressao_1.json"]
const ERROS := {
	"codigo_invalido": "CODIGO INVALIDO",
	"tamanho_invalido": "SAVE GRANDE DEMAIS PARA ENVIAR",
	"muitos_envios": "MUITOS ENVIOS NA ULTIMA HORA. TENTE MAIS TARDE",
	"sem_codigo": "NAO FOI POSSIVEL GERAR O CODIGO. TENTE DE NOVO",
	"nao_encontrado": "CODIGO NAO ENCONTRADO OU EXPIRADO",
	"aguarde": "MUITAS TENTATIVAS. AGUARDE UM MINUTO",
}

static func versao_app() -> String:
	return str(ProjectSettings.get_setting("application/config/version", ""))

## Pacote do mundo solo: {formato, versao_app, versao_save, arquivos: {nome: texto}}
static func empacotar() -> Dictionary:
	var arquivos := {}
	for nome in ARQUIVOS:
		var caminho: String = "user://" + nome
		if FileAccess.file_exists(caminho):
			arquivos[nome] = FileAccess.get_file_as_string(caminho)
	return {"formato": FORMATO, "versao_app": versao_app(), "versao_save": VersaoSave.ATUAL, "arquivos": arquivos}

## Confere o pacote recebido. Devolve "" ou o motivo da recusa.
static func validar(pacote) -> String:
	if not pacote is Dictionary or int(pacote.get("formato", 0)) != FORMATO or not pacote.get("arquivos") is Dictionary:
		return "SAVE RECEBIDO ESTA CORROMPIDO"
	if str(pacote.get("versao_app", "")) != versao_app():
		return "VERSOES DIFERENTES (%s NO OUTRO APARELHO, %s AQUI). ATUALIZE OS DOIS" % [pacote.get("versao_app", "?"), versao_app()]
	if int(pacote.get("versao_save", -1)) != VersaoSave.ATUAL:
		return "SAVE DE OUTRA VERSAO DO JOGO"
	var arquivos: Dictionary = pacote.arquivos
	if not arquivos.has("configuracao_jogador.json"):
		return "O OUTRO APARELHO NAO TEM PERSONAGEM CRIADO"
	for nome in arquivos:
		if not nome in ARQUIVOS or not arquivos[nome] is String:
			return "SAVE RECEBIDO ESTA CORROMPIDO"
	return ""

## Grava o pacote no mundo solo, depois de copiar o save atual para user://backups/antes_transferencia_<data>/.
## Arquivos do mundo solo que não vieram no pacote são removidos (o save fica igual ao do outro aparelho).
static func aplicar(pacote: Dictionary) -> String:
	var erro := validar(pacote)
	if not erro.is_empty():
		return erro
	var backup := "user://backups/antes_transferencia_%s/" % Time.get_datetime_string_from_system().replace(":", "-")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(backup))
	for nome in ARQUIVOS:
		var caminho: String = "user://" + nome
		if FileAccess.file_exists(caminho):
			if DirAccess.copy_absolute(ProjectSettings.globalize_path(caminho), ProjectSettings.globalize_path(backup + nome)) != OK:
				return "NAO FOI POSSIVEL GUARDAR UMA COPIA DO SAVE ATUAL"
	var arquivos: Dictionary = pacote.arquivos
	for nome in ARQUIVOS:
		var caminho: String = "user://" + nome
		if arquivos.has(nome):
			var temporario := caminho + ".tmp"
			var arquivo := FileAccess.open(temporario, FileAccess.WRITE)
			if arquivo == null:
				return "NAO FOI POSSIVEL GRAVAR O SAVE"
			arquivo.store_string(arquivos[nome])
			arquivo.close()
			DirAccess.rename_absolute(ProjectSettings.globalize_path(temporario), ProjectSettings.globalize_path(caminho))
		elif FileAccess.file_exists(caminho):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(caminho))
	return ""

## Envia o save deste aparelho. Devolve {"codigo", "minutos"} ou {"erro"}.
func enviar() -> Dictionary:
	if _ranking().codigo_secreto().is_empty() or not _ranking().disponivel():
		return {"erro": "SEM CONEXAO COM O SERVIDOR"}
	if not FileAccess.file_exists("user://configuracao_jogador.json"):
		return {"erro": "CRIE UM PERSONAGEM ANTES DE ENVIAR"}
	_ranking().gravar_perfis()
	var resposta := await _rpc("transferencia_enviar", {"p_codigo_secreto": _ranking().codigo_secreto(),
		"p_dados": JSON.stringify(empacotar())})
	if resposta.has("codigo"):
		return {"codigo": _formatar(str(resposta.codigo)), "minutos": int(resposta.get("minutos", 15))}
	return {"erro": ERROS.get(str(resposta.get("erro", "")), str(resposta.get("erro", "FALHA NA CONEXAO")))}

## Baixa o save pelo código e confere a versão. Devolve {"pacote"} ou {"erro"}. Não grava nada.
func receber(codigo: String) -> Dictionary:
	if not _ranking().disponivel():
		return {"erro": "SEM CONEXAO COM O SERVIDOR"}
	var resposta := await _rpc("transferencia_receber", {"p_codigo": codigo})
	if not resposta.has("dados"):
		return {"erro": ERROS.get(str(resposta.get("erro", "")), str(resposta.get("erro", "FALHA NA CONEXAO")))}
	var pacote = JSON.parse_string(str(resposta.dados))
	var erro := validar(pacote)
	if not erro.is_empty():
		return {"erro": erro}
	return {"pacote": pacote}

func _ranking() -> Node:
	return get_node("/root/Ranking")

static func _formatar(codigo: String) -> String:
	return codigo.substr(0, 3) + "-" + codigo.substr(3)

func _rpc(funcao: String, corpo: Dictionary) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = 20.0
	add_child(http)
	if http.request(_ranking().url_servico + "/rest/v1/rpc/" + funcao, _ranking().cabecalhos_servico(), HTTPClient.METHOD_POST, JSON.stringify(corpo)) != OK:
		http.queue_free()
		return {"erro": "FALHA NA CONEXAO"}
	var resposta: Array = await http.request_completed
	http.queue_free()
	if int(resposta[0]) != HTTPRequest.RESULT_SUCCESS or int(resposta[1]) >= 300:
		return {"erro": "FALHA NA CONEXAO (%d)" % int(resposta[1])}
	var dados = JSON.parse_string((resposta[3] as PackedByteArray).get_string_from_utf8())
	return dados if dados is Dictionary else {"erro": "RESPOSTA INVALIDA DO SERVIDOR"}
