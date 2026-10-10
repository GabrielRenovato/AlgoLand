extends CanvasLayer

const FRACAO_VIDA_BAIXA := 0.3
# A fita do pack tem 16px de altura: em 2x o banner fica legível no centro da tela
const ESCALA_BANNER := Vector2(2, 2)
const COR_STAMINA := Color(1, 0.85, 0.3)
const COR_STAMINA_VAZIA := Color(1, 0.3, 0.3)

@onready var coracao: TextureRect = %Coracao
@onready var barra_vida: Control = %BarraVida
@onready var rotulo_vida: Label = %RotuloVida
@onready var barra_stamina: Control = %BarraStamina
@onready var icone_stamina: TextureRect = %IconeStamina
@onready var rotulo_moedas: Label = %RotuloMoedas
@onready var rotulo_onda: Label = %RotuloOnda
@onready var linha_inimigos: Control = %LinhaInimigos
@onready var rotulo_inimigos: Label = %RotuloInimigos
@onready var barra_inimigos: Control = %BarraInimigos
@onready var rotulo_espera: Label = %RotuloEspera
@onready var painel_chefe: Control = %PainelChefe
@onready var nome_chefe: Label = %NomeChefe
@onready var barra_chefe: Control = %BarraChefe
@onready var faixa_banner: Control = %FaixaBanner
@onready var rotulo_banner: Label = %RotuloBanner
@onready var subtitulo_banner: Label = %SubtituloBanner

var _vida_atual := -1
var _tween_coracao: Tween
var _tween_banner: Tween
var _tween_stamina: Tween
var _vida_baixa := false
var _gerenciador: Node

func _ready() -> void:
	add_to_group("hud")
	faixa_banner.hide()
	_mostrar_inimigos(false)
	atualizar_moedas(DadosJogo.moedas)
	# O Jogador fica antes na árvore e já atualizou a vida antes deste nó entrar no grupo
	var jogador := get_parent().get_node_or_null("Jogador")
	if jogador:
		jogador.atualizar_barra_hp()
		atualizar_stamina(jogador.stamina, jogador.stamina_maxima)
	# O GerenciadorOndas fica dentro do enemySpawner e pode entrar na árvore depois do HUD
	await get_tree().process_frame
	var gerenciador := get_tree().get_first_node_in_group("gerenciador_ondas")
	if gerenciador == null:
		return
	_gerenciador = gerenciador
	gerenciador.onda_iniciada.connect(_ao_onda_iniciada)
	gerenciador.onda_completada.connect(_ao_onda_completada)
	gerenciador.sinal_ondas_paradas.connect(_ao_ondas_paradas)
	gerenciador.inimigos_alterados.connect(_ao_inimigos_alterados)
	rotulo_onda.text = "ONDA %d" % gerenciador.onda_atual

func atualizar_vida(atual: int, maximo: int) -> void:
	var levou_dano := _vida_atual >= 0 and atual < _vida_atual
	_vida_atual = atual
	barra_vida.definir(atual, maximo, levou_dano)
	rotulo_vida.text = "%d/%d" % [atual, maximo]
	if levou_dano:
		_pulsar_coracao()
	_definir_vida_baixa(maximo > 0 and float(atual) / maximo <= FRACAO_VIDA_BAIXA)

func mostrar_chefe(nome: String, vida: int, vida_maxima: int) -> void:
	nome_chefe.text = nome
	barra_chefe.definir(vida, vida_maxima, false)
	painel_chefe.modulate.a = 0.0
	painel_chefe.show()
	create_tween().tween_property(painel_chefe, "modulate:a", 1.0, 0.4)
	_mostrar_banner(nome, "BATALHA DE CHEFE", 2.2)

func atualizar_chefe(vida: int, vida_maxima: int) -> void:
	barra_chefe.definir(vida, vida_maxima)

func esconder_chefe() -> void:
	if not painel_chefe.visible:
		return
	var tween := create_tween()
	tween.tween_interval(0.8)
	tween.tween_property(painel_chefe, "modulate:a", 0.0, 0.4)
	tween.tween_callback(painel_chefe.hide)

func atualizar_stamina(atual: float, maximo: float) -> void:
	barra_stamina.definir(atual, maximo, false)

func avisar_stamina_insuficiente() -> void:
	if _tween_stamina and _tween_stamina.is_running():
		return
	_tween_stamina = create_tween()
	for i in 2:
		_tween_stamina.tween_property(icone_stamina, "modulate", COR_STAMINA_VAZIA, 0.08)
		_tween_stamina.tween_property(icone_stamina, "modulate", COR_STAMINA, 0.08)

func atualizar_moedas(quantidade: int) -> void:
	rotulo_moedas.text = str(quantidade)

func _ao_onda_iniciada(onda: int) -> void:
	_mostrar_inimigos(true)
	# Na onda do chefe o anúncio é dele (mostrar_chefe), não da onda
	if _eh_onda_chefe(onda):
		rotulo_onda.text = "CHEFE"
		return
	rotulo_onda.text = "ONDA %d" % onda
	_mostrar_banner("ONDA %d" % onda)

func _ao_onda_completada(onda: int) -> void:
	rotulo_onda.text = "ONDA %d" % (onda + 1)
	_mostrar_inimigos(false)
	if _eh_onda_chefe(onda):
		_mostrar_banner("CHEFE DERROTADO", "ONDA %d CONCLUIDA" % onda)
	else:
		_mostrar_banner("ONDA %d CONCLUIDA" % onda)

func _eh_onda_chefe(onda: int) -> bool:
	return _gerenciador != null and _gerenciador.eh_onda_chefe(onda)

func _ao_ondas_paradas() -> void:
	rotulo_onda.text = "ONDA 1"
	_mostrar_inimigos(false)
	esconder_chefe()

func _ao_inimigos_alterados(vivos: int, total: int) -> void:
	rotulo_inimigos.text = "%d/%d" % [maxi(vivos, 0), total]
	barra_inimigos.definir(maxi(vivos, 0), maxi(total, 1))

func _mostrar_inimigos(em_onda: bool) -> void:
	linha_inimigos.visible = em_onda
	rotulo_espera.visible = not em_onda

func _mostrar_banner(texto: String, subtitulo := "", tempo_visivel := 1.5) -> void:
	rotulo_banner.text = texto
	subtitulo_banner.text = subtitulo
	subtitulo_banner.visible = subtitulo != ""
	if _tween_banner:
		_tween_banner.kill()
	faixa_banner.show()
	faixa_banner.modulate.a = 0.0
	faixa_banner.scale = ESCALA_BANNER * 1.3
	# Espera o PanelContainer recalcular o tamanho para o texto novo
	await get_tree().process_frame
	faixa_banner.pivot_offset = faixa_banner.size / 2.0
	_tween_banner = create_tween()
	_tween_banner.set_parallel()
	_tween_banner.tween_property(faixa_banner, "modulate:a", 1.0, 0.2)
	_tween_banner.tween_property(faixa_banner, "scale", ESCALA_BANNER, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween_banner.chain().tween_interval(tempo_visivel)
	_tween_banner.chain().tween_property(faixa_banner, "modulate:a", 0.0, 0.4)
	_tween_banner.chain().tween_callback(faixa_banner.hide)

func _pulsar_coracao() -> void:
	if _vida_baixa:
		return
	if _tween_coracao:
		_tween_coracao.kill()
	coracao.scale = Vector2(1.4, 1.4)
	_tween_coracao = create_tween()
	_tween_coracao.tween_property(coracao, "scale", Vector2.ONE, 0.2)

func _definir_vida_baixa(baixa: bool) -> void:
	if baixa == _vida_baixa:
		return
	_vida_baixa = baixa
	if _tween_coracao:
		_tween_coracao.kill()
	coracao.scale = Vector2.ONE
	if not baixa:
		return
	_tween_coracao = create_tween().set_loops()
	_tween_coracao.tween_property(coracao, "scale", Vector2(1.25, 1.25), 0.3)
	_tween_coracao.tween_property(coracao, "scale", Vector2.ONE, 0.3)
