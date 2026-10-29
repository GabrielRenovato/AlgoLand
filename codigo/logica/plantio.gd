extends Node2D

## Plantio na cena da fazenda (filho do terreno, na origem: as coordenadas do nó são as do mapa). Liga o jogador ao
## autoload Fazenda (as regras e os dados moram lá) e desenha o que é do mapa:
##  - o solo arado e molhado (canteiros contínuos com contornos arredondados sobre a terra batida);
##  - as plantas (um Sprite2D por planta, na profundidade do tile);
##  - o cursor do tile que a ferramenta vai acertar;
##  - o clima do dia (sorteado ao dormir) na cena.
##
## Ataque x ferramenta: na fazenda não há armas em uso, então o botão de ataque (e o clique) vira "usar ferramenta":
## o Jogador (modo_fazenda) deixa de atacar e pede a ferramenta aqui (sinal ferramenta_pedida). As armas continuam
## equipadas (a mochila e as estatísticas não mudam) e o dash (rolar) segue valendo. As ferramentas e as sementes são itens da
## mochila: a barra de baixo (teclas 1 a 5, toque) escolhe a ativa, e Q/E (LB/RB) passa para a seguinte.
## A animação só toca se a ação é possível; senão aparece o motivo no aviso da barra.

const Profundidade := preload("res://codigo/globais/profundidade.gd")
const IconesFazenda := preload("res://codigo/ui/icones_fazenda.gd")
const LimitePlantio := preload("res://codigo/cenario/limite_plantio.gd")
const SoloArado := preload("res://codigo/cenario/solo_arado.gd")
const Interagivel := preload("res://codigo/logica/interagivel.gd")

## Acima do chão (camadas do terreno em Z_CHAO) e dos respingos de chuva, abaixo de tudo que tem altura
const Z_SOLO := -997
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
const MSG_SEM_FERRAMENTA := "SEM FERRAMENTA NA MOCHILA"
const MSG_SEM_EXTRACAO := "NADA PARA FAZER AQUI"
const COR_CURSOR_OK := Color(1.0, 0.95, 0.55, 0.95)
const COR_CURSOR_NAO := Color(1.0, 0.5, 0.45, 0.7)

static var _material_seco: ShaderMaterial = null
static var _deslocamentos_das_plantas: Dictionary = {}

var jogador: CharacterBody2D = null

var _plantas: Node2D
var _sprites: Dictionary = {}   # Vector2i -> Sprite2D
var _celula_cursor := Vector2i(-1, -1)
var _cursor_valido := false
var _cursor_visivel := false
var _estacoes: Node
## O regador está sendo enchido no lago (o impacto da animação enche em vez de regar)
var _enchendo := false
## Balão de colher: mesma moldura e tecla do aviso da caverna, em cima da planta pronta à frente do jogador
var _aviso_colher: Sprite2D
var _tecla_colher: Button

func _ready() -> void:
	add_to_group("plantio_fazenda")
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
	_montar_aviso_colher()
	_procurar_jogador()

func _procurar_jogador() -> void:
	for no in get_tree().get_nodes_in_group("character"):
		if no is CharacterBody2D and no.get_world_2d() == get_world_2d() and no.has_method("ponto_acao_fazenda"):
			jogador = no
			break
	if jogador == null:
		return
	jogador.modo_fazenda = true
	jogador.ferramenta_pedida.connect(_ao_ferramenta_pedida)
	jogador.acao_fazenda_impacto.connect(_ao_impacto)

## Cooperativo: o jogador 2 também usa as ferramentas (cada um escolhe a sua, da própria mochila). Cada pedido roda com
## `jogador` apontando para quem pediu
var _outros: Array[Node] = []

func ligar_jogador(outro: Node) -> void:
	if outro in _outros or outro == jogador:
		return
	_outros.append(outro)
	outro.modo_fazenda = true
	outro.ferramenta_pedida.connect(func() -> void: _como(outro, _ao_ferramenta_pedida))
	outro.acao_fazenda_impacto.connect(func(acao: String, ponto: Vector2) -> void: _como(outro, _ao_impacto.bind(acao, ponto)))

func _como(quem: Node, funcao: Callable) -> void:
	if quem.get_world_2d() != get_world_2d():
		return
	var antes := jogador
	jogador = quem
	funcao.call()
	jogador = antes

# --- Entrada ----------------------------------------------------------------------------------------------

func _unhandled_input(evento: InputEvent) -> void:
	if Controle.digitando and evento is InputEventKey: return
	if Introducao.acompanhando:
		return
	for outro in _outros:
		if is_instance_valid(outro) and outro.get_world_2d() == get_world_2d() and _entrada_do_outro(outro, evento):
			get_viewport().set_input_as_handled()
			return
	# Com tela aberta ou no meio da animacao nao troca (a acao em andamento usa a ferramenta que a comecou)
	if jogador == null or jogador.get_world_2d() != get_world_2d() or not jogador.movimento_habilitado or jogador.esta_em_acao_fazenda:
		return
	if evento.is_action_pressed("colher") and not evento.is_echo():
		pedir_coleta()
		get_viewport().set_input_as_handled()
		return
	var passo := 0
	if evento.is_action_pressed("ferramenta_proxima"):
		passo = 1
	elif evento.is_action_pressed("ferramenta_anterior"):
		passo = -1
	if passo == 0:
		return
	EventosJogo.inventario_de(jogador).definir_vara_na_mao(false)
	Fazenda.trocar_ferramenta(passo, _lado())
	Sons.tocar("menu_mover", 0.0, -3.0)
	get_viewport().set_input_as_handled()

## Colher e trocar ferramenta no controle do jogador 2. true se usou o evento
func _entrada_do_outro(outro: Node, evento: InputEvent) -> bool:
	if not outro.movimento_habilitado or outro.esta_em_acao_fazenda or evento.is_echo():
		return false
	if evento.is_action_pressed(outro.acao("colher")):
		_como(outro, pedir_coleta)
		return true
	var passo := 1 if evento.is_action_pressed(outro.acao("ferramenta_proxima")) else (-1 if evento.is_action_pressed(outro.acao("ferramenta_anterior")) else 0)
	if passo != 0:
		EventosJogo.inventario_de(outro).definir_vara_na_mao(false)
		Fazenda.trocar_ferramenta(passo, Fazenda.lado_de(outro))
		return true
	return false

## Cooperativo: quem viajou sozinho para a fazenda fica com ela num SubViewport à parte, que não recebe eventos; o próprio
## jogador repassa colher e trocar ferramenta por aqui (Jogador._entrada_fazenda_fora_da_cena)
func entrada_do_jogador(quem: Node, colher: bool, passo: int) -> void:
	if quem.get_world_2d() != get_world_2d() or not quem.movimento_habilitado or quem.esta_em_acao_fazenda:
		return
	if colher:
		_como(quem, pedir_coleta)
	elif passo != 0:
		EventosJogo.inventario_de(quem).definir_vara_na_mao(false)
		Fazenda.trocar_ferramenta(passo, Fazenda.lado_de(quem))
		Sons.tocar("menu_mover", 0.0, -3.0)

## Coleta independente da ferramenta equipada; teclado, controle e botão da interface usam este caminho.
func pedir_coleta() -> void:
	if jogador == null or not jogador.movimento_habilitado or jogador.ataques_bloqueados \
			or jogador.estaMorto or jogador.esta_em_acao_fazenda or jogador.esta_em_dash \
			or jogador.esta_sentado or jogador.esta_forjando or get_viewport().gui_get_focus_owner() != null:
		return
	var motivo := avaliar_terreno("colher", celula_alvo())
	if motivo != "":
		_avisar(motivo)
		Sons.tocar("erro", 0.0, -4.0)
		return
	jogador.acao_fazenda("colher")

## Tile do terreno que a ferramenta acerta (o ponto à frente dos pés do jogador)
func celula_alvo() -> Vector2i:
	return Fazenda.celula_do_ponto(to_local(jogador.ponto_acao_fazenda()))

## O botão de ataque foi apertado: confere se a ação é possível e só então toca a animação
func _ao_ferramenta_pedida() -> void:
	if jogador == null or jogador.get_world_2d() != get_world_2d():
		return
	if EventosJogo.inventario_de(jogador).vara_na_mao:
		_avisar("SEGURE ATAQUE E SOLTE JUNTO AO LAGO")
		return
	if Fazenda.acao_da_ferramenta(_lado()) == "":
		_avisar(MSG_SEM_FERRAMENTA)
		Sons.tocar("erro", 0.0, -4.0)
		return
	_enchendo = false
	# Regador virado para o lago: enche
	if Fazenda.acao_da_ferramenta(_lado()) == "regar" and _lago_a_frente():
		if Fazenda.agua_regador >= Fazenda.regador_capacidade:
			_avisar(Fazenda.MSG_REGADOR_CHEIO)
			return
		_enchendo = true
		jogador.acao_fazenda("encher")
		return
	var motivo := _motivo_da_ferramenta(celula_alvo())
	# Machadinha e picareta não mexem no solo: quem decide é a Extracao (árvores e pedras do mapa)
	if _eh_extracao(Fazenda.acao_da_ferramenta(_lado())):
		var extracao := _extracao()
		motivo = extracao.motivo(Fazenda.acao_da_ferramenta(_lado()), jogador.ponto_acao_fazenda()) if extracao != null else MSG_SEM_EXTRACAO
	if motivo != "":
		_avisar(motivo)
		Sons.tocar("erro", 0.0, -4.0)
		return
	var acao_ferramenta := Fazenda.acao_da_ferramenta(_lado())
	if not Fazenda.gastar_energia(acao_ferramenta, _lado()):
		_avisar(Fazenda.MSG_SEM_ENERGIA)
		Sons.tocar("erro", 0.0, -4.0)
		return
	jogador.acao_fazenda(acao_ferramenta)

## De quem é o pedido em andamento (o `jogador` aponta para quem pediu)
func _lado() -> int:
	return Fazenda.lado_de(jogador)

func _lago_a_frente() -> bool:
	var ponto: Vector2 = jogador.ponto_acao_fazenda()
	for lago in get_tree().get_nodes_in_group("lago_fazenda"):
		if lago.contem(ponto):
			return true
	return false

static func _eh_extracao(acao: String) -> bool:
	return acao == "machado" or acao == "picareta"

func _extracao() -> Node:
	return get_parent().get_node_or_null("Extracao")

func _motivo_da_ferramenta(celula: Vector2i) -> String:
	return avaliar_terreno(Fazenda.acao_da_ferramenta(_lado()), celula, Fazenda.semente_da_ferramenta(_lado()))

## A área lógica inclui os tiles de transição; a enxada só começa um canteiro onde o centro é terra.
## Canteiros e plantas antigos continuam utilizáveis; limpar entulho também permanece permitido.
func avaliar_terreno(acao: String, celula: Vector2i, semente := "") -> String:
	# A floresta usa o mesmo Plantio só para as ferramentas de corte, o regador e o lago: sem solo para arar
	if bool(get_parent().get_meta("sem_plantio", false)) and acao != "regar":
		return Fazenda.MSG_FORA
	var motivo := Fazenda.avaliar(acao, celula, semente, _lado())
	if motivo != "" or acao != "enxada" or Fazenda.esta_arado(celula) or Fazenda.entulho.has(celula):
		return motivo
	var terra := get_parent().get_node_or_null("Terra") as TileMapLayer
	if terra == null or terra.get_cell_source_id(celula) < 0:
		return Fazenda.MSG_FORA
	if not LimitePlantio.cobre_pixel(_estacao_visual(), _atlas_da_terra(terra, celula), 8, 8):
		return Fazenda.MSG_FORA
	return ""

func _atlas_da_terra(terra: TileMapLayer, celula: Vector2i) -> Vector2i:
	if _estacoes != null and _estacoes._terra_continua._fonte != null:
		return _estacoes._terra_continua.atlas_original(celula)
	return terra.get_cell_atlas_coords(celula)

func _estacao_visual() -> int:
	return _estacoes.estacao_atual if _estacoes != null and _estacoes.estacao_atual >= 0 else Calendario.estacao()

## A ferramenta acertou o chão (quadro de impacto da animação): aplica a ação no tile à frente
func _ao_impacto(acao: String, ponto: Vector2) -> void:
	if jogador == null or jogador.get_world_2d() != get_world_2d():
		return
	if acao == "encher" and _enchendo:
		_enchendo = false
		Fazenda.encher_regador()
		Sons.tocar("regar", 0.05)
		_efeito_particulas(to_local(ponto), Color(0.55, 0.8, 1.0))
		_avisar("REGADOR CHEIO (%d)" % Fazenda.regador_capacidade)
		return
	if _eh_extracao(acao):
		if _extracao() != null:
			# Sem alvo no alcance o golpe não faz nada: avisa o motivo em vez de falhar em silêncio
			if _extracao().alvo(acao, ponto).is_empty():
				_avisar(_extracao().motivo(acao, ponto))
				return
			_extracao().impacto(acao, ponto, preload("res://codigo/dados/melhorias_ferramentas.gd").nivel(Fazenda.mochila_do_lado(_lado()),"machadinha" if acao=="machado" else "picareta"),jogador.global_position)
		return
	var celula := Fazenda.celula_do_ponto(to_local(ponto))
	var grau: int=preload("res://codigo/dados/melhorias_ferramentas.gd").nivel(Fazenda.mochila_do_lado(_lado()),"enxada" if acao=="enxada" else "regador") if acao in ["enxada","regar"] else 1
	var semente := Fazenda.semente_da_ferramenta(_lado())
	var planta_antes := Fazenda.planta_em(celula)
	var era_resto := Fazenda.esta_murcha(celula)
	var motivo := avaliar_terreno(acao, celula, semente)
	if motivo == "":
		motivo = Fazenda.aplicar(acao, celula, semente, _lado())
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
	if grau>1:
		var lateral := Vector2i(1,0) if absf(jogador._direcao_ataque.y)>=absf(jogador._direcao_ataque.x) else Vector2i(0,1)
		for i in range(-1,2):
			for j in range(-1 if grau==3 else 0,2 if grau==3 else 1):
				var extra := celula+lateral*i+Vector2i(-lateral.y,lateral.x)*j
				if extra==celula: continue
				if avaliar_terreno(acao,extra)=="": Fazenda.aplicar(acao,extra,"",_lado())

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
	get_tree().call_group(jogador.grupo_hud() if jogador != null else "hud_p1", "avisar_ferramenta", texto)

# --- Plantas ----------------------------------------------------------------------------------------------

## Mapas sem horta (a floresta) reaproveitam este nó só para as ferramentas de corte e o regador: o solo arado e as
## plantas do save são das células da fazenda e não podem aparecer em outro mapa
func _sem_horta() -> bool:
	return bool(get_parent().get_meta("sem_plantio", false))

func _reconstruir_plantas() -> void:
	for sprite in _sprites.values():
		sprite.queue_free()
	_sprites.clear()
	if _sem_horta():
		queue_redraw()
		return
	for celula in Fazenda.celulas_com_planta():
		_atualizar_planta(celula)
	queue_redraw()

func _ao_solo_alterado(celula: Vector2i) -> void:
	if _sem_horta():
		return
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
	sprite.offset = deslocamento_da_planta(id, sprite.frame)
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

## Centraliza a arte visível, descontando as margens transparentes de cada estágio.
## Quadros maiores que o tile crescem para cima, mantendo a base dentro do canteiro.
static func deslocamento_da_planta(id: String, quadro: int) -> Vector2:
	var chave := "%s:%d" % [id, quadro]
	if not _deslocamentos_das_plantas.has(chave):
		var imagem := IconesFazenda.tira(id).get_image()
		var area := imagem.get_region(Rect2i(quadro * IconesFazenda.LADO, 0, IconesFazenda.LADO, imagem.get_height())).get_used_rect()
		var centro := Vector2(IconesFazenda.LADO * 0.5, -IconesFazenda.LADO * 0.5)
		centro.y -= maxf(0.0, area.size.y - IconesFazenda.LADO) * 0.5
		_deslocamentos_das_plantas[chave] = (centro - Vector2(area.position) - Vector2(area.size) * 0.5).round()
	return _deslocamentos_das_plantas[chave]

func _novo_sprite_de_planta(celula: Vector2i, id: String) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = "Planta_%d_%d" % [celula.x, celula.y]
	sprite.texture = IconesFazenda.tira(id)
	sprite.hframes = IconesFazenda.quadros_da_tira(id)
	sprite.centered = false
	# Origem na base do tile: o jogador passa na frente de quem está acima dele e atrás de quem está abaixo
	sprite.position = Vector2(celula.x * Fazenda.LADO, (celula.y + 1) * Fazenda.LADO)
	sprite.z_index = Profundidade.z_de(celula.y * Fazenda.LADO + 10.0)
	_plantas.add_child(sprite)
	return sprite

func _montar_aviso_colher() -> void:
	_aviso_colher = Sprite2D.new()
	_aviso_colher.name = "AvisoColher"
	_aviso_colher.texture = Interagivel.TEXTURA_AVISO
	_aviso_colher.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_aviso_colher.z_as_relative = false
	_aviso_colher.z_index = 900
	_aviso_colher.scale = Vector2(0.538463, 0.519231)
	_aviso_colher.visible = false
	add_child(_aviso_colher)
	_tecla_colher = Button.new()
	_tecla_colher.flat = true
	_tecla_colher.focus_mode = Control.FOCUS_NONE
	_tecla_colher.position = Vector2(-15.1428, -15.7037)
	_tecla_colher.size = Vector2(32, 31)
	_tecla_colher.add_theme_font_override("font", Interagivel.FONTE_AVISO)
	Interagivel.aplicar_cores_aviso(_tecla_colher)
	_tecla_colher.pressed.connect(pedir_coleta)
	_aviso_colher.add_child(_tecla_colher)
	Interagivel.aplicar_circulo_aviso(_aviso_colher,_tecla_colher)
	Controle.dicas_alteradas.connect(_atualizar_tecla_colher)
	_atualizar_tecla_colher()

func _atualizar_tecla_colher() -> void:
	_tecla_colher.text = Controle.rotulo_acao("colher")
	_tecla_colher.add_theme_font_size_override("font_size", 9 if _tecla_colher.text.length() <= 2 else 6)
	_tecla_colher.size = Vector2(18,18)

## Mostra o balão só quando dá para colher a planta do tile à frente; fica logo acima da arte da planta.
func _atualizar_aviso_colher() -> void:
	var pronta := false
	var celula := Vector2i.ZERO
	if jogador != null and is_instance_valid(jogador) and jogador.movimento_habilitado and not jogador.esta_em_acao_fazenda \
			and not Introducao.acompanhando:
		celula = celula_alvo()
		pronta = _sprites.has(celula) and avaliar_terreno("colher", celula) == ""
	_aviso_colher.visible = pronta
	if pronta:
		var sprite: Sprite2D = _sprites[celula]
		var altura := maxf(Fazenda.LADO, sprite.texture.get_height())
		_aviso_colher.position = sprite.position + Vector2(Fazenda.LADO * 0.5, -altura - 10.0)

# --- Estação ----------------------------------------------------------------------------------------------
# O clima do dia (o mesmo da arena) é aplicado pelo próprio clima.gd; aqui só se redesenha o solo na troca de estação

func _ao_estacao_visual_mudou(_indice: int) -> void:
	queue_redraw()

# --- Solo ---------------------------------------------------------------------------------------------------

func _process(_delta: float) -> void:
	_atualizar_cursor()
	_atualizar_aviso_colher()

func _atualizar_cursor() -> void:
	var visivel := false
	var celula := Vector2i(-1, -1)
	var valido := false
	if jogador != null and is_instance_valid(jogador) and jogador.movimento_habilitado and not jogador.esta_em_acao_fazenda:
		celula = celula_alvo()
		visivel = Fazenda.dentro_da_area(celula) and not _eh_extracao(Fazenda.acao_da_ferramenta(_lado()))
		# O teste de espada no F3 não usa a ferramenta nem seu marcador de solo.
		var cartoon := jogador.get_node_or_null("HeroiCartoon") as CanvasItem
		if cartoon != null and cartoon.visible:
			visivel = false
		var base_3d := jogador.get_node_or_null("HeroiBase3D") as CanvasItem
		if base_3d != null and base_3d.visible and base_3d.demonstrar_combate_na_fazenda:
			visivel = false
		if visivel:
			valido = _motivo_da_ferramenta(celula) == ""
	if visivel != _cursor_visivel or celula != _celula_cursor or valido != _cursor_valido:
		_cursor_visivel = visivel
		_celula_cursor = celula
		_cursor_valido = valido
		queue_redraw()

func _draw() -> void:
	var estacao := _estacao_visual()
	var terra := get_parent().get_node_or_null("Terra") as TileMapLayer
	var celulas_arado: Dictionary = {} if _sem_horta() else Fazenda.solo
	for celula in celulas_arado:
		if terra == null or terra.get_cell_source_id(celula) < 0:
			continue
		var atlas := _atlas_da_terra(terra, celula)
		var origem := Vector2(celula) * Fazenda.LADO
		var molhado := Fazenda.esta_molhado(celula)
		var ligacoes := SoloArado.vizinhos(Fazenda.solo, celula)
		var regadas := SoloArado.vizinhos(Fazenda.solo, celula, true) if molhado else 0
		var tiny := bool(get_parent().get_meta("visual_tiny", false))
		if not tiny and get_parent().has_node("NaturezaFazenda"):
			draw_texture_rect(SoloArado.textura_detalhada(estacao,molhado,celula,ligacoes,regadas,atlas),Rect2(origem,Vector2(16,16)),false)
		else:
			draw_texture(SoloArado.textura(estacao, molhado, celula, ligacoes, regadas, atlas, tiny), origem)
	if _cursor_visivel:
		_desenhar_cursor(Vector2(_celula_cursor) * Fazenda.LADO)

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

## As conexões entram no cache: arar ou regar um vizinho atualiza também o encaixe deste tile.
static func textura_do_solo(estacao: int, molhado: bool, celula: Vector2i, ligacoes := 0, regadas := 0, atlas := Vector2i(-1, -1)) -> Texture2D:
	return SoloArado.textura(estacao, molhado, celula, ligacoes, regadas, atlas)
