extends Node2D

const TecladoVirtual := preload("res://Codigos/UI/teclado_virtual.gd")
## Tamanho máximo do apelido digitado pelo teclado virtual
const MAX_APELIDO := 12
## Passo dos sliders de cor no direcional do controle (de 1 em 1 levaria 255 toques)
const PASSO_SLIDER_CONTROLE := 5.0

# Referência ao "jogador" simplificado de customização.
@onready var jogador_personalizado = $"../PersonalizacaoJogador"

# Botões para trocar o tipo de cabelo/roupa
@onready var btn_proximo_cabelo = $Container/ContainerTrocarCabelo/TrocarCabelo
@onready var btn_anterior_cabelo = $Container/ContainerTrocarCabelo/TrocarCabeloVoltar
@onready var btn_proxima_roupa = $Container/ContainerTrocarRoupa/TrocarRoupa
@onready var btn_anterior_roupa = $Container/ContainerTrocarRoupa/TrocarRoupaVoltar
@onready var btn_salvar = $Container/Salvar/Botao

# Campo de texto para apelido
@onready var campo_texto = $Container/Apelido/CampoTexto

# Sliders para cor do cabelo (RGB)
@onready var slider_vermelho = $CorCabelo/ContainerCorCabelo/SliderVermelho
@onready var slider_verde = $CorCabelo/ContainerCorCabelo2/SliderVerde
@onready var slider_azul = $CorCabelo/ContainerCorCabelo3/SliderAzul

# Teclado na tela para digitar o apelido com o controle
var teclado: CanvasLayer

# Labels que exibem o valor atual dos sliders
@onready var rotulo_vermelho = $CorCabelo/ContainerCorCabelo/RotuloValorVermelho
@onready var rotulo_verde = $CorCabelo/ContainerCorCabelo2/RotuloValorVerde
@onready var rotulo_azul = $CorCabelo/ContainerCorCabelo3/RotuloValorAzul

func _ready() -> void:
	if jogador_personalizado:
		# Conecta o sinal de finalização do jogador de customização.
		jogador_personalizado.connect("personalizacao_finalizada", Callable(self, "_on_personalizacao_jogador_finalizada"))

		# Conecta botões da UI aos métodos do jogador_personalizado.
		btn_proximo_cabelo.connect("pressed", Callable(self, "_on_trocar_cabelo_pressionado"))
		btn_anterior_cabelo.connect("pressed", Callable(self, "_on_trocar_cabelo_voltar_pressionado"))
		btn_proxima_roupa.connect("pressed", Callable(self, "_on_trocar_roupa_pressionado"))
		btn_anterior_roupa.connect("pressed", Callable(self, "_on_trocar_roupa_voltar_pressionado"))
		
		# Botão de salvar customização.
		btn_salvar.connect("pressed", Callable(self, "_on_salvar_pressionado"))

		# LineEdit para apelido.
		campo_texto.connect("text_changed", Callable(self, "_on_campo_texto_alterado"))

		# Configura sliders (0 a 255) para R, G, B
		slider_vermelho.min_value = 0
		slider_vermelho.max_value = 255
		slider_verde.min_value = 0
		slider_verde.max_value = 255
		slider_azul.min_value = 0
		slider_azul.max_value = 255

		# Conecta sinais dos sliders.
		slider_vermelho.connect("value_changed", Callable(self, "_on_slider_vermelho_alterado"))
		slider_verde.connect("value_changed", Callable(self, "_on_slider_verde_alterado"))
		slider_azul.connect("value_changed", Callable(self, "_on_slider_azul_alterado"))

		# Define cor inicial (exemplo loiro)
		slider_vermelho.value = 255
		slider_verde.value = 220
		slider_azul.value = 100
		atualizar_cor_cabelo()

		_configurar_controle()
	else:
		print("Erro: PersonalizacaoJogador não encontrado!")

# ---------------------------
# CONTROLE
# ---------------------------
func _configurar_controle() -> void:
	for slider in [slider_vermelho, slider_verde, slider_azul]:
		slider.gui_input.connect(_ao_entrada_slider.bind(slider))
	_configurar_navegacao()
	teclado = TecladoVirtual.new()
	add_child(teclado)
	teclado.confirmado.connect(_ao_apelido_confirmado)
	# Confirmar (A) no campo de nome abre o teclado virtual; no teclado físico o campo segue igual
	campo_texto.gui_input.connect(_ao_entrada_campo_texto)
	Controle.modo_alterado.connect(_ao_modo_controle)
	Controle.focar(btn_proximo_cabelo)

# Os controles estão espalhados e em escalas diferentes, e a navegação automática do Godot se perde.
# Ordem explícita, de cima para baixo: cabelo, roupa, nome, cores e salvar (e volta ao começo)
func _configurar_navegacao() -> void:
	var linhas: Array = [
		[btn_anterior_cabelo, btn_proximo_cabelo],
		[btn_anterior_roupa, btn_proxima_roupa],
		[campo_texto],
		[slider_vermelho],
		[slider_verde],
		[slider_azul],
		[btn_salvar],
	]
	for i in linhas.size():
		var acima: Array = linhas[(i - 1 + linhas.size()) % linhas.size()]
		var abaixo: Array = linhas[(i + 1) % linhas.size()]
		var linha: Array = linhas[i]
		for k in linha.size():
			var no: Control = linha[k]
			no.focus_neighbor_top = no.get_path_to(acima[mini(k, acima.size() - 1)])
			no.focus_neighbor_bottom = no.get_path_to(abaixo[mini(k, abaixo.size() - 1)])
			if linha.size() > 1:
				no.focus_neighbor_left = no.get_path_to(linha[(k - 1 + linha.size()) % linha.size()])
				no.focus_neighbor_right = no.get_path_to(linha[(k + 1) % linha.size()])

# O slider sozinho anda de 1 em 1 no direcional; segurar o direcional repete o passo
func _ao_entrada_slider(evento: InputEvent, slider: HSlider) -> void:
	var passo := 0.0
	if evento.is_action_pressed("ui_left", true):
		passo = -PASSO_SLIDER_CONTROLE
	elif evento.is_action_pressed("ui_right", true):
		passo = PASSO_SLIDER_CONTROLE
	if passo != 0.0:
		slider.value += passo
		slider.accept_event()

func _ao_entrada_campo_texto(evento: InputEvent) -> void:
	if evento is InputEventJoypadButton and evento.is_action_pressed("ui_accept"):
		teclado.abrir(campo_texto.text, MAX_APELIDO)
		campo_texto.accept_event()

func _ao_apelido_confirmado(texto: String) -> void:
	campo_texto.text = texto
	_on_campo_texto_alterado(texto)
	# Depois do nome o próximo passo natural é salvar
	btn_salvar.grab_focus()

func _ao_modo_controle(usando_controle: bool) -> void:
	if usando_controle and get_viewport().gui_get_focus_owner() == null and not teclado.visible:
		btn_proximo_cabelo.grab_focus()
		# o toque que acordou o controle só acende o foco, sem já andar uma posição
		get_viewport().set_input_as_handled()

func _on_campo_texto_alterado(novo_texto: String) -> void:
	jogador_personalizado.definir_apelido(novo_texto)

# ---------------------------
# SLIDERS DE COR
# ---------------------------
func _on_slider_vermelho_alterado(valor: float) -> void:
	rotulo_vermelho.text = str(valor)
	atualizar_cor_cabelo()

func _on_slider_verde_alterado(valor: float) -> void:
	rotulo_verde.text = str(valor)
	atualizar_cor_cabelo()

func _on_slider_azul_alterado(valor: float) -> void:
	rotulo_azul.text = str(valor)
	atualizar_cor_cabelo()

func atualizar_cor_cabelo() -> void:
	var r = int(slider_vermelho.value)
	var g = int(slider_verde.value)
	var b = int(slider_azul.value)
	var cor = Color(r / 255.0, g / 255.0, b / 255.0, 1.0)
	jogador_personalizado.definir_cor_cabelo(cor)

# ---------------------------
# BOTÕES DE TROCAR CABELO/ROUPA
# ---------------------------
func _on_trocar_cabelo_pressionado():
	jogador_personalizado.trocar_cabelo_avancar()

func _on_trocar_cabelo_voltar_pressionado():
	jogador_personalizado.trocar_cabelo_voltar()

func _on_trocar_roupa_pressionado():
	jogador_personalizado.trocar_roupa_avancar()

func _on_trocar_roupa_voltar_pressionado():
	jogador_personalizado.trocar_roupa_voltar()

# ---------------------------
# BOTÃO "SALVAR"
# ---------------------------
func _on_salvar_pressionado() -> void:
	jogador_personalizado.salvar_personalizacao()

# ---------------------------
# RECEBE O SINAL DO JOGADOR (quando finaliza customização)
# ---------------------------
func _on_personalizacao_jogador_finalizada(indice_cabelo: int, indice_roupa: int, cor: Color, apelido: String) -> void:
	print("Personalização concluída! Cabelo:", indice_cabelo, "Roupa:", indice_roupa, "Cor:", cor, "Apelido:", apelido)
	salvar_em_json(indice_cabelo, indice_roupa, cor, apelido)

func salvar_em_json(indice_cabelo: int, indice_roupa: int, cor_escolhida: Color, apelido: String) -> void:
	var diretorio_documentos = OS.get_user_data_dir()
	var caminho_arquivo = diretorio_documentos.path_join("configuracao_jogador.json")
	var arquivo = FileAccess.open(caminho_arquivo, FileAccess.WRITE)
	if arquivo == null:
		print("Erro ao abrir o arquivo para escrita.")
		return
	
	var dados = {
		"cabelo_atual": indice_cabelo,
		"roupa_atual": indice_roupa,
		"apelido": apelido,
		"cor_cabelo": {
			"r": cor_escolhida.r,
			"g": cor_escolhida.g,
			"b": cor_escolhida.b,
			"a": cor_escolhida.a
		}
	}

	var string_json = JSON.stringify(dados)
	arquivo.store_string(string_json)
	arquivo.close()

	# Carrega a cena principal
	var cena = load("res://cenas/cenario.tscn")
	var instancia = cena.instantiate()
	get_tree().root.add_child(instancia)
	get_tree().current_scene.queue_free()
	get_tree().current_scene = instancia
