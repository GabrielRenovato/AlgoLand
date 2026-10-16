extends CharacterBody2D

const Clima := preload("res://codigo/cenario/clima.gd")
const Dados := preload("res://codigo/cidade/dados_cidade.gd")
const Profundidade := preload("res://codigo/globais/profundidade.gd")
const Interacao := preload("res://codigo/cidade/interacao_morador.gd")
const SombraCidade := preload("res://codigo/cidade/sombra_cidade.gd")
const Trajeto := preload("res://codigo/cidade/trajeto_morador.gd")
const Conversa := preload("res://codigo/cidade/conversa_moradores.gd")
const FONTE := preload("res://assets/ui/Planes_ValMore.ttf")
## Balão de fala: aparece quando o jogador passa perto, com intervalo por morador e entre moradores
const DISTANCIA_BALAO := 56.0
const INTERVALO_BALAO := 45.0
const INTERVALO_ENTRE_BALOES := 6.0
const DURACAO_BALAO := 3.5
static var _proximo_balao_global := 0.0
var id := ""
var vila: Node2D
var agenda: Dictionary = {}
var sprite: Sprite2D
var usando_capa_chuva := false
var interacao: Area2D
var caminho := PackedVector2Array()
var _alvo := Vector2.ZERO
var _saindo := false
var _tempo := 0.0
var _linha := 0
var _espera_rota := 0.0
## O jogador parado no caminho: o morador espera um pouco e depois passa por ele (sem colisão até se afastarem).
## Antes o morador não enxergava o jogador e o empurrava à frente dele ("arrastava")
const TEMPO_ESPERA_JOGADOR := 0.7
const DISTANCIA_SOLTAR_JOGADOR := 18.0
const CAMADA_JOGADOR := 2
var _esperando_jogador := 0.0
var _atravessando: Array[Node] = []
var _balao: Label
var _espera_balao := 3.0
var _animacao_balao: Tween
var assento := preload("res://codigo/cidade/assento_morador.gd").new()
var passeando_taverna := false
var atendendo_mesas := false
## Na festa de sábado o Caio serve as mesas com pressa (pedido de 2026-10-16): anda e anima mais rápido
const RITMO_FESTA := 2.2
var parceiro_papo: Node2D
var passeio := preload("res://codigo/cidade/passeio_morador.gd").new()
var _agenda_base: Dictionary = {}
## Folha: coluna 0 parado, colunas 1 em diante andando (uma linha por direção)
var _colunas := 7
var _quadros_andar := 6
## Dormindo na cama: só a cabeça aparece no travesseiro (o corpo fica sob o cobertor) e uns "z" sobem devagar
var dormindo := false
var _cabeca: Sprite2D
var _zzz: Label
var _pe_da_cama := Vector2.ZERO
## O que fica escondido enquanto dorme (o corpo e a sombra de contato)
var _escondidos: Array[CanvasItem] = []

func _ready() -> void:
	add_to_group("moradores_cidade")
	collision_layer = 32
	collision_mask = 64 | CAMADA_JOGADOR
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var dados: Dictionary = Dados.MORADORES[id]
	sprite = Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = load(Dados.caminho_sprite(id))
	var geometria := Dados.geometria_sprite(id)
	_colunas = int(geometria["grade"][0])
	_quadros_andar = int(geometria["quadros_andar"])
	sprite.hframes = _colunas
	sprite.vframes = int(geometria["grade"][1])
	var escala: float = geometria["escala_mapa"]
	sprite.scale = Vector2.ONE * escala
	# Aumenta só o desenho; a base visível continua alinhada à colisão dos pés.
	sprite.position.y = 9 - (float(geometria["pes_y"]) - 32) * escala
	sprite.modulate = dados["cor"]
	add_child(sprite)
	SombraCidade.contato(self, 17.0, 3.0, Vector2(0, 10))
	var forma := CollisionShape2D.new()
	forma.name = "CollisionShape2D"
	var capsula := CapsuleShape2D.new()
	capsula.radius = 5
	capsula.height = 12
	forma.shape = capsula
	forma.position.y = 9
	add_child(forma)
	_montar_balao()
	interacao = Interacao.new()
	interacao.id = id
	var zona := CollisionShape2D.new()
	var circulo := CircleShape2D.new()
	circulo.radius = 30
	zona.shape = circulo
	interacao.add_child(zona)
	add_child(interacao)
	visible = false
	atualizar_rotina(true)

func atualizar_rotina(inicial := false) -> void:
	var clima: int = vila.clima_atual()
	# Atualiza mesmo quando a agenda é igual: começar/parar de chover só troca o traje.
	_atualizar_visual_chuva(clima)
	var nova := Dados.agenda(id, vila.hora_atual(), Calendario.estacao(), clima, Calendario.dia_da_semana())
	if nova == _agenda_base:
		return
	if is_instance_valid(parceiro_papo):
		vila._encerrar_papo()
	_agenda_base = nova.duplicate(true)
	passeio.reiniciar()
	var anterior := agenda
	agenda = nova
	if dormindo and not agenda.get("dormindo", false):
		_acordar()
	if inicial:
		visible = agenda["local"] == vila.local and not Trajeto.aguardar(self)
		position = agenda["ponto"] if visible else Vector2.ZERO
		if visible and agenda.get("festa", false):
			visible = not Trajeto.aguardar(self)
			position = vila.porta_do_local("cidade")
			_ir_ate(agenda["ponto"])
		elif vila.local == "cidade" and agenda.get("festa", false):
			Trajeto.iniciar_rua(self, Dados.MORADORES[id]["casa"])
		_alvo = caminho[-1] if not caminho.is_empty() else position
		if visible and agenda.get("dormindo", false):
			_deitar()
	elif agenda["local"] == vila.local:
		Trajeto.preparar_chegada(self, str(anterior.get("local", "")))
		if not visible and Trajeto.aguardar(self):
			return
		if not visible:
			position = vila.porta_do_local(str(anterior.get("local", Dados.MORADORES[id]["casa"])))
		visible = true
		_saindo = false
		_ir_ate(agenda["ponto"])
	elif visible:
		_saindo = true
		_ir_ate(vila.porta_do_local(agenda["local"]))
		Trajeto.registrar(self)
	elif vila.local == "cidade" and str(anterior.get("local", "")) != str(agenda["local"]):
		Trajeto.iniciar_rua(self, str(anterior.get("local", Dados.MORADORES[id]["casa"])))
	_atualizar_colisao()

## As capas têm os mesmos 28 quadros, célula e pivô das roupas normais.
func _atualizar_visual_chuva(clima: int) -> void:
	var usar: bool = vila.local == "cidade" and Clima.eh_chuva(clima)
	if usar == usando_capa_chuva:
		return
	usando_capa_chuva = usar
	var quadro := sprite.frame
	var geometria := Dados.geometria_sprite(id)
	sprite.texture = load(geometria["folha_chuva"] if usar else Dados.caminho_sprite(id))
	sprite.frame = quadro

func _montar_balao() -> void:
	_balao = Label.new()
	_balao.name = "Balao"
	_balao.add_theme_font_override("font", FONTE)
	_balao.add_theme_font_size_override("font_size", 8)
	_balao.add_theme_color_override("font_color", Color("fff3d6"))
	_balao.add_theme_color_override("font_outline_color", Color("2a2230"))
	_balao.add_theme_constant_override("outline_size", 3)
	_balao.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_balao.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_balao.size = Vector2(164, 0)
	_balao.resized.connect(func(): _balao.position = Vector2(-82, -34 - _balao.size.y))
	var fundo := StyleBoxFlat.new()
	fundo.bg_color = Color(0.10, 0.09, 0.14, 0.94)
	fundo.set_content_margin_all(3)
	_balao.add_theme_stylebox_override("normal", fundo)
	_balao.position = Vector2(-80, -34)
	_balao.z_as_relative = false
	_balao.z_index = 899
	_balao.visible = false
	add_child(_balao)

## Frase curta sobre a cabeça quando o jogador passa perto (fora de conversa)
func _talvez_falar(delta: float, distancia: float, conversando: bool) -> void:
	_espera_balao -= delta
	var agora := Time.get_ticks_msec() / 1000.0
	if conversando:
		calar()
		return
	if not vila._participantes.is_empty() or _balao.visible or _espera_balao > 0 or distancia > DISTANCIA_BALAO or agora < _proximo_balao_global:
		return
	var texto := Conversa.balao(id, Conversa.contexto(id, get_tree()))
	if texto == "":
		return
	_proximo_balao_global = agora + INTERVALO_ENTRE_BALOES
	dizer(texto)

## Um único balão por ambiente, inclusive quando dois vizinhos estão lado a lado.
func dizer(texto: String, duracao := DURACAO_BALAO) -> void:
	if dormindo:
		return
	for npc in vila.moradores.values():
		npc.calar()
	_espera_balao = INTERVALO_BALAO
	_proximo_balao_global = Time.get_ticks_msec() / 1000.0 + duracao + 0.5
	_balao.text = texto
	_balao.size = Vector2(164, 0)
	_balao.position = Vector2(-82, -34 - _balao.size.y)
	_balao.modulate.a = 0.0
	_balao.visible = true
	_animacao_balao = create_tween()
	_animacao_balao.tween_property(_balao, "modulate:a", 1.0, 0.15)
	_animacao_balao.tween_interval(duracao)
	_animacao_balao.tween_property(_balao, "modulate:a", 0.0, 0.2)
	_animacao_balao.tween_callback(func(): _balao.visible = false)

func calar() -> void:
	if _animacao_balao != null and _animacao_balao.is_valid():
		_animacao_balao.kill()
	_balao.visible = false

func pode_continuar_papo() -> bool:
	return visible and not dormindo and not _saindo and not interacao._tela_aberta and Cidade.interlocutor != id

## Pode parar durante um passeio; o trajeto continua depois da despedida.
func livre_para_papo() -> bool:
	return pode_continuar_papo() and not atendendo_mesas and not is_instance_valid(parceiro_papo) and not _balao.visible and (caminho.is_empty() or agenda.get("livre", false))

func olhar_para(ponto: Vector2) -> void:
	if assento.ocupado():
		return
	_linha = _direcao(ponto - position)
	sprite.frame = _linha * _colunas

func _atualizar_colisao() -> void:
	collision_layer = 32 if visible else 0
	interacao.set_deferred("monitoring", visible)

func _ir_ate(ponto: Vector2) -> void:
	_alvo = ponto
	caminho = vila.caminho_entre(position, ponto)

func _physics_process(delta: float) -> void:
	Trajeto.sincronizar(self)
	if not visible:
		return
	_tempo += delta
	if dormindo:
		_animar_sono()
		return
	_espera_rota -= delta
	if not _atravessando.is_empty():
		_soltar_atravessados()
	var jogador: Node2D = Cooperativo.jogador_no_ambiente(self)
	var distancia := global_position.distance_to(jogador.global_position) if jogador != null else INF
	# Sentar perto da mesa não inicia conversa nem interrompe o atendimento.
	var perto: bool = distancia < 34 and not jogador.esta_sentado and not atendendo_mesas
	# Parado durante a conversa e também nos serviços abertos por ela (loja, poções, pedidos): enquanto o jogador está numa tela
	var conversando: bool = jogador != null and Cidade.interlocutor == id and (interacao._tela_aberta or (not jogador.movimento_habilitado and not jogador.esta_sentado))
	# Todas as telas fecharam: a conversa acabou (senão a próxima mochila aberta prenderia este morador)
	if Cidade.interlocutor == id and not conversando:
		Cidade.interlocutor = ""
	if assento.atualizar(self, delta):
		_talvez_falar(delta, distancia, conversando)
		return
	if is_instance_valid(parceiro_papo) and not conversando and not _saindo:
		olhar_para(parceiro_papo.position)
		return
	_talvez_falar(delta, distancia, conversando or _saindo)
	if not perto and not conversando:
		passeio.atualizar(self, delta)
	var andando := false
	if (perto and not _saindo) or conversando:
		_linha = _direcao(jogador.position - position)
	elif not caminho.is_empty():
		var diferenca := caminho[0] - position
		if diferenca.length() <= 1.0:
			caminho.remove_at(0)
		else:
			andando = true
			_linha = _direcao(diferenca)
			var colisao := move_and_collide(diferenca.normalized() * minf((passeio.velocidade if agenda.get("livre", false) else 26.0 * ritmo()) * delta, diferenca.length()))
			if colisao != null and colisao.get_collider() is Node and (colisao.get_collider() as Node).is_in_group("jogadores"):
				_jogador_no_caminho(colisao.get_collider(), delta)
				andando = false
			elif colisao == null:
				_esperando_jogador = 0.0
			elif _espera_rota <= 0:
				_ir_ate(_alvo)
				_espera_rota = 1.0
	elif _saindo:
		Trajeto.concluir(self)
		visible = false
		_saindo = false
		_atualizar_colisao()
	elif agenda.get("dormindo", false) and not conversando:
		_deitar()
		return
	z_index = Profundidade.z_de(position.y + 9)
	sprite.frame = _linha * _colunas + (1 + int(_tempo * 8 * ritmo()) % _quadros_andar if andando else 0)

## Mais rápido só servindo as mesas na festa
func ritmo() -> float:
	return RITMO_FESTA if atendendo_mesas and agenda.get("festa", false) else 1.0

func _jogador_no_caminho(jogador: Node, delta: float) -> void:
	_esperando_jogador += delta
	if _esperando_jogador < TEMPO_ESPERA_JOGADOR:
		return
	_esperando_jogador = 0.0
	if not jogador in _atravessando:
		_atravessando.append(jogador)
		add_collision_exception_with(jogador)
		jogador.add_collision_exception_with(self)

## Quem o morador atravessou volta a colidir quando os dois se afastam
func _soltar_atravessados() -> void:
	for i in range(_atravessando.size() - 1, -1, -1):
		var jogador: Node = _atravessando[i]
		if is_instance_valid(jogador) and jogador.is_inside_tree() and visible and jogador.get_world_2d() == get_world_2d() \
				and global_position.distance_to(jogador.global_position) < DISTANCIA_SOLTAR_JOGADOR:
			continue
		if is_instance_valid(jogador):
			remove_collision_exception_with(jogador)
			jogador.remove_collision_exception_with(self)
		_atravessando.remove_at(i)

# --- Sono ---------------------------------------------------------------------------------------------------------

## Chegou ao pé da cama: deita. A cabeça (recorte do topo do quadro de frente) vai para o travesseiro, por cima da cama
func _deitar() -> void:
	if dormindo or not agenda.has("cama"):
		return
	dormindo = true
	caminho.clear()
	_balao.visible = false
	var base: Vector2 = agenda["cama"]
	var altura: float = agenda["altura_cama"]
	_pe_da_cama = base + Vector2(0, 12)
	position = base + Vector2(0, -altura + 4)
	_escondidos.clear()
	for filho in get_children():
		if filho is CanvasItem and filho != _cabeca and filho != _zzz and filho != _balao and filho.visible:
			filho.visible = false
			_escondidos.append(filho)
	if _cabeca == null:
		_cabeca = Sprite2D.new()
		_cabeca.name = "Cabeca"
		_cabeca.texture = _recorte_da_cabeca()
		_cabeca.scale = sprite.scale
		_cabeca.z_as_relative = false
		add_child(_cabeca)
		_zzz = Label.new()
		_zzz.name = "Zzz"
		_zzz.text = "z"
		_zzz.add_theme_font_override("font", FONTE)
		_zzz.add_theme_font_size_override("font_size", 8)
		_zzz.add_theme_color_override("font_color", Color("e8f0ff"))
		_zzz.add_theme_color_override("font_outline_color", Color("2a2230"))
		_zzz.add_theme_constant_override("outline_size", 3)
		_zzz.z_as_relative = false
		_zzz.z_index = 899
		add_child(_zzz)
	_cabeca.visible = true
	_zzz.visible = true
	# Por cima da cama (que ordena pela base dela)
	_cabeca.z_index = Profundidade.z_de(base.y) + 1
	collision_layer = 0
	interacao.set_deferred("monitoring", false)

func _acordar() -> void:
	dormindo = false
	for filho in _escondidos:
		if is_instance_valid(filho):
			filho.visible = true
	_escondidos.clear()
	if _cabeca != null:
		_cabeca.visible = false
		_zzz.visible = false
	# Levanta no pé da cama
	position = _pe_da_cama
	_atualizar_colisao()

## Respira devagar (a cabeça sobe e desce um pixel) e os "z" sobem e somem em ciclo
func _animar_sono() -> void:
	_cabeca.position.y = -1.0 if fmod(_tempo, 2.4) < 1.2 else 0.0
	var ciclo := fmod(_tempo, 2.0) / 2.0
	_zzz.text = "z" if ciclo < 0.33 else ("zZ" if ciclo < 0.66 else "zZz")
	_zzz.position = Vector2(4, -16 - ciclo * 8)
	_zzz.modulate.a = 1.0 - ciclo * 0.6
	z_index = Profundidade.z_de(position.y)

## Topo do primeiro quadro (de frente, parado): os 14 px de cima da arte, onde fica a cabeça
func _recorte_da_cabeca() -> Texture2D:
	var folha: Texture2D = sprite.texture
	var celula := Vector2i(folha.get_width() / sprite.hframes, folha.get_height() / sprite.vframes)
	var imagem := folha.get_image().get_region(Rect2i(Vector2i.ZERO, celula))
	var usado := imagem.get_used_rect()
	var recorte := AtlasTexture.new()
	recorte.atlas = folha
	recorte.region = Rect2(usado.position.x, usado.position.y, usado.size.x, mini(14, usado.size.y))
	return recorte

func _direcao(vetor: Vector2) -> int:
	if absf(vetor.x) > absf(vetor.y):
		return 1 if vetor.x > 0 else 3
	return 0 if vetor.y >= 0 else 2
