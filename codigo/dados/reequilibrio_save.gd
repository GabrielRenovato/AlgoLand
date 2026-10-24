extends RefCounted

## Limpeza pontual autorizada para o patch de progressão. Não subir a versão
## geral do save: fazenda, personagem, calendário e demais conquistas continuam.
const MARCADOR := "reequilibrio_progressao_1.json"
const ARQUIVOS := ["progresso.json", "inventario.json", "inventario_p2.json",
	"bau.json", "introducao.json", "inventario_introducao_checkpoint.json"]
const SLOTS_ARMADURA := ["cabeca", "corpo", "luvas", "botas"]

static func limpar(valor: Variant) -> Variant:
	if valor is Array:
		var lista := []
		for entrada in valor: lista.append(limpar(entrada))
		return lista
	if not valor is Dictionary: return valor
	var categoria := str(valor.get("categoria", ""))
	if categoria == "receita" or str(valor.get("tipo", "")).begins_with("receita:"):
		return null
	if categoria in SLOTS_ARMADURA and valor.get("raridade") == "lendario":
		return null
	var dados := {}
	for chave in valor: dados[chave] = limpar(valor[chave])
	return dados

static func _gravar(caminho: String, dados: Dictionary) -> Error:
	var temporario := caminho + ".reequilibrio.tmp"
	var arquivo := FileAccess.open(temporario, FileAccess.WRITE)
	if arquivo == null: return FileAccess.get_open_error()
	arquivo.store_string(JSON.stringify(dados, "\t"))
	arquivo.flush()
	var erro := arquivo.get_error()
	arquivo.close()
	if erro != OK: return erro
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(temporario), ProjectSettings.globalize_path(caminho))

static func preparar(pasta: String) -> Error:
	var marcador := pasta.path_join(MARCADOR)
	if FileAccess.file_exists(marcador):
		var feito = JSON.parse_string(FileAccess.get_file_as_string(marcador))
		return OK if feito is Dictionary and feito.get("concluido") == true else ERR_PARSE_ERROR
	# Valida tudo antes da primeira escrita. Uma interrupção pode repetir a limpeza
	# idempotente; os autoloads só carregam depois da confirmação de todos os arquivos.
	var alterados := {}
	for nome in ARQUIVOS:
		var caminho := pasta.path_join(nome)
		if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(caminho)): return ERR_FILE_CANT_WRITE
		if not FileAccess.file_exists(caminho): continue
		var json := JSON.new()
		if json.parse(FileAccess.get_file_as_string(caminho)) != OK or not json.data is Dictionary:
			return ERR_PARSE_ERROR
		var dados: Dictionary = limpar(json.data)
		if nome == "progresso.json":
			dados["brasas"] = 0
			dados["armas_liberadas"] = {}
		alterados[caminho] = dados
	for caminho in alterados:
		var erro := _gravar(caminho, alterados[caminho])
		if erro != OK: return erro
	return _gravar(marcador, {"concluido": true})
