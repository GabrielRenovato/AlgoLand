extends Node2D

## Árvores e pedras da fazenda que a machadinha corta e a picareta quebra (filho do terreno, na origem: as coordenadas
## são as do mapa). O gerador (ferramentas/fazenda/gerar_fazenda.py) lista os recursos: a chave, o tipo ("arvore",
## "arbusto" ou "pedra"), o ponto da base, o sprite (árvores) ou a célula da camada Detalhes (pedras) e o polígono de
## colisão. Cada golpe balança e solta lascas; no último, a pedra se desfaz e a colisão sai; o carvalho cai e deixa um toco
## (ferramentas/fazenda/desenhar_toco.py), que segue bloqueando e sai com mais VIDA_TOCO golpes.
## O que caiu volta depois de alguns dias (Fazenda.RECRESCER), ao carregar a cena. Por enquanto não dropa nada.
## Também desenha o entulho da área de plantio (Fazenda.entulho, como no Stardew) com os desenhos recortados por
## ferramentas/fazenda/recortar_entulho.py (sem o chão da folha, um por estação), com colisão (menos o mato). Pedra, arbusto e arvoreta saem como os recursos fixos,
## mas não voltam; o mato sai com a enxada (Fazenda.aplicar).
## Quem chama é o Plantio: ele recebe o botão de usar ferramenta e repassa as ações "machado" e "picareta".

## Só emite quando o último golpe derruba/quebra o recurso.
signal recurso_extraido(chave: String, tipo: String)

const MSG_NADA_CORTAR := "NADA PARA CORTAR AQUI"
const MSG_NADA_QUEBRAR := "NADA PARA QUEBRAR AQUI"
## Golpes para derrubar
const VIDA := {"arvore": 4, "arvoreta": 3, "arbusto": 2, "pedra": 3}
const VIDA_TOCO := 2
## Toco: <pasta>/<estação>.png, com a base do carvalho na última linha e o tronco a 24 px da esquerda
const PASTA_TOCO := "res://assets/cenario/fazenda/toco/"
const DESENHO_TOCO := Vector2(-24, -25)
## Queda do carvalho: a copa (o desenho acima do corte) gira a partir do corte, ALTURA_CORTE px acima da base, e cai
## para o lado oposto ao do jogador
const ALTURA_CORTE := 19.0
const DURACAO_QUEDA := 0.75
## Que ferramenta serve para cada tipo
const ACAO_DO_TIPO := {"arvore": "machado", "arvoreta": "machado", "arbusto": "machado", "pedra": "picareta"}
## Distância máxima do ponto à frente do jogador até a base do recurso
const ALCANCE := {"arvore": 26.0, "arvoreta": 18.0, "arbusto": 18.0, "pedra": 16.0}
const COR_LASCA := {"arvore": Color(0.62, 0.45, 0.28), "arvoreta": Color(0.45, 0.6, 0.3), "arbusto": Color(0.36, 0.55, 0.25),
	"pedra": Color(0.68, 0.66, 0.64)}
const Profundidade := preload("res://codigo/globais/profundidade.gd")
const COR_ALVO := Color(1.0, 0.95, 0.55, 0.9)

## [{"chave", "tipo", "pos": Vector2, "no": NodePath do sprite, "celula": Vector2i, "obstaculo": NodePath}]
@export var recursos: Array = []
## Desenhos do entulho: <pasta>/<estação>/<peça>.png (pedra_N, mato_N, arbusto, arvoreta). Arbusto e arvoreta com o
## deslocamento do desenho e a colisão relativos à base; a pedra com a colisão relativa ao canto da célula, por variante
const PASTA_ENTULHO := "res://assets/cenario/fazenda/entulho/"
const NOMES_ESTACAO := ["primavera", "verao", "outono", "inverno"]
@export var desenho_arbusto := Rect2(-8, -31, 0, 0)
@export var desenho_arvoreta := Rect2(-16, -31, 0, 0)
@export var colisao_arbusto := Rect2(-5, -8, 10, 8)
@export var colisao_arvoreta := Rect2(-13, -8, 26, 8)
@export var colisoes_pedra: Array[Rect2] = []
@export var variantes_mato := 2

var _vida: Dictionary = {}
var _caidos: Dictionary = {}
var _alvo: Dictionary = {}
## Entulho desenhado: Vector2i -> {"recurso": dicionário como os de `recursos`, "sprite": Sprite2D, "forma": CollisionShape2D}
var _entulho: Dictionary = {}
var _corpo_entulho: StaticBody2D
## Tocos à vista: chave do carvalho -> Sprite2D
var _tocos: Dictionary = {}

func _ready() -> void:
	z_index = 900
	for recurso in recursos:
		if Fazenda.tem_toco(recurso["chave"]):
			var sprite := _sprite(recurso)
			if sprite != null:
				sprite.visible = false
			_mostrar_toco(recurso)
		elif Fazenda.recurso_removido(recurso["chave"]):
			_sumir(recurso, false)
	_corpo_entulho = StaticBody2D.new()
	_corpo_entulho.name = "ObstaculosEntulho"
	_corpo_entulho.collision_layer = 64
	_corpo_entulho.collision_mask = 0
	add_child(_corpo_entulho)
	Fazenda.iniciar_entulho()
	Fazenda.entulho_alterado.connect(func(_celula): _sincronizar_entulho())
	var estacoes := get_parent().get_node_or_null("Estacoes")
	if estacoes != null and estacoes.has_signal("estacao_mudou"):
		estacoes.estacao_mudou.connect(func(_indice): _trocar_estacao())
	_sincronizar_entulho()

func _estacao() -> int:
	var estacoes := get_parent().get_node_or_null("Estacoes")
	if estacoes != null and int(estacoes.get("estacao_atual")) >= 0:
		return int(estacoes.estacao_atual)
	return Calendario.estacao()

func _textura(peca: String) -> Texture2D:
	return load(PASTA_ENTULHO + NOMES_ESTACAO[_estacao()] + "/" + peca + ".png")

## A estação visual virou: cada entulho troca para o desenho da nova
func _trocar_estacao() -> void:
	for registro in _entulho.values():
		if registro.has("sprite"):
			registro["sprite"].texture = _textura(registro["peca"])
	for toco in _tocos.values():
		toco.texture = _textura_toco()

func _textura_toco() -> Texture2D:
	return load(PASTA_TOCO + NOMES_ESTACAO[_estacao()] + ".png")

func _mostrar_toco(recurso: Dictionary) -> void:
	var toco := Sprite2D.new()
	toco.texture = _textura_toco()
	toco.centered = false
	toco.offset = DESENHO_TOCO
	toco.position = recurso["pos"]
	toco.z_as_relative = false
	toco.z_index = Profundidade.z_de(recurso["pos"].y)
	add_child(toco)
	_tocos[recurso["chave"]] = toco

# --- Entulho da área de plantio ---------------------------------------------------------------------------

## Desenha o que entrou e apaga o que saiu de Fazenda.entulho
func _sincronizar_entulho() -> void:
	for celula in _entulho.keys():
		if Fazenda.entulho.get(celula, "") != _entulho[celula]["recurso"]["tipo"]:
			_apagar_entulho(celula)
	for celula in Fazenda.entulho:
		if not _entulho.has(celula):
			_desenhar_entulho(celula, Fazenda.entulho[celula])

func _desenhar_entulho(celula: Vector2i, tipo: String) -> void:
	var variante := absi(celula.x * 7 + celula.y * 13)
	var canto := Vector2(celula) * Fazenda.LADO
	var base := canto + Vector2(8, 16)
	var peca := tipo
	var desenho := Vector2.ZERO
	var area := Rect2()
	match tipo:
		"pedra":
			var n := maxi(colisoes_pedra.size(), 1)
			peca = "pedra_%d" % (variante % n)
			area = colisoes_pedra[variante % n] if not colisoes_pedra.is_empty() else Rect2(3, 6, 10, 9)
			area.position += canto
			desenho = canto - base
		"mato":
			peca = "mato_%d" % (variante % maxi(variantes_mato, 1))
			desenho = canto - base
		"arbusto":
			desenho = desenho_arbusto.position
			area = colisao_arbusto
			area.position += base
		"arvoreta":
			desenho = desenho_arvoreta.position
			area = colisao_arvoreta
			area.position += base
	var sprite := Sprite2D.new()
	sprite.texture = _textura(peca)
	sprite.centered = false
	sprite.offset = desenho
	sprite.position = base
	sprite.z_as_relative = false
	# mato fica no chão; o resto ordena pela base, como os outros objetos
	sprite.z_index = Profundidade.Z_CHAO + 4 if tipo == "mato" else Profundidade.z_de(base.y)
	add_child(sprite)
	var registro := {"recurso": {"chave": "Entulho_%d_%d" % [celula.x, celula.y], "tipo": tipo, "pos": base - Vector2(0, 2),
		"entulho": celula, "no": sprite.get_path()}, "sprite": sprite, "peca": peca}
	_entulho[celula] = registro
	if tipo == "mato":
		return
	var forma := CollisionShape2D.new()
	var retangulo := RectangleShape2D.new()
	retangulo.size = area.size
	forma.shape = retangulo
	forma.position = area.get_center()
	_corpo_entulho.add_child(forma)
	registro["forma"] = forma

func _apagar_entulho(celula: Vector2i) -> void:
	var registro: Dictionary = _entulho.get(celula, {})
	_entulho.erase(celula)
	if registro.has("forma"):
		registro["forma"].queue_free()
	if registro.has("sprite") and is_instance_valid(registro["sprite"]):
		registro["sprite"].queue_free()

func _jogador() -> Node:
	for no in get_tree().get_nodes_in_group("character"):
		if no is CharacterBody2D and no.has_method("ponto_acao_fazenda"):
			return no
	return null

## O recurso mais perto do ponto que a ação alcança ({} se não houver)
func alvo(acao: String, ponto_global: Vector2) -> Dictionary:
	var ponto := to_local(ponto_global)
	var melhor: Dictionary = {}
	var distancia := INF
	var candidatos: Array = recursos.duplicate()
	for registro in _entulho.values():
		if ACAO_DO_TIPO.has(registro["recurso"]["tipo"]):
			candidatos.append(registro["recurso"])
	for recurso in candidatos:
		if _caidos.has(recurso["chave"]) or ACAO_DO_TIPO[recurso["tipo"]] != acao:
			continue
		var d: float = ponto.distance_to(recurso["pos"])
		if d <= ALCANCE[recurso["tipo"]] and d < distancia:
			distancia = d
			melhor = recurso
	return melhor

## Por que a ação não dá agora ("" = dá)
func motivo(acao: String, ponto_global: Vector2) -> String:
	if not alvo(acao, ponto_global).is_empty():
		return ""
	return MSG_NADA_CORTAR if acao == "machado" else MSG_NADA_QUEBRAR

## A ferramenta acertou (quadro de impacto da animação)
func impacto(acao: String, ponto_global: Vector2) -> void:
	var recurso := alvo(acao, ponto_global)
	if recurso.is_empty():
		return
	var chave: String = recurso["chave"]
	var tipo: String = recurso["tipo"]
	var no_toco := _tocos.has(chave)
	_vida[chave] = int(_vida.get(chave, VIDA_TOCO if no_toco else VIDA[tipo])) - 1
	_lascas(recurso["pos"] + Vector2(0, -10 if tipo != "pedra" else -4), COR_LASCA[tipo], 6)
	if _vida[chave] > 0:
		Sons.tocar("acerto" if tipo != "pedra" else "bloqueio", 0.1, -4.0)
		if no_toco:
			_balancar_no(_tocos[chave])
		else:
			_balancar(recurso)
		return
	Sons.tocar("escudada" if tipo != "pedra" else "bloqueio", 0.05, -1.0)
	_lascas(recurso["pos"] + Vector2(0, -16 if tipo == "arvore" else -4), COR_LASCA[tipo], 14)
	_vida.erase(chave)
	recurso_extraido.emit.call_deferred(chave, tipo)
	if recurso.has("entulho"):
		_soltar_entulho(recurso)
		return
	# Carvalho: cai e deixa o toco (a colisão continua); o toco, quando sai, libera a passagem
	if tipo == "arvore" and not no_toco:
		Fazenda.remover_recurso(chave, tipo, true)
		_derrubar(recurso, ponto_global)
		_mostrar_toco(recurso)
		return
	if no_toco:
		Fazenda.arrancar_toco(chave)
		var toco: Sprite2D = _tocos[chave]
		_tocos.erase(chave)
		var some := toco.create_tween()
		some.tween_property(toco, "modulate:a", 0.0, 0.35)
		some.tween_callback(toco.queue_free)
		_caidos[chave] = true
		var obstaculo := get_parent().get_node_or_null(recurso["obstaculo"]) as CollisionPolygon2D
		if obstaculo != null:
			obstaculo.set_deferred("disabled", true)
		return
	Fazenda.remover_recurso(chave, tipo)
	_sumir(recurso, true)

## Entulho derrubado: desbota antes de sair. Não volta
func _soltar_entulho(recurso: Dictionary) -> void:
	var celula: Vector2i = recurso["entulho"]
	var registro: Dictionary = _entulho.get(celula, {})
	if registro.has("sprite"):
		var sprite: Sprite2D = registro["sprite"]
		registro.erase("sprite")
		var animacao := sprite.create_tween()
		animacao.tween_property(sprite, "modulate:a", 0.0, 0.35)
		animacao.tween_callback(sprite.queue_free)
	Fazenda.remover_entulho(celula)

## O carvalho tomba: some o desenho inteiro e entra só a parte de cima do corte, que gira até o chão (devagar no começo,
## acelerando), quica de leve, levanta poeira e folhas e o tronco caído desbota
func _derrubar(recurso: Dictionary, ponto_golpe: Vector2) -> void:
	var original := _sprite(recurso) as Sprite2D
	if original == null:
		return
	original.visible = false
	var atlas := original.texture as AtlasTexture
	if atlas == null:
		return
	var regiao := atlas.region
	var copa := AtlasTexture.new()
	copa.atlas = atlas.atlas
	# Só as linhas acima do corte: o desenho começa 'offset.y' px acima da base
	copa.region = Rect2(regiao.position, Vector2(regiao.size.x, -original.offset.y - ALTURA_CORTE))
	var corte: Vector2 = recurso["pos"] - Vector2(0, ALTURA_CORTE)
	var tronco := Sprite2D.new()
	tronco.texture = copa
	tronco.centered = false
	tronco.offset = Vector2(original.offset.x, -copa.region.size.y)
	tronco.position = corte
	tronco.z_as_relative = false
	tronco.z_index = Profundidade.z_de(recurso["pos"].y) + 1
	add_child(tronco)
	var lado := 1.0 if to_local(ponto_golpe).x <= recurso["pos"].x else -1.0
	var queda := tronco.create_tween()
	queda.tween_property(tronco, "rotation", lado * deg_to_rad(8.0), 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	queda.tween_property(tronco, "rotation", lado * deg_to_rad(90.0), DURACAO_QUEDA).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	queda.tween_callback(func(): _impacto_queda(corte + Vector2(lado * 48.0, 6.0), recurso["tipo"]))
	queda.tween_property(tronco, "rotation", lado * deg_to_rad(84.0), 0.09).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	queda.tween_property(tronco, "rotation", lado * deg_to_rad(90.0), 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	queda.tween_interval(0.5)
	queda.tween_property(tronco, "modulate:a", 0.0, 0.5)
	queda.tween_callback(tronco.queue_free)

func _impacto_queda(posicao: Vector2, tipo: String) -> void:
	Sons.tocar("escudada", 0.05, 0.0)
	_lascas(posicao, Color(0.62, 0.55, 0.42), 16)
	_lascas(posicao + Vector2(0, -16), COR_LASCA[tipo], 12)

func _sprite(recurso: Dictionary) -> CanvasItem:
	if not recurso.has("no"):
		return null
	var caminho: NodePath = recurso["no"]
	return get_node_or_null(caminho) if caminho.is_absolute() else get_parent().get_node_or_null(caminho)

func _balancar(recurso: Dictionary) -> void:
	_balancar_no(_sprite(recurso) as Node2D)

func _balancar_no(sprite: Node2D) -> void:
	if sprite == null:
		return
	var origem: Vector2 = sprite.get_meta("posicao_original", sprite.position)
	sprite.set_meta("posicao_original", origem)
	var animacao := sprite.create_tween()
	for desvio in [2.0, -2.0, 1.0, 0.0]:
		animacao.tween_property(sprite, "position:x", origem.x + desvio, 0.04)

## Tira o recurso do mapa: some o desenho (a árvore desbota; a pedra sai da camada) e a colisão
func _sumir(recurso: Dictionary, animado: bool) -> void:
	_caidos[recurso["chave"]] = true
	var obstaculo := get_parent().get_node_or_null(recurso["obstaculo"]) as CollisionPolygon2D
	if obstaculo != null:
		obstaculo.set_deferred("disabled", true)
	if recurso["tipo"] == "pedra":
		var detalhes := get_parent().get_node_or_null("Detalhes") as TileMapLayer
		if detalhes != null:
			detalhes.erase_cell(recurso["celula"])
		return
	var sprite := _sprite(recurso)
	if sprite == null:
		return
	if not animado:
		sprite.visible = false
		return
	var animacao := sprite.create_tween()
	animacao.tween_property(sprite, "modulate:a", 0.0, 0.45)
	animacao.tween_callback(func(): sprite.visible = false)

## Lascas de madeira, folha ou pedra que pulam e caem
func _lascas(posicao: Vector2, cor: Color, quantidade: int) -> void:
	var p := CPUParticles2D.new()
	p.position = posicao
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = quantidade
	p.lifetime = 0.5
	p.direction = Vector2(0, -1)
	p.spread = 70.0
	p.initial_velocity_min = 30.0
	p.initial_velocity_max = 60.0
	p.gravity = Vector2(0, 160)
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	p.color = cor
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)

# --- Marca do alvo (cantos em volta da base, quando a ferramenta ativa é a machadinha ou a picareta) --------

func _process(_delta: float) -> void:
	var novo: Dictionary = {}
	var acao := Fazenda.acao_da_ferramenta()
	var jogador := _jogador()
	if (acao == "machado" or acao == "picareta") and jogador != null and jogador.movimento_habilitado and not jogador.esta_em_acao_fazenda:
		novo = alvo(acao, jogador.ponto_acao_fazenda())
	if novo.get("chave", "") != _alvo.get("chave", ""):
		_alvo = novo
		queue_redraw()

func _draw() -> void:
	if _alvo.is_empty():
		return
	var largura := 20.0 if _alvo["tipo"] == "arvore" or _alvo["tipo"] == "arvoreta" else 14.0
	var centro: Vector2 = _alvo["pos"] + Vector2(0, -6)
	var area := Rect2(centro - Vector2(largura / 2, 7), Vector2(largura, 14))
	var c := 4.0
	for canto: Vector2 in [area.position, Vector2(area.end.x, area.position.y), Vector2(area.position.x, area.end.y), area.end]:
		var sx := 1.0 if canto.x == area.position.x else -1.0
		var sy := 1.0 if canto.y == area.position.y else -1.0
		draw_line(canto, canto + Vector2(c * sx, 0), COR_ALVO, 1.0)
		draw_line(canto, canto + Vector2(0, c * sy), COR_ALVO, 1.0)
