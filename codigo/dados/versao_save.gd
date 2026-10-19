extends RefCounted

## A primeira versão inicia a nova progressão da forja sem importar partidas antigas.
## Subir este número exige uma decisão explícita de reiniciar a progressão dos jogadores.
const ATUAL := 1
const MARCADOR := "versao_save.json"
const ARQUIVOS := [
	"progresso.json", "calendario.json", "cidade.json", "fazenda.json",
	"introducao.json", "bau.json", "comercio.json", "inventario.json",
	"inventario_p2.json", "configuracao_jogador.json", "configuracao_jogador_p2.json",
	"inventario_introducao_checkpoint.json",
]

## Executar antes de qualquer autoload carregar ou salvar o mundo. Nunca remove opções
## nem arquivos desconhecidos. Só confirma a versão depois de concluir toda a limpeza.
static func preparar(pasta: String) -> Error:
	var marcador := pasta.path_join(MARCADOR)
	if FileAccess.file_exists(marcador):
		var json := JSON.new()
		if json.parse(FileAccess.get_file_as_string(marcador)) != OK:
			return ERR_PARSE_ERROR
		var dados = json.data
		if not dados is Dictionary:
			return ERR_PARSE_ERROR
		var valor = dados.get("versao")
		if not (valor is float or valor is int) or valor != int(valor) or valor < 0:
			return ERR_PARSE_ERROR
		var versao := int(dados["versao"])
		if versao == ATUAL:
			return OK
		# Um executável antigo não pode apagar partidas de uma versão mais nova.
		if versao > ATUAL:
			return ERR_UNAVAILABLE
	var erro := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(pasta))
	if erro != OK:
		return erro
	for nome in ARQUIVOS:
		var caminho := pasta.path_join(nome)
		if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(caminho)):
			return ERR_FILE_CANT_WRITE
		if not FileAccess.file_exists(caminho):
			continue
		erro = DirAccess.remove_absolute(ProjectSettings.globalize_path(caminho))
		if erro != OK:
			return erro
	var temporario := marcador + ".tmp"
	var arquivo := FileAccess.open(temporario, FileAccess.WRITE)
	if arquivo == null:
		return FileAccess.get_open_error()
	arquivo.store_string(JSON.stringify({"versao": ATUAL}))
	arquivo.flush()
	erro = arquivo.get_error()
	arquivo.close()
	if erro != OK:
		return erro
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(temporario), ProjectSettings.globalize_path(marcador))
