extends Node
## Save na nuvem. Filho do ContaJogador. Reaproveita o pacote da transferência entre aparelhos (transferencia_save.gd).
## Regras: nunca sobrescreve sem saber; cada gravação informa a revisão que conhece e o servidor recusa se outro aparelho
## gravou antes (conflito). O que for substituído fica guardado: cópia local em user://backups e versão anterior na nuvem.
## Baixar só acontece no menu inicial, onde recarregar o mundo é seguro; no meio do jogo só sobe.
signal mudou
signal save_aplicado

const TransferenciaSave := preload("res://codigo/globais/transferencia_save.gd")
const ARQUIVO := "user://nuvem.json"
const INTERVALO_AUTOMATICO_S := 90
const LIMITE_CODIFICADO := 1400000
## "", "sincronizando", "ok", "erro", "conflito", "nuvem_adiante"
var estado := ""
var mensagem := ""
## Preenchido em conflito: {rev, atualizado_em, aparelho, local: resumo, nuvem: resumo}
var conflito: Dictionary = {}
var ultima_sincronizacao := 0
var _rev := 0
var _hash := ""
var _usuario := ""
var _ocupado := false
var _ultimo_ms := -10000000

func conta() -> Node:
	return get_parent()

func ocupado() -> bool:
	return _ocupado

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_carregar()

# --- Pacote

static func tem_save_local() -> bool:
	return FileAccess.file_exists("user://configuracao_jogador.json")

static func codificar(pacote: Dictionary) -> String:
	var bytes := JSON.stringify(pacote).to_utf8_buffer()
	return "%d:%s" % [bytes.size(), Marshalls.raw_to_base64(bytes.compress(FileAccess.COMPRESSION_GZIP))]

static func decodificar(texto: String) -> Dictionary:
	var separador := texto.find(":")
	if separador <= 0: return {}
	var tamanho := int(texto.substr(0, separador))
	if tamanho <= 0 or tamanho > 20000000: return {}
	var bytes := Marshalls.base64_to_raw(texto.substr(separador + 1)).decompress(tamanho, FileAccess.COMPRESSION_GZIP)
	var dados = JSON.parse_string(bytes.get_string_from_utf8())
	return dados if dados is Dictionary else {}

static func hash_de(pacote: Dictionary) -> String:
	return JSON.stringify(pacote.get("arquivos", {}), "", true).sha256_text()

## Dia do calendário, recorde de andar e Brasas: o que o jogador reconhece ao escolher entre dois saves.
static func resumo_de(pacote: Dictionary) -> Dictionary:
	var arquivos = pacote.get("arquivos", {})
	if not arquivos is Dictionary: return {}
	var calendario = JSON.parse_string(str(arquivos.get("calendario.json", "{}")))
	var progresso = JSON.parse_string(str(arquivos.get("progresso.json", "{}")))
	var resumo := {"dia": 1, "recorde": 0, "brasas": 0}
	if calendario is Dictionary: resumo.dia = int(calendario.get("dia", 1))
	if progresso is Dictionary:
		resumo.recorde = int(progresso.get("recorde_onda", 0))
		resumo.brasas = int(progresso.get("brasas", 0))
	return resumo

func _pacote_local(gravar_antes: bool) -> Dictionary:
	if not tem_save_local(): return {}
	if gravar_antes:
		# No menu inicial os autoloads ainda não carregaram o save: gravar de lá apagaria o progresso do disco.
		var saves := get_tree().root.get_node_or_null("Saves")
		if saves != null and get_tree().current_scene != null and not no_titulo(get_tree()): saves.salvar_tudo()
	return TransferenciaSave.empacotar()

static func no_titulo(arvore: SceneTree) -> bool:
	return arvore.current_scene != null and arvore.current_scene.scene_file_path.ends_with("inicio_do_jogo.tscn")

# --- Sincronização

## motivo: "login", "titulo", "manual", "dormir", "saida". Devolve o estado final (veja `estado`).
func sincronizar(motivo: String) -> String:
	var c := conta()
	if not c.logado() or c.offline or _ocupado: return "ignorado"
	var automatico := motivo in ["dormir", "saida"]
	if automatico and Time.get_ticks_msec() - _ultimo_ms < INTERVALO_AUTOMATICO_S * 1000: return "ignorado"
	_ocupado = true
	_trocar_usuario()
	_definir("sincronizando", "")
	var resultado := await _sincronizar(motivo)
	_ocupado = false
	_ultimo_ms = Time.get_ticks_msec()
	mudou.emit()
	return resultado

func _sincronizar(motivo: String) -> String:
	var meta: Dictionary = await conta().chamar("meta_nuvem")
	if meta.has("erro"): return _definir("erro", str(meta.erro))
	var local := _pacote_local(motivo != "titulo")
	var tem_local := not local.is_empty()
	var hash := hash_de(local) if tem_local else ""
	if not bool(meta.get("existe", false)):
		if not tem_local: return _definir("ok", "")
		return await _subir(local, 0, hash)
	var rev_nuvem := int(meta.get("rev", 0))
	if rev_nuvem == _rev:
		if tem_local and hash != _hash: return await _subir(local, rev_nuvem, hash)
		ultima_sincronizacao = int(Time.get_unix_time_from_system())
		return _definir("ok", "")
	# A nuvem está à frente deste aparelho (ou é o primeiro encontro entre os dois).
	if not tem_local: return await _baixar(meta)
	if _rev > 0 and hash == _hash:
		if no_titulo(get_tree()): return await _baixar(meta)
		return _definir("nuvem_adiante", "HA UM SAVE MAIS NOVO NA NUVEM. ELE SERA TRAZIDO NO MENU INICIAL.")
	var nuvem_baixada: Dictionary = await _baixar_pacote(false)
	conflito = {"rev": rev_nuvem, "atualizado_em": str(meta.get("atualizado_em", "")), "aparelho": str(meta.get("aparelho", "")),
		"local": resumo_de(local), "nuvem": resumo_de(nuvem_baixada)}
	return _definir("conflito", "ESTE APARELHO E A NUVEM TEM PROGRESSOS DIFERENTES.")

func _subir(pacote: Dictionary, rev_esperada: int, hash: String) -> String:
	var texto := codificar(pacote)
	if texto.length() > LIMITE_CODIFICADO: return _definir("erro", "SAVE GRANDE DEMAIS PARA A NUVEM")
	var r: Dictionary = await conta().chamar("salvar_nuvem", {"p_pacote": texto, "p_rev_esperada": rev_esperada,
		"p_versao_app": TransferenciaSave.versao_app(), "p_versao_save": int(pacote.get("versao_save", 0)), "p_aparelho": _nome_aparelho()})
	if r.has("erro"): return _definir("erro", str(r.erro))
	match str(r.get("estado", "")):
		"ok":
			_rev = int(r.get("rev", _rev))
			_hash = hash
			ultima_sincronizacao = int(Time.get_unix_time_from_system())
			conflito = {}
			_gravar()
			return _definir("ok", "")
		"conflito":
			var nuvem_baixada: Dictionary = await _baixar_pacote(false)
			conflito = {"rev": int(r.get("rev", 0)), "atualizado_em": str(r.get("atualizado_em", "")), "aparelho": str(r.get("aparelho", "")),
				"local": resumo_de(pacote), "nuvem": resumo_de(nuvem_baixada)}
			return _definir("conflito", "OUTRO APARELHO SALVOU ANTES. ESCOLHA QUAL PROGRESSO MANTER.")
		"rapido":
			return _definir("ok", "")
		"tamanho_invalido":
			return _definir("erro", "SAVE GRANDE DEMAIS PARA A NUVEM")
	return _definir("erro", "NAO FOI POSSIVEL SALVAR NA NUVEM")

## Baixa o pacote da nuvem sem gravar nada. {} se não há ou está inválido.
func _baixar_pacote(anterior: bool) -> Dictionary:
	var r: Dictionary = await conta().chamar("baixar_nuvem", {"p_anterior": anterior})
	if r.has("erro") or not bool(r.get("existe", false)): return {}
	return decodificar(str(r.get("pacote", "")))

func _baixar(meta: Dictionary) -> String:
	if not no_titulo(get_tree()): return _definir("nuvem_adiante", "HA UM SAVE MAIS NOVO NA NUVEM. ELE SERA TRAZIDO NO MENU INICIAL.")
	if int(meta.get("versao_save", 0)) > TransferenciaSave.VersaoSave.ATUAL:
		return _definir("erro", "O SAVE DA NUVEM E DE UMA VERSAO MAIS NOVA. ATUALIZE O JOGO")
	var pacote := await _baixar_pacote(false)
	if pacote.is_empty(): return _definir("erro", "NAO FOI POSSIVEL BAIXAR O SAVE DA NUVEM")
	var erro := TransferenciaSave.aplicar(pacote, false)
	if not erro.is_empty(): return _definir("erro", erro)
	_rev = int(meta.get("rev", 0))
	_hash = hash_de(TransferenciaSave.empacotar())
	ultima_sincronizacao = int(Time.get_unix_time_from_system())
	conflito = {}
	_gravar()
	save_aplicado.emit()
	return _definir("baixado", "SAVE DA NUVEM APLICADO. UMA COPIA DO ANTERIOR FICOU GUARDADA.")

## Resolve o conflito: usar a nuvem (só no menu inicial) ou manter este aparelho (a nuvem guarda a versão anterior).
func resolver(usar_nuvem: bool) -> String:
	if conflito.is_empty() or _ocupado: return "ignorado"
	_ocupado = true
	var resultado := ""
	var meta: Dictionary = await conta().chamar("meta_nuvem")
	if meta.has("erro"):
		resultado = _definir("erro", str(meta.erro))
	elif usar_nuvem:
		resultado = await _baixar(meta)
	else:
		var local := _pacote_local(true)
		resultado = await _subir(local, int(meta.get("rev", 0)), hash_de(local))
		# A conta passa a apontar para o código deste aparelho, que veio junto com o save mantido.
		if resultado == "ok": await conta().adotar_codigo_local()
	_ocupado = false
	mudou.emit()
	return resultado

# --- Estado e disco

func _definir(novo: String, texto: String) -> String:
	estado = novo
	mensagem = texto
	mudou.emit()
	return novo

func _nome_aparelho() -> String:
	return "%s %s" % [OS.get_name(), OS.get_model_name() if OS.get_model_name() != "GenericDevice" else ""]

## Outra conta neste aparelho: as revisões da conta anterior não valem.
func _trocar_usuario() -> void:
	if _usuario == conta().usuario_id: return
	_usuario = conta().usuario_id
	_rev = 0
	_hash = ""
	conflito = {}
	_gravar()

func _gravar() -> void:
	var arquivo := FileAccess.open(ARQUIVO, FileAccess.WRITE)
	if arquivo == null: return
	arquivo.store_string(JSON.stringify({"usuario": _usuario, "rev": _rev, "hash": _hash, "ultima": ultima_sincronizacao}))

func _carregar() -> void:
	if not FileAccess.file_exists(ARQUIVO): return
	var dados = JSON.parse_string(FileAccess.get_file_as_string(ARQUIVO))
	if not dados is Dictionary: return
	_usuario = str(dados.get("usuario", ""))
	_rev = int(dados.get("rev", 0))
	_hash = str(dados.get("hash", ""))
	ultima_sincronizacao = int(dados.get("ultima", 0))
