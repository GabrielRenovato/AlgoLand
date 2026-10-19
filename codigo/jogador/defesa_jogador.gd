extends Node

## Aparar e escudada do jogador (poses da página 1 dos pacotes de combate e o "shield bash" da página 3 do pacote de espada e escudo).
##
## APARAR: segurar o botão (botão direito do mouse, Ctrl, LT) põe o jogador em guarda, parado (só vira, andando as setas), na pose
## de aparar da arma que ele empunha (espada, lança ou arco). Gasta estamina para entrar e um pouco por segundo; para de gastar
## ao soltar. Um golpe que vem de frente:
##   - nos primeiros JANELA_PERFEITA segundos é APARO PERFEITO: sem dano, empurra e atordoa quem está na frente, devolve estamina e
##     ainda dá uma invulnerabilidade curta;
##   - depois disso é BLOQUEIO: leva só uma fração do dano e do empurrão, e o golpe custa estamina; sem estamina para segurá-lo a
##     guarda quebra e o dano entra inteiro;
##   - pelas costas ou pelo lado, a guarda não vale.
## ESCUDADA: com espada e escudo, o aparo perfeito vira contra-ataque: um empurrão com o escudo, mais forte que um golpe da
## espada e que atordoa. Não tem botão próprio.
## A escudada usa os mesmos nós da animação de ataque da espada (Jogador.corpo_espada_escudo_ataque etc.), com os quadros do
## "shield bash" (linhas 4 a 7 e colunas 4 a 7 da folha), na ordem de camadas do guia do pacote.
## Quem chama: jogador.gd (_physics_process escolhe entre atualizar() e andar; receber_dano pergunta resolver()).

const EfeitosLuz := preload("res://codigo/efeitos/efeitos_luz.gd")
const ArcoJogador := preload("res://codigo/jogador/arco_jogador.gd")
const Profundidade := preload("res://codigo/globais/profundidade.gd")
const FONTE := preload("res://assets/ui/Planes_ValMore.ttf")

enum Estado { LIVRE, GUARDA, CONTRA, ESCUDADA }

# --- Aparar
const CUSTO_INICIAL := 8.0
const CONSUMO_POR_SEGUNDO := 6.0
const JANELA_PERFEITA := 0.25
const REDUCAO_BLOQUEIO := 0.65
const KNOCKBACK_BLOQUEIO := 0.3
## Estamina que segurar um golpe custa, por ponto de dano
const STAMINA_POR_DANO := 0.6
## Cosseno do ângulo (a partir de para onde a guarda aponta) que ainda protege: 0,3 = uns 72 graus para cada lado
const COSSENO_FRONTAL := 0.3
const RECARGA_AO_SOLTAR := 0.3
const RECARGA_GUARDA_QUEBRADA := 1.2
const REEMBOLSO_PERFEITO := 15.0
const INVULNERAVEL_APARO := 0.4
# --- Empurrão do aparo perfeito
const ALCANCE_REPELIR := 48.0
const FORCA_REPELIR := 320.0
const ATORDOAR_APARO := 1.0
# --- Escudada
## Parada com a pose de aparar antes do contra-ataque (o "tum" do aparo ser sentido)
const PAUSA_ANTES_DA_ESCUDADA := 0.12
## Quadros do shield bash: [coluna, duração em s]; as linhas 4 a 7 são baixo, cima, direita, esquerda
const QUADROS_ESCUDADA: Array = [[4, 0.14], [5, 0.07], [6, 0.09], [7, 0.2]]
const LINHA_BASE_ESCUDADA := 4
const QUADRO_IMPACTO_ESCUDADA := 1
const MULT_DANO_ESCUDADA := 1.5
const MULT_EMPURRAO_ESCUDADA := 1.8
const ATORDOAR_ESCUDADA := 1.8
const ALCANCE_ESCUDADA := 38.0
const COSSENO_ESCUDADA := 0.2
# Camadas do guia "layer order, page ONE-hand 3": z do nó ao ficar na frente ou atrás do corpo (z 1), por linha da folha (baixo, cima,
# direita, esquerda) e coluna do bloco (4..7). F = frente, B = atrás
const Z_FRENTE := 4
const Z_ATRAS := 0
const ORDEM_ESPADA := ["BBBB", "BBBB", "FFFF", "FFFF"]
const ORDEM_ESCUDO := ["FFBB", "BFFF", "FBFF", "FBFF"]

var estado: Estado = Estado.LIVRE
## Para onde a guarda aponta (vetor cardinal)
var direcao_guarda: Vector2 = Vector2.DOWN

var jogador: CharacterBody2D = null

var _inicio_guarda_ms := 0
var _livre_ate_ms := 0
var _pausa := 0.0
var _indice := 0
var _tempo := 0.0
var _impacto_feito := false
var _linha := 0

func em_guarda() -> bool:
	return estado == Estado.GUARDA or estado == Estado.CONTRA

func escudando() -> bool:
	return estado == Estado.ESCUDADA

# ---------------------------------------------------------------------------------------------------------------
# Guarda
# ---------------------------------------------------------------------------------------------------------------

## Chamado todo quadro de física no lugar de andar. Devolve true se o jogador está em guarda (ou na escudada) e por isso não anda
func atualizar(delta: float) -> bool:
	match estado:
		Estado.LIVRE:
			if Input.is_action_pressed(jogador.acao("aparar")) and _pode_iniciar():
				_iniciar()
				return true
			return false
		Estado.GUARDA:
			if not _pode_manter():
				cancelar()
				return false
			_girar()
			jogador._gastar_stamina(CONSUMO_POR_SEGUNDO * delta)
			if jogador.stamina <= 0.5:
				_soltar(RECARGA_GUARDA_QUEBRADA)
				return false
			_parar(delta)
			return true
		Estado.CONTRA:
			_parar(delta)
			_pausa -= delta
			if _pausa <= 0.0:
				_iniciar_escudada()
			return true
		Estado.ESCUDADA:
			_parar(delta)
			jogador._pedido_ataque = false
			_andar_escudada(delta)
			return true
	return false

func _pode_iniciar() -> bool:
	return Time.get_ticks_msec() >= _livre_ate_ms and jogador.pode_aparar() and jogador.stamina >= CUSTO_INICIAL

func _pode_manter() -> bool:
	return Input.is_action_pressed(jogador.acao("aparar")) and not jogador.estaMorto and jogador.movimento_habilitado and not jogador.modo_fazenda \
			and not jogador.ataques_bloqueados and jogador.get_viewport().gui_get_focus_owner() == null

func _iniciar() -> void:
	estado = Estado.GUARDA
	_inicio_guarda_ms = Time.get_ticks_msec()
	jogador._gastar_stamina(CUSTO_INICIAL)
	jogador._pedido_ataque = false
	direcao_guarda = _cardinal(jogador._direcao_ataque)
	jogador.tocar_pose_aparar()

# Soltou o botão (ou acabou a estamina): sai da guarda e espera a recarga
func _soltar(recarga: float) -> void:
	estado = Estado.LIVRE
	_livre_ate_ms = Time.get_ticks_msec() + int(recarga * 1000.0)
	jogador.no_reacao.encerrar()

## Encerra tudo na hora (dash, tela aberta, morte...)
func cancelar() -> void:
	if estado == Estado.LIVRE:
		return
	var era_escudada := estado == Estado.ESCUDADA
	estado = Estado.LIVRE
	_livre_ate_ms = Time.get_ticks_msec() + int(RECARGA_AO_SOLTAR * 1000.0)
	jogador.no_reacao.encerrar()
	if era_escudada:
		_terminar_escudada()

# Segurando a guarda o jogador só vira: as setas giram a pose
func _girar() -> void:
	var dir: Vector2 = jogador._vetor_movimento()
	if dir == Vector2.ZERO:
		return
	jogador._direcao_ataque = dir.normalized()
	direcao_guarda = _cardinal(dir)
	jogador.no_reacao.virar(direcao_guarda)
	jogador.virar_para(dir.normalized())

func _parar(delta: float) -> void:
	jogador._pedido_ataque = false
	jogador.velocity = jogador.velocity.move_toward(Vector2.ZERO, 900.0 * delta)

## O vetor cardinal (como a linha da folha) mais próximo de uma direção
func _cardinal(dir: Vector2) -> Vector2:
	match ArcoJogador.linha_da_direcao(dir):
		0: return Vector2.DOWN
		1: return Vector2.UP
		2: return Vector2.RIGHT
	return Vector2.LEFT

# ---------------------------------------------------------------------------------------------------------------
# Receber o golpe
# ---------------------------------------------------------------------------------------------------------------

## Pergunta feita por Jogador.receber_dano antes de descontar a vida. Devolve {} (a guarda não vale: dano normal), ou
## {"tipo": "perfeito"} (sem dano), ou {"tipo": "bloqueio", "dano": n, "knockback": v} (dano e empurrão já reduzidos)
func resolver(dano: int, forca_knockback: Vector2) -> Dictionary:
	if not em_guarda():
		return {}
	# De onde veio o golpe: o empurrão aponta do atacante para o jogador; sem empurrão, conta como de frente
	var para_atacante := -forca_knockback.normalized() if forca_knockback != Vector2.ZERO else direcao_guarda
	if direcao_guarda.dot(para_atacante) < COSSENO_FRONTAL:
		cancelar()   # pelas costas ou pelo lado a guarda não vale: o golpe entra e a pose de ferido toma o lugar dela
		return {}
	if estado == Estado.CONTRA or float(Time.get_ticks_msec() - _inicio_guarda_ms) / 1000.0 <= JANELA_PERFEITA:
		_aparo_perfeito()
		return {"tipo": "perfeito"}
	var custo := float(dano) * STAMINA_POR_DANO
	if jogador.stamina < custo:
		jogador.stamina = 0.0
		jogador._avisar_stamina()
		_soltar(RECARGA_GUARDA_QUEBRADA)
		Sons.tocar("erro", 0.0)
		_texto("GUARDA QUEBRADA", Color(1, 0.45, 0.4))
		return {}
	jogador._gastar_stamina(custo)
	_bloqueio()
	return {"tipo": "bloqueio", "dano": maxi(1, roundi(dano * (1.0 - REDUCAO_BLOQUEIO))), "knockback": forca_knockback * KNOCKBACK_BLOQUEIO}

func _aparo_perfeito() -> void:
	var j := jogador
	j.contragolpe_ate_ms = Time.get_ticks_msec() + 3000
	j.stamina = minf(j.stamina + REEMBOLSO_PERFEITO, j.stamina_maxima)
	j._avisar_stamina()
	var pode_contra: bool = j.usando_espada and j.usando_escudo
	j.invulneravel = true
	j.temporizador_invul = maxf(j.temporizador_invul, INVULNERAVEL_APARO + (PAUSA_ANTES_DA_ESCUDADA + _duracao_escudada() if pode_contra else 0.0))
	Sons.tocar("aparo", 0.05)
	Controle.vibrar(0.4, 0.9, 0.14, jogador)
	_faisca(Color(1, 0.95, 0.6), 1.5, 0.9)
	_texto("APAROU!", Color(1, 0.92, 0.45))
	_tremer(2.0, 0.15)
	for inimigo in j.get_tree().get_nodes_in_group("enemy"):
		if not (inimigo is Node2D) or not is_instance_valid(inimigo) or inimigo.get("esta_morto"):
			continue
		var para: Vector2 = inimigo.global_position - j.global_position
		if para.length() > ALCANCE_REPELIR or para.normalized().dot(direcao_guarda) < -0.2:
			continue
		if inimigo.has_method("empurrar"):
			inimigo.empurrar(para.normalized() * FORCA_REPELIR)
		if inimigo.has_method("atordoar"):
			inimigo.atordoar(ATORDOAR_APARO)
	if pode_contra:
		estado = Estado.CONTRA
		_pausa = PAUSA_ANTES_DA_ESCUDADA

func _bloqueio() -> void:
	Sons.tocar("bloqueio", 0.08)
	Controle.vibrar(0.5, 0.3, 0.1, jogador)
	_faisca(Color(0.85, 0.9, 1.0), 0.8, 0.6)
	_tremer(1.0, 0.1)

# ---------------------------------------------------------------------------------------------------------------
# Escudada
# ---------------------------------------------------------------------------------------------------------------

func _duracao_escudada() -> float:
	var total := 0.0
	for quadro in QUADROS_ESCUDADA:
		total += float(quadro[1])
	return total

func _iniciar_escudada() -> void:
	var j := jogador
	j.no_reacao.encerrar()
	estado = Estado.ESCUDADA
	_indice = 0
	_tempo = 0.0
	_impacto_feito = false
	_linha = ArcoJogador.linha_da_direcao(direcao_guarda)
	j._esta_atacando = true
	j.ataque_enfileirado = false
	j._fase_combo = 0
	j.pausar_animacoes(true)
	j.definir_sprites_visiveis(true)
	_aplicar_quadro()
	Sons.tocar("escudada", 0.05)

func _andar_escudada(delta: float) -> void:
	_tempo += delta
	if not _impacto_feito and _indice >= QUADRO_IMPACTO_ESCUDADA:
		_impacto_feito = true
		_impacto_escudada()
	while _tempo >= float(QUADROS_ESCUDADA[_indice][1]):
		_tempo -= float(QUADROS_ESCUDADA[_indice][1])
		_indice += 1
		if _indice >= QUADROS_ESCUDADA.size():
			estado = Estado.LIVRE
			_livre_ate_ms = Time.get_ticks_msec() + int(RECARGA_AO_SOLTAR * 1000.0)
			_terminar_escudada()
			return
		if not _impacto_feito and _indice >= QUADRO_IMPACTO_ESCUDADA:
			_impacto_feito = true
			_impacto_escudada()
	_aplicar_quadro()

func _terminar_escudada() -> void:
	jogador.pausar_animacoes(false)
	jogador._esta_atacando = false
	jogador.definir_sprites_visiveis(false)

# Pinta o quadro atual nas cinco camadas da animação de ataque da espada, cada uma na frente ou atrás do corpo
func _aplicar_quadro() -> void:
	var j := jogador
	var coluna: int = int(QUADROS_ESCUDADA[_indice][0])
	var quadro := (LINHA_BASE_ESCUDADA + _linha) * 8 + coluna
	var camadas: Array = [j.corpo_espada_escudo_ataque, j.braco_espada_ataque, j.escudo_ataque, j.cabelo_ataque, j.roupa_ataque]
	for camada: Sprite2D in camadas:
		camada.frame = quadro
		camada.flip_h = false
	j.corpo_espada_escudo_ataque.z_index = 1
	j.roupa_ataque.z_index = 2
	j.cabelo_ataque.z_index = 3
	var indice_coluna := coluna - 4
	j.braco_espada_ataque.z_index = Z_FRENTE if ORDEM_ESPADA[_linha][indice_coluna] == "F" else Z_ATRAS
	j.escudo_ataque.z_index = Z_FRENTE if ORDEM_ESCUDO[_linha][indice_coluna] == "F" else Z_ATRAS

# O escudo acerta quem está à frente: golpe mais forte que o da espada, empurra mais e atordoa
func _impacto_escudada() -> void:
	var j := jogador
	_tremer(2.5, 0.18)
	Controle.vibrar(0.5, 0.8, 0.12, jogador)
	_faisca(Color(1, 0.9, 0.7), 1.2, 0.8)
	for inimigo in j.get_tree().get_nodes_in_group("enemy"):
		if not (inimigo is Node2D) or not is_instance_valid(inimigo) or inimigo.get("esta_morto"):
			continue
		var para: Vector2 = inimigo.global_position - j.global_position
		if inimigo.has_method("ponto_de_acerto_proximo"):
			para = inimigo.ponto_de_acerto_proximo(j.global_position) - j.global_position
			if para.length_squared() < 0.01:
				para = direcao_guarda
		if para.length() > ALCANCE_ESCUDADA or para.normalized().dot(direcao_guarda) < COSSENO_ESCUDADA:
			continue
		j.aplicar_golpe(inimigo, para.normalized(), MULT_DANO_ESCUDADA, MULT_EMPURRAO_ESCUDADA)
		if is_instance_valid(inimigo) and inimigo.has_method("atordoar"):
			inimigo.atordoar(ATORDOAR_ESCUDADA)

# ---------------------------------------------------------------------------------------------------------------
# Efeitos
# ---------------------------------------------------------------------------------------------------------------

func _faisca(cor: Color, energia: float, escala: float) -> void:
	EfeitosLuz.criar_flash(jogador.get_tree().current_scene, jogador.global_position + direcao_guarda * 12.0 + Vector2(0, -6), cor, energia, escala, 0.18)

func _tremer(intensidade: float, duracao: float) -> void:
	var camera: Camera2D = jogador.camera
	if camera == null:
		return
	var tween := camera.create_tween()
	var passos := 5
	for i in passos:
		var forca := intensidade * (1.0 - float(i) / passos)
		tween.tween_property(camera, "offset", Vector2(randf_range(-forca, forca), randf_range(-forca, forca)), duracao / passos)
	tween.tween_property(camera, "offset", Vector2.ZERO, 0.03)

# Texto que sobe da cabeça do jogador e some
func _texto(conteudo: String, cor: Color) -> void:
	var cena := jogador.get_tree().current_scene
	if cena == null:
		return
	var rotulo := Label.new()
	rotulo.text = conteudo
	rotulo.add_theme_font_override("font", FONTE)
	rotulo.add_theme_font_size_override("font_size", 8)
	rotulo.add_theme_color_override("font_color", cor)
	rotulo.add_theme_color_override("font_outline_color", Color(0.1, 0.07, 0.1))
	rotulo.add_theme_constant_override("outline_size", 3)
	rotulo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rotulo.z_as_relative = false
	rotulo.z_index = Profundidade.Z_TOPO - 40
	cena.add_child(rotulo)
	rotulo.reset_size()
	var inicio := jogador.global_position + Vector2(-rotulo.size.x / 2.0, -34)
	rotulo.global_position = inicio
	var tween := rotulo.create_tween().set_parallel(true)
	tween.tween_property(rotulo, "global_position", inicio + Vector2(0, -14), 0.7).set_trans(Tween.TRANS_SINE)
	tween.tween_property(rotulo, "modulate:a", 0.0, 0.35).set_delay(0.4)
	tween.chain().tween_callback(rotulo.queue_free)
