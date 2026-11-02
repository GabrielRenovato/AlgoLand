extends Node
## Estatísticas da tentativa. Combate do grupo é contabilizado pelo anfitrião; saque e maestria são pessoais.
var cena: Node2D
var regiao := ""
var tempo := 0.0
var concluida := false
var apresentada := false
var chefe_derrotado := false
var _inimigos: Dictionary = {}
var _ultimo_autor: Dictionary = {}
var _grupo: Dictionary = {}
var _drops: Dictionary = {}
var _xp_inicial: Dictionary = {}
var _desde_fim := 0.0
var _remoto: Dictionary = {}
var _seq := 0
var _ultimo_seq := -1

func iniciar(raiz: Node2D) -> void:
	cena=raiz
	cena.jogador.maestria.acerto_confirmado.connect(_acerto_local)
	cena.jogador.maestria.defesa_confirmada.connect(func():_pessoal().bloqueios+=1)

func reiniciar(id: String) -> void:
	regiao=id;tempo=0;concluida=false;apresentada=false;chefe_derrotado=false
	_inimigos.clear();_ultimo_autor.clear();_grupo.clear();_drops.clear();_remoto.clear()
	_desde_fim=0;_seq=0;_ultimo_seq=-1
	_xp_inicial=cena.jogador.maestria.modelo.experiencia.duplicate()
	_pessoal()

func eu() -> String:
	return cena.sessao.eu if cena.sessao!=null and cena.sessao.ativo else "local"

func _participante(id: String) -> Dictionary:
	if not _grupo.has(id):
		var nome: String=Ranking.apelido_personagem("")
		if cena.sessao!=null and cena.sessao.ativo:nome=str(cena.sessao.perfil_de(id).get("apelido","Aventureiro"))
		_grupo[id]={"id":id,"nome":nome.left(32),"dano":0,"abates":0,"recebido":0,"bloqueios":0,"mortes":0}
	return _grupo[id]

func _pessoal() -> Dictionary:return _participante(eu())

func registrar_inimigo(no: Node, chefe := false) -> void:
	var id := no.get_instance_id()
	if _inimigos.has(id):return
	_inimigos[id]={"morto":false,"chefe":chefe}
	no.inimigo_morreu.connect(_abate.bind(id),CONNECT_ONE_SHOT)

func _abate(id: int) -> void:
	if not _inimigos.has(id) or _inimigos[id].morto:return
	_inimigos[id].morto=true
	if _inimigos[id].chefe:chefe_derrotado=true
	var autor: String=str(_ultimo_autor.get(id,""))
	if not autor.is_empty():_participante(autor).abates+=1

func _acerto_local(alvo: Node, dano: int) -> void:
	acerto(eu(),alvo,dano)

func acerto(autor: String, alvo: Node, dano: int) -> void:
	if concluida or dano<=0 or not is_instance_valid(alvo) or not _inimigos.has(alvo.get_instance_id()):return
	_participante(autor).dano+=dano
	_ultimo_autor[alvo.get_instance_id()]=autor

func dano_recebido(dano: int) -> void:
	if not concluida:_pessoal().recebido+=maxi(0,dano)

func morte() -> void:
	_pessoal().mortes+=1

func drop_sorteado(id: String, item: Resource) -> void:
	if not _drops.has(id):_drops[id]={"item":item.para_dict(),"recolhido":false}

func drop_recolhido(id: String, item: Resource) -> void:
	drop_sorteado(id,item)
	_drops[id].recolhido=true

func _process(delta: float) -> void:
	if regiao.is_empty() or not is_instance_valid(cena.interface):return
	var livre: bool=cena.interface._telas_abertas.is_empty() and not get_tree().get_meta("cinema_ativo",false) and not cena.jogador.estaMorto
	if not concluida and livre:tempo+=delta
	var autoridade: bool=cena.sessao==null or not cena.sessao.ativo or cena.sessao.sou_host()
	if autoridade and not concluida:
		var vivos: int=_inimigos.values().filter(func(d):return not d.morto).size()
		if regiao in ["chegada","estrada"]:
			concluida=not _inimigos.is_empty() and vivos==0 and (regiao!="chegada" or chefe_derrotado)
		elif regiao=="vila":concluida=cena.controlador.progresso.missao_concluida("acolhimento")
		elif regiao=="pomar":concluida="canal" in cena.controlador.progresso.objetivos_cumpridos("pomar_sulcos")
	if concluida and not apresentada:
		_desde_fim+=delta
		# Deixa terminar a morte, os avisos de saque e a fala que concluiu a missão.
		if livre and _desde_fim>=2.0:
			apresentada=true
			cena.interface.mostrar_resultado()

func resumo_rede() -> Dictionary:
	_seq+=1
	return {"regiao":regiao,"seq":_seq,"tempo":tempo,"concluida":concluida,"chefe":chefe_derrotado,"inimigos":_inimigos.size(),"abates":_inimigos.values().filter(func(d):return d.morto).size(),"grupo":_grupo.values().duplicate(true)}

func receber_resumo(d: Dictionary) -> bool:
	if d.get("regiao")!=regiao or not d.get("grupo") is Array or d.grupo.size()>4:return false
	if not d.get("seq") is int and not d.get("seq") is float:return false
	if int(d.seq)<=_ultimo_seq or not d.get("concluida") is bool or not d.get("chefe") is bool:return false
	for chave in ["tempo","inimigos","abates"]:
		if not (d.get(chave) is int or d.get(chave) is float) or not is_finite(float(d[chave])) or float(d[chave])<0 or float(d[chave])>10000000:return false
	if d.abates>d.inimigos:return false
	var ids := {}
	for p in d.grupo:
		if not p is Dictionary or not p.get("id") is String or p.id.length()>128 or ids.has(p.id) or not p.get("nome") is String or p.nome.length()>32:return false
		ids[p.id]=true
		for chave in ["dano","abates","recebido","bloqueios","mortes"]:
			if not (p.get(chave) is int or p.get(chave) is float) or float(p[chave])<0 or float(p[chave])>100000000 or not is_finite(float(p[chave])):return false
	_ultimo_seq=int(d.seq);_remoto=d.duplicate(true)
	tempo=float(d.tempo);concluida=d.concluida;chefe_derrotado=d.chefe
	return true

func dados() -> Dictionary:
	var r := resumo_rede() if _remoto.is_empty() else _remoto.duplicate(true)
	# O anfitrião conhece o dano de todos; vida perdida e bloqueios locais ficam neste cliente.
	var pessoal := _pessoal().duplicate()
	var grupo: Array=r.grupo
	if not grupo.any(func(p):return p.id==eu()):grupo.append(pessoal.duplicate())
	for p in grupo:
		if p.id==eu():
			for campo in ["recebido","bloqueios","mortes"]:p[campo]=pessoal[campo]
	grupo.sort_custom(func(a,b):return a.dano>b.dano if a.dano!=b.dano else str(a.id)<str(b.id))
	for p in grupo:
		if p.id==eu():
			pessoal.dano=p.dano;pessoal.abates=p.abates
	r.grupo=grupo;r.eu=eu();r.pessoal=pessoal;r.drops=_drops.values().duplicate(true)
	r.maestria=[]
	for f in _xp_inicial:
		var ganho: int=int(cena.jogador.maestria.modelo.experiencia.get(f,0))-int(_xp_inicial[f])
		if ganho>0:r.maestria.append({"familia":f,"xp":ganho,"nivel":cena.jogador.maestria.modelo.nivel(f)})
	return r
