extends Control

const IconesItens := preload("res://Codigos/UI/icones_itens.gd")
const CenaItem := preload("res://cenas/item.tscn")
const Equipamentos := preload("res://Codigos/DadosLocais/Equipamentos.gd")

# As fontes pixel do jogo não têm acentos nem "→"; os textos do painel usam ASCII
const NOMES_UPGRADE := {"espada_basica": "ESPADA", "lanca_basica": "LANCA", "escudo_basico": "ESCUDO"}
const COR_TEXTO_OK := Color(1, 1, 1)
const COR_TEXTO_BLOQUEADO := Color(1, 0.45, 0.45)
const COR_BOTAO_DESABILITADO := Color(1, 1, 1, 0.5)

# Equipamentos é um Node fora da árvore; guardado aqui para liberar em _exit_tree
var _equipamentos := Equipamentos.new()

@onready var _menu_principal: Control = %Botoes
@onready var _lista_armas: Control = %Armas
@onready var _container_itens: GridContainer = %ContainerItens
@onready var _especificacao_item: Control = %EspecificacaoItem
@onready var _container_moedas: Control = %Moedas
@onready var _moldura: Control = %Moldura2
@onready var _botao_voltar: Button = %BotaoVoltar
@onready var _aba_bigorna: Control = %Atualizar
@onready var _slot_bigorna: Control = %Slot
@onready var _info_upgrade: Control = %InfoItemUpgrade
@onready var _textos_upgrade: Control = %ConteudoTextos
@onready var _rotulo_arraste: Label = get_node("%Atualizar/Label")
@onready var _botao_upgrade: Button = %CliqueUpgrade
@onready var _botao_iniciar_onda: Button = %IniciarOnda
@onready var _botao_atualizar: Button = get_node("%Botoes/Atualizar")
@onready var _botao_espada: TextureButton = %espada
@onready var _botao_lanca: TextureButton = %lanca
@onready var _botao_escudo: TextureButton = %Escudo

func _ready() -> void:
	add_to_group("tela_mercante")
	_slot_bigorna.item_alterado.connect(_ao_item_slot_alterado)
	visibility_changed.connect(_ao_visibilidade_alterada)
	set_process(false)

func _exit_tree() -> void:
	_equipamentos.free()

func _process(_delta: float) -> void:
	var jogador := IconesItens.obter_jogador(get_tree())
	if jogador == null:
		return
	_botao_iniciar_onda.disabled = not _tem_arma_equipada(jogador)
	_botao_atualizar.disabled = not (jogador.usando_espada or jogador.usando_lanca)
	_atualizar_botoes_armas(jogador)

func _ao_visibilidade_alterada() -> void:
	set_process(visible)
	if visible:
		atualizar_exibicao_moedas()
	else:
		_slot_bigorna.limpar()

func _tem_arma_equipada(jogador: Node) -> bool:
	return jogador.usando_espada or jogador.usando_lanca or jogador.usando_escudo

func _fechar() -> void:
	EventosJogo.fechar_tela.emit("mercante")

func _on_iniciar_onda_pressionado() -> void:
	var jogador := IconesItens.obter_jogador(get_tree())
	if jogador != null and not _tem_arma_equipada(jogador):
		return
	var gerenciador_ondas := get_tree().get_first_node_in_group("gerenciador_ondas")
	if gerenciador_ondas != null:
		gerenciador_ondas.iniciar_onda()
	_fechar()

func _on_sair_pressionado() -> void:
	_fechar()

func _on_armas_pressionado() -> void:
	_botao_voltar.visible = true
	_menu_principal.visible = false
	_moldura.visible = true
	_lista_armas.visible = true

func _on_construir_pressionado() -> void:
	_menu_principal.visible = false
	_moldura.visible = true
	_lista_armas.visible = false
	_container_itens.visible = true
	_botao_voltar.visible = true
	_container_moedas.visible = true
	for filho in _container_itens.get_children():
		filho.queue_free()
	atualizar_exibicao_moedas()
	for chave in DadosDosItems.itens.keys():
		var dados_item: Dictionary = DadosDosItems.obter_dados_item(chave)
		if dados_item.size() > 0:
			var instancia_item: Control = CenaItem.instantiate()
			instancia_item.definir_dados_item(dados_item)
			instancia_item.item_clicado.connect(_ao_item_clicado)
			_container_itens.add_child(instancia_item)

func _ao_item_clicado(dados_item_clicado: Dictionary) -> void:
	_especificacao_item.visible = true
	_especificacao_item.definir_dados_item(dados_item_clicado)

func _on_botao_voltar_pressionado() -> void:
	_menu_principal.visible = true
	_botao_voltar.visible = false
	_moldura.visible = false
	_lista_armas.visible = false
	_container_itens.visible = false
	_especificacao_item.visible = false
	_container_moedas.visible = false
	_slot_bigorna.limpar()
	_aba_bigorna.visible = false

func atualizar_exibicao_moedas() -> void:
	var rotulo_moedas := _container_moedas.get_node("contador") as Label
	rotulo_moedas.text = str(DadosJogo.moedas)

func _on_atualizar_pressionado() -> void:
	_aba_bigorna.visible = true
	_menu_principal.visible = false
	_botao_voltar.visible = true
	_moldura.visible = true
	_lista_armas.visible = false
	_container_itens.visible = false
	_especificacao_item.visible = false
	_container_moedas.visible = false
	atualizar_painel_upgrade()

func _ao_item_slot_alterado(_tem_item: bool) -> void:
	atualizar_painel_upgrade()

func _nivel_atual_do_item(jogador: Node, tipo_item: String) -> int:
	match tipo_item:
		"espada_basica":
			return jogador.nivel_espada
		"lanca_basica":
			return jogador.nivel_lanca
		"escudo_basico":
			return jogador.nivel_escudo
	return 0

# Vazio se não há item válido na bigorna
func _dados_upgrade() -> Dictionary:
	var item: Node = _slot_bigorna.item_atual
	var jogador := IconesItens.obter_jogador(get_tree())
	if item == null or jogador == null or not NOMES_UPGRADE.has(item.obter_tipo_item()):
		return {}
	var tipo_item: String = item.obter_tipo_item()
	var nivel: int = _nivel_atual_do_item(jogador, tipo_item)
	var proximo: Dictionary = _equipamentos.obter_dados_nivel_arma(tipo_item, nivel + 1)
	var gerenciador_ondas := get_tree().get_first_node_in_group("gerenciador_ondas")
	var onda_atual: int = gerenciador_ondas.onda_atual if gerenciador_ondas != null else 0
	var custo: int = proximo.get("custo", 0)
	var onda_necessaria: int = proximo.get("onda_necessaria", 0)
	return {
		"tipo_item": tipo_item,
		"nivel": nivel,
		"atual": _equipamentos.obter_dados_nivel_arma(tipo_item, nivel),
		"proximo": proximo,
		"custo": custo,
		"onda_necessaria": onda_necessaria,
		"onda_ok": onda_atual >= onda_necessaria,
		"moedas_ok": DadosJogo.moedas >= custo,
	}

func atualizar_painel_upgrade() -> void:
	var rotulo_titulo: Label = _textos_upgrade.get_node("FOR")
	var rotulo_atributos: Label = _textos_upgrade.get_node("DAN")
	var rotulo_requisitos: Label = _textos_upgrade.get_node("NIVEL")
	_textos_upgrade.get_node("VIT").visible = false
	_textos_upgrade.get_node("DEF").visible = false

	var dados := _dados_upgrade()
	_rotulo_arraste.visible = dados.is_empty()
	_info_upgrade.visible = not dados.is_empty()
	_botao_upgrade.text = "MELHORAR"
	if dados.is_empty():
		_definir_botao_upgrade(false)
		return

	var nome: String = NOMES_UPGRADE[dados["tipo_item"]]
	var nivel: int = dados["nivel"]
	var atual: Dictionary = dados["atual"]
	var proximo: Dictionary = dados["proximo"]
	if proximo.is_empty():
		rotulo_titulo.text = "%s NV %d" % [nome, nivel]
		rotulo_atributos.text = "NIVEL MAXIMO"
		rotulo_requisitos.text = ""
		_botao_upgrade.text = "MAXIMO"
		_definir_botao_upgrade(false)
		return

	rotulo_titulo.text = "%s NV %d > %d" % [nome, nivel, nivel + 1]
	if dados["tipo_item"] == "escudo_basico":
		rotulo_atributos.text = "DEF %d>%d  VIT %d>%d" % [
			atual.get("bonus_defesa", 0), proximo.get("bonus_defesa", 0),
			atual.get("bonus_vitalidade", 0), proximo.get("bonus_vitalidade", 0)]
	else:
		rotulo_atributos.text = "DANO %d > %d" % [atual.get("dano", 0), proximo.get("dano", 0)]

	var requisitos := "CUSTO %d MOEDAS" % dados["custo"]
	if not dados["onda_ok"]:
		requisitos += "\nREQUER ONDA %d" % dados["onda_necessaria"]
	elif not dados["moedas_ok"]:
		requisitos += "\nMOEDAS INSUFICIENTES"
	rotulo_requisitos.text = requisitos
	var pode_melhorar: bool = dados["onda_ok"] and dados["moedas_ok"]
	rotulo_requisitos.modulate = COR_TEXTO_OK if pode_melhorar else COR_TEXTO_BLOQUEADO
	_definir_botao_upgrade(pode_melhorar)

func _definir_botao_upgrade(habilitado: bool) -> void:
	_botao_upgrade.disabled = not habilitado
	_botao_upgrade.modulate = Color(1, 1, 1, 1) if habilitado else Color(0.6, 0.6, 0.6, 1)

func _on_clique_upgrade_pressionado() -> void:
	var jogador := IconesItens.obter_jogador(get_tree())
	var dados := _dados_upgrade()
	if jogador == null or dados.is_empty() or dados["proximo"].is_empty() or not (dados["onda_ok"] and dados["moedas_ok"]):
		return
	jogador.gastar_moedas(dados["custo"])
	atualizar_exibicao_moedas()
	jogador.iniciar_forja(dados["tipo_item"])
	_slot_bigorna.limpar()
	await get_tree().create_timer(0.1).timeout
	_fechar()

func _on_espada_pressionado() -> void:
	var jogador := IconesItens.obter_jogador(get_tree())
	if jogador == null:
		return
	if jogador.usando_lanca:
		jogador.desequipar_lanca()
	if jogador.usando_espada:
		jogador.desequipar_espada()
	else:
		jogador.equipar_espada()
	_atualizar_botoes_armas(jogador)

func _on_lanca_pressionado() -> void:
	var jogador := IconesItens.obter_jogador(get_tree())
	if jogador == null:
		return
	if jogador.usando_espada:
		jogador.desequipar_espada()
	if jogador.usando_lanca:
		jogador.desequipar_lanca()
	else:
		jogador.equipar_lanca()
	_atualizar_botoes_armas(jogador)

func _on_escudo_pressionado() -> void:
	var jogador := IconesItens.obter_jogador(get_tree())
	if jogador == null:
		return
	if jogador.usando_escudo:
		jogador.desequipar_escudo()
	else:
		jogador.equipar_escudo()
	_atualizar_botoes_armas(jogador)

# Os textos seguem o estado do jogador, que também muda pelo inventário
func _atualizar_botoes_armas(jogador: Node) -> void:
	_botao_espada.get_node("Texto").text = "DESEQUIPAR" if jogador.usando_espada else "EQUIPAR"
	_botao_lanca.get_node("Texto").text = "DESEQUIPAR" if jogador.usando_lanca else "EQUIPAR"
	_botao_escudo.get_node("Texto").text = "DESEQUIPAR" if jogador.usando_escudo else "EQUIPAR"
	# A lança é de duas mãos: com ela equipada o escudo fica indisponível
	_botao_escudo.disabled = jogador.usando_lanca
	_botao_escudo.modulate = COR_BOTAO_DESABILITADO if jogador.usando_lanca else Color.WHITE
