extends RefCounted

## Persistência opt-in por perfil. Nenhum autoload ou save existente é alterado.
## Confirmar conclusão é uma operação interna: o futuro controlador da sessão
## deve validar objetivos e participação antes de chamá-la, nunca aceitar RPC direto.
const Catalogo := preload("res://codigo/campanha/catalogo_campanha.gd")
const Preparos := preload("res://codigo/campanha/preparos_ivo.gd")
const VERSAO_SAVE := 1
var _catalogo: Dictionary = Catalogo.dados()
var _concluidas: Array = []
var _objetivos: Dictionary = {}
var _retorno: Dictionary = {}
var tempos_regioes: Dictionary = {}
var bau_resgate_aberto := false
var preparo := ""
var recompensas: Array = []
var _arquivo := ""
var _perfil := ""
var _pronto := false
var _existia := false
var _texto_base := ""
var _tentativas: Dictionary = {}

func iniciar(pasta: String, perfil: String) -> Error:
	_pronto = false
	_tentativas = {}
	_concluidas = []
	_objetivos = {}
	_retorno = {}
	tempos_regioes = {}
	bau_resgate_aberto = false
	preparo = ""
	recompensas = []
	_arquivo = ""
	_perfil = ""
	_existia = false
	_texto_base = ""
	var identificador := RegEx.new()
	identificador.compile("^[a-zA-Z0-9_-]{1,64}$")
	if not pasta.begins_with("user://") or ".." in pasta.split("/") or identificador.search(perfil) == null:
		return ERR_INVALID_PARAMETER
	if not Catalogo.validar(_catalogo):
		return ERR_INVALID_DATA
	_perfil = perfil
	_arquivo = pasta.path_join("campanhas").path_join(perfil).path_join(Catalogo.ID + ".json")
	if DirAccess.dir_exists_absolute(_arquivo):
		return ERR_FILE_CANT_READ
	_existia = FileAccess.file_exists(_arquivo)
	if _existia:
		var arquivo := FileAccess.open(_arquivo, FileAccess.READ)
		if arquivo == null:
			return FileAccess.get_open_error()
		_texto_base = arquivo.get_as_text()
		arquivo.close()
		var json := JSON.new()
		if json.parse(_texto_base) != OK or not json.data is Dictionary:
			return ERR_FILE_CORRUPT
		# Compatibilidade restrita à versão antiga, já concluída, de quatro objetivos.
		var lista_antiga: Variant = json.data.get("objetivos",{})
		var antigos: Variant = lista_antiga.get("sobreviver_queda",[]) if lista_antiga is Dictionary else []
		if json.data.get("concluidas") is Array and "sobreviver_queda" in json.data.concluidas and antigos is Array and antigos.size()==4 and ["espada","escudo","combate","saida"].all(func(id):return id in antigos):
			json.data.objetivos.sobreviver_queda = _catalogo.missoes.sobreviver_queda.objetivos.map(func(o):return o.id)
		var migracao := _migrar_conteudo(json.data)
		if migracao != OK:
			return migracao
		var erro := _validar_save(json.data)
		if erro != OK:
			return erro
		_concluidas = json.data.concluidas.duplicate()
		_objetivos = json.data.get("objetivos", {}).duplicate(true)
		_retorno = json.data.get("retorno", {}).duplicate(true)
		tempos_regioes = json.data.get("tempos_regioes",{}).duplicate()
		bau_resgate_aberto = json.data.get("bau_resgate_aberto",false)
		preparo = json.data.get("preparo","")
		recompensas = json.data.get("recompensas",[]).duplicate()
		_tentativas = json.data.get("tentativas",{}).duplicate(true)
	_pronto = true

	return OK

func _migrar_conteudo(dados: Dictionary) -> Error:
	if dados.get("versao_conteudo") != 1: return OK
	# Validar pelo contrato anterior antes de transformar o save em memória.
	var atual := _catalogo
	var anterior := atual.duplicate(true)
	anterior.versao_conteudo = 1
	anterior.destinos.vila.requisitos = ["sobreviver_queda"]
	var acolhimento: Array = anterior.missoes.acolhimento.objetivos
	anterior.missoes.estrada_interrompida.objetivos.append_array(acolhimento.slice(0,2))
	anterior.missoes.estrada_interrompida.objetivos[2].apos = ["trabalhador"]
	anterior.missoes.acolhimento.objetivos = acolhimento.slice(2)
	anterior.missoes.acolhimento.objetivos[0].apos = []
	_catalogo = anterior
	var erro := _validar_save(dados)
	_catalogo = atual
	if erro != OK: return erro
	var objetivos: Dictionary = dados.get("objetivos",{}).duplicate(true)
	var estrada: Array = objetivos.get("estrada_interrompida",[])
	var relato: Array = estrada.filter(func(id):return id in ["dara","retorno"])
	if "estrada_interrompida" in dados.concluidas: relato = ["dara","retorno"]
	if objetivos.has("estrada_interrompida"):
		objetivos.estrada_interrompida = estrada.filter(func(id):return not id in ["dara","retorno"])
		if objetivos.estrada_interrompida.size()==2 and not "estrada_interrompida" in dados.concluidas:
			dados.concluidas.append("estrada_interrompida")
	if "acolhimento" in dados.concluidas:
		if objetivos.has("acolhimento"):
			objetivos.acolhimento = atual.missoes.acolhimento.objetivos.map(func(o):return o.id)
	else:
		var antigos: Array = objetivos.get("acolhimento",[])
		if not antigos.is_empty(): relato = ["dara","retorno"]
		if not relato.is_empty(): objetivos.acolhimento = relato + antigos
	dados.objetivos = objetivos
	# Uma visita antiga à vila não pode colocar o jogador além do novo bloqueio.
	if dados.get("retorno",{}).get("regiao","")=="vila" and not "estrada_interrompida" in dados.concluidas:
		dados.retorno = {}
	dados.versao_conteudo = atual.versao_conteudo
	return OK

func ponto_retorno() -> Dictionary:
	return _retorno.duplicate(true) if _pronto else {}

func salvar_retorno(regiao: String, posicao: Vector2) -> Error:
	if not _pronto:
		return ERR_UNCONFIGURED
	if not acesso_liberado(regiao) or _catalogo.destinos[regiao].tipo == "andar" or not posicao.is_finite() or absf(posicao.x)>100000 or absf(posicao.y)>100000:
		return ERR_INVALID_PARAMETER
	var anterior := _retorno.duplicate(true)
	_retorno = {"regiao":regiao,"posicao":[posicao.x,posicao.y]}
	var erro := _gravar(_concluidas)
	if erro != OK:
		_retorno = anterior
	return erro

func _validar_save(dados: Dictionary) -> Error:
	if not dados.get("bau_resgate_aberto",false) is bool: return ERR_FILE_CORRUPT
	var escolha: Variant = dados.get("preparo","")
	if not escolha is String or (not escolha.is_empty() and not Preparos.valido(escolha)): return ERR_FILE_CORRUPT
	var versao: Variant = dados.get("versao")
	var conteudo: Variant = dados.get("versao_conteudo")
	if not (versao is int or versao is float) or versao != int(versao):
		return ERR_FILE_CORRUPT
	if versao > VERSAO_SAVE:
		return ERR_UNAVAILABLE
	if versao != VERSAO_SAVE or dados.get("campanha") != Catalogo.ID or dados.get("perfil") != _perfil:
		return ERR_FILE_CORRUPT
	if not (conteudo is int or conteudo is float) or conteudo != int(conteudo):
		return ERR_FILE_CORRUPT
	if conteudo != _catalogo.versao_conteudo:
		return ERR_UNAVAILABLE
	if not Catalogo._lista_ids(dados.get("concluidas"), _catalogo.missoes):
		return ERR_FILE_CORRUPT
	for id in dados.concluidas:
		if not Catalogo.requisitos_cumpridos(_catalogo.missoes[id].requisitos, dados.concluidas):
			return ERR_FILE_CORRUPT
	var objetivos: Variant = dados.get("objetivos", {})
	if not objetivos is Dictionary:
		return ERR_FILE_CORRUPT
	for missao in objetivos:
		if not _catalogo.missoes.has(missao):
			return ERR_FILE_CORRUPT
		var por_id := {}
		for item in _catalogo.missoes[missao].get("objetivos", []):
			por_id[item.id] = item
		if not Catalogo._lista_ids(objetivos[missao], por_id):
			return ERR_FILE_CORRUPT
		if not Catalogo.requisitos_cumpridos(_catalogo.missoes[missao].requisitos, dados.concluidas):
			return ERR_FILE_CORRUPT
		for objetivo in objetivos[missao]:
			if not Catalogo.requisitos_cumpridos(por_id[objetivo].apos, objetivos[missao]):
				return ERR_FILE_CORRUPT
		if not objetivos[missao].is_empty():
			var completa: bool = objetivos[missao].size() == por_id.size()
			if completa != (missao in dados.concluidas):
				return ERR_FILE_CORRUPT
	if not escolha.is_empty() and not "oficio" in objetivos.get("acolhimento",[]): return ERR_FILE_CORRUPT
	var entregues: Variant = dados.get("recompensas",[])
	if not Catalogo._lista_ids(entregues, _catalogo.missoes): return ERR_FILE_CORRUPT
	for id in entregues:
		if not id in dados.concluidas: return ERR_FILE_CORRUPT
	var tentativas: Variant = dados.get("tentativas",{})
	if not tentativas is Dictionary: return ERR_FILE_CORRUPT
	for missao in tentativas:
		if not _catalogo.missoes.has(missao): return ERR_FILE_CORRUPT
		if not Catalogo.requisitos_cumpridos(_catalogo.missoes[missao].requisitos,dados.concluidas): return ERR_FILE_CORRUPT
		var conhecidos := {}
		for o in _catalogo.missoes[missao].objetivos: conhecidos[o.id] = o
		if not Catalogo._lista_ids(tentativas[missao],conhecidos): return ERR_FILE_CORRUPT
		for id in tentativas[missao]:
			if not Catalogo.requisitos_cumpridos(conhecidos[id].apos,tentativas[missao]): return ERR_FILE_CORRUPT
	var tempos: Variant = dados.get("tempos_regioes",{})
	if not tempos is Dictionary: return ERR_FILE_CORRUPT
	for id in tempos:
		if not _catalogo.destinos.has(id) or not (tempos[id] is int or tempos[id] is float) or not is_finite(float(tempos[id])) or float(tempos[id])<0:
			return ERR_FILE_CORRUPT
	var retorno: Variant = dados.get("retorno", {})
	if not retorno is Dictionary:
		return ERR_FILE_CORRUPT
	if not retorno.is_empty():
		if not _catalogo.destinos.has(retorno.get("regiao", "")) or _catalogo.destinos[retorno.regiao].tipo == "andar":
			return ERR_FILE_CORRUPT
		if not Catalogo.requisitos_cumpridos(_catalogo.destinos[retorno.regiao].requisitos,dados.concluidas):
			return ERR_FILE_CORRUPT
		if not retorno.get("posicao") is Array or retorno.posicao.size() != 2:
			return ERR_FILE_CORRUPT
		for valor in retorno.posicao:
			if not (valor is int or valor is float) or not is_finite(float(valor)) or absf(float(valor)) > 100000:
				return ERR_FILE_CORRUPT
	return OK

## A tentativa é independente do histórico de desbloqueios. Entregas em outra região sobrevivem ao mapa.
func iniciar_instancia(regiao: String) -> Error:
	if not _pronto or not acesso_liberado(regiao): return ERR_UNAUTHORIZED
	var missao := ""
	for id in _catalogo.missoes:
		if _catalogo.missoes[id].destino == regiao:
			missao = id
			break
	if missao.is_empty(): return ERR_INVALID_PARAMETER
	var antes := _tentativas.duplicate(true)
	var tempos := tempos_regioes.duplicate()
	var bau := bau_resgate_aberto
	_tentativas[missao] = []
	# O pedido recebido na cidade continua válido ao entrar no estágio da investigação.
	for o in _catalogo.missoes[missao].objetivos:
		if o.regiao == regiao: break
		if o.id in _objetivos.get(missao,[]): _tentativas[missao].append(o.id)
	tempos_regioes[regiao] = 0.0
	if regiao == "chegada": bau_resgate_aberto = false
	var erro := _gravar(_concluidas)
	if erro != OK:
		_tentativas = antes
		tempos_regioes = tempos
		bau_resgate_aberto = bau
	return erro

func objetivos_cumpridos(missao: String) -> Array:
	if _pronto and _tentativas.has(missao): return _tentativas[missao].duplicate()
	return _objetivos.get(missao, []).duplicate() if _pronto else []

func registrar_abertura_bau() -> Error:
	if not _pronto: return ERR_UNCONFIGURED
	if bau_resgate_aberto: return OK
	bau_resgate_aberto = true
	var erro := _gravar(_concluidas)
	if erro!=OK: bau_resgate_aberto=false
	return erro

func registrar_objetivo(missao: String, id: String) -> Error:
	if not _pronto:
		return ERR_UNCONFIGURED
	if not _catalogo.missoes.has(missao):
		return ERR_INVALID_PARAMETER
	var lista: Array = _catalogo.missoes[missao].get("objetivos", [])
	var encontrado := {}
	for objetivo in lista:
		if objetivo.id == id:
			encontrado = objetivo
	if encontrado.is_empty():
		return ERR_INVALID_PARAMETER
	if not pode_concluir(missao):
		return ERR_UNAUTHORIZED
	if missao_concluida(missao) or id in objetivos_cumpridos(missao):
		return OK
	if not Catalogo.requisitos_cumpridos(encontrado.apos, objetivos_cumpridos(missao)):
		return ERR_UNAUTHORIZED
	if _tentativas.has(missao):
		var anterior: Array = _tentativas[missao].duplicate()
		_tentativas[missao].append(id)
		var historico := _objetivos.duplicate(true)
		var permanentes: Array = historico.get(missao,[])
		var concluidas := _concluidas.duplicate()
		if not missao in concluidas and not id in permanentes:
			permanentes.append(id)
			historico[missao] = permanentes
			if permanentes.size() == lista.size(): concluidas.append(missao)
		# Tentativa e histórico compartilham uma única gravação atômica.
		var erro := _gravar(concluidas,historico)
		if erro != OK: _tentativas[missao] = anterior
		return erro
	var objetivos := _objetivos.duplicate(true)
	var cumpridos: Array = objetivos.get(missao, [])
	cumpridos.append(id)
	objetivos[missao] = cumpridos
	var concluidas := _concluidas.duplicate()
	if cumpridos.size() == lista.size():
		concluidas.append(missao)
	return _gravar(concluidas, objetivos)

## A escolha e o objetivo `oficio` entram na mesma gravação; se ela falhar, nada fica pela metade.
func registrar_preparo(escolha: String) -> Error:
	if not _pronto:
		return ERR_UNCONFIGURED
	if not Preparos.valido(escolha):
		return ERR_INVALID_PARAMETER
	if not preparo.is_empty():
		return OK
	if missao_concluida("acolhimento") or "oficio" in objetivos_cumpridos("acolhimento"):
		return ERR_ALREADY_EXISTS
	preparo = escolha
	var erro := registrar_objetivo("acolhimento", "oficio")
	if erro != OK:
		preparo = ""
	return erro

## Missões concluídas cuja recompensa ainda não foi entregue (a entrega acontece na cena, que grava o recibo).
func recompensas_pendentes() -> Array:
	return _concluidas.filter(func(id):return not id in recompensas)

func registrar_recompensa(missao: String) -> Error:
	if not _pronto:
		return ERR_UNCONFIGURED
	if not missao in _concluidas:
		return ERR_UNAUTHORIZED
	if missao in recompensas:
		return OK
	recompensas.append(missao)
	var erro := _gravar(_concluidas)
	if erro != OK:
		recompensas.erase(missao)
	return erro

func missao_concluida(id: String) -> bool:
	if _pronto and _tentativas.has(id): return _tentativas[id].size() == _catalogo.missoes[id].objetivos.size()
	return _pronto and id in _concluidas

func pode_concluir(id: String) -> bool:
	return _pronto and _catalogo.missoes.has(id) and Catalogo.requisitos_cumpridos(_catalogo.missoes[id].requisitos, _concluidas)

func confirmar_conclusao(id: String) -> Error:
	if not _pronto:
		return ERR_UNCONFIGURED
	if not _catalogo.missoes.has(id):
		return ERR_INVALID_PARAMETER
	if id in _concluidas:
		return OK
	if not pode_concluir(id):
		return ERR_UNAUTHORIZED
	var novas := _concluidas.duplicate()
	novas.append(id)
	return _gravar(novas)

func possui_reliquia(id: String) -> bool:
	return _pronto and _catalogo.reliquias.has(id) and _catalogo.reliquias[id].obtida_em in _concluidas

func ativar_reliquia(id: String) -> Error:
	if not _pronto:
		return ERR_UNCONFIGURED
	if not _catalogo.reliquias.has(id):
		return ERR_INVALID_PARAMETER
	if not possui_reliquia(id):
		return ERR_UNAUTHORIZED
	return confirmar_conclusao(_catalogo.reliquias[id].ativada_em)

func acesso_liberado(id: String) -> bool:
	return _pronto and _catalogo.destinos.has(id) and Catalogo.requisitos_cumpridos(_catalogo.destinos[id].requisitos, _concluidas)

func estado_destino(id: String) -> String:
	if not _pronto or not _catalogo.destinos.has(id):
		return "desconhecido"
	if not acesso_liberado(id):
		return "bloqueado"
	return "em_preparacao" if _catalogo.destinos[id].conteudo != "jogavel" else "disponivel"

func retrato() -> Dictionary:
	if not _pronto:
		return {}
	return _snapshot(_concluidas)

func caminho_save() -> String:
	return _arquivo

func _snapshot(concluidas: Array, objetivos: Variant = null) -> Dictionary:
	if objetivos == null:
		objetivos = _objetivos
	# Relíquia e acesso são derivados do mesmo registro de conclusões. Não há
	# uma segunda escrita para conceder recompensa que possa ficar pela metade.
	return {"versao": VERSAO_SAVE, "campanha": Catalogo.ID, "versao_conteudo": _catalogo.versao_conteudo,
		"perfil": _perfil, "concluidas": concluidas.duplicate(), "objetivos": objetivos.duplicate(true), "retorno":_retorno.duplicate(true), "tempos_regioes":tempos_regioes.duplicate(), "bau_resgate_aberto":bau_resgate_aberto,"preparo":preparo,"recompensas":recompensas.duplicate(),"tentativas":_tentativas.duplicate(true)}

func _gravar(novas: Array, objetivos: Variant = null) -> Error:
	if objetivos == null:
		objetivos = _objetivos
	# Uma instância antiga não pode sobrescrever avanço salvo por outra instância.
	# Não é um bloqueio entre processos: a integração deve manter um escritor por perfil.
	if FileAccess.file_exists(_arquivo) != _existia:
		return ERR_BUSY
	if _existia and FileAccess.get_file_as_string(_arquivo) != _texto_base:
		return ERR_BUSY
	var erro := DirAccess.make_dir_recursive_absolute(_arquivo.get_base_dir())
	if erro != OK:
		return erro
	var temporario := _arquivo + ".tmp"
	var arquivo := FileAccess.open(temporario, FileAccess.WRITE)
	if arquivo == null:
		return FileAccess.get_open_error()
	var texto := JSON.stringify(_snapshot(novas, objetivos))
	arquivo.store_string(texto)
	arquivo.flush()
	erro = arquivo.get_error()
	arquivo.close()
	if erro != OK:
		return erro
	# Renomear só depois de fechar o temporário. Um .tmp abandonado nunca é
	# promovido ao carregar: apenas o arquivo final representa uma confirmação.
	erro = DirAccess.rename_absolute(temporario, _arquivo)
	if erro != OK:
		return erro
	_concluidas = novas
	_objetivos = objetivos.duplicate(true)
	_texto_base = texto
	_existia = true
	return OK
