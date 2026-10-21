extends Sprite2D
## Corpo base Raven sem roupa/cabelo prontos; apresentação exclusiva do jogador.
## Único renderizador do jogador: nenhuma ação restaura camadas de outro pacote.
## A lógica de combate/ferramentas permanece dona dos tempos e impactos.
const AparenciaRaven := preload("res://codigo/dados/aparencia_raven.gd")
const CoresArmas := preload("res://codigo/dados/cores_armas_raven.gd")
var _camadas: Array[Sprite2D] = []
var _chave_aparencia := ""
const Profundidade := preload("res://codigo/globais/profundidade.gd")
var _jogador: Node2D
var _texturas: Dictionary = {}
var _animacao := ""
var _direcao := -1
var _tempo := 0.0
var _original_visivel := true
var _pontas: Array = []
var _vara_pesca: Line2D
var _porte_arma := ""
var _escudo_ativo := false
const POSES_PESCA := [0,1,2,3,3,3,3,3]
const PEGADAS_VARAS := [Vector2(-4,-9),Vector2(6,-11),Vector2(3,-13),Vector2(-7,-11)]
const PONTAS_VARAS := [Vector2(-7,7),Vector2(22,-15),Vector2(10,-29),Vector2(-23,-15)]

func _ready() -> void:
	name = "HeroiRaven"
	_jogador = get_parent()
	texture_filter = TEXTURE_FILTER_NEAREST
	centered = false
	offset = Vector2(-40, -47)
	position.y = Profundidade.PES_JOGADOR
	z_index = 3
	process_priority = 120
	hframes = 4
	vframes = 4
	_pontas = JSON.parse_string(FileAccess.get_file_as_string("res://assets/personagens/raven_fantasy/pontas_pesca.json"))
	for i in 14:
		var camada := Sprite2D.new()
		camada.name = "Camada%d" % i
		camada.texture_filter = TEXTURE_FILTER_NEAREST
		camada.centered = false
		camada.offset = offset
		camada.hframes = 4
		camada.vframes = 4
		add_child(camada)
		_camadas.append(camada)
	_camadas[7].z_index = -1 # Parte do escudo atrás do corpo.
	_camadas[8].z_index = 4 # Parte frontal acima do cabelo.
	_camadas[9].z_index = 3 # Elmo/cartola.
	_camadas[10].z_index = 1 # Peitoral.
	_camadas[11].z_index = 2 # Luvas.
	_camadas[12].z_index = 2 # Botas.
	_camadas[13].z_index = -2 # Aljava nas costas.
	# Haste com pegada e comprimento medidos no quarto quadro nativo.
	# A ponta flexiona na disputa sem repetir o gesto de arremessar.
	_vara_pesca = Line2D.new()
	_vara_pesca.width = 2.0
	var espessura := Curve.new()
	espessura.add_point(Vector2(0,1))
	espessura.add_point(Vector2(1,0.5))
	_vara_pesca.width_curve = espessura
	_vara_pesca.default_color = Color("745c42")
	_vara_pesca.antialiased = false
	_vara_pesca.visible = false
	add_child(_vara_pesca)
	_process(0.0)

func _exit_tree() -> void:
	if is_instance_valid(_jogador):
		_jogador.get_node("CompositeSprites").visible = false

func _process(delta: float) -> void:
	if not is_instance_valid(_jogador):
		return
	var original := _jogador.get_node("CompositeSprites") as CanvasItem
	var pesca := _jogador.get_node_or_null("AnimacaoPesca")
	visible = true
	original.visible = false
	self_modulate = original.self_modulate
	modulate = original.modulate
	var vetor: Vector2 = _jogador._direcao_ataque
	if _jogador.defesa != null and (_jogador.defesa.em_guarda() or _jogador.defesa.escudando()):
		vetor = _jogador.defesa.direcao_guarda
	var direcao := 0
	if absf(vetor.x) > absf(vetor.y):
		direcao = 3 if vetor.x < 0 else 1
	elif vetor.y < 0:
		direcao = 2
	var nome := "correr" if _jogador.velocity.length() > 2.0 else "parado"
	var coluna := -1
	var duracao := clampf(48.0 / maxf(_jogador.velocity.length(),1.0),0.24,0.9) if nome == "correr" else 0.8
	var repetir := true
	_porte_arma = ""
	_escudo_ativo = false
	if _jogador.esta_sentado:
		nome = "sentado"
		direcao = (0 if _jogador._frente_sentado > 0 else 2) if _jogador._frente_sentado != 0 else (1 if _jogador._lado_sentado > 0 else 3)
		coluna = 0
	elif _jogador.caido or _jogador.estaMorto:
		nome = "morrer"
		repetir = false
	elif pesca != null:
		nome = "pescar"
		pesca.visible = false
		coluna = quadro_pesca(pesca._pose)
	elif _jogador.esta_em_acao_fazenda and _jogador.no_fazenda != null:
		var acao: String = _jogador.no_fazenda.acao_atual
		nome = acao
		coluna = int(_jogador.no_fazenda._quadros[_jogador.no_fazenda._indice][0]) % 4
	elif _jogador.esta_em_dash:
		nome = "esquiva"
		duracao = _jogador.duracao_dash
		repetir = false
	elif _jogador.defesa != null and _jogador.defesa.escudando():
		nome = "bloquear"
		coluna = [3,0,1,2][clampi(_jogador.defesa._indice,0,3)]
		_escudo_ativo = true
	elif _jogador.defesa != null and _jogador.defesa.em_guarda():
		_escudo_ativo = _jogador.usando_escudo
		nome = "bloquear" if _escudo_ativo else _tipo_armamento()
		# Os primeiros quadros de bloquear são a reação/avanço, não a guarda.
		coluna = 3 if _escudo_ativo else 0
	elif _jogador.no_reacao != null and _jogador.no_reacao.visible and _jogador.no_reacao.pose_atual == "ferido":
		nome = "ferido"
		coluna = 1
	elif _jogador.usando_arco and _jogador.no_arco != null and _jogador.no_arco.esta_disparando():
		nome = "arco"
		coluna = [0,0,1,1,1,2,3,3][clampi(_jogador.no_arco._indice,0,7)]
	elif _jogador._esta_atacando:
		nome = "lanca" if _jogador.usando_lanca else "espada"
		if _jogador.usando_espada and _jogador.id_arma_atual == "machado":
			nome = "machado"
		elif _jogador.usando_espada and _arma_duas_maos():
			nome = "espada_dupla"
		elif _jogador.usando_espada and _jogador._fase_combo == 2:
			nome = "espada_2"
		if not _jogador._temporizador.is_stopped():
			coluna = clampi(int(4.0 * (1.0 - _jogador._temporizador.time_left / _jogador._temporizador.wait_time)),0,3)
		repetir = false
	# Fora do ataque/aparo, a seleção da barra não põe a arma na mão.
	if nome != _animacao or direcao != _direcao:
		_tempo = 0.0
		_animacao = nome
		_direcao = direcao
	_tempo += delta
	if coluna < 0:
		var instante := fmod(_tempo,duracao) if repetir else minf(_tempo,duracao-0.0001)
		coluna = clampi(int(instante / duracao * 4.0),0,3)
	_aplicar_aparencia(nome)
	_vara_pesca.visible = nome == "pescar" and coluna == 3
	if _vara_pesca.visible:
		_vara_pesca.points = pontos_vara(direcao,pesca.tensao)
		_vara_pesca.z_index = -1 if direcao==2 else 0
	_camadas[5].visible = not _vara_pesca.visible
	frame = direcao*4 + clampi(coluna,0,3)
	for camada in _camadas: camada.frame = frame

func criar_previa() -> Sprite2D:
	# Usa o mesmo compositor do mundo em pose neutra, restaurando o estado
	# imediatamente para não mudar direção, golpe ou materiais do jogador.
	var direcao_anterior := _direcao
	var escudo_anterior := _escudo_ativo
	var porte_anterior := _porte_arma
	var quadro_anterior := frame
	_direcao = 0
	_escudo_ativo = false
	_porte_arma = ""
	_aplicar_aparencia("parado")
	frame = 0
	for camada in _camadas: camada.frame = 0
	var previa := criar_rastro()
	previa.modulate = Color.WHITE
	previa.self_modulate = Color.WHITE
	_direcao = direcao_anterior
	_escudo_ativo = escudo_anterior
	_porte_arma = porte_anterior
	_aplicar_aparencia(_animacao if not _animacao.is_empty() else "parado")
	frame = quadro_anterior
	for camada in _camadas: camada.frame = quadro_anterior
	return previa

func criar_rastro() -> Sprite2D:
	# Fotografia das camadas renderizadas: mantém grade, pivô, roupa, cabelo
	# e materiais Raven, sem copiar scripts ou consultar sprites ocultos.
	var copia := _copiar_sprite(self)
	copia.transform = Transform2D.IDENTITY
	for camada in _camadas:
		if camada.is_visible_in_tree() and camada.texture != null:
			copia.add_child(_copiar_sprite(camada))
	return copia

func _copiar_sprite(origem: Sprite2D) -> Sprite2D:
	var copia := Sprite2D.new()
	copia.name = origem.name
	copia.texture = origem.texture
	copia.hframes = origem.hframes
	copia.vframes = origem.vframes
	copia.frame = origem.frame
	copia.centered = origem.centered
	copia.offset = origem.offset
	copia.flip_h = origem.flip_h
	copia.flip_v = origem.flip_v
	copia.transform = origem.transform
	copia.z_index = origem.z_index
	copia.z_as_relative = origem.z_as_relative
	copia.modulate = origem.modulate
	copia.self_modulate = origem.self_modulate
	copia.material = origem.material
	copia.texture_filter = TEXTURE_FILTER_NEAREST
	return copia

func _arma_duas_maos() -> bool:
	var arma = _jogador.inventario.equipados.get("arma")
	return arma != null and arma.duas_maos

func _tipo_armamento() -> String:
	if _jogador.inventario.vara_na_mao: return ""
	if _jogador.usando_lanca: return "lanca"
	if _jogador.usando_arco: return "arco"
	if _jogador.usando_espada:
		if _jogador.id_arma_atual == "machado": return "machado"
		return "espada_dupla" if _arma_duas_maos() else "espada"
	return ""

func quadro_pesca(pose: int) -> int:
	var pesca := _jogador.get_node_or_null("AnimacaoPesca")
	# O quadro com rastro continua no lançamento; na espera a vara fica estendida.
	return 3 if pesca != null and pesca.em_espera else POSES_PESCA[clampi(pose,0,7)]

func ponta_pesca(pose: int, linha: int) -> Vector2:
	# A folha anterior ordena baixo/cima/direita/esquerda.
	var direcao: int = [0,2,1,3][linha]
	var quadro := quadro_pesca(pose)
	if quadro == 3:
		var pesca := _jogador.get_node_or_null("AnimacaoPesca")
		return pontos_vara(direcao,pesca.tensao if pesca != null else 0.0)[-1]+position
	var ponto: Array = _pontas[direcao][quadro]
	return Vector2(ponto[0],ponto[1])

func pontos_vara(direcao: int, tensao: float) -> PackedVector2Array:
	var mao: Vector2 = PEGADAS_VARAS[direcao]
	var ponta: Vector2 = PONTAS_VARAS[direcao]
	var frente: Vector2 = [Vector2.DOWN,Vector2.RIGHT,Vector2.UP,Vector2.LEFT][direcao]
	return PackedVector2Array([mao,mao.lerp(ponta,0.5).round(),(mao.lerp(ponta,0.8)+frente*tensao).round(),(ponta+frente*2.0*tensao).round()])

func _aplicar_aparencia(acao: String) -> void:
	var dados: Dictionary = _jogador.aparencia_raven
	var raizes: Dictionary = _jogador.raizes_armadura.duplicate()
	var visual: String = preload("res://codigo/dados/aparencia.gd").raiz_armadura_visual(_jogador.roupa_atual)
	if not visual.is_empty():
		for peca in ["elmo","peitoral","luvas","botas"]:
			if _jogador.pecas_cavaleiro & preload("res://codigo/dados/aparencia.gd").PECAS_CAVALEIRO[peca]: raizes[peca]=visual
	var basicas := {}
	for par in [["cabeca","elmo","cabeca_basica"],["corpo","peitoral","armadura_basica"],["luvas","luvas","luvas_basicas"],["botas","botas","botas_basicas"]]:
		var item = _jogador.inventario.equipados.get(par[0])
		if item != null and item.tipo == par[2] and not raizes.has(par[1]): basicas[par[1]]=true
	var arma = _jogador.inventario.equipados.get("arma")
	var escudo = _jogador.inventario.equipados.get("escudo")
	var nivel_arma: int = arma.nivel if arma != null else 1
	var nivel_escudo: int = escudo.nivel if escudo != null else 1
	var tipo_arma: String = arma.tipo if arma != null else _jogador.id_arma_atual
	var chave: String = acao+JSON.stringify(dados)+JSON.stringify(raizes)+JSON.stringify(basicas)+str(_direcao)+str(_escudo_ativo)+str(_jogador.usando_arco)+_jogador.id_arma_atual+JSON.stringify([tipo_arma,nivel_arma,nivel_escudo,_jogador.esta_em_acao_fazenda])
	if chave == _chave_aparencia: return
	_chave_aparencia = chave
	var pele := clampi(int(dados.get("pele",0)),0,2)
	var cabelo := AparenciaRaven.indice_cabelo(int(dados.get("cabelo",0)))
	var roupa := AparenciaRaven.indice_roupa(int(dados.get("roupa",0)))
	material = AparenciaRaven.material_pose(false,acao=="sentado",_direcao)
	texture = AparenciaRaven.folha("corpo_%d" % pele,acao)
	var pecas := AparenciaRaven.pecas_roupa(roupa)
	for i in 5:
		_camadas[i].texture = AparenciaRaven.folha(pecas[i] if i < pecas.size() else "vazio",acao)
		_camadas[i].material = AparenciaRaven.material_pose(false,acao=="sentado",_direcao)
	_camadas[5].texture = AparenciaRaven.folha("ferramentas",acao)
	if not _porte_arma.is_empty():
		_camadas[5].texture = AparenciaRaven.folha("porte_"+_porte_arma,acao)
	_camadas[5].material = AparenciaRaven.material_pose(false,acao=="sentado",_direcao,true,acao=="pescar")
	if not _jogador.esta_em_acao_fazenda and acao in ["espada","espada_2","espada_dupla","machado","lanca","arco"]:
		_camadas[5].material = CoresArmas.material(tipo_arma,nivel_arma)
	_camadas[6].texture = AparenciaRaven.folha("vazio" if cabelo == 0 else "cabelo_%d" % cabelo,acao)
	var cor: Array = dados.get("cor",[1,1,1,1])
	_camadas[6].material = AparenciaRaven.material_pose(true,acao=="sentado",_direcao)
	_camadas[6].modulate = Color(cor[0],cor[1],cor[2],cor[3])
	_camadas[7].texture = AparenciaRaven.folha("escudo_tras" if _escudo_ativo else "vazio",acao)
	_camadas[8].texture = AparenciaRaven.folha("escudo_frente" if _escudo_ativo else "vazio",acao)
	for i in [7,8]: _camadas[i].material = CoresArmas.material("escudo_basico",nivel_escudo) if _escudo_ativo else AparenciaRaven.material_pose(false,acao=="sentado",_direcao)

	for i in 4:
		var peca: String = ["elmo","peitoral","luvas","botas"][i]
		var raiz: String = raizes.get(peca,"")
		_camadas[9+i].texture = AparenciaRaven.folha("vazio",acao) if raiz.is_empty() else AparenciaRaven.folha_arquivo(raiz+"raven_"+peca+".png",acao)
		if basicas.has(peca):
			_camadas[9+i].texture = AparenciaRaven.folha_arquivo("res://assets/personagens/conjuntos/carrasco/raven_elmo.png",acao) if peca=="elmo" else AparenciaRaven.folha(["vazio","camisa_azul","luvas","botas"][i],acao)
		_camadas[9+i].material = AparenciaRaven.material_pose(false,acao=="sentado",_direcao,false)
	# Peças reais substituem as camadas que cobrem, sem retirar as demais.
	var cobertas := raizes.duplicate()
	for peca in basicas: cobertas[peca]=true
	for i in 5:
		var peca := pecas[i] if i<pecas.size() else ""
		if cobertas.has("peitoral") and (peca.begins_with("camisa_") or peca=="capa"):
			_camadas[i].texture = AparenciaRaven.folha("vazio",acao)
		if cobertas.has("luvas") and peca=="luvas": _camadas[i].texture=AparenciaRaven.folha("vazio",acao)
		if cobertas.has("botas") and peca=="botas": _camadas[i].texture=AparenciaRaven.folha("vazio",acao)
	if basicas.has("elmo") or (raizes.has("elmo") and not raizes.elmo.contains("cavalheiro/")):
		_camadas[6].texture=AparenciaRaven.folha("vazio",acao)
	_camadas[13].texture = AparenciaRaven.folha("aljava" if _jogador.usando_arco else "vazio",acao)
	_camadas[13].z_index = 2 if _direcao==2 else -2
	_camadas[13].material = AparenciaRaven.material_pose(false,acao=="sentado",_direcao,false)
	if _jogador.id_arma_atual=="maca" and acao in ["espada","espada_2"]:
		_camadas[5].texture=AparenciaRaven.folha("marreta_"+acao,acao)
