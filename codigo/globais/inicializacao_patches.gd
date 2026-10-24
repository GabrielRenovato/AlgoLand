extends Node

## Núcleo fixo: precisa ser o PRIMEIRO autoload. Nunca referencia scripts do jogo.
## A montagem acontece no _init, antes de o Godot compilar os outros autoloads.
const CHAVE = preload("res://codigo/globais/atualizacao_chave.gd")
const PASTA := "user://atualizacao/"
const REGISTRO := PASTA + "pacotes.json"
var conteudo := 0
var manifesto: Dictionary = {}
var erro := ""
var erro_fatal := false

func _init() -> void:
	if OS.has_feature("web"):
		return
	var registro = JSON.parse_string(FileAccess.get_file_as_string(REGISTRO)) if FileAccess.file_exists(REGISTRO) else null
	if not registro is Dictionary:
		return
	var dados := validar_manifesto(registro)
	if dados.is_empty():
		erro = "Manifesto local inválido ou de outra versão."
		return
	# Confere TODOS antes de montar qualquer um: evita misturar gerações incompletas.
	for pacote in dados.pacotes:
		if not conferir_pacote(PASTA + str(pacote.arquivo), pacote):
			erro = "Pacote local ausente ou corrompido."
			return
	for pacote in dados.pacotes:
		if not ProjectSettings.load_resource_pack(PASTA + str(pacote.arquivo), true):
			# Um pacote inválido após a verificação não permite abrir com montagem parcial.
			erro = "Não foi possível montar o conteúdo. Reabra para recuperar."
			DirAccess.remove_absolute(REGISTRO)
			erro_fatal = true
			return
	# O tema global é aberto pelo motor antes dos autoloads. Atualiza a mesma
	# instância em cache e suas texturas/fontes antes de criar a interface.
	var tema := str(ProjectSettings.get_setting("gui/theme/custom", ""))
	if not tema.is_empty():
		ResourceLoader.load(tema, "", ResourceLoader.CACHE_MODE_REPLACE_DEEP)
	manifesto = dados
	conteudo = int(dados.conteudo)

func _ready() -> void:
	if erro_fatal:
		push_error(erro)
		get_tree().quit(1)
		return
	if not manifesto.is_empty():
		var manter := {}
		for pacote in manifesto.pacotes: manter[str(pacote.arquivo)] = true
		var pasta := DirAccess.open(PASTA)
		if pasta != null:
			for nome in pasta.get_files():
				if nome.ends_with(".pck") and not manter.has(nome): pasta.remove(nome)

static func plataforma() -> String:
	if OS.has_feature("android"): return "android"
	if OS.has_feature("windows"): return "windows"
	return "linux"

static func assinatura_valida(hash_hex: String, assinatura: String) -> bool:
	var chave := CryptoKey.new()
	if chave.load_from_string(CHAVE.PUBLICA, true) != OK: return false
	return Crypto.new().verify(HashingContext.HASH_SHA256, hash_hex.hex_decode(), Marshalls.base64_to_raw(assinatura), chave)

static func validar_manifesto(envelope: Dictionary) -> Dictionary:
	var texto: String = str(envelope.get("dados", ""))
	if not assinatura_valida(texto.sha256_text(), str(envelope.get("assinatura", ""))): return {}
	var dados = JSON.parse_string(texto)
	if not dados is Dictionary: return {}
	if dados.get("formato") != 2 or str(dados.get("app_base", "")) != str(ProjectSettings.get_setting("application/config/version", "")): return {}
	if dados.get("plataforma") != plataforma() or not dados.get("pacotes") is Array or int(dados.get("conteudo", 0)) <= 0: return {}
	var nomes := {}
	var ids := {}
	for pacote in dados.pacotes:
		if not pacote is Dictionary: return {}
		var nome := str(pacote.get("arquivo", ""))
		var id := str(pacote.get("id", ""))
		if nome.is_empty() or nome != nome.get_file() or nome.contains("..") or nome.contains("\\") or not nome.ends_with(".pck"): return {}
		if id.is_empty() or ids.has(id) or nomes.has(nome) or int(pacote.get("tamanho", 0)) <= 0: return {}
		var hash_hex := str(pacote.get("sha256", ""))
		if hash_hex.length() != 64 or hash_hex.hex_decode().size() != 32: return {}
		ids[id] = true
		nomes[nome] = true
	return dados

static func conferir_pacote(caminho: String, pacote: Dictionary) -> bool:
	var arquivo := FileAccess.open(caminho, FileAccess.READ)
	if arquivo == null: return false
	var tamanho := arquivo.get_length()
	var magic := arquivo.get_buffer(4).get_string_from_ascii()
	arquivo.close()
	if tamanho != int(pacote.get("tamanho", -1)) or magic != "GDPC": return false
	var hash_hex := FileAccess.get_sha256(caminho)
	return hash_hex == str(pacote.get("sha256", "")) and assinatura_valida(hash_hex, str(pacote.get("assinatura", "")))
