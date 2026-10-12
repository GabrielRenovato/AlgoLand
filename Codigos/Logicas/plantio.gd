extends Node2D

## Plantio na cena da fazenda (filho do terreno, na origem: as coordenadas do nó são as do mapa). Liga o jogador ao
## autoload Fazenda (as regras e os dados moram lá) e desenha o que é do mapa:
##  - o solo arado e molhado (a terra do tileset sazonal, com sulcos, desenhada por cima da terra batida);
##  - as plantas (um Sprite2D por planta, na profundidade do tile);
##  - o cursor do tile que a ferramenta vai acertar;
##  - o clima do dia (sorteado ao dormir) na cena.
##
## Ataque x ferramenta: na fazenda não há armas em uso, então o botão de ataque (e o clique) vira "usar ferramenta":
## o Jogador (modo_fazenda) deixa de atacar e pede a ferramenta aqui (sinal ferramenta_pedida). As armas continuam
## equipadas (a mochila e as estatísticas não mudam) e o dash (rolar) segue valendo. Troca de ferramenta: Q/E e LB/RB.
## A animação só toca se a ação é possível; senão aparece o motivo no aviso da barra de ferramentas.

const Profundidade := preload("res://Codigos/Globais/profundidade.gd")
const EstacoesScript := preload("res://Codigos/Design/estacoes.gd")
const IconesFazenda := preload("res://Codigos/UI/icones_fazenda.gd")

## Acima do chão (camadas do terreno em Z_CHAO) e dos respingos de chuva, abaixo de tudo que tem altura
const Z_SOLO := -997
## Tiles de terra lisa da folha sazonal (coluna 4, linhas 0..4) que servem de base do solo arado
const COLUNA_TERRA := 4
const VARIANTES_TERRA := 5
## Brilho de cada linha de pixels (período de 8): crista clara, plano, sulco escuro
const SULCOS := [1.2, 1.12, 1.0, 0.86, 0.72, 0.84, 1.0, 1.08]
## Multiplicador do solo molhado (mais escuro e levemente azulado)
const COR_MOLHADO := Color(0.58, 0.58, 0.68)
const COR_BORDA := Color(0.1, 0.06, 0.04, 0.5)
## Planta murcha: o verde vira palha seca (quase sem cor, puxada para o marrom) por um shader pequeno nos sprites
const COR_PLANTA_MURCHA := Color(0.92, 0.86, 0.8)
const CODIGO_SECO := """
shader_type canvas_item;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float l = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	vec3 seco = vec3(l * 1.25 + 0.05) * vec3(0.95, 0.72, 0.42);
	COLOR = vec4(mix(c.rgb, seco, 0.88), c.a);
}
"""
const COR_CURSOR_OK := Color(1.0, 0.95, 0.55, 0.95)
const COR_CURSOR_NAO := Color(1.0, 0.5, 0.45, 0.7)

static var _texturas_solo: Dictionary = {}
static var _material_seco: ShaderMaterial = null

var jogador: CharacterBody2D = null

var _plantas: Node2D
var _sprites: Dictionary = {}   # Vector2i -> Sprite2D
var _celula_cursor := Vector2i(-1, -1)
var _cursor_valido := false
var _cursor_visivel := false
var _estacoes: Node

func _ready() -> void:
	z_index = Z_SOLO
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_plantas = Node2D.new()
	_plantas.name = "Plantas"
	_plantas.z_as_relative = false
	_plantas.z_index = 0
	add_child(_plantas)
	_estacoes = get_parent().get_node_or_null("Estacoes")
	if _estacoes != null:
		_estacoes.estacao_mudou.connect(_ao_estacao_visual_mudou)
	Fazenda.solo_alterado.connect(_ao_solo_alterado)
	Fazenda.solo_recarregado.connect(_reconstruir_plantas)
	_reconstruir_plantas()
	_procurar_jogador()

func _procurar_jogador() -> void:
	for no in get_tree().get_nodes_in_group("character"):
		if no is CharacterBody2D and no.has_method("ponto_acao_fazenda"):
			jogador = no
			break
	if jogador == null:
		return
	jogador.modo_fazenda = true
	jogador.ferramenta_pedida.connect(_ao_ferramenta_pedida)
	jogador.acao_fazenda_impacto.connect(_ao_impacto)

# --- Entrada ----------------------------------------------------------------------------------------------

func _unhandled_input(evento: InputEvent) -> void:
	# Com tela aberta ou no meio da animacao nao troca (a acao em andamento usa a ferramenta que a comecou)
	if jogador == null or not jogador.movimento_habilitado or jogador.esta_em_acao_fazenda:
		return
	var passo := 0
	if evento.is_action_pressed("ferramenta_proxima"):
		passo = 1
	elif evento.is_action_pressed("ferramenta_anterior"):
		passo = -1
	if passo == 0:
		return
	Fazenda.trocar_ferramenta(passo)
	Sons.tocar("menu_mover", 0.0, -3.0)
	get_viewport().set_input_as_handled()

## Tile do terreno que a ferramenta acerta (o ponto à frente dos pés do jogador)
func celula_alvo() -> Vector2i:
	return Fazenda.celula_do_ponto(to_local(jogador.ponto_acao_fazenda()))

## O botão de ataque foi apertado: confere se a ação é possível e só então toca a animação
func _ao_ferramenta_pedida() -> void:
	var motivo := _motivo_da_ferramenta(celula_alvo())
	if motivo != "":
		_avisar(motivo)
		Sons.tocar("erro", 0.0, -4.0)
		return
	jogador.acao_fazenda(Fazenda.acao_da_ferramenta())

func _motivo_da_ferramenta(celula: Vector2i) -> String:
	return Fazenda.avaliar(Fazenda.acao_da_ferramenta(), celula, Fazenda.semente_da_ferramenta())

## A ferramenta acertou o chão (quadro de impacto da animação): aplica a ação no tile à frente
func _ao_impacto(acao: String, ponto: Vector2) -> void:
	var celula := Fazenda.celula_do_ponto(to_local(ponto))
	var semente := Fazenda.semente_da_ferramenta()
	var planta_antes := Fazenda.planta_em(celula)
	var era_resto := Fazenda.esta_murcha(celula)
	var motivo := Fazenda.aplicar(acao, celula, semente)
	if motivo != "":
		_avisar(motivo)
		return
	var centro := Vector2(celula) * Fazenda.LADO + Vector2(8, 10)
	match acao:
		"enxada":
			Sons.tocar("enxada", 0.08)
			_efeito_particulas(centro, Color(0.45, 0.3, 0.2) if not era_resto else Color(0.55, 0.45, 0.3))
		"regar":
			Sons.tocar("regar", 0.05)
			_efeito_particulas(centro, Color(0.45, 0.7, 0.95))
		"plantar":
			Sons.tocar("plantar", 0.08)
			_efeito_particulas(centro, Color(0.5, 0.35, 0.22))
			if semente != "" and not Fazenda.da_tempo_de_crescer(semente):
				_avisar(Fazenda.MSG_SEM_TEMPO)
		"colher":
			Sons.tocar("colher", 0.06)
			_efeito_colheita(celula, planta_antes)

# --- Efeitos ----------------------------------------------------------------------------------------------

func _efeito_particulas(posicao: Vector2, cor: Color) -> void:
	var particulas := CPUParticles2D.new()
	particulas.position = posicao
	particulas.z_as_relative = false
	particulas.z_index = Profundidade.Z_TOPO - 20
	particulas.amount = 7
	particulas.lifetime = 0.45
	particulas.one_shot = true
	particulas.explosiveness = 1.0
	particulas.direction = Vector2.UP
	particulas.spread = 65.0
	particulas.initial_velocity_min = 22.0
	particulas.initial_velocity_max = 44.0
	particulas.gravity = Vector2(0, 190)
	particulas.scale_amount_min = 1.2
	particulas.scale_amount_max = 2.2
	particulas.color = cor
	add_child(particulas)
	particulas.emitting = true
	get_tree().create_timer(particulas.lifetime + 0.3).timeout.connect(particulas.queue_free)

# O item colhido sobe da planta e some
func _efeito_colheita(celula: Vector2i, id: String) -> void:
	if id == "":
		return
	var item := Sprite2D.new()
	item.texture = IconesFazenda.item_colhido(id)
	item.z_as_relative = false
	item.z_index = Profundidade.Z_TOPO - 10
	item.position = Vector2(celula) * Fazenda.LADO + Vector2(8, 4)
	add_child(item)
	var tween := item.create_tween().set_parallel()
	tween.tween_property(item, "position:y", item.position.y - 18.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(item, "modulate:a", 0.0, 0.25).set_delay(0.35)
	tween.chain().tween_callback(item.queue_free)

func _avisar(texto: String) -> void:
	get_tree().call_group("hud", "avisar_ferramenta", texto)

# --- Plantas ----------------------------------------------------------------------------------------------

func _reconstruir_plantas() -> void:
	for sprite in _sprites.values():
		sprite.queue_free()
	_sprites.clear()
	for celula in Fazenda.celulas_com_planta():
		_atualizar_planta(celula)
	queue_redraw()

func _ao_solo_alterado(celula: Vector2i) -> void:
	_atualizar_planta(celula)
	queue_redraw()

func _atualizar_planta(celula: Vector2i) -> void:
	var id := Fazenda.planta_em(celula)
	if id == "":
		if _sprites.has(celula):
			_sprites[celula].queue_free()
			_sprites.erase(celula)
		return
	var sprite: Sprite2D = _sprites.get(celula)
	if sprite == null:
		sprite = _novo_sprite_de_planta(celula, id)
		_sprites[celula] = sprite
	sprite.frame = _quadro(id, celula)
	var murcha := Fazenda.esta_murcha(celula)
	sprite.modulate = COR_PLANTA_MURCHA if murcha else Color.WHITE
	sprite.material = _material_da_planta_seca() if murcha else null

static func _material_da_planta_seca() -> ShaderMaterial:
	if _material_seco == null:
		var shader := Shader.new()
		shader.code = CODIGO_SECO
		_material_seco = ShaderMaterial.new()
		_material_seco.shader = shader
	return _material_seco

func _quadro(id: String, celula: Vector2i) -> int:
	return Fazenda.quadro_da_planta(id, Fazenda.dias_crescidos(celula))

func _novo_sprite_de_planta(celula: Vector2i, id: String) -> Sprite2D:
	var dados: Dictionary = Fazenda.PLANTAS[id]
	var sprite := Sprite2D.new()
	sprite.name = "Planta_%d_%d" % [celula.x, celula.y]
	sprite.texture = IconesFazenda.tira(id)
	sprite.hframes = IconesFazenda.quadros_da_tira(id)
	sprite.centered = false
	var altura := 32 if dados["alta"] else 16
	sprite.offset = Vector2(0, -altura)
	# Origem na base do tile: o jogador passa na frente de quem está acima dele e atrás de quem está abaixo
	sprite.position = Vector2(celula.x * Fazenda.LADO, (celula.y + 1) * Fazenda.LADO)
	sprite.z_index = Profundidade.z_de(celula.y * Fazenda.LADO + 10.0)
	_plantas.add_child(sprite)
	return sprite

# --- Estação ----------------------------------------------------------------------------------------------
# O clima do dia (o mesmo da arena) é aplicado pelo próprio clima.gd; aqui só se redesenha o solo na troca de estação

func _ao_estacao_visual_mudou(_indice: int) -> void:
	queue_redraw()

# --- Solo ---------------------------------------------------------------------------------------------------

func _process(_delta: float) -> void:
	_atualizar_cursor()

func _atualizar_cursor() -> void:
	var visivel := false
	var celula := Vector2i(-1, -1)
	var valido := false
	if jogador != null and is_instance_valid(jogador) and jogador.movimento_habilitado and not jogador.esta_em_acao_fazenda:
		celula = celula_alvo()
		visivel = Fazenda.dentro_da_area(celula)
		if visivel:
			valido = _motivo_da_ferramenta(celula) == ""
	if visivel != _cursor_visivel or celula != _celula_cursor or valido != _cursor_valido:
		_cursor_visivel = visivel
		_celula_cursor = celula
		_cursor_valido = valido
		queue_redraw()

func _draw() -> void:
	var estacao: int = _estacoes.estacao_atual if _estacoes != null and _estacoes.estacao_atual >= 0 else Calendario.estacao()
	for celula in Fazenda.solo:
		var origem := Vector2(celula) * Fazenda.LADO
		draw_texture(textura_do_solo(estacao, Fazenda.esta_molhado(celula), celula), origem)
		# borda escura onde o solo arado termina
		for lado in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			if not Fazenda.solo.has(celula + lado):
				_desenhar_borda(origem, lado)
	if _cursor_visivel:
		_desenhar_cursor(Vector2(_celula_cursor) * Fazenda.LADO)

func _desenhar_borda(origem: Vector2, lado: Vector2i) -> void:
	var l := float(Fazenda.LADO)
	match lado:
		Vector2i.UP:
			draw_rect(Rect2(origem, Vector2(l, 1)), COR_BORDA)
		Vector2i.DOWN:
			draw_rect(Rect2(origem + Vector2(0, l - 1), Vector2(l, 1)), COR_BORDA)
		Vector2i.LEFT:
			draw_rect(Rect2(origem, Vector2(1, l)), COR_BORDA)
		Vector2i.RIGHT:
			draw_rect(Rect2(origem + Vector2(l - 1, 0), Vector2(1, l)), COR_BORDA)

# Quatro cantos em "L" no tile alvo
func _desenhar_cursor(origem: Vector2) -> void:
	var cor := COR_CURSOR_OK if _cursor_valido else COR_CURSOR_NAO
	var l := float(Fazenda.LADO)
	var c := 4.0
	for canto: Vector2 in [Vector2(0, 0), Vector2(l, 0), Vector2(0, l), Vector2(l, l)]:
		var sx := 1.0 if canto.x == 0.0 else -1.0
		var sy := 1.0 if canto.y == 0.0 else -1.0
		var ponto: Vector2 = origem + canto
		draw_line(ponto + Vector2(0.5 * sx, 0.5 * sy), ponto + Vector2((c - 0.5) * sx, 0.5 * sy), cor, 1.0)
		draw_line(ponto + Vector2(0.5 * sx, 0.5 * sy), ponto + Vector2(0.5 * sx, (c - 0.5) * sy), cor, 1.0)

## Terra arada: um tile de terra lisa da folha da estação (a variante sai da posição, para não repetir em fileira) com
## sulcos horizontais; molhada, mais escura. Cada combinação é montada uma vez e guardada
static func textura_do_solo(estacao: int, molhado: bool, celula: Vector2i) -> Texture2D:
	var variante := posmod(celula.x * 7 + celula.y * 13, VARIANTES_TERRA)
	var chave := estacao * 1000 + (500 if molhado else 0) + variante
	if _texturas_solo.has(chave):
		return _texturas_solo[chave]
	var folha: Image = EstacoesScript.FOLHAS[estacao].get_image()
	if folha.is_compressed():
		folha.decompress()
	var lado := Fazenda.LADO
	var imagem := Image.create(lado, lado, false, Image.FORMAT_RGBA8)
	for y in lado:
		var brilho: float = SULCOS[y % SULCOS.size()]
		for x in lado:
			var cor := folha.get_pixel(COLUNA_TERRA * lado + x, variante * lado + y)
			cor = Color(clampf(cor.r * brilho, 0.0, 1.0), clampf(cor.g * brilho, 0.0, 1.0), clampf(cor.b * brilho, 0.0, 1.0), 1.0)
			if molhado:
				cor = Color(cor.r * COR_MOLHADO.r, cor.g * COR_MOLHADO.g, cor.b * COR_MOLHADO.b, 1.0)
			imagem.set_pixel(x, y, cor)
	var textura := ImageTexture.create_from_image(imagem)
	_texturas_solo[chave] = textura
	return textura
