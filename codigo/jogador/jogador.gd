extends CharacterBody2D

const EfeitosLuz := preload("res://codigo/efeitos/efeitos_luz.gd")
const Encantamentos := preload("res://codigo/dados/encantamentos.gd")
const Carrasco := preload("res://codigo/dados/conjunto_carrasco.gd")
const Mordomo := preload("res://assets/personagens/conjuntos/cavalheiro/definicao.gd")
const Conjuntos := preload("res://codigo/dados/conjuntos_armadura.gd")
const RaioCarrasco := preload("res://codigo/efeitos/raio.gd")
const Equipamentos := preload("res://codigo/dados/equipamentos.gd")
const ArcoJogador := preload("res://codigo/jogador/arco_jogador.gd")
const Flecha := preload("res://codigo/jogador/flecha.gd")
const ReacaoJogador := preload("res://codigo/jogador/reacao_jogador.gd")
const DefesaJogador := preload("res://codigo/jogador/defesa_jogador.gd")
const FazendaJogador := preload("res://codigo/jogador/fazenda_jogador.gd")
const EfeitosPocao := preload("res://codigo/jogador/efeitos_pocao.gd")
const Aparencia := preload("res://codigo/dados/aparencia.gd")
const Profundidade := preload("res://codigo/globais/profundidade.gd")
const PetrificacaoJogador := preload("res://codigo/jogador/petrificacao_jogador.gd")
var petrificacao: Node = null
const Raridades := preload("res://codigo/dados/raridades.gd")
const ALCANCE_MIRA_ARCO := 260.0
## Mira assistida do arco: com o jogador apontando uma direção, só inimigos dentro deste cone (cosseno do ângulo, uns 65 graus para cada
## lado) atraem a flecha; sem alvo no cone ela vai para onde ele aponta
const COSSENO_CONE_MIRA := 0.42
## Inclinação mínima do direcional/joystick para contar como "estou apontando"
const ZONA_MORTA_MIRA := 0.25
const ObjetosRefinados := preload("res://codigo/dados/objetos_refinados.gd")
const TEXTURA_ALJAVA := preload("res://assets/personagens/Arco/carregando/aljava.png")

# Preload do banco de dados de armas (nome: banco_dados_armas)
var banco_dados_armas = preload("res://codigo/dados/equipamentos.gd")
signal equipamento_alterado
@onready var estatisticas = preload("res://codigo/jogador/status_do_jogador.gd").new()
var eh_arma_duas_maos: bool = false
@export var cor_cabelo: Color = Color(1, 1, 1)  # Branco como padrão
var ataques_bloqueados: bool = false
@export_category("Variáveis")
@export var _friccao: float = 0.3
@export var _aceleracao: float = 0.3
@export var _decaimento_knockback: float = 0.1
var nivel_escudo: int:
	get: return _nivel_no_modelo("escudo_basico")
var esta_forjando: bool = false
## Sentado numa cadeira (cadeira.gd): usa os nós da Forja, que têm as folhas da página 4 (pose de sentar na coluna 3 de
## cada direção: linha 6 = olhando para a direita, linha 7 = para a esquerda)
var esta_sentado: bool = false
## O assento em que está sentado (cadeira.gd), para o botão de interagir usar a mesa em vez de levantar
var assento_atual: Node = null
## O jogador pediu para levantar (F/Y, B/Esc ou andar): quem o sentou (cadeira.gd) o tira de lá
signal pediu_levantar
const QUADRO_SENTADO := {1: 51, -1: 59}
## Sentado de frente (banco acima da mesa: olha para baixo) e de costas (banco abaixo da mesa: olha para cima), página 4
const QUADRO_SENTADO_FRENTE := {1: 35, -1: 43}
## 0 = de lado (QUADRO_SENTADO), 1 = de frente, -1 = de costas
var _frente_sentado := 0
## Tempo mínimo sentado antes de aceitar o pedido de levantar (o mesmo F que sentou não pode levantar na hora)
const TEMPO_MINIMO_SENTADO := 0.5
## Roupas da página 4 para a pose de sentar, na mesma ordem das de andar (a forja só tem o avental de ferreiro; ver
## assets/personagens/Sentado/LEIAME.txt)
var _lado_sentado := 1
var _z_sentado := 0
var _tempo_sentado := 0.0
var _arm_forja_visivel := true
var id_escudo_atual: String = "escudo_basico"
var movimento_habilitado: bool = true
## Rota exclusiva do tutorial: não usa nem simula entradas do jogador.
var seguindo_introducao := false
var seguimento_bloqueado := false
var caminho_introducao := PackedVector2Array()
var alvo_introducao: Node2D

# Vitalidade: separando base e bônus
var vitalidade_base: int = 5              # Valor base de vitalidade
var bonus_vitalidade: int = 0             # Soma de todos os bônus de vitalidade
var vitalidade_atual: int = vitalidade_base  # Vitalidade total (base + bônus)

# Defesa: como não há um "base_defense" explícito, assumimos que estatisticas.defesa = soma dos bônus
var bonus_defesa: int = 0               # Soma de todos os bônus de defesa

@export var tipo_item_atual: String = ""  # "espada", "lanca", etc.
# >>> Escudo controlado separadamente <<<
@export var usando_escudo: bool = false
var ataque_enfileirado: bool = false
# Variável que controla o nível da arma (espada)
var nivel_espada: int:
	get: return _nivel_no_modelo(id_arma_atual)
var id_arma_atual: String = "espada_basica"
@export var usando_espada: bool = false

# Variáveis para controlar a lança
@export var usando_lanca: bool = false
var nivel_lanca: int:
	get: return _nivel_no_modelo(id_lanca_atual)
var id_lanca_atual: String = "lanca_basica"

# Arco: camadas visuais próprias (arco_jogador.gd) no lugar de BaseSprites
@export var usando_arco: bool = false
var nivel_arco: int:
	get: return _nivel_no_modelo(id_arco_atual)
var id_arco_atual: String = "arco_curvo"
var no_arco: ArcoJogador = null
# Poses curtas de sacar/guardar a arma, esquiva e ferido (reacao_jogador.gd)
var no_reacao: ReacaoJogador = null
## Aparar e escudada (defesa_jogador.gd)
var defesa: DefesaJogador = null
var contragolpe_ate_ms := 0
# Enxada, machado, picareta, plantar, regar e colher (fazenda_jogador.gd); trava o jogador enquanto dura
var no_fazenda: FazendaJogador = null
var esta_em_acao_fazenda: bool = false
## Na fazenda não há armas em uso: o botão de ataque pede a ferramenta ativa (sinal ferramenta_pedida) em vez de atacar.
## O Plantio (codigo/logica/plantio.gd) liga isto; as armas seguem equipadas e o dash continua valendo
var modo_fazenda: bool = false
## Selecionada pela barra, sem trocar o equipamento real nem desligar o combate da arena.
var picareta_arena_ativa := false
## Poções bebidas e o cinto (efeitos_pocao.gd). Só se bebe na arena: Q/E (LB/RB) trocam a poção, R (X) bebe
var efeitos_pocao: EfeitosPocao = null
## Teto da redução de dano somando a poção de pedra (a da defesa sozinha para em REDUCAO_MAXIMA)
const REDUCAO_MAXIMA_COM_POCAO := 0.85
## Distância à frente dos pés onde a ação de fazenda acontece (o tile que a enxada acerta)
const ALCANCE_ACAO_FAZENDA := 14.0
var _inventario_pronto: bool = false
## Os itens (a instância, não só o tipo) que o corpo está usando: duas espadas iguais de raridades diferentes têm o mesmo tipo, mas dano e
## afixos diferentes, então trocar de uma para a outra precisa reaplicar tudo (ver _aplicar_modelo)
var _arma_aplicada: DadosItem = null
var _escudo_aplicado: DadosItem = null
## O que cada slot ("arma", "escudo") somou aos status (ver _pacote_do_item): ao trocar, subtrai exatamente isto, então nada "vaza"
var _pacote_aplicado := {"arma": {}, "escudo": {}, "cabeca": {}, "corpo": {}, "luvas": {}, "botas": {}}
var _recarga_carrasco := 0.0
var _rng_carrasco := RandomNumberGenerator.new()
var _recarga_mordomo := 0.0
var _rng_mordomo := RandomNumberGenerator.new()
var botao_ataque_pressionado: bool = false
const TIPOS_ARMADURA := {
	"cabeca_basica": "usando_cabeca",
	"armadura_basica": "usando_corpo",
	"luvas_basicas": "usando_luvas",
	"botas_basicas": "usando_botas",
}

# Evita eco: mudanças vindas do modelo não podem voltar para ele (e vice-versa)
var _sincronizando: bool = false
# Lido em _unhandled_input para que cliques consumidos pela GUI não ataquem
var _pedido_ataque: bool = false
# No controle o B fecha as telas e também rola, e o A confirma e também ataca. O toque que fecha uma tela não pode
# virar dash nem golpe: Input.action_release não cancela is_action_just_pressed, então fica uma janela sem ação
const JANELA_SEM_ACAO_APOS_TELA_MS := 250
var _sem_acao_ate_ms: int = 0
var _interacao_bloqueada := false
var _quadro_bloqueio_interacao := -1
@export_category("Objetos")
@export var _arvore_animacao: AnimationTree = null
@export var _temporizador: Timer = null  # Timer para controlar a duração de cada golpe

signal forja_finalizada

# ---------------------------
# BaseSprites
# ---------------------------
@onready var sprite_corpo = $CompositeSprites/BaseSprites/Corpo
@onready var sprite_cabelo = $CompositeSprites/BaseSprites/Cabelo
@onready var sprite_roupa = $CompositeSprites/BaseSprites/Roupa
@onready var sprite_espada = $CompositeSprites/BaseSprites/Braco
@onready var sprite_escudo = $CompositeSprites/BaseSprites/Escudo
@onready var sprite_lanca = $CompositeSprites/BaseSprites/Lanca


# ---------------------------
# AttackSwordAnimation (espada)
# ---------------------------
@onready var corpo_espada_escudo_ataque = $CompositeSprites/AttackSwordAnimation/CorpoEspadaEscudo
@onready var braco_espada_ataque = $CompositeSprites/AttackSwordAnimation/BracoEspada
@onready var escudo_ataque = $CompositeSprites/AttackSwordAnimation/Escudo
@onready var cabelo_ataque = $CompositeSprites/AttackSwordAnimation/Cabelo
@onready var roupa_ataque = $CompositeSprites/AttackSwordAnimation/Roupa

# ---------------------------
# AttackSpearAnimation (lança)
# ---------------------------
@onready var corpo_lanca_escudo_ataque = $CompositeSprites/AttackSpearAnimation/Corpo
@onready var braco_lanca_ataque = $CompositeSprites/AttackSpearAnimation/Lanca
@onready var cabelo_lanca_ataque = $CompositeSprites/AttackSpearAnimation/Cabelo
@onready var roupa_lanca_ataque = $CompositeSprites/AttackSpearAnimation/Roupa

@onready var camera: Camera2D = $Camera2D


signal jogador_morreu
## Ações de fazenda (fazenda_jogador.gd): "impacto" no quadro em que a ferramenta acerta o chão, com o ponto
## à frente do jogador; "concluida" quando a animação acaba
signal acao_fazenda_impacto(acao: String, ponto: Vector2)
signal acao_fazenda_concluida(acao: String)
## Botão de ataque apertado com modo_fazenda ligado ("usar ferramenta")
signal ferramenta_pedida

@export var estaMorto = false
## Cooperativo local (Cooperativo.gd): este é o jogador 2, que lê as ações "p2_*" do controle dele, divide a mochila com
## o jogador 1 sem mexer nela, e mostra a vida numa barrinha sobre a cabeça em vez do HUD
var eh_p2 := false
## Mochila e equipamento deste jogador: o InventarioJogador, ou o InventarioJogador2 no jogador 2 (cooperativo)
var inventario: Node
## Caiu no cooperativo com o parceiro de pé: fica no chão até ser levantado (Cooperativo._cuidar_dos_caidos)
var caido := false
var _barra_p2: Node2D
## Só existe na arena (cenario.tscn); na fazenda e na casa é null e o jogador não morre nem recebe ondas
@onready var gerenciador_ondas = get_node_or_null("../enemySpawner/GerenciadorOndas")

## Para onde o jogador volta depois de cair (a posição inicial da cena, junto da fogueira)
var _posicao_acampamento: Vector2 = Vector2.ZERO
var apelido: String = ""
var inimigos_danificados: Array[Node] = []
var itens_comprados: Array[Dictionary] = []

var cabelo_atual: int = 0
var roupa_atual: int = 0
var _maquina_estados: Object 
var status_armas = preload("res://codigo/dados/equipamentos.gd").new()
var _knockback: Vector2 = Vector2.ZERO
var temporizador_knockback: float = 0.0

var _direcao_ataque: Vector2 = Vector2.DOWN
## Cardinal do último golpe de espada ou lança (desempate das diagonais)
var _cardinal_anterior: Vector2 = Vector2.DOWN
var hp_atual: int

var invulneravel: bool = false
var tempo_invul: float = 0.6
var temporizador_invul: float = 0.0

@export var duracao_dash: float = 0.15
@export var velocidade_dash: float = 380.0
@export var recarga_dash: float = 0.6
@export var intervalo_rastro_dash: float = 0.025
@export var duracao_rastro_dash: float = 0.25
# Tom azulado das "sombras" deixadas pelo dash
@export var cor_rastro_dash: Color = Color(0.55, 0.8, 1.0, 0.6)
var esta_em_dash: bool = false
var _dash_disponivel: bool = true

@export var stamina_maxima: float = 100.0
# Estamina sem a melhoria "folego" (Progresso); stamina_maxima = base * (1 + bonus)
var _stamina_base: float = 100.0
# 35 por dash: dá 2 dashes seguidos e o terceiro precisa esperar recarregar
@export var custo_stamina_dash: float = 35.0
@export var regeneracao_stamina: float = 30.0
@export var atraso_regeneracao_stamina: float = 0.6
var stamina: float = 100.0
var _espera_regeneracao: float = 0.0
var _tempo_proximo_rastro: float = 0.0

# ---------------------------
# COMBO
# ---------------------------
var _esta_atacando: bool = false
var _fase_combo: int = 0
var _pode_encadear_combo: bool = false

# Tempos para cada slash da espada
var _tempo_slash_1: float = 0.3
var _tempo_slash_2: float = 0.3
var _tempo_slash_3: float = 0.3

# >>> Tempos para a lança (ordem 2 -> 3 -> 1) <<<
var _tempo_slash_lanca_2: float = 0.35
var _tempo_slash_lanca_3: float = 0.45
var _tempo_slash_lanca_1: float = 0.35

var _temporizador_janela_combo: Timer

# ---------------------------
# FORJA
# ---------------------------
@onready var no_forja: Node2D = $CompositeSprites/Forja
@onready var sprite_corpo_forja: Sprite2D = $CompositeSprites/Forja/Corpo
@onready var sprite_cabelo_forja: Sprite2D = $CompositeSprites/Forja/Cabelo
@onready var sprite_roupa_forja: Sprite2D = $CompositeSprites/Forja/Roupa

@onready var reprodutor_anim: AnimationPlayer = $CompositeSprites/Animation/AnimationPlayer

@onready var sprite_armadura_cabeca  : Sprite2D = $CompositeSprites/Armaduras/cabeca
@onready var sprite_armadura_corpo  : Sprite2D = $CompositeSprites/Armaduras/corpo
@onready var sprite_armadura_luvas: Sprite2D = $CompositeSprites/Armaduras/luvas
@onready var sprite_armadura_botas : Sprite2D = $CompositeSprites/Armaduras/botas

# Níveis atuais de cada peça de armadura (iniciam em 1 por padrão)
@export var nivel_cabeca: int = 1
@export var nivel_corpo: int = 1
@export var nivel_luvas: int = 1
@export var nivel_botas: int = 1

# IDs (chaves no banco de dados `armaduras`)
var id_cabeca_atual: String   = "armadura_cabeca"
var id_corpo_atual: String   = "armadura_corpo"
var id_luvas_atual: String = "armadura_luvas"
var id_botas_atual: String  = "armadura_botas"

# Flags para indicar se cada peça está equipada ou não
@export var usando_cabeca: bool   = false
@export var usando_corpo: bool   = false
@export var usando_luvas: bool = false
@export var usando_botas: bool  = false

## Nome da ação deste jogador (o jogador 2 usa as cópias "p2_" presas ao controle dele)
func acao(nome: String) -> String:
	return "p2_" + nome if eh_p2 else nome

func _vetor_movimento() -> Vector2:
	return Cooperativo.vetor_p2() if eh_p2 else Controle.vetor_movimento()

func _ready() -> void:
	inventario = InventarioJogador2 if eh_p2 else InventarioJogador
	add_to_group("jogadores")
	if eh_p2:
		remove_from_group("character")
		add_to_group("jogador2")
		$Camera2D.enabled = false
	_rng_carrasco.randomize()
	_rng_mordomo.randomize()
	# Inicializa vitalidade e defesa corretamente
	vitalidade_base = 5
	bonus_vitalidade = 0
	_temporizador = $AttackTimer
	bonus_defesa = 0
	estatisticas.vitalidade = vitalidade_base
	estatisticas.defesa = 0  # Será calculado depois
	vitalidade_atual = vitalidade_base
	_arvore_animacao = $CompositeSprites/Animation/AnimationTree
	# Conecta timer de ataque se existir
	if _temporizador:
		_temporizador.connect("timeout", Callable(self, "_on_temporizador_ataque_timeout"))

	_temporizador_janela_combo = Timer.new()
	_temporizador_janela_combo.one_shot = true
	add_child(_temporizador_janela_combo)
	_temporizador_janela_combo.connect("timeout", Callable(self, "_on_timeout_janela_combo"))

	no_arco = ArcoJogador.new()
	no_arco.name = "Arco"
	no_arco.jogador = self
	no_arco.visible = false
	$CompositeSprites.add_child(no_arco)
	no_arco.disparo_liberado.connect(_ao_disparo_liberado)
	no_arco.disparo_terminado.connect(_ao_disparo_terminado)

	no_reacao = ReacaoJogador.new()
	no_reacao.name = "Reacao"
	no_reacao.jogador = self
	$CompositeSprites.add_child(no_reacao)
	no_reacao.terminou.connect(_atualizar_visual_arco)

	defesa = DefesaJogador.new()
	defesa.name = "Defesa"
	defesa.jogador = self
	add_child(defesa)

	no_fazenda = FazendaJogador.new()
	no_fazenda.name = "Fazenda"
	no_fazenda.jogador = self
	$CompositeSprites.add_child(no_fazenda)
	no_fazenda.impacto.connect(_ao_impacto_fazenda)
	no_fazenda.terminou.connect(_ao_fim_acao_fazenda)

	efeitos_pocao = EfeitosPocao.new()
	efeitos_pocao.name = "EfeitosPocao"
	add_child(efeitos_pocao)


	# Cabelo e roupa de cada animação (andar, golpes, forja...): ver codigo/dados/aparencia.gd
	_aplicar_aparencia()
	ObjetosRefinados.aplicar($CompositeSprites/Forja/Arm, $CompositeSprites/Forja/Arm.texture)

	if _arvore_animacao:
		_maquina_estados = _arvore_animacao.get("parameters/playback")

	# Camadas da área de ataque ficam na cena (camada nenhuma, máscara inimigos)
	$AreaAtaque.monitoring = false
	$AreaAtaque.monitorable = false

	conectar_sinal_se_nao_conectado($AreaAtaque, "body_entered", "_on_corpo_entrou_area_ataque")
	conectar_sinal_se_nao_conectado($AreaAtaque, "area_entered", "_on_area_entrou_area_ataque")

	# Carrega dados salvos
	var dados_carregados = carregar_de_json()
	aplicar_dados_carregados(dados_carregados)

	no_forja.visible = false
	if gerenciador_ondas != null:
		gerenciador_ondas.connect("onda_completada", Callable(self, "_on_onda_completada"))
	definir_sprites_visiveis(false)
	atualizar_rotulo_moedas()
	atualizar_barra_hp()

	hp_atual = estatisticas.hp_maximo
	atualizar_barra_hp()

	_iniciar_inventario()
	# As texturas antigas são ícones dos itens básicos; os bônus agora vêm dos slots do modelo.
	carregar_conjunto_armadura(1)

	_stamina_base = stamina_maxima
	_posicao_acampamento = global_position
	Progresso.melhorias_alteradas.connect(aplicar_melhorias_permanentes)
	aplicar_melhorias_permanentes()

func _iniciar_inventario() -> void:
	if inventario.esta_vazio() and not inventario.carregar():
		inventario.criar_itens_iniciais(Introducao.ativa())
	inventario.entregar_armas_liberadas()
	# Saves antigos guardavam as sementes na fazenda: agora são itens da mochila
	Fazenda.migrar_sementes_antigas()
	Fazenda.migrar_peixes_antigos()
	_aplicar_modelo()
	# As armaduras já foram equipadas acima; alinha o modelo caso o arquivo salvo divirja
	_enviar_estado_ao_modelo()
	equipamento_alterado.connect(_enviar_estado_ao_modelo)
	inventario.equipamento_alterado.connect(_ao_modelo_equipamento_alterado)
	EventosJogo.tela_fechada.connect(_ao_tela_fechada)
	_inventario_pronto = true

func _nivel_no_modelo(tipo: String) -> int:
	var item: DadosItem = inventario.buscar_por_tipo(tipo)
	return item.nivel if item != null else 1

func _subir_nivel_no_modelo(item: DadosItem) -> void:
	if item == null:
		return
	inventario.subir_nivel(item)
	inventario.salvar()

func _ao_tela_fechada(_nome: String) -> void:
	inventario.salvar()

# Sincroniza a arma nas chamadas legadas. O escudo equipado independe da sua atividade visual.
func _enviar_estado_ao_modelo() -> void:
	if _sincronizando:
		return
	_sincronizando = true
	var estados := {}
	for tipo in Equipamentos.FAMILIAS:
		match Equipamentos.familia_de(tipo):
			"espada":
				estados[tipo] = usando_espada and tipo == id_arma_atual
			"lanca":
				estados[tipo] = usando_lanca and tipo == id_lanca_atual
			"arco":
				estados[tipo] = usando_arco and tipo == id_arco_atual
	for tipo in estados:
		var item: DadosItem = inventario.buscar_por_tipo(tipo)
		if item != null and not estados[tipo] and inventario.slot_de(item) != "":
			inventario.desequipar(item.categoria)
	for tipo in estados:
		var item: DadosItem = inventario.buscar_por_tipo(tipo)
		if item != null and estados[tipo] and inventario.slot_de(item) == "":
			inventario.equipar(item)
	_sincronizando = false

func _ao_modelo_equipamento_alterado(_slot: String) -> void:
	picareta_arena_ativa = false
	_aplicar_modelo()

func _aplicar_modelo() -> void:
	if _sincronizando:
		return
	_sincronizando = true
	var arma = inventario.equipados["arma"] if not inventario.vara_na_mao else null
	var escudo = inventario.equipados["escudo"] if inventario.escudo_ativo() else null
	var tipo_arma: String = arma.tipo if arma != null else ""

	# Outro escudo (mesmo do mesmo tipo, de outra raridade) também sai e entra de novo: os bônus são os do item
	if usando_escudo and (escudo == null or escudo != _escudo_aplicado):
		desequipar_escudo()
	var familia: String = Equipamentos.familia_de(tipo_arma)
	# Trocar por outra arma da mesma família também desequipa, para recarregar as texturas; o mesmo vale para outra arma do MESMO tipo
	# (raridade e nível próprios)
	var outra_arma: bool = arma != _arma_aplicada
	if outra_arma: contragolpe_ate_ms = 0
	if usando_espada and (familia != "espada" or tipo_arma != id_arma_atual or outra_arma):
		desequipar_espada()
	if usando_lanca and (familia != "lanca" or tipo_arma != id_lanca_atual or outra_arma):
		desequipar_lanca()
	if usando_arco and (familia != "arco" or tipo_arma != id_arco_atual or outra_arma):
		desequipar_arco()
	# Os afixos da arma valem antes do dano ser calculado em equipar_*
	_arma_aplicada = arma
	_aplicar_bonus_item("arma", arma)
	if familia == "espada" and not usando_espada:
		id_arma_atual = tipo_arma
		equipar_espada()
	elif familia == "lanca" and not usando_lanca:
		id_lanca_atual = tipo_arma
		equipar_lanca()
	elif familia == "arco" and not usando_arco:
		id_arco_atual = tipo_arma
		equipar_arco()
	if escudo != null and not usando_escudo:
		equipar_escudo()
	for slot in ["cabeca", "corpo", "luvas", "botas"]:
		var item: DadosItem = inventario.equipados[slot]
		_aplicar_bonus_item(slot, item)
		set("usando_" + slot, item != null)
		set("nivel_" + slot, item.nivel if item != null else 1)
	_atualizar_bonus_conjuntos()
	_aplicar_aparencia()

	_sincronizando = false

## Multiplicadores separados dos pacotes: trocar/sincronizar não acumula bônus.
func _atualizar_bonus_conjuntos() -> void:
	var anterior: int = estatisticas.hp_maximo
	var bonus := Conjuntos.bonus_status(inventario.equipados)
	estatisticas.bonus_defesa_conjunto = float(bonus["defesa"])
	estatisticas.bonus_vitalidade_conjunto = float(bonus["vitalidade"])
	estatisticas.calcular_estatisticas_derivadas(usando_espada or usando_lanca)
	hp_atual = mini(hp_atual + maxi(estatisticas.hp_maximo - anterior, 0), estatisticas.hp_maximo)
	atualizar_barra_hp()

func _on_onda_completada(_onda: int) -> void:
	hp_atual = estatisticas.hp_maximo
	atualizar_barra_hp()
	inventario.salvar()

func iniciar_dash() -> void:
	var dir = _vetor_movimento()
	if dir == Vector2.ZERO:
		dir = _direcao_ataque
	dir = dir.normalized()

	esta_em_dash = true
	_dash_disponivel = false
	_gastar_stamina(custo_stamina_dash)
	Sons.tocar("dash")
	invulneravel = true
	temporizador_invul = duracao_dash
	velocity = dir * velocidade_dash
	_tempo_proximo_rastro = 0.0
	_direcao_ataque = dir
	_tocar_pose("esquiva", duracao_dash)

	await get_tree().create_timer(duracao_dash).timeout
	# Sai do dash com parte do impulso, para não parar seco
	velocity *= 0.35
	esta_em_dash = false

	await get_tree().create_timer(recarga_dash).timeout
	_dash_disponivel = true

func _gastar_stamina(quantidade: float) -> void:
	stamina = maxf(stamina - quantidade, 0.0)
	_espera_regeneracao = atraso_regeneracao_stamina
	_avisar_stamina()

func _regenerar_stamina(delta: float) -> void:
	if stamina >= stamina_maxima:
		return
	# Poção de fôlego: sem a espera depois de gastar e recupera mais rápido
	var folego := efeitos_pocao.bonus("folego") if efeitos_pocao != null else 0.0
	if _espera_regeneracao > 0.0 and folego <= 0.0:
		_espera_regeneracao -= delta
		return
	stamina = minf(stamina + regeneracao_stamina * (1.0 + folego) * delta, stamina_maxima)
	_avisar_stamina()

## O HUD deste jogador (cooperativo: cada um tem o seu na metade dele)
func grupo_hud() -> String:
	return "hud_p2" if eh_p2 else "hud_p1"

func _avisar_stamina() -> void:
	get_tree().call_group(grupo_hud(), "atualizar_stamina", stamina, stamina_maxima)

func _atualizar_dash(delta: float) -> void:
	_tempo_proximo_rastro -= delta
	if _tempo_proximo_rastro <= 0.0:
		_tempo_proximo_rastro = intervalo_rastro_dash
		_criar_rastro_dash()
	move_and_slide()
	animar()

# Copia os sprites visíveis do personagem no ponto atual e desvanece a cópia (afterimage)
func _criar_rastro_dash() -> void:
	var cena_atual := Cooperativo.cena_de(self)
	if cena_atual == null:
		return
	var rastro := Node2D.new()
	rastro.global_position = $CompositeSprites.global_position
	rastro.z_index = z_index - 1
	rastro.modulate = cor_rastro_dash
	for camada in [$CompositeSprites/BaseSprites, $CompositeSprites/Armaduras, no_arco, no_reacao]:
		if not camada.visible:
			continue
		for sprite in camada.get_children():
			if sprite is Sprite2D and sprite.visible and sprite.texture:
				var copia := Sprite2D.new()
				copia.texture = sprite.texture
				copia.hframes = sprite.hframes
				copia.vframes = sprite.vframes
				copia.frame = sprite.frame
				copia.flip_h = sprite.flip_h
				copia.flip_v = sprite.flip_v
				copia.position = camada.position + sprite.position
				copia.rotation = sprite.rotation
				copia.scale = sprite.scale
				copia.z_index = sprite.z_index
				copia.self_modulate = sprite.self_modulate * sprite.modulate
				rastro.add_child(copia)
	cena_atual.add_child(rastro)
	var tween := rastro.create_tween()
	tween.tween_property(rastro, "modulate:a", 0.0, duracao_rastro_dash)
	tween.tween_callback(rastro.queue_free)

func bloquear_ataques(bloquear: bool) -> void:
	ataques_bloqueados = bloquear

func carregar_conjunto_armadura(id_conjunto: int) -> void:
	var caminho_base := "res://assets/personagens/Armors/%d" % id_conjunto

	var caminho_cabeca   : String = "%s/head.png"   % caminho_base
	var caminho_corpo   : String = "%s/armor.png"  % caminho_base
	var caminho_luvas : String = "%s/gloves.png" % caminho_base
	var caminho_botas  : String = "%s/boots.png"  % caminho_base

	if ResourceLoader.exists(caminho_cabeca):
		sprite_armadura_cabeca.texture = load(caminho_cabeca)
	else:
		push_warning("[carregar_conjunto_armadura] head.png não encontrado em: " + caminho_cabeca)

	if ResourceLoader.exists(caminho_corpo):
		sprite_armadura_corpo.texture = load(caminho_corpo)
	else:
		push_warning("[carregar_conjunto_armadura] armor.png não encontrado em: " + caminho_corpo)
	if ResourceLoader.exists(caminho_luvas):
		sprite_armadura_luvas.texture = load(caminho_luvas)
	else:
		push_warning("[carregar_conjunto_armadura] gloves.png não encontrado em: " + caminho_luvas)

	if ResourceLoader.exists(caminho_botas):
		sprite_armadura_botas.texture = load(caminho_botas)
	else:
		push_warning("[carregar_conjunto_armadura] boots.png não encontrado em: " + caminho_botas)

func conectar_sinal_se_nao_conectado(no: Node, nome_sinal: String, metodo: String) -> void:
	if not no.is_connected(nome_sinal, Callable(self, metodo)):
		no.connect(nome_sinal, Callable(self, metodo))

func _physics_process(delta: float) -> void:
	if _interacao_bloqueada:
		pode_iniciar_interacao()
	_recarga_carrasco = maxf(_recarga_carrasco - delta, 0.0)
	_recarga_mordomo = maxf(_recarga_mordomo - delta, 0.0)
	_regenerar_stamina(delta)
	if petrificacao != null and petrificacao.atualizar(delta):
		_pedido_ataque = false
		velocity = Vector2.ZERO
		if invulneravel:
			temporizador_invul -= delta
			if temporizador_invul <= 0:
				invulneravel = false
		return
	if esta_sentado:
		_atualizar_sentado(delta)
		return
	# Caído no cooperativo: espera o parceiro, sem andar, atacar, rolar ou defender (antes seguia batendo nos inimigos)
	if caido:
		_pedido_ataque = false
		velocity = Vector2.ZERO
		return
	# Mesma escala de profundidade de inimigos, árvores e objetos (ver Profundidade)
	z_index = Profundidade.z_de(global_position.y + Profundidade.PES_JOGADOR)
	if seguindo_introducao and movimento_habilitado:
		_pedido_ataque = false
		defesa.cancelar()
		_mover_na_introducao(delta)
		return
	if not movimento_habilitado:
		_pedido_ataque = false
		defesa.cancelar()
		# Sem isso a velocidade da corrida fica congelada e a animação continua correndo com a loja aberta
		if not esta_forjando and velocity != Vector2.ZERO:
			velocity = Vector2.ZERO
			animar()
		return

	if Input.is_action_just_pressed("debug_damage"):
		receber_dano(1)

	if invulneravel:
		temporizador_invul -= delta
		if temporizador_invul <= 0:
			invulneravel = false


	# Durante a ação de fazenda o jogador fica parado: sem andar, atacar ou rolar
	if esta_em_acao_fazenda:
		_pedido_ataque = false
		velocity = Vector2.ZERO
		return

	if esta_em_dash:
		_atualizar_dash(delta)
		return

	if Input.is_action_just_pressed(acao("rolar")) and _dash_disponivel and not _esta_atacando and not esta_forjando \
			and Time.get_ticks_msec() >= _sem_acao_ate_ms:
		if stamina >= custo_stamina_dash:
			defesa.cancelar()
			iniciar_dash()
			return
		get_tree().call_group(grupo_hud(), "avisar_stamina_insuficiente")

	if temporizador_knockback > 0:
		temporizador_knockback -= delta
		velocity = _knockback
		_knockback = _knockback.lerp(Vector2.ZERO, _decaimento_knockback)
	elif defesa.atualizar(delta):
		pass   # em guarda (ou na escudada): só vira, não anda nem ataca
	else:
		mover()
		logica_combo_ataque()  # Chamado a cada frame

	move_and_slide()
	animar()

## Percorre a rota continuamente, com a animação e a colisão normais do personagem.
func _mover_na_introducao(delta: float) -> void:
	seguimento_bloqueado = false
	var antes := global_position
	var ultima_direcao := _direcao_ataque
	var restante := 100.0 * delta
	if is_instance_valid(alvo_introducao):
		restante = minf(restante, maxf(0, distancia_caminho_introducao() - 27))
	while not caminho_introducao.is_empty() and restante > 0:
		var diferenca := caminho_introducao[0] - position
		var comprimento := diferenca.length()
		if comprimento < 0.1:
			caminho_introducao.remove_at(0)
			continue
		var passo := minf(comprimento, restante)
		ultima_direcao = _cardinal_de(diferenca.normalized())
		var colisao := move_and_collide(diferenca.normalized() * passo)
		restante -= passo
		if colisao != null:
			seguimento_bloqueado = true
			break
		if passo >= comprimento:
			caminho_introducao.remove_at(0)
	velocity = (global_position - antes) / maxf(delta, 0.001)
	if velocity.length() > 0.1:
		_direcao_ataque = ultima_direcao
		_cardinal_anterior = ultima_direcao
		_arvore_animacao.set("parameters/idle/blend_position", _direcao_ataque)
		_arvore_animacao.set("parameters/running/blend_position", _direcao_ataque)
	animar()

## Comprimento do rastro: a distância em linha reta cortava as curvas do guia.
func distancia_caminho_introducao() -> float:
	var total := 0.0
	var anterior := position
	for ponto in caminho_introducao:
		total += anterior.distance_to(ponto)
		anterior = ponto
	return total

func parar_para_conversa(ponto: Vector2) -> void:
	velocity = Vector2.ZERO
	_direcao_ataque = _cardinal_de(ponto - global_position)
	_cardinal_anterior = _direcao_ataque
	virar_para(_direcao_ataque)
	_arvore_animacao.set("parameters/running/blend_position", _direcao_ataque)
	_maquina_estados.start("idle")
	_arvore_animacao.advance(0)

## Para onde o jogador aponta agora (direcional, analógico ou joystick); sem nada apertado, a última direção
func direcao_apontada() -> Vector2:
	var dir := _vetor_movimento()
	return dir.normalized() if dir.length() >= ZONA_MORTA_MIRA else _direcao_ataque

## A direção cardinal (cima, baixo, esquerda ou direita) mais próxima de `dir`. Na diagonal exata mantém o eixo do golpe anterior, para a
## mira não oscilar entre dois lados. Os golpes de espada e lança só existem nas quatro direções: na diagonal a animação misturava as
## duas (mostrava um lado e o golpe saía para o outro)
func _cardinal_de(dir: Vector2) -> Vector2:
	var ax := absf(dir.x)
	var ay := absf(dir.y)
	var horizontal := Vector2(signf(dir.x), 0.0)
	var vertical := Vector2(0.0, signf(dir.y))
	if absf(ax - ay) < 0.2:
		if _cardinal_anterior.x != 0.0 and signf(dir.x) == _cardinal_anterior.x:
			return _cardinal_anterior
		if _cardinal_anterior.y != 0.0 and signf(dir.y) == _cardinal_anterior.y:
			return _cardinal_anterior
		return horizontal if ax > 0.0 else vertical
	return horizontal if ax > ay else vertical

# Direção do próximo golpe: a que o jogador está apontando NESTE instante, em cardinal. Também vira o corpo para lá (parado e correndo)
func _apontar_golpe() -> void:
	_direcao_ataque = _cardinal_de(direcao_apontada())
	_cardinal_anterior = _direcao_ataque
	virar_para(_direcao_ataque)

func mover() -> void:
	# A mira acompanha o direcional mesmo no meio de um golpe (o golpe que já começou não muda; o próximo, enfileirado, sai para onde
	# ele aponta agora e não para onde apontava no começo do golpe anterior)
	var apontando := _vetor_movimento()
	if apontando.length() >= ZONA_MORTA_MIRA:
		_direcao_ataque = apontando.normalized()
	# Se o jogador está no meio de um ataque, não movimenta
	if _esta_atacando:
		velocity.x = lerp(velocity.x, 0.0, _friccao)
		velocity.y = lerp(velocity.y, 0.0, _friccao)
		return

	# Lê o input de movimento (teclas de andar)
	var dir = _vetor_movimento()

	if dir != Vector2.ZERO:
		# Normaliza a direção para não ficar maior que 1 em magnitude
		dir = dir.normalized()

		# **IMPORTANTE**: Atualiza a última direção de ataque
		_direcao_ataque = dir

		# Trocar o item da mão não altera a velocidade de deslocamento.
		var velocidade_base = 114.0
		var visual_gerado := get_node_or_null("HeroiGerado")
		if visual_gerado != null:
			velocidade_base = visual_gerado.velocidade_de_teste()

		# 2) Soma os bônus que já estão em estatisticas
		#    (quando compra item, incrementa estatisticas.bonus_velocidade_item)
		var bonus_velocidade_item = estatisticas.bonus_velocidade_item

		# 3) Soma também o bônus de agilidade, caso queira
		var bonus_agilidade = float(estatisticas.agilidade) * 1.5

		# 4) Soma tudo para obter a velocidade final
		var velocidade_final = min(velocidade_base + bonus_velocidade_item + bonus_agilidade, estatisticas.VELOCIDADE_MAXIMA)
		# 5) Poção de velocidade multiplica por cima (pode passar do teto enquanto dura)
		velocidade_final *= 1.0 + efeitos_pocao.bonus("velocidade")
		# O corpo Tiny em escala nativa pede um deslocamento menor por passada.
		if has_node("HeroiTiny"):
			velocidade_final *= HeroiTiny.MULTIPLICADOR_MOVIMENTO

		# Move interpolando a velocidade atual para a velocidade desejada
		velocity.x = lerp(velocity.x, dir.x * velocidade_final, _aceleracao)
		velocity.y = lerp(velocity.y, dir.y * velocidade_final, _aceleracao)

		_arvore_animacao.set("parameters/idle/blend_position", dir)
		_arvore_animacao.set("parameters/running/blend_position", dir)
	else:
		# Se não há input (dir == Vector2.ZERO), freia suavemente
		velocity.x = lerp(velocity.x, 0.0, _friccao)
		velocity.y = lerp(velocity.y, 0.0, _friccao)

# ---------------------------
# COMBO / ATAQUE
# ---------------------------
## Dentro da vista individual, o evento do controle já foi normalizado para as ações dos menus.
func acao_evento(nome: String) -> String:
	return nome if eh_p2 and get_viewport().has_meta("dono") else acao(nome)

func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_action_pressed(acao_evento("attack")):
		if Time.get_ticks_msec() >= _sem_acao_ate_ms:
			_pedido_ataque = true
	elif _cinto_de_pocoes_ativo():
		if evento.is_action_pressed(acao_evento("usar_pocao")):
			usar_pocao()
			get_viewport().set_input_as_handled()
		elif evento.is_action_pressed(acao_evento("ferramenta_proxima")):
			efeitos_pocao.trocar(1)
			get_viewport().set_input_as_handled()
		elif evento.is_action_pressed(acao_evento("ferramenta_anterior")):
			efeitos_pocao.trocar(-1)
			get_viewport().set_input_as_handled()
	elif modo_fazenda and _entrada_fazenda_fora_da_cena(evento):
		get_viewport().set_input_as_handled()

## Cooperativo: a fazenda de quem viajou sozinho fica num SubViewport sem entrada, e o Plantio de lá não ouvia o LB/RB
## nem o colher. Aí o jogador (que está na vista dele e recebe os eventos) repassa. Com a fazenda como cena principal o
## Plantio recebe direto e isto não faz nada.
func _entrada_fazenda_fora_da_cena(evento: InputEvent) -> bool:
	if evento.is_echo():
		return false
	var colher := evento.is_action_pressed(acao_evento("colher"))
	var passo := 0
	if evento.is_action_pressed(acao_evento("ferramenta_proxima")):
		passo = 1
	elif evento.is_action_pressed(acao_evento("ferramenta_anterior")):
		passo = -1
	if not colher and passo == 0:
		return false
	for plantio in get_tree().get_nodes_in_group("plantio_fazenda"):
		if plantio.get_world_2d() == get_world_2d() and plantio.get_viewport() != get_viewport():
			plantio.entrada_do_jogador(self, colher, passo)
			return true
	return false

## O cinto vale na arena e nos encontros de estrada, com o jogador vivo e sem tela aberta.
func _cinto_de_pocoes_ativo() -> bool:
	return efeitos_pocao != null and (gerenciador_ondas != null or Comercio.em_combate) and not modo_fazenda and not estaMorto \
			and movimento_habilitado and get_viewport().gui_get_focus_owner() == null

## Bebe a poção escolhida no cinto; se não deu, o HUD mostra o motivo
func usar_pocao() -> String:
	var motivo := efeitos_pocao.beber_selecionada()
	if motivo != "":
		Sons.tocar("erro", 0.0)
		get_tree().call_group(grupo_hud(), "avisar_pocao", motivo)
	return motivo

## Cura `quantidade` de vida (poção de cura), sem passar da máxima
func curar(quantidade: int) -> void:
	if estaMorto or quantidade <= 0:
		return
	hp_atual = mini(hp_atual + quantidade, estatisticas.hp_maximo)
	atualizar_barra_hp()

func logica_combo_ataque() -> void:
	var atacar := _pedido_ataque
	_pedido_ataque = false
	if ataques_bloqueados or estaMorto or caido or get_viewport().gui_get_focus_owner() != null:
		return
	if inventario.vara_na_mao:
		if atacar and movimento_habilitado and not esta_em_acao_fazenda and not esta_em_dash and not esta_sentado:
			preload("res://codigo/pesca/ponto_pesca.gd").tentar_lancar(self)
		return
	# Na fazenda o ataque vira "usar ferramenta" (quem decide e toca a animação é o Plantio)
	if modo_fazenda:
		if atacar and not esta_em_acao_fazenda:
			ferramenta_pedida.emit()
		return
	if picareta_arena_ativa:
		if atacar:
			for mineracao in get_tree().get_nodes_in_group("mineracao_arena"):
				if mineracao.get_world_2d()==get_world_2d():
					mineracao.pedir_golpe(self)
					break
		return
	# Durante a pose (sacar, esquiva, ferido) o jogador não ataca
	if no_reacao.visible:
		return

	if atacar:
		if _esta_atacando:
			ataque_enfileirado = true
		else:
			if usando_espada:
				# Aqui usamos os nomes e tempos de ataque da espada
				if _fase_combo == 0:
					_fase_combo = 1
					iniciar_slash_ataque("AtaqueEspadaSlash_1", _tempo_slash_1)
				elif _fase_combo == 1:
					_fase_combo = 2
					iniciar_slash_ataque("AtaqueEspadaSlash_2", _tempo_slash_2)
				elif _fase_combo == 2:
					_fase_combo = 3
					iniciar_slash_ataque("AtaqueEspadaSlash_3", _tempo_slash_3)
			elif usando_arco:
				_iniciar_disparo()
			# Caso queira manter a lógica de lança, deixe o bloco abaixo
			elif usando_lanca:
				if _fase_combo == 0:
					_fase_combo = 1
					iniciar_slash_ataque_lanca("AtaqueLancaSlash_2", _tempo_slash_lanca_2)
				elif _fase_combo == 1:
					_fase_combo = 2
					iniciar_slash_ataque_lanca("AtaqueLancaSlash_3", _tempo_slash_lanca_3)
				elif _fase_combo == 2:
					_fase_combo = 3
					iniciar_slash_ataque_lanca("AtaqueLancaSlash_1", _tempo_slash_lanca_1)

var _alvos_area_golpe := {}

func iniciar_slash_ataque_lanca(nome_anim: String, tempo_slash: float) -> void:
	_alvos_area_golpe.clear()
	# Ajusta a velocidade da animação se necessário (pode ser removido se não for desejado)
	reprodutor_anim.speed_scale = 0.2
	_apontar_golpe()
	_flash_golpe()
	Sons.tocar("golpe_lanca")
	_esta_atacando = true
	$AreaAtaque.monitoring = true
	$AreaAtaque.monitorable = true
	definir_sprites_visiveis(true)
	_arvore_animacao.set("parameters/%s/blend_position" % nome_anim, _direcao_ataque)
	_maquina_estados.travel(nome_anim)
	_temporizador.start(tempo_slash)
	_pode_encadear_combo = true

func _flash_golpe() -> void:
	EfeitosLuz.criar_flash(Cooperativo.cena_de(self), global_position + _direcao_ataque * 14.0,
			Color(1, 0.95, 0.8), 0.9, 0.7, 0.15)

func iniciar_slash_ataque(nome_anim: String, tempo_slash: float) -> void:
	_alvos_area_golpe.clear()
	_apontar_golpe()
	_flash_golpe()
	Sons.tocar("golpe_espada")
	_esta_atacando = true
	$AreaAtaque.monitoring = true
	$AreaAtaque.monitorable = true
	definir_sprites_visiveis(true)
	_arvore_animacao.set("parameters/%s/blend_position" % nome_anim, _direcao_ataque)
	_maquina_estados.travel(nome_anim)
	_temporizador.start(tempo_slash)
	_pode_encadear_combo = true
	var visual_gerado := get_node_or_null("HeroiGerado")
	if visual_gerado != null:
		visual_gerado.iniciar_ataque_espada(tempo_slash, false, maxi(1, _fase_combo))

func _on_temporizador_ataque_timeout() -> void:
	_esta_atacando = false
	$AreaAtaque.monitoring = false
	$AreaAtaque.monitorable = false
	definir_sprites_visiveis(false)
	reprodutor_anim.speed_scale = 1.0

	# Se houver um ataque enfileirado, processa-o imediatamente
	if ataque_enfileirado:
		ataque_enfileirado = false
		# Verifica se está usando a espada e continua o combo
		if usando_espada:
			if _fase_combo == 1:
				_fase_combo = 2
				iniciar_slash_ataque("AtaqueEspadaSlash_2", _tempo_slash_2)
			elif _fase_combo == 2:
				_fase_combo = 3
				iniciar_slash_ataque("AtaqueEspadaSlash_3", _tempo_slash_3)
			else:
				_fase_combo = 0  # Caso tenha chegado ao final ou algum erro, reinicia
		elif usando_lanca:
			# Lógica para lança (se necessário)
			if _fase_combo == 1:
				_fase_combo = 2
				iniciar_slash_ataque_lanca("AtaqueLancaSlash_3", _tempo_slash_lanca_3)
			elif _fase_combo == 2:
				_fase_combo = 3
				iniciar_slash_ataque_lanca("AtaqueLancaSlash_1", _tempo_slash_lanca_1)
			else:
				_fase_combo = 0
		return

	# Se não houver ataque enfileirado, reinicia o combo
	_fase_combo = 0

## O acerto normal (espada, lança ou flecha) pode invocar um raio aliado. O raio não passa por aplicar_golpe,
## portanto não gera outro raio, crítico, roubo de vida nem encantamentos em cadeia.
func _tentar_raio_carrasco(alvo: Node2D, dano_golpe: int, sorteio: float = -1.0) -> bool:
	if Carrasco.TIPO_BONUS != "raio":
		return false
	if not is_instance_valid(alvo) or not is_inside_tree() or estaMorto:
		return false
	var valor := _rng_carrasco.randf() if sorteio < 0.0 else sorteio
	if not Carrasco.pode_ativar(inventario.equipados, _recarga_carrasco, valor):
		return false
	var cena := Cooperativo.cena_de(self)
	if cena == null:
		return false
	_recarga_carrasco = Carrasco.RECARGA_RAIO
	var raio := RaioCarrasco.new()
	raio.fracao_dano_chefe = 1.0
	raio.add_to_group("raios_carrasco")
	cena.add_child(raio)
	raio.iniciar(alvo.global_position, Carrasco.AVISO_RAIO, maxi(1, roundi(dano_golpe * Carrasco.MULT_DANO_RAIO * Conjuntos.fator_nivel(Carrasco, inventario.equipados))), 0)
	return true

func _tentar_congelamento_mordomo(alvo: Node, sorteio: float = -1.0) -> bool:
	if estaMorto or not is_instance_valid(alvo) or not alvo.has_method("aplicar_congelamento"):
		return false
	if "esta_morto" in alvo and alvo.esta_morto:
		return false
	var valor := _rng_mordomo.randf() if sorteio < 0 else sorteio
	if Mordomo.TIPO_BONUS != "congelamento" or not Mordomo.pode_ativar(inventario.equipados, _recarga_mordomo, valor):
		return false
	_recarga_mordomo = Mordomo.RECARGA_BONUS
	alvo.aplicar_congelamento(Mordomo.DURACAO_BONUS)
	return true

func _on_timeout_janela_combo() -> void:
	_fase_combo = 0  # Reseta o combo independente do estágio
	_pode_encadear_combo = false

# ---------------------------
# Animação
# ---------------------------
func animar() -> void:
	# A forja e a cadeira têm pose própria: abrir uma tela por perto (portal, mochila) não pode trocar para "parado"
	if esta_forjando or esta_sentado:
		return
	# O deslocamento guiado também usa a corrida, independentemente do item na mão.
	if seguindo_introducao:
		_maquina_estados.travel("running" if velocity.length() > 2 else "idle")
		return
	if _esta_atacando:
		return
	if velocity.length() > 2:
		_maquina_estados.travel("running")
	else:
		_maquina_estados.travel("idle")

func _on_corpo_entrou_area_ataque(corpo: Node2D) -> void:
	if corpo.is_in_group("enemy"):
		aplicar_golpe(corpo, (corpo.position - position).normalized())

func _on_area_entrou_area_ataque(area: Area2D) -> void:
	if area.is_in_group("hurtbox_inimigo"):
		var alvo := area.get_parent() as Node2D
		if alvo == null or not alvo.is_in_group("enemy"):
			return
		var id := alvo.get_instance_id()
		if _alvos_area_golpe.has(id):
			return
		_alvos_area_golpe[id] = true
		aplicar_golpe(alvo, (alvo.global_position - global_position).normalized())
		return
	if area.is_in_group("enemy"):
		aplicar_golpe(area, (area.global_position - position).normalized())

func _aplicar_encantamento(alvo: Node, dano_golpe: int) -> void:
	var arma = inventario.equipados.get("arma")
	if arma == null or arma.encantamento == "" or not is_instance_valid(alvo):
		return
	var tipo: String = arma.encantamento
	var efeito := Encantamentos.efeito(tipo, arma.nivel_encantamento)
	var cor := Encantamentos.cor(tipo)
	match tipo:
		"fogo":
			if alvo.has_method("aplicar_queimadura"):
				alvo.aplicar_queimadura(efeito["dano_tick"], efeito["intervalo"], efeito["duracao"], cor)
		"gelo":
			if alvo.has_method("aplicar_lentidao"):
				alvo.aplicar_lentidao(efeito["lentidao"], efeito["duracao"])
		"raio":
			_saltar_raio(alvo, maxi(1, roundi(dano_golpe * efeito["fracao_dano"])), efeito["alcance"], cor)
		"eletrico":
			if alvo.has_method("receber_dano_efeito"):
				alvo.receber_dano_efeito(maxi(1, roundi(dano_golpe * efeito["fracao_dano"])), cor)
			if is_instance_valid(alvo) and alvo.has_method("atordoar") and randf() < efeito["chance_paralisia"]:
				alvo.atordoar(efeito["paralisia"])

func _saltar_raio(origem: Node2D, dano_raio: int, alcance: float, cor: Color) -> void:
	var alvo_raio: Node2D = null
	var menor := alcance
	for inimigo in get_tree().get_nodes_in_group("enemy"):
		if inimigo == origem or not (inimigo is Node2D) or inimigo.get("esta_morto"):
			continue
		var distancia := origem.global_position.distance_to(inimigo.global_position)
		if distancia < menor:
			menor = distancia
			alvo_raio = inimigo
	if alvo_raio == null or not alvo_raio.has_method("receber_dano_efeito"):
		return
	_desenhar_raio(origem.global_position, alvo_raio.global_position, cor)
	alvo_raio.receber_dano_efeito(dano_raio, cor)

func _desenhar_raio(de: Vector2, ate: Vector2, cor: Color) -> void:
	var linha := Line2D.new()
	linha.width = 1.5
	linha.default_color = cor
	linha.z_index = Profundidade.Z_TOPO
	var passos := 6
	var normal := (ate - de).orthogonal().normalized()
	for i in passos + 1:
		var t := float(i) / passos
		var desvio := 0.0 if i == 0 or i == passos else randf_range(-4.0, 4.0)
		linha.add_point(de.lerp(ate, t) + normal * desvio)
	Cooperativo.cena_de(self).add_child(linha)
	var tween := linha.create_tween()
	tween.tween_property(linha, "modulate:a", 0.0, 0.2)
	tween.tween_callback(linha.queue_free)

## mult_dano e mult_empurrao: a escudada (defesa_jogador.gd) bate mais forte e empurra mais que o golpe da arma
func aplicar_golpe(alvo: Node, direcao_knockback: Vector2, mult_dano: float = 1.0, mult_empurrao: float = 1.0, disparo: Dictionary = {}) -> void:
	if not alvo.has_method("receber_dano"):
		return
	if "esta_morto" in alvo and alvo.esta_morto:
		return
	var golpe: Dictionary = disparo.get("golpe", estatisticas.calcular_dano_golpe()).duplicate()
	var tipo: String = disparo.get("tipo", inventario.equipados.arma.tipo if inventario.equipados.arma != null else "")
	var distancia: float = disparo.get("distancia", global_position.distance_to(alvo.global_position))
	var contra: bool = tipo == "espada_basica" and Time.get_ticks_msec() < contragolpe_ate_ms and mult_dano == 1.0
	var estilo := preload("res://codigo/dados/estilos_arma.gd").efeito(tipo, _fase_combo, distancia, contra) if mult_dano == 1.0 else {"dano":1.0,"empurrao":1.0,"atordoar":0.0}
	if contra: contragolpe_ate_ms = 0
	mult_dano *= float(estilo.dano)
	mult_empurrao *= float(estilo.empurrao)
	# Poção de força
	golpe["dano"] = maxi(1, roundi(golpe["dano"] * (1.0 + float(disparo.get("forca", efeitos_pocao.bonus("forca")))) * mult_dano))
	var forca = (225.0 if golpe["critico"] else 150.0) * mult_empurrao
	alvo.receber_dano(golpe["dano"], direcao_knockback * forca)
	if is_instance_valid(alvo) and float(estilo.atordoar) > 0 and alvo.has_method("atordoar"):
		alvo.atordoar(float(estilo.atordoar))
	# Toque leve a cada acerto; o crítico pesa mais
	Controle.vibrar(0.0, 0.5 if golpe["critico"] else 0.2, 0.07, self)
	_aplicar_encantamento(alvo, golpe["dano"])
	_tentar_raio_carrasco(alvo, golpe["dano"])
	_tentar_congelamento_mordomo(alvo)
	if estatisticas.roubo_vida > 0:
		var percentual = min(estatisticas.roubo_vida, estatisticas.ROUBO_VIDA_MAXIMO) / 100.0
		var cura = max(1, int(round(golpe["dano"] * percentual)))
		hp_atual = min(hp_atual + cura, estatisticas.hp_maximo)
		atualizar_barra_hp()
	# Poção vampírica: soma por fora do roubo de vida dos itens
	var vampiro := efeitos_pocao.bonus("vampiro")
	if vampiro > 0.0:
		curar(maxi(1, roundi(golpe["dano"] * vampiro)))

# ---------------------------
# Visibilidade dos sprites
# ---------------------------
## As armas equipadas acompanham o movimento nas costas até o início do golpe.
const ARMAS_NAS_COSTAS := true

func definir_sprites_visiveis(esta_atacando: bool) -> void:
	sprite_corpo.visible = not esta_atacando
	sprite_cabelo.visible = not esta_atacando
	sprite_roupa.visible = not esta_atacando

	sprite_espada.visible = _armas_nas_costas() and (not esta_atacando) and usando_espada
	sprite_lanca.visible = _armas_nas_costas() and (not esta_atacando) and usando_lanca

	# Escudo só aparece se usando escudo E NÃO está atacando e NÃO está usando lança
	sprite_escudo.visible = _armas_nas_costas() and (not esta_atacando) and usando_escudo and not usando_lanca

	# -- Animação de ataque com espada --
	corpo_espada_escudo_ataque.visible = esta_atacando and usando_espada
	braco_espada_ataque.visible = esta_atacando and usando_espada
	escudo_ataque.visible = esta_atacando and usando_escudo and usando_espada  # Ajuste aqui
	cabelo_ataque.visible = esta_atacando and usando_espada
	roupa_ataque.visible = esta_atacando and usando_espada

	# -- Animação de ataque com lança --
	corpo_lanca_escudo_ataque.visible = esta_atacando and usando_lanca
	braco_lanca_ataque.visible = esta_atacando and usando_lanca
	cabelo_lanca_ataque.visible = esta_atacando and usando_lanca
	roupa_lanca_ataque.visible = esta_atacando and usando_lanca

# ---------------------------
# CUSTOMIZAÇÃO
# ---------------------------
## Põe o cabelo e a roupa (índices de Aparencia) em todas as camadas do personagem: andar, golpes de espada e lança, forja e sentado
## (as de fazenda, arco e reação se atualizam sozinhas ao tocar, lendo cabelo_atual e roupa_atual)
var _pecas_cavaleiro_debug := 15
var pecas_cavaleiro: int:
	get:
		if not Aparencia.raiz_armadura_visual(roupa_atual).is_empty():
			return _pecas_cavaleiro_debug
		return Conjuntos.mascara(inventario.equipados)
	set(valor):
		_pecas_cavaleiro_debug = valor & 15

var raizes_armadura: Dictionary:
	get:
		if not Aparencia.raiz_armadura_visual(roupa_atual).is_empty():
			return {}
		return Conjuntos.raizes(inventario.equipados)

## Liga/desliga uma peça visual mantendo as outras equipadas.
func definir_peca_cavaleiro(peca: String, ativa: bool) -> void:
	if not Aparencia.PECAS_CAVALEIRO.has(peca):
		return
	var bit: int = Aparencia.PECAS_CAVALEIRO[peca]
	pecas_cavaleiro = (pecas_cavaleiro | bit) if ativa else (pecas_cavaleiro & ~bit)
	_aplicar_aparencia()

func definir_aparencia(cabelo: int, roupa: int) -> void:
	cabelo_atual = Aparencia.indice_cabelo(cabelo)
	roupa_atual = Aparencia.indice_roupa(roupa)
	_aplicar_aparencia()

func _armas_nas_costas() -> bool:
	return ARMAS_NAS_COSTAS

func _aplicar_aparencia() -> void:
	if sprite_corpo:
		Aparencia.aplicar_corpo(sprite_corpo, "andar", roupa_atual, pecas_cavaleiro, raizes_armadura)
	if corpo_espada_escudo_ataque:
		Aparencia.aplicar_corpo(corpo_espada_escudo_ataque, "espada", roupa_atual, pecas_cavaleiro, raizes_armadura)
	if corpo_lanca_escudo_ataque:
		Aparencia.aplicar_corpo(corpo_lanca_escudo_ataque, "lanca", roupa_atual, pecas_cavaleiro, raizes_armadura)
	Aparencia.aplicar_cabelo(sprite_cabelo, cabelo_atual, "andar", roupa_atual, pecas_cavaleiro, raizes_armadura)
	Aparencia.aplicar_roupa(sprite_roupa, roupa_atual, "andar", pecas_cavaleiro, raizes_armadura)
	Aparencia.aplicar_cabelo(cabelo_ataque, cabelo_atual, "espada", roupa_atual, pecas_cavaleiro, raizes_armadura)
	Aparencia.aplicar_roupa(roupa_ataque, roupa_atual, "espada", pecas_cavaleiro, raizes_armadura)
	Aparencia.aplicar_cabelo(cabelo_lanca_ataque, cabelo_atual, "lanca", roupa_atual, pecas_cavaleiro, raizes_armadura)
	Aparencia.aplicar_roupa(roupa_lanca_ataque, roupa_atual, "lanca", pecas_cavaleiro, raizes_armadura)
	definir_cor_cabelo(cor_cabelo)
	if sprite_cabelo_forja:
		aplicar_dados_forja()
		if esta_sentado:
			_aplicar_roupa_sentado()

func adicionar_moedas(quantidade: int) -> void:
	DadosJogo.moedas += quantidade
	atualizar_rotulo_moedas()

func gastar_moedas(quantidade: int) -> void:
	DadosJogo.gastar_de(self, mini(quantidade, DadosJogo.moedas_de(self)))

func atualizar_rotulo_moedas() -> void:
	DadosJogo.atualizar_ui_moedas()

# ---------------------------
# FUNÇÕES DE EQUIPAR/DESEQUIPAR
# ---------------------------
func atualizar_dano_arma() -> void:
	var dados := {}
	if usando_espada:
		dados = status_armas.obter_dados_nivel_arma(id_arma_atual, nivel_espada)
	elif usando_lanca:
		dados = status_armas.obter_dados_nivel_arma(id_lanca_atual, nivel_lanca)
	elif usando_arco:
		dados = status_armas.obter_dados_nivel_arma(id_arco_atual, nivel_arco)
	# A raridade da arma EM USO multiplica o dano do nível (Raridades.escalar)
	var empunhada = inventario.equipados.get("arma")
	var raridade: String = empunhada.raridade if empunhada != null else "comum"
	estatisticas.dano_arma = Raridades.escalar(int(dados.get("dano", 0)), raridade)
	estatisticas.calcular_estatisticas_derivadas(usando_espada or usando_lanca)

func equipar_espada() -> void:
	# Se já estiver usando espada, remover
	if usando_espada:
		desequipar_espada()
		return

	# Se estiver usando lança, remover antes
	if usando_lanca:
		desequipar_lanca()
	if usando_arco:
		desequipar_arco()

	tipo_item_atual = ""
	usando_espada = true
	eh_arma_duas_maos = false
	atualizar_texturas_espada()
	sprite_espada.visible = _armas_nas_costas()
	atualizar_dano_arma()
	_tocar_pose("sacar")
	emit_signal("equipamento_alterado")

func desequipar_espada() -> void:
	if usando_espada:
		_tocar_pose("guardar")
	usando_espada = false
	sprite_espada.visible = false
	atualizar_dano_arma()
	emit_signal("equipamento_alterado")

func equipar_lanca() -> void:
	if usando_lanca:
		desequipar_lanca()
		return

	if usando_espada:
		desequipar_espada()

	if usando_arco:
		desequipar_arco()

	if usando_escudo:
		desequipar_escudo()

	tipo_item_atual = "lanca_basica"
	usando_lanca = true
	eh_arma_duas_maos = true
	atualizar_dano_arma()
	atualizar_texturas_lanca()
	sprite_lanca.visible = _armas_nas_costas()
	_tocar_pose("sacar")
	emit_signal("equipamento_alterado")

func desequipar_lanca() -> void:
	if usando_lanca:
		_tocar_pose("guardar")
	usando_lanca = false
	eh_arma_duas_maos = false
	sprite_lanca.visible = false
	atualizar_dano_arma()
	emit_signal("equipamento_alterado")

func equipar_arco() -> void:
	if usando_arco:
		desequipar_arco()
		return
	if usando_espada:
		desequipar_espada()
	if usando_lanca:
		desequipar_lanca()
	# Arco usa as duas mãos
	if usando_escudo:
		desequipar_escudo()

	tipo_item_atual = id_arco_atual
	usando_arco = true
	eh_arma_duas_maos = true
	atualizar_dano_arma()
	atualizar_texturas_arco()
	sprite_espada.visible = false
	sprite_escudo.visible = true
	_atualizar_visual_arco()
	_tocar_pose("sacar")
	emit_signal("equipamento_alterado")

func desequipar_arco() -> void:
	if not usando_arco:
		return
	_tocar_pose("guardar")
	usando_arco = false
	eh_arma_duas_maos = false
	if _esta_atacando:
		_esta_atacando = false
	no_arco.parar_disparo()
	sprite_espada.visible = false
	sprite_escudo.visible = false
	_atualizar_visual_arco()
	atualizar_dano_arma()
	emit_signal("equipamento_alterado")

# Com o arco: andando, BaseSprites + arco/aljava de no_arco; disparando, no_arco desenha o personagem inteiro
func _atualizar_visual_arco() -> void:
	var forja_ou_cadeira: bool = esta_forjando or esta_sentado
	var em_pose: bool = no_reacao.visible and not forja_ou_cadeira
	var disparando: bool = usando_arco and no_arco.esta_disparando()
	var na_fazenda: bool = esta_em_acao_fazenda
	no_arco.visible = usando_arco and not forja_ou_cadeira and not em_pose and not na_fazenda
	$CompositeSprites/BaseSprites.visible = not forja_ou_cadeira and not em_pose and not disparando and not na_fazenda
	if forja_ou_cadeira:
		no_reacao.visible = false

# Família visual das poses da página 1; vazio se estiver desarmado
func _familia_das_poses() -> String:
	if usando_arco:
		return "arco"
	if usando_lanca:
		return "lanca"
	if usando_espada:
		return "um_mao"
	return ""

# Lê o equipamento atual, então "guardar" deve ser chamado antes de zerar as flags
## Troca rápida pela barra de baixo: troca a arma na hora, sem a pose de sacar/guardar (ver barra_armas.gd)
var troca_sem_pose: bool = false

func _tocar_pose(pose: String, duracao: float = 0.25) -> void:
	if troca_sem_pose and (pose == "sacar" or pose == "guardar"):
		return
	var familia := _familia_das_poses()
	if familia == "" or not _inventario_pronto or esta_forjando or esta_sentado or _esta_atacando or estaMorto:
		return
	var id_arma := id_arma_atual
	var nivel := nivel_espada
	match familia:
		"lanca":
			id_arma = id_lanca_atual
			nivel = nivel_lanca
		"arco":
			id_arma = id_arco_atual
			nivel = nivel_arco
	var nivel_do_escudo := nivel_escudo if (usando_escudo and familia == "um_mao") else 0
	no_reacao.tocar(pose, _direcao_ataque, familia, id_arma, nivel, nivel_do_escudo, duracao)
	_atualizar_visual_arco()

## Pode levantar a guarda agora? (armado, solto, sem tela aberta nem outra ação em andamento)
func pode_aparar() -> bool:
	if estaMorto or esta_sentado or esta_forjando or esta_em_dash or _esta_atacando or esta_em_acao_fazenda or modo_fazenda \
			or ataques_bloqueados or not movimento_habilitado or temporizador_knockback > 0.0:
		return false
	if not _inventario_pronto or _familia_das_poses() == "" or no_reacao.visible or Time.get_ticks_msec() < _sem_acao_ate_ms:
		return false
	return get_viewport().gui_get_focus_owner() == null

## Liga/desliga a AnimationTree. Desligada, ela para de reescrever os quadros das camadas (quem desenha à mão, como a escudada, precisa)
func pausar_animacoes(pausar: bool) -> void:
	if _arvore_animacao == null:
		return
	_arvore_animacao.active = not pausar
	if not pausar and _maquina_estados:
		_maquina_estados.travel("idle")

func tocar_pose_aparar() -> void:
	_tocar_pose("aparar")

## Vira o personagem parado para `dir` (a pose de parado e a de correr passam a olhar para lá)
func virar_para(dir: Vector2) -> void:
	_arvore_animacao.set("parameters/idle/blend_position", dir)
	_arvore_animacao.set("parameters/running/blend_position", dir)

func atualizar_texturas_arco() -> void:
	var dados_nivel: Dictionary = status_armas.obter_dados_nivel_arma(id_arco_atual, nivel_arco)
	if dados_nivel.has("textura") and dados_nivel.has("textura_ataque"):
		no_arco.configurar(dados_nivel["textura"], dados_nivel["textura_ataque"])
	# Andando, só a aljava aparece: um sprite solto no nó do escudo, movido pela animação.
	# O arco só é desenhado durante o disparo (no_arco).
	ObjetosRefinados.aplicar(sprite_escudo, TEXTURA_ALJAVA)

func _iniciar_disparo() -> void:
	var mira := _mira_do_disparo()
	_direcao_ataque = mira
	# Depois do disparo o corpo volta olhando para onde mirou
	_arvore_animacao.set("parameters/idle/blend_position", mira)
	_arvore_animacao.set("parameters/running/blend_position", mira)
	_esta_atacando = true
	var tempo: float = status_armas.armas[id_arco_atual].get("tempo_disparo", 0.65)
	no_arco.disparar(mira, tempo)
	_atualizar_visual_arco()

# Mira no inimigo vivo mais próximo ao alcance; sem alvo, segue a última direção de movimento
func _mira_do_disparo() -> Vector2:
	var menor := ALCANCE_MIRA_ARCO
	var apontada := direcao_apontada()
	var apontando := _vetor_movimento().length() >= ZONA_MORTA_MIRA
	var mira := apontada
	for inimigo in get_tree().get_nodes_in_group("enemy"):
		if not (inimigo is Node2D) or inimigo.get("esta_morto"):
			continue
		var para: Vector2 = inimigo.global_position - global_position
		var distancia := para.length()
		if distancia >= menor:
			continue
		# Apontando para um lado, o inimigo nas costas dele não rouba a flecha
		if apontando and para.normalized().dot(apontada) < COSSENO_CONE_MIRA:
			continue
		menor = distancia
		mira = para.normalized()
	return mira

func _ao_disparo_liberado(direcao: Vector2) -> void:
	# Arcos de várias flechas (o longo atira 3): saem em leque, centradas na mira
	var dados_arco: Dictionary = status_armas.armas.get(id_arco_atual, {})
	var quantidade: int = maxi(int(dados_arco.get("flechas", 1)), 1)
	var abertura := deg_to_rad(float(dados_arco.get("abertura_graus", 0.0)))
	for i in quantidade:
		var rumo := direcao.rotated((float(i) - float(quantidade - 1) / 2.0) * abertura)
		var flecha := Flecha.new()
		Cooperativo.cena_de(self).add_child(flecha)
		flecha.global_position = global_position + Vector2(0, 2) + rumo * 12.0
		flecha.iniciar(self, rumo)
	Sons.tocar("flecha")

func _ao_disparo_terminado() -> void:
	_esta_atacando = false
	_atualizar_visual_arco()
	var repetir := ataque_enfileirado or Input.is_action_pressed(acao("attack"))
	ataque_enfileirado = false
	if repetir and usando_arco and not ataques_bloqueados and movimento_habilitado and get_viewport().gui_get_focus_owner() == null:
		_iniciar_disparo()

func equipar_escudo() -> void:
	if usando_escudo:
		desequipar_escudo()
		return
	if not inventario.escudo_ativo():
		return

	usando_escudo = true
	sprite_escudo.visible = _armas_nas_costas()
	atualizar_texturas_escudo()
	_escudo_aplicado = inventario.equipados.get("escudo")
	_aplicar_bonus_item("escudo", _escudo_aplicado)
	emit_signal("equipamento_alterado")

func desequipar_escudo() -> void:
	if not usando_escudo:
		return

	_escudo_aplicado = null
	_aplicar_bonus_item("escudo", null)

	usando_escudo = false
	sprite_escudo.visible = false
	emit_signal("equipamento_alterado")

## O que o item equipado soma aos status: vida e defesa do escudo (do nível, vezes o multiplicador da raridade) e os afixos da raridade
## (arma e escudo). Um item nulo não soma nada
func _pacote_do_item(item: DadosItem) -> Dictionary:
	var pacote := {"vitalidade": 0, "defesa": 0, "critico": 0.0, "dano_critico": 0.0, "roubo_vida": 0, "velocidade": 0.0}
	if item == null:
		return pacote
	if item.categoria == "escudo":
		var dados: Dictionary = status_armas.obter_dados_nivel_arma(item.tipo, item.nivel)
		pacote["vitalidade"] = Raridades.escalar(int(dados.get("bonus_vitalidade", 0)), item.raridade)
		pacote["defesa"] = Raridades.escalar(int(dados.get("bonus_defesa", 0)), item.raridade)
	elif item.categoria in ["cabeca", "corpo", "luvas", "botas"]:
		var dados: Dictionary = status_armas.obter_dados_nivel_armadura(item.tipo, item.nivel)
		pacote["vitalidade"] = Raridades.escalar(int(dados.get("bonus_vitalidade", 0)), item.raridade)
		pacote["defesa"] = Raridades.escalar(int(dados.get("bonus_defesa", 0)), item.raridade)
	pacote["vitalidade"] += roundi(item.afixo("vitalidade"))
	pacote["defesa"] += roundi(item.afixo("defesa"))
	pacote["critico"] = item.afixo("critico")
	pacote["dano_critico"] = item.afixo("dano_critico")
	pacote["roubo_vida"] = roundi(item.afixo("roubo_vida"))
	pacote["velocidade"] = item.afixo("velocidade")
	return pacote

## Troca o que cada slot soma aos status: tira exatamente o pacote anterior e põe o do item novo. Único caminho
## destes bônus, então equipar, trocar, desequipar e subir de nível do escudo ou da arma nunca deixam sobras
func _aplicar_bonus_item(slot: String, item: DadosItem) -> void:
	var antigo: Dictionary = _pacote_aplicado[slot]
	var novo := _pacote_do_item(item)
	var hp_maximo_anterior: int = estatisticas.hp_maximo
	var dif_vitalidade: int = int(novo["vitalidade"]) - int(antigo.get("vitalidade", 0))
	var dif_defesa: int = int(novo["defesa"]) - int(antigo.get("defesa", 0))
	bonus_vitalidade += dif_vitalidade
	vitalidade_atual = vitalidade_base + bonus_vitalidade
	estatisticas.vitalidade = vitalidade_atual
	bonus_defesa += dif_defesa
	estatisticas.defesa = bonus_defesa
	estatisticas.bonus_critico += float(novo["critico"]) - float(antigo.get("critico", 0.0))
	estatisticas.bonus_dano_critico += float(novo["dano_critico"]) - float(antigo.get("dano_critico", 0.0))
	estatisticas.roubo_vida += int(novo["roubo_vida"]) - int(antigo.get("roubo_vida", 0))
	estatisticas.bonus_velocidade_item += float(novo["velocidade"]) - float(antigo.get("velocidade", 0.0))
	_pacote_aplicado[slot] = novo
	estatisticas.calcular_estatisticas_derivadas(usando_espada or usando_lanca)
	# Mais vida máxima enche a vida na mesma medida (como ao vestir o escudo antes); menos só limita
	hp_atual = mini(hp_atual + maxi(estatisticas.hp_maximo - hp_maximo_anterior, 0), estatisticas.hp_maximo)
	atualizar_barra_hp()

# ---------------------------
# COMPRAS
# ---------------------------
func aplicar_efeitos_item(dados_item: Dictionary) -> void:
	if not dados_item.has("efeitos"):
		return
	var hp_maximo_anterior = estatisticas.hp_maximo
	for chave_efeito in dados_item.efeitos.keys():
		var valor_efeito = dados_item.efeitos[chave_efeito]
		match chave_efeito:
			"forca":
				estatisticas.forca += valor_efeito
			"defesa":
				# Esse bônus se soma a defesa base
				bonus_defesa += valor_efeito
				estatisticas.defesa = bonus_defesa
			"agilidade":
				estatisticas.agilidade += valor_efeito
			"vitalidade":
				# Mesmo caminho do bônus do escudo, senão o próximo equipar/desequipar sobrescreve
				bonus_vitalidade += valor_efeito
				vitalidade_atual = vitalidade_base + bonus_vitalidade
				estatisticas.vitalidade = vitalidade_atual
			"roubo_vida":
				estatisticas.roubo_vida += valor_efeito
			"sorte":
				estatisticas.sorte += valor_efeito
			_:
				pass
	estatisticas.calcular_estatisticas_derivadas(usando_espada or usando_lanca)
	hp_atual = min(hp_atual + max(estatisticas.hp_maximo - hp_maximo_anterior, 0), estatisticas.hp_maximo)
	atualizar_barra_hp()

# ---------------------------
# DANO / MORTE
# ---------------------------
# ---------------------------
# AÇÕES DE FAZENDA
# ---------------------------
## Toca uma ação de fazenda ("enxada", "machado", "picareta", "plantar", "regar", "colher") virada para a
## última direção. Retorna false se o jogador estiver ocupado (atacando, rolando, forjando, em menu...)
func acao_fazenda(acao: String) -> bool:
	if not FazendaJogador.ACOES.has(acao):
		return false
	if estaMorto or esta_forjando or esta_sentado or esta_em_dash or _esta_atacando or esta_em_acao_fazenda or not movimento_habilitado:
		return false
	if usando_arco and no_arco.esta_disparando():
		return false
	esta_em_acao_fazenda = true
	velocity = Vector2.ZERO
	no_reacao.visible = false
	no_fazenda.tocar(acao, _direcao_ataque)
	_atualizar_visual_arco()
	return true

## Ponto do chão à frente dos pés, na direção em que o jogador está virado (alvo da enxada, do regador...)
func ponto_acao_fazenda() -> Vector2:
	var linha := ArcoJogador.linha_da_direcao(_direcao_ataque)
	var frente: Vector2 = [Vector2.DOWN, Vector2.UP, Vector2.RIGHT, Vector2.LEFT][linha]
	return global_position + Vector2(0, Profundidade.PES_JOGADOR) + frente * ALCANCE_ACAO_FAZENDA

func cancelar_acao_fazenda() -> void:
	if not esta_em_acao_fazenda:
		return
	no_fazenda.parar()
	esta_em_acao_fazenda = false
	_atualizar_visual_arco()

func _ao_impacto_fazenda(acao: String) -> void:
	acao_fazenda_impacto.emit(acao, ponto_acao_fazenda())

func _ao_fim_acao_fazenda(acao: String) -> void:
	esta_em_acao_fazenda = false
	_atualizar_visual_arco()
	acao_fazenda_concluida.emit(acao)

func aplicar_petrificacao(duracao: float) -> bool:
	if petrificacao == null:
		petrificacao = PetrificacaoJogador.new()
		petrificacao.name = "Petrificacao"
		add_child(petrificacao)
	return petrificacao.aplicar(duracao)

func esta_petrificado() -> bool:
	return petrificacao != null and (petrificacao.restante > 0 or petrificacao._esfarelando)

func aplicar_petrificacao_fatal() -> bool:
	if petrificacao == null:
		petrificacao = PetrificacaoJogador.new()
		petrificacao.name = "Petrificacao"
		add_child(petrificacao)
	return petrificacao.aplicar(0.65, true)

func receber_dano(dano: int, forca_knockback: Vector2 = Vector2.ZERO) -> void:
	if invulneravel or estaMorto:
		return
	# Guarda levantada: aparo perfeito anula o golpe e bloqueio deixa passar só uma fração (defesa_jogador.gd)
	var guarda := defesa.resolver(dano, forca_knockback)
	var tipo_guarda: String = guarda.get("tipo", "")
	if tipo_guarda == "perfeito":
		return
	var bloqueado := tipo_guarda == "bloqueio"
	if bloqueado:
		dano = guarda["dano"]
		forca_knockback = guarda["knockback"]
	# Levar dano interrompe a ação de fazenda
	cancelar_acao_fazenda()
	# Poção de pedra soma na redução da defesa
	var reducao := minf(estatisticas.reducao_dano() + efeitos_pocao.bonus("pedra"), REDUCAO_MAXIMA_COM_POCAO)
	var dano_final = max(1, int(round(dano * (1.0 - reducao))))
	hp_atual = max(hp_atual - dano_final, 0)
	invulneravel = true
	temporizador_invul = tempo_invul
	atualizar_barra_hp()
	# O controle vibra mais forte quanto maior o pedaço da vida que o golpe levou
	var forca_vibracao := clampf(0.3 + float(dano_final) / maxf(estatisticas.hp_maximo, 1.0) * 3.0, 0.3, 1.0)
	Controle.vibrar(forca_vibracao * 0.6, forca_vibracao, 0.15 + forca_vibracao * 0.15, self)
	if forca_knockback != Vector2.ZERO:
		aplicar_knockback(forca_knockback)
	if hp_atual <= 0:
		morrer()
	elif not bloqueado and not esta_petrificado():
		Sons.tocar("jogador_dano")
		_tocar_pose("ferido", 0.3)

func atualizar_barra_hp() -> void:
	get_tree().call_group(grupo_hud(), "atualizar_vida", hp_atual, estatisticas.hp_maximo)

func receber_hitkill_dragao() -> void:
	receber_hitkill_chefe()

func receber_hitkill_chefe() -> void:
	if estaMorto:
		return
	hp_atual = 0
	atualizar_barra_hp()
	morrer(true)

func morrer(ignorar_reviver: bool = false) -> void:
	if Comercio.em_combate:
		hp_atual = 1
		atualizar_barra_hp()
		Comercio.terminar_combate(false)
		return
	if estaMorto:
		return
	# Fora da arena (fazenda e casa) não há partida para perder: a vida só encosta no mínimo
	if gerenciador_ondas == null:
		hp_atual = 1
		atualizar_barra_hp()
		return
	# Curandeira: um reviver por partida, com metade da vida e uns segundos de invulnerabilidade
	if not ignorar_reviver and Progresso.usar_reviver():
		_reviver_com_curandeira()
		return
	# Cooperativo: com o parceiro de pé, só cai (e espera ser levantado); os dois no chão = fim da partida
	var parceiro := Cooperativo.parceiro_de(self)
	if parceiro != null and not parceiro.estaMorto:
		_cair()
		return
	if eh_p2:
		_cair()
		if parceiro != null and bool(parceiro.get("caido")):
			parceiro.morrer_de_vez()
		return
	estaMorto = true
	caido = false
	if petrificacao != null:
		petrificacao.liberar()
	defesa.cancelar()
	efeitos_pocao.limpar()
	Sons.tocar("jogador_morre", 0.0)
	Controle.vibrar(0.6, 1.0, 0.6, self)
	emit_signal("jogador_morreu")
	gerenciador_ondas.parar_ondas()
	desabilitar_todas_acoes(true)
	Progresso.encerrar_partida()
	# O jogador só volta ao acampamento quando confirmar na tela (ver reiniciar_para_nova_partida)
	EventosJogo.abrir_tela.emit("fim_partida")

func _reviver_com_curandeira() -> void:
	hp_atual = maxi(1, roundi(estatisticas.hp_maximo * Progresso.VIDA_REVIVER))
	invulneravel = true
	temporizador_invul = Progresso.INVULNERABILIDADE_REVIVER
	atualizar_barra_hp()
	Sons.tocar("reviver", 0.0)
	get_tree().call_group(grupo_hud(), "anunciar", "A CURANDEIRA TE REVIVEU", "VIDA %d%%" % roundi(Progresso.VIDA_REVIVER * 100.0), 2.0)

## Dormir na cama: vida e estamina cheias
func descansar() -> void:
	hp_atual = estatisticas.hp_maximo
	atualizar_barra_hp()
	stamina = stamina_maxima
	_avisar_stamina()

## Devolve o que atravessa a troca de cena (Transicao): totens comprados, vida e estamina. Os totens somam em
## estatísticas que moram neste nó, então são reaplicados antes de restaurar a vida (que o aumento de vida máxima
## poderia empurrar). Sem foto guardada (partida nova), não faz nada
func aplicar_estado_de_transicao(estado: Dictionary) -> void:
	if estado.is_empty():
		return
	var totens = estado.get("itens_comprados", [])
	if totens is Array and itens_comprados.is_empty():
		for dados_item in totens:
			aplicar_efeitos_item(dados_item)
			itens_comprados.append(dados_item.duplicate(true))
	if estado.has("hp"):
		hp_atual = clampi(int(estado["hp"]), 1, estatisticas.hp_maximo)
		atualizar_barra_hp()
	if estado.has("stamina"):
		stamina = clampf(float(estado["stamina"]), 0.0, stamina_maxima)
		_avisar_stamina()

## Morte roguelite: perde ouro, equipamento e totens comprados (volta ao kit inicial), exceto as peças de conjunto e as moedas de forja, e reaparece junto da fogueira.
## Só as melhorias permanentes (Progresso) continuam. Chamado pela tela de fim de partida ao confirmar
func reiniciar_para_nova_partida() -> void:
	if petrificacao != null:
		petrificacao.limpar()
		petrificacao.queue_free()
		petrificacao = null
	$CompositeSprites.show()
	_remover_efeitos_itens_comprados()
	_desequipar_arma_e_escudo_sem_modelo()
	# Kit inicial: armadura, espada e escudo equipados; lança na mochila
	# Peças de conjunto e moedas de forja são permanentes: não somem com a morte
	# Morreu: o saque da partida se perde junto
	Saque.encerrar(false)
	# Cooperativo: o jogador 2 recomeça junto (o kit dele, sem os totens dele)
	if not eh_p2:
		var parceiro := Cooperativo.jogador2()
		if parceiro != null:
			parceiro.caido = false
			parceiro.reiniciar_para_nova_partida()
		Cooperativo.encerrar_partida_p2()
	var guardado: Dictionary = inventario.guardar_para_nova_partida()
	inventario.limpar()
	inventario.criar_itens_iniciais(Introducao.ativa())
	inventario.restaurar_da_partida_anterior(guardado)
	inventario.salvar()
	DadosJogo.definir_ouro_inicial()
	DadosDosItems.resetar_precos()
	atualizar_rotulo_moedas()
	_cancelar_acoes_em_andamento()
	global_position = _posicao_acampamento
	if camera != null:
		camera.reset_smoothing()
	estaMorto = false
	invulneravel = false
	temporizador_invul = 0.0
	Progresso.iniciar_partida()
	estatisticas.calcular_estatisticas_derivadas(false)
	hp_atual = estatisticas.hp_maximo
	atualizar_barra_hp()
	stamina = stamina_maxima
	_avisar_stamina()
	Introducao.reiniciar_apos_morte()

# Os totens da loja somam em estatisticas/bônus; desfaz cada um (a lista guarda os dados de compra)
func _remover_efeitos_itens_comprados() -> void:
	for dados_item in itens_comprados:
		var efeitos: Dictionary = dados_item.get("efeitos", {})
		for chave_efeito in efeitos:
			var valor_efeito = efeitos[chave_efeito]
			match chave_efeito:
				"forca":
					estatisticas.forca -= valor_efeito
				"defesa":
					bonus_defesa -= valor_efeito
					estatisticas.defesa = bonus_defesa
				"agilidade":
					estatisticas.agilidade -= valor_efeito
				"vitalidade":
					bonus_vitalidade -= valor_efeito
					vitalidade_atual = vitalidade_base + bonus_vitalidade
					estatisticas.vitalidade = vitalidade_atual
				"roubo_vida":
					estatisticas.roubo_vida -= valor_efeito
				"sorte":
					estatisticas.sorte -= valor_efeito
	itens_comprados.clear()

# Tira da mão o que o modelo ainda guarda (o escudo desfaz o bônus pelo nível dele, que vem do modelo).
# _sincronizando evita que o personagem devolva a mudança ao modelo antes de ele ser esvaziado
func _desequipar_arma_e_escudo_sem_modelo() -> void:
	_sincronizando = true
	desequipar_espada()
	desequipar_lanca()
	desequipar_arco()
	desequipar_escudo()
	_sincronizando = false

func _cancelar_acoes_em_andamento() -> void:
	velocity = Vector2.ZERO
	_knockback = Vector2.ZERO
	temporizador_knockback = 0.0
	esta_em_dash = false
	_esta_atacando = false
	if _temporizador:
		_temporizador.stop()
	ataque_enfileirado = false
	_pedido_ataque = false
	_fase_combo = 0
	$AreaAtaque.monitoring = false
	$AreaAtaque.monitorable = false
	definir_sprites_visiveis(false)

## Aplica as melhorias permanentes de vida (vigor), dano (forca) e estamina (folego); chamado ao comprar uma melhoria
func aplicar_melhorias_permanentes() -> void:
	var hp_maximo_anterior: int = estatisticas.hp_maximo
	var stamina_maxima_anterior := stamina_maxima
	stamina_maxima = _stamina_base * (1.0 + Progresso.bonus("folego"))
	stamina = clampf(stamina + (stamina_maxima - stamina_maxima_anterior), 0.0, stamina_maxima)
	estatisticas.calcular_estatisticas_derivadas(usando_espada or usando_lanca)
	hp_atual = mini(hp_atual + maxi(estatisticas.hp_maximo - hp_maximo_anterior, 0), estatisticas.hp_maximo)
	atualizar_barra_hp()
	_avisar_stamina()

func aplicar_knockback(forca: Vector2) -> void:
	_knockback = forca
	temporizador_knockback = 0.1

	var sprites_para_piscar = [
		$CompositeSprites/BaseSprites/Corpo,
		$CompositeSprites/BaseSprites/Cabelo,
		$CompositeSprites/BaseSprites/Roupa,
		$CompositeSprites/BaseSprites/Braco,
		$CompositeSprites/BaseSprites/Escudo,
		$CompositeSprites/BaseSprites/Lanca,
		$CompositeSprites/AttackSwordAnimation/CorpoEspadaEscudo,
		$CompositeSprites/AttackSwordAnimation/BracoEspada,
		$CompositeSprites/AttackSwordAnimation/Escudo,
		$CompositeSprites/AttackSwordAnimation/Cabelo,
		$CompositeSprites/AttackSwordAnimation/Roupa,
		$CompositeSprites/AttackSpearAnimation/Corpo,
		$CompositeSprites/AttackSpearAnimation/Lanca,
		$CompositeSprites/AttackSpearAnimation/Cabelo,
		$CompositeSprites/AttackSpearAnimation/Roupa,
		no_arco,
		no_reacao
	]

	for i in range(5):
		for sprite in sprites_para_piscar:
			if sprite:
				sprite.modulate.a = 0.2
		await get_tree().create_timer(0.1).timeout

		for sprite in sprites_para_piscar:
			if sprite:
				sprite.modulate.a = 1.0
		await get_tree().create_timer(0.1).timeout

# ---------------------------
# SALVAR / CARREGAR
# ---------------------------
func carregar_de_json() -> Dictionary:
	# Cada mundo (solo ou cooperativo) e cada jogador tem o próprio personagem (Saves)
	var arquivo = FileAccess.open(Saves.caminho_personagem(eh_p2), FileAccess.READ)
	if arquivo == null:
		return Cooperativo.APARENCIA_P2.duplicate(true) if eh_p2 else {}
	var string_json = arquivo.get_as_text()
	arquivo.close()
	var json = JSON.new()
	var erro_parse = json.parse(string_json)
	if erro_parse != OK:
		return {}
	return json.get_data()

func aplicar_dados_carregados(dados: Dictionary) -> void:
	# Antes de aplicar, zera todos os bônus de armadura/escudo
	bonus_vitalidade = 0
	bonus_defesa = 0
	vitalidade_atual = vitalidade_base
	estatisticas.vitalidade = vitalidade_atual
	estatisticas.defesa = bonus_defesa

	# Os índices do save valem para sempre (peças novas só entram depois das antigas); um que não exista mais cai na primeira peça
	if dados.has("cabelo_atual") or dados.has("roupa_atual"):
		definir_aparencia(int(dados.get("cabelo_atual", cabelo_atual)), int(dados.get("roupa_atual", roupa_atual)))

	if dados.has("apelido"):
		apelido = dados["apelido"]

	if dados.has("cor_cabelo"):
		var dict_cor = dados["cor_cabelo"]
		var cor_cabelo_salva = Color(dict_cor["r"], dict_cor["g"], dict_cor["b"], dict_cor["a"])
		definir_cor_cabelo(cor_cabelo_salva)

	atualizar_dano_arma()

func aplicar_dados_forja() -> void:
	if sprite_corpo_forja:
		Aparencia.aplicar_corpo(sprite_corpo_forja, "forja", roupa_atual, pecas_cavaleiro, raizes_armadura)
	Aparencia.aplicar_cabelo(sprite_cabelo_forja, cabelo_atual, "forja", roupa_atual, pecas_cavaleiro, raizes_armadura)
	sprite_cabelo_forja.modulate = cor_cabelo
	Aparencia.aplicar_roupa(sprite_roupa_forja, roupa_atual, "forja", pecas_cavaleiro, raizes_armadura)
	Aparencia.aplicar_cartola(sprite_cabelo_forja, sprite_roupa_forja, "forja", roupa_atual, pecas_cavaleiro, raizes_armadura)

## Senta o jogador na posição `posicao` olhando para `lado` (1 = direita, -1 = esquerda), desenhado no z `z`
## (acima do encosto da cadeira). Quem pede é o cadeira.gd, que depois o tira com levantar()
func sentar(posicao: Vector2, lado: int, z: int, frente: int = 0) -> void:
	if esta_sentado or estaMorto:
		return
	cancelar_acao_fazenda()
	esta_sentado = true
	_lado_sentado = 1 if lado >= 0 else -1
	_frente_sentado = signi(frente)
	_z_sentado = z
	_tempo_sentado = 0.0
	aplicar_dados_forja()
	_aplicar_roupa_sentado()
	_arm_forja_visivel = $CompositeSprites/Forja/Arm.visible
	$CompositeSprites/Forja/Arm.visible = false   # a marreta da forja
	# A árvore de animação reescreve o quadro da Forja (volta para a pose de martelar) a cada atualização: desligada
	# enquanto sentado, o quadro fica o que definir_quadro_sentado pôs
	if _arvore_animacao:
		_arvore_animacao.active = false
	velocity = Vector2.ZERO
	global_position = posicao
	z_index = z
	movimento_habilitado = false
	ataques_bloqueados = true
	no_forja.visible = true
	definir_quadro_sentado()
	_atualizar_visual_arco()

# A roupa que ele está usando, na versão da página 4 (a da forja das roupas antigas é o avental de ferreiro)
func _aplicar_roupa_sentado() -> void:
	if sprite_corpo_forja:
		Aparencia.aplicar_corpo(sprite_corpo_forja, "sentado", roupa_atual, pecas_cavaleiro, raizes_armadura)
	Aparencia.aplicar_cabelo(sprite_cabelo_forja, cabelo_atual, "sentado", roupa_atual, pecas_cavaleiro, raizes_armadura)
	Aparencia.aplicar_roupa(sprite_roupa_forja, roupa_atual, "sentado", pecas_cavaleiro, raizes_armadura)
	Aparencia.aplicar_cartola(sprite_cabelo_forja, sprite_roupa_forja, "sentado", roupa_atual, pecas_cavaleiro, raizes_armadura)

## Põe o quadro de sentar (olhando para o lado da cadeira) nas camadas da forja
func definir_quadro_sentado() -> void:
	var quadro: int = QUADRO_SENTADO_FRENTE[_frente_sentado] if _frente_sentado != 0 else QUADRO_SENTADO[_lado_sentado]
	for camada in [sprite_corpo_forja, sprite_cabelo_forja, sprite_roupa_forja]:
		camada.frame = quadro

## Levanta e põe o jogador em `posicao` (de pé, solto)
func levantar(posicao: Vector2) -> void:
	if not esta_sentado:
		return
	esta_sentado = false
	no_forja.visible = false
	$CompositeSprites/Forja/Arm.visible = _arm_forja_visivel
	if _arvore_animacao:
		_arvore_animacao.active = true
		if _maquina_estados:
			_maquina_estados.travel("idle" if not (usando_espada or usando_lanca or usando_arco) else "idle")
	global_position = posicao
	_atualizar_visual_arco()
	movimento_habilitado = true
	ataques_bloqueados = false
	# O F/Y que levantou não pode sentar de novo antes de a zona atualizar os corpos.
	_interacao_bloqueada = true
	_quadro_bloqueio_interacao = Engine.get_process_frames()
	_sem_acao_ate_ms = Time.get_ticks_msec() + JANELA_SEM_ACAO_APOS_TELA_MS

# Sentado: parado, no z da cadeira; F/Y, B/Esc ou andar pedem para levantar (depois de um instante)
func _atualizar_sentado(delta: float) -> void:
	z_index = _z_sentado
	velocity = Vector2.ZERO
	_pedido_ataque = false
	_tempo_sentado += delta
	if _tempo_sentado < TEMPO_MINIMO_SENTADO or get_viewport().gui_get_focus_owner() != null:
		return
	var anda := _vetor_movimento().length() > 0.6
	# O A/F que fechou uma tela (pedido, conversa) não levanta nem reabre nada
	var interagir := Input.is_action_just_pressed(acao("open_menu")) and Time.get_ticks_msec() >= _sem_acao_ate_ms and pode_iniciar_interacao()
	var cancelar := not eh_p2 and Input.is_action_just_pressed("ui_cancel")
	# Na mesa da taverna o botão abre o cardápio; com um vizinho ao lado, conversa com ele
	if interagir and is_instance_valid(assento_atual) and assento_atual.has_method("interagir_sentado") and assento_atual.interagir_sentado(self):
		return
	if anda or interagir or cancelar:
		pediu_levantar.emit()

func iniciar_forja(item: DadosItem) -> void:
	esta_forjando = true
	var dados_carregados = carregar_de_json()
	if dados_carregados:
		if dados_carregados.has("cabelo_atual"):
			cabelo_atual = dados_carregados["cabelo_atual"]
		if dados_carregados.has("roupa_atual"):
			roupa_atual = dados_carregados["roupa_atual"]

	aplicar_dados_forja()
	movimento_habilitado = false
	no_forja.visible = true
	$CompositeSprites/BaseSprites.visible = false
	no_arco.visible = false
	no_reacao.visible = false

	if _arvore_animacao and _maquina_estados:
		_maquina_estados.travel("smithing")

	var temporizador_forja = Timer.new()
	temporizador_forja.wait_time = 5.0
	temporizador_forja.one_shot = true
	add_child(temporizador_forja)
	temporizador_forja.connect("timeout", Callable(self, "_on_forja_finalizada").bind(item))
	temporizador_forja.start()

func _on_forja_finalizada(item: DadosItem) -> void:
	esta_forjando = false
	no_forja.visible = false
	_atualizar_visual_arco()
	if _arvore_animacao and _maquina_estados:
		_maquina_estados.travel("idle")
	movimento_habilitado = true
	# A loja fecha durante o refino (desabilitar_todas_acoes trava os ataques enquanto forja): sem destravar aqui, a
	# arma refinada não atacava mais. Com outra tela aberta, ela mesma destrava ao fechar
	if not _tem_tela_aberta():
		ataques_bloqueados = false

	# O nível sobe no item que foi para a bigorna (a instância), não no primeiro do mesmo tipo
	_subir_nivel_no_modelo(item)
	if item != null:
		match Equipamentos.familia_de(item.tipo):
			"espada":
				atualizar_texturas_espada()
			"escudo":
				atualizar_texturas_escudo()
				# Se é o escudo em uso, troca o pacote de vida e defesa pelo do nível novo
				if usando_escudo and item == _escudo_aplicado:
					_aplicar_bonus_item("escudo", item)
			"lanca":
				atualizar_texturas_lanca()
			"arco":
				atualizar_texturas_arco()
		# Peça de conjunto equipada: troca o pacote de status do nível novo e refaz o bônus do conjunto
		if item.categoria in ["cabeca", "corpo", "luvas", "botas"] and inventario.equipados.get(item.categoria) == item:
			_aplicar_bonus_item(item.categoria, item)
			set("nivel_" + item.categoria, item.nivel)
			_atualizar_bonus_conjuntos()
	atualizar_dano_arma()

	atualizar_aparencia_arma() # Garante atualização visual correta
	emit_signal("forja_finalizada")

func _tem_tela_aberta() -> bool:
	var interface := EventosJogo.interface_de(self)
	return interface != null and "_telas_abertas" in interface and not interface._telas_abertas.is_empty()

# ---------------------------
# ATUALIZAÇÃO DAS TEXTURAS
# ---------------------------
func atualizar_texturas_espada() -> void:
	var instancia_bd_armas = preload("res://codigo/dados/equipamentos.gd").new()
	var dados_nivel = instancia_bd_armas.obter_dados_nivel_arma(id_arma_atual, nivel_espada)
	if dados_nivel.size() > 0 and dados_nivel.has("textura"):
		ObjetosRefinados.aplicar(sprite_espada, dados_nivel["textura"])
		if dados_nivel.has("textura_ataque"):
			ObjetosRefinados.aplicar(braco_espada_ataque, dados_nivel["textura_ataque"])
	else:
		if nivel_espada == 1:
			var caminho_espada_base = "res://assets/personagens/Arms/swords/Sword_1.png"
			var caminho_ataque_espada = "res://assets/personagens/Arms/swords/Attack/slash_1.png"
			if ResourceLoader.exists(caminho_espada_base):
				ObjetosRefinados.aplicar(sprite_espada, load(caminho_espada_base))
			if ResourceLoader.exists(caminho_ataque_espada):
				ObjetosRefinados.aplicar(braco_espada_ataque, load(caminho_ataque_espada))
		else:
			var caminho_espada_base2 = "res://assets/personagens/Arms/swords/swords_upgraded/%d/Sword_1.png" % nivel_espada
			var caminho_ataque_espada2 = "res://assets/personagens/Arms/swords/Attack/swords_upgraded/slash_1/%d/slash_1.png" % nivel_espada
			if ResourceLoader.exists(caminho_espada_base2):
				ObjetosRefinados.aplicar(sprite_espada, load(caminho_espada_base2))
			if ResourceLoader.exists(caminho_ataque_espada2):
				ObjetosRefinados.aplicar(braco_espada_ataque, load(caminho_ataque_espada2))

func atualizar_texturas_lanca() -> void:
	var instancia_bd_armas = preload("res://codigo/dados/equipamentos.gd").new()
	var dados_nivel = instancia_bd_armas.obter_dados_nivel_arma(id_lanca_atual, nivel_lanca)
	if dados_nivel.size() > 0:
		if dados_nivel.has("textura") and dados_nivel["textura"] is Texture2D:
			ObjetosRefinados.aplicar(sprite_lanca, dados_nivel["textura"])
		if dados_nivel.has("textura_ataque") and dados_nivel["textura_ataque"] is Texture2D:
			ObjetosRefinados.aplicar(braco_lanca_ataque, dados_nivel["textura_ataque"])
	else:
		var caminho_lanca_base = ""
		var caminho_ataque_lanca = ""

		if nivel_lanca == 1:
			caminho_lanca_base = "res://assets/personagens/Arms/spears/spear_1.png"
			caminho_ataque_lanca = "res://assets/personagens/Arms/spears/Attack/slash_1.png"
		else:
			caminho_lanca_base = "res://assets/personagens/Arms/spears/spears_upgraded/%d/spear_1.png" % nivel_lanca
			caminho_ataque_lanca = "res://assets/personagens/Arms/spears/Attack/spears_upgraded/%d/slash_1.png" % nivel_lanca

		if ResourceLoader.exists(caminho_lanca_base):
			ObjetosRefinados.aplicar(sprite_lanca, load(caminho_lanca_base))
		else:
			print("Erro: Textura não encontrada:", caminho_lanca_base)

		if ResourceLoader.exists(caminho_ataque_lanca):
			ObjetosRefinados.aplicar(braco_lanca_ataque, load(caminho_ataque_lanca))
		else:
			print("Erro: Textura não encontrada:", caminho_ataque_lanca)

func atualizar_texturas_escudo() -> void:
	# O nó também desenha a aljava: refinar escudo inativo não pode substituí-la.
	if not usando_escudo:
		return
	var instancia_bd_armas = preload("res://codigo/dados/equipamentos.gd").new()
	var dados_nivel = instancia_bd_armas.obter_dados_nivel_arma(id_escudo_atual, nivel_escudo)
	if dados_nivel.size() > 0 and dados_nivel.has("textura"):
		ObjetosRefinados.aplicar(sprite_escudo, dados_nivel["textura"])
		if dados_nivel.has("textura_ataque"):
			ObjetosRefinados.aplicar(escudo_ataque, dados_nivel["textura_ataque"])
	else:
		if nivel_escudo == 1:
			var caminho_escudo_base = "res://assets/personagens/Arms/shields/shield_1.png"
			var caminho_ataque_escudo = "res://assets/personagens/Arms/shields/attack/slash_1.png"
			if ResourceLoader.exists(caminho_escudo_base):
				ObjetosRefinados.aplicar(sprite_escudo, load(caminho_escudo_base))
			if ResourceLoader.exists(caminho_ataque_escudo):
				ObjetosRefinados.aplicar(escudo_ataque, load(caminho_ataque_escudo))
		else:
			var caminho_escudo_base2 = "res://assets/personagens/Arms/shields/upgraded_shields/%d/shield_1.png" % nivel_escudo
			var caminho_ataque_escudo2 = "res://assets/personagens/Arms/shields/attack/shields_upgrade/slash_1/%d/slash_1.png" % nivel_escudo
			if ResourceLoader.exists(caminho_escudo_base2):
				ObjetosRefinados.aplicar(sprite_escudo, load(caminho_escudo_base2))
			if ResourceLoader.exists(caminho_ataque_escudo2):
				ObjetosRefinados.aplicar(escudo_ataque, load(caminho_ataque_escudo2))

func atualizar_aparencia_arma() -> void:
	if usando_espada:
		atualizar_texturas_espada()
	elif usando_lanca:
		atualizar_texturas_lanca()
	elif usando_escudo:
		atualizar_texturas_escudo()

## Confirmar/fechar uma tela não pode interagir com a porta novamente no mesmo toque.
func pode_iniciar_interacao() -> bool:
	if _interacao_bloqueada:
		var nome := acao("open_menu")
		if Engine.get_process_frames() <= _quadro_bloqueio_interacao or (InputMap.has_action(nome) and Input.is_action_pressed(nome)):
			return false
		_interacao_bloqueada = false
	return true

func desabilitar_todas_acoes(desabilitar: bool) -> void:
	# Se estiver em forja, não permite reativar as ações
	if esta_forjando:
		ataques_bloqueados = true
		movimento_habilitado = false
		return

	# Código original
	ataques_bloqueados = desabilitar
	movimento_habilitado = !desabilitar
	if not desabilitar:
		_interacao_bloqueada = true
		_quadro_bloqueio_interacao = Engine.get_process_frames()
		_sem_acao_ate_ms = Time.get_ticks_msec() + JANELA_SEM_ACAO_APOS_TELA_MS

	if desabilitar and usando_arco:
		no_arco.parar_disparo()
		_atualizar_visual_arco()
	if desabilitar and _esta_atacando:
		_esta_atacando = false
		$AreaAtaque.monitoring = false
		$AreaAtaque.monitorable = false
		definir_sprites_visiveis(false)
		reprodutor_anim.speed_scale = 1.0
		_fase_combo = 0

# ---------------------------
# FUNÇÕES DE ARMADURA
# ---------------------------
func equipar_cabeca() -> void:
	if not usando_cabeca:
		usando_cabeca = true
		carregar_conjunto_armadura(nivel_cabeca)
		
		var instancia_bd_armaduras = preload("res://codigo/dados/equipamentos.gd").new()
		var dados_cabeca = instancia_bd_armaduras.obter_dados_nivel_armadura(id_cabeca_atual, nivel_cabeca)
		
		if dados_cabeca.has("bonus_vitalidade"):
			bonus_vitalidade += dados_cabeca["bonus_vitalidade"]
			vitalidade_atual = vitalidade_base + bonus_vitalidade
			estatisticas.vitalidade = vitalidade_atual
			estatisticas.calcular_estatisticas_derivadas(usando_espada or usando_lanca)
			hp_atual = min(hp_atual + dados_cabeca["bonus_vitalidade"] * 6, estatisticas.hp_maximo)
		
		if dados_cabeca.has("bonus_defesa"):
			bonus_defesa += dados_cabeca["bonus_defesa"]
			estatisticas.defesa = bonus_defesa
		
		estatisticas.calcular_estatisticas_derivadas(usando_espada or usando_lanca)
		atualizar_barra_hp()
		emit_signal("equipamento_alterado")

func equipar_corpo() -> void:
	if not usando_corpo:
		usando_corpo = true
		carregar_conjunto_armadura(nivel_corpo)
		
		var instancia_bd_armaduras = preload("res://codigo/dados/equipamentos.gd").new()
		var dados_corpo = instancia_bd_armaduras.obter_dados_nivel_armadura(id_corpo_atual, nivel_corpo)
		
		if dados_corpo.has("bonus_vitalidade"):
			bonus_vitalidade += dados_corpo["bonus_vitalidade"]
			vitalidade_atual = vitalidade_base + bonus_vitalidade
			estatisticas.vitalidade = vitalidade_atual
			estatisticas.calcular_estatisticas_derivadas(usando_espada or usando_lanca)
			hp_atual = min(hp_atual + dados_corpo["bonus_vitalidade"] * 6, estatisticas.hp_maximo)
		
		if dados_corpo.has("bonus_defesa"):
			bonus_defesa += dados_corpo["bonus_defesa"]
			estatisticas.defesa = bonus_defesa
		
		estatisticas.calcular_estatisticas_derivadas(usando_espada or usando_lanca)
		atualizar_barra_hp()
		emit_signal("equipamento_alterado")

func equipar_luvas() -> void:
	if not usando_luvas:
		usando_luvas = true
		carregar_conjunto_armadura(nivel_luvas)
		
		var instancia_bd_armaduras = preload("res://codigo/dados/equipamentos.gd").new()
		var dados_luvas = instancia_bd_armaduras.obter_dados_nivel_armadura(id_luvas_atual, nivel_luvas)
		
		if dados_luvas.has("bonus_vitalidade"):
			bonus_vitalidade += dados_luvas["bonus_vitalidade"]
			vitalidade_atual = vitalidade_base + bonus_vitalidade
			estatisticas.vitalidade = vitalidade_atual
			estatisticas.calcular_estatisticas_derivadas(usando_espada or usando_lanca)
			hp_atual = min(hp_atual + dados_luvas["bonus_vitalidade"] * 6, estatisticas.hp_maximo)
		
		if dados_luvas.has("bonus_defesa"):
			bonus_defesa += dados_luvas["bonus_defesa"]
			estatisticas.defesa = bonus_defesa
		
		estatisticas.calcular_estatisticas_derivadas(usando_espada or usando_lanca)
		atualizar_barra_hp()
		emit_signal("equipamento_alterado")

func equipar_botas() -> void:
	if not usando_botas:
		usando_botas = true
		carregar_conjunto_armadura(nivel_botas)
		
		var instancia_bd_armaduras = preload("res://codigo/dados/equipamentos.gd").new()
		var dados_botas = instancia_bd_armaduras.obter_dados_nivel_armadura(id_botas_atual, nivel_botas)
		
		if dados_botas.has("bonus_vitalidade"):
			bonus_vitalidade += dados_botas["bonus_vitalidade"]
			vitalidade_atual = vitalidade_base + bonus_vitalidade
			estatisticas.vitalidade = vitalidade_atual
			estatisticas.calcular_estatisticas_derivadas(usando_espada or usando_lanca)
			hp_atual = min(hp_atual + dados_botas["bonus_vitalidade"] * 6, estatisticas.hp_maximo)
		
		if dados_botas.has("bonus_defesa"):
			bonus_defesa += dados_botas["bonus_defesa"]
			estatisticas.defesa = bonus_defesa
		
		estatisticas.calcular_estatisticas_derivadas(usando_espada or usando_lanca)
		atualizar_barra_hp()
		emit_signal("equipamento_alterado")

func definir_cor_cabelo(nova_cor: Color) -> void:
	cor_cabelo = nova_cor
	sprite_cabelo.modulate = nova_cor
	cabelo_ataque.modulate = nova_cor
	cabelo_lanca_ataque.modulate = nova_cor
	if sprite_cabelo_forja:
		sprite_cabelo_forja.modulate = nova_cor
	Aparencia.aplicar_cartola(sprite_cabelo, sprite_roupa, "andar", roupa_atual, pecas_cavaleiro, raizes_armadura)
	Aparencia.aplicar_cartola(cabelo_ataque, roupa_ataque, "espada", roupa_atual, pecas_cavaleiro, raizes_armadura)
	Aparencia.aplicar_cartola(cabelo_lanca_ataque, roupa_lanca_ataque, "lanca", roupa_atual, pecas_cavaleiro, raizes_armadura)
	if sprite_cabelo_forja and sprite_roupa_forja:
		Aparencia.aplicar_cartola(sprite_cabelo_forja, sprite_roupa_forja, "sentado" if esta_sentado else "forja", roupa_atual, pecas_cavaleiro, raizes_armadura)

func definir_apelido(novo_apelido: String) -> void:
	apelido = novo_apelido

# --- Cooperativo: barra do jogador 2 e cair/levantar ----------------------------------------------------------------

## Barrinha de vida (vermelha) e estamina (amarela) sobre a cabeça do jogador 2, com "P2"
func _montar_barra_p2() -> void:
	_barra_p2 = Node2D.new()
	_barra_p2.name = "BarraP2"
	_barra_p2.z_as_relative = false
	_barra_p2.z_index = 898
	_barra_p2.position = Vector2(0, -26)
	_barra_p2.draw.connect(_desenhar_barra_p2)
	add_child(_barra_p2)
	var rotulo := Label.new()
	rotulo.text = "P2"
	rotulo.add_theme_font_override("font", preload("res://assets/ui/Planes_ValMore.ttf"))
	rotulo.add_theme_font_size_override("font_size", 8)
	rotulo.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))
	rotulo.add_theme_color_override("font_outline_color", Color("211c2b"))
	rotulo.add_theme_constant_override("outline_size", 3)
	rotulo.position = Vector2(-22, -6)
	_barra_p2.add_child(rotulo)

var _progresso_reviver := 0.0

func _atualizar_barra_p2() -> void:
	if _barra_p2 != null:
		_barra_p2.queue_redraw()

func _desenhar_barra_p2() -> void:
	var largura := 20.0
	var vida := clampf(float(hp_atual) / float(maxi(estatisticas.hp_maximo, 1)), 0.0, 1.0)
	var folego := clampf(stamina / maxf(stamina_maxima, 1.0), 0.0, 1.0)
	_barra_p2.draw_rect(Rect2(-largura / 2.0 - 1, -1, largura + 2, 5), Color("211c2b"))
	_barra_p2.draw_rect(Rect2(-largura / 2.0, 0, largura * vida, 2), Color(0.9, 0.25, 0.25))
	_barra_p2.draw_rect(Rect2(-largura / 2.0, 2, largura * folego, 1), Color(0.95, 0.85, 0.3))

## Mostra quanto falta para levantar (0..1): um anel acima de quem caiu
func mostrar_reviver(fracao: float) -> void:
	_progresso_reviver = fracao
	queue_redraw()

func _draw() -> void:
	if caido:
		draw_arc(Vector2(0, -30), 6.0, 0.0, TAU, 20, Color(0, 0, 0, 0.5), 2.0)
		if _progresso_reviver > 0.0:
			draw_arc(Vector2(0, -30), 6.0, -PI / 2.0, -PI / 2.0 + TAU * _progresso_reviver, 20, Color(0.55, 1.0, 0.6), 2.0)

func _cair() -> void:
	if caido:
		return
	caido = true
	estaMorto = true
	hp_atual = 0
	atualizar_barra_hp()
	defesa.cancelar()
	_cancelar_acoes_em_andamento()
	velocity = Vector2.ZERO
	$CompositeSprites.modulate = Color(0.6, 0.6, 0.7, 0.55)
	Sons.tocar("jogador_morre", 0.0)
	get_tree().call_group("hud", "anunciar", "%s CAIU" % ("JOGADOR 2" if eh_p2 else "JOGADOR 1"), "FIQUE PERTO PARA LEVANTAR", 2.0)
	queue_redraw()

## Levantado pelo parceiro (ou no fim da onda): metade da vida e um instante sem levar dano
func levantar_caido() -> void:
	if not caido:
		return
	caido = false
	estaMorto = false
	_progresso_reviver = 0.0
	$CompositeSprites.modulate = Color.WHITE
	hp_atual = maxi(1, roundi(estatisticas.hp_maximo * 0.5))
	invulneravel = true
	temporizador_invul = 2.0
	atualizar_barra_hp()
	Sons.tocar("reviver", 0.0)
	queue_redraw()

## O parceiro também caiu: o jogador 1 morre de verdade (tela de fim de partida)
func morrer_de_vez() -> void:
	if eh_p2:
		return
	caido = false
	$CompositeSprites.modulate = Color.WHITE
	estaMorto = false
	morrer(true)

