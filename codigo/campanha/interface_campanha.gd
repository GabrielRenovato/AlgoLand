extends "res://codigo/ui/interface.gd"

const Estilo := preload("res://codigo/ui/estilo_campanha.gd")
var _destino_resultado := ""
var _hud_da_campanha: Node
var _relatorio: Button

## Conserva mochila e pausa, sem atalhos para modos fora do percurso isolado.
func _ready() -> void:
	script_cliente_mercado=preload("res://codigo/campanha/cliente_leilao.gd")
	super._ready()
	var lobby = _telas.lobby
	lobby.set_process(false)
	lobby.set_process_input(false)
	lobby.set_process_unhandled_input(false)
	lobby._historico.hide()
	lobby._botao_hud.hide()
	var resultado := preload("res://codigo/campanha/tela_resultado.gd").new()
	resultado.name="ResultadoExpedicao"
	add_child(resultado)
	_telas["resultado"]=resultado
	_paineis["resultado"]=resultado.painel
	resultado.layout_alterado.connect(func():_paineis["resultado"]=resultado.painel)
	resultado.explorar.connect(func():_fechar_tela("resultado"))
	resultado.mapa.connect(_mapa_resultado)
	resultado.rejogar.connect(_repetir_resultado)
	Estilo.fontes(self)
	Estilo.botao(_troca_companheira,true)
	Estilo.dicas(_troca_companheira)
	for nome in _telas:
		if nome!="resultado":_vestir_tela(nome)
	var dialogo: Control=_telas.introducao
	Estilo.pergaminho(dialogo.painel,10)
	dialogo._titulo.add_theme_font_override("font",Estilo.FONTE_TITULO)
	dialogo._titulo.add_theme_color_override("font_color",Estilo.VERDE)
	dialogo._texto.add_theme_color_override("font_color",Estilo.TINTA)
	Estilo.botao(dialogo._avancar)
	Estilo.botao(dialogo._fechar_dialogo)
	var pausa := _telas.get("pausa") as Control
	if pausa!=null:
		var quadro := pausa.get_node_or_null("Centro/Painel") as Control
		if quadro!=null:Estilo.pergaminho(quadro,10)
	var hud: Node=get_parent().hud
	_hud_da_campanha=hud
	hud.set_meta("acabamento_campanha",true)
	_somente_ouro(hud)
	Estilo.vestir(hud)
	var tutorial: Control=hud.get_node_or_null("MiniTutorial")
	if tutorial!=null:Estilo.vestir(tutorial)
	var objetivo: Control=hud.get_node("ObjetivoPrincipal")
	Estilo.painel(objetivo,false,10)
	objetivo._titulo.add_theme_color_override("font_color",Estilo.VERDE)
	objetivo._texto.add_theme_color_override("font_color",Estilo.TINTA)
	get_tree().node_added.connect(_novo_controle)
	_relatorio=Button.new();_relatorio.text="Relatório"
	_relatorio.custom_minimum_size=Vector2(65,22)
	_relatorio.focus_mode=Control.FOCUS_NONE
	Estilo.botao(_relatorio)
	add_child(_relatorio)
	_relatorio.pressed.connect(func():mostrar_resultado())

## A campanha usa só ouro por enquanto: esconde as Brasas e a moeda de forja, que ficam depois delas na mesma linha.
func _somente_ouro(hud: Node) -> void:
	var linha: Node = hud.rotulo_brasas.get_parent()
	var inicio: int = hud.rotulo_brasas.get_index()
	if inicio > 0 and linha.get_child(inicio - 1) is TextureRect:
		inicio -= 1
	for i in range(inicio, linha.get_child_count()):
		linha.get_child(i).visible = false

func _process(delta: float) -> void:
	super._process(delta)
	var cidade_publica: bool=get_parent().regiao=="vila"
	_telas.lobby.set_process(cidade_publica)
	_telas.lobby.set_process_input(cidade_publica)
	_telas.lobby.set_process_unhandled_input(cidade_publica)
	_telas.lobby._botao_hud.visible=cidade_publica
	if not cidade_publica:_telas.lobby._historico.hide()

	if _botao_duelo != null: _botao_duelo.hide()
	if _botao_amigos != null: _botao_amigos.hide()
	if _relatorio!=null:
		_relatorio.visible=not cidade_publica and get_parent().registro_run.apresentada and _telas_abertas.is_empty() and not get_parent().cinema_cidade_ativa()
		var medida := preload("res://codigo/ui/escala_interface.gd").tamanho_logico(self)
		_relatorio.position=Vector2(medida.x-_relatorio.size.x-8,8)

func _abrir_tela(nome: String, acompanhante := false) -> void:
	if get_parent().cinema_cidade_ativa(): return
	if "resultado" in _telas_abertas and nome!="resultado":return
	if nome == "mapa_mundi":
		get_parent().voltar_ao_mapa()
		return
	super._abrir_tela(nome,acompanhante)
	if _telas.has(nome):_vestir_tela(nome)

func _novo_controle(no: Node) -> void:
	if (no is Label or no is Button or no is RichTextLabel or no is LineEdit or no is TextEdit or no is PanelContainer) and (is_ancestor_of(no) or (is_instance_valid(_hud_da_campanha) and _hud_da_campanha.is_ancestor_of(no))):_fonte_depois.call_deferred(weakref(no))

func _fonte_depois(referencia: WeakRef) -> void:
	var no: Node=referencia.get_ref()
	if is_instance_valid(no) and not _telas.resultado.is_ancestor_of(no) and (is_ancestor_of(no) or (is_instance_valid(_hud_da_campanha) and _hud_da_campanha.is_ancestor_of(no))):Estilo.vestir(no)

func _vestir_tela(nome: String) -> void:
	if nome=="resultado":return
	Estilo.vestir(_telas[nome])
	Estilo.dicas(_telas[nome])
	var quadro: Control=_paineis.get(nome)
	if quadro!=null:Estilo.pergaminho(quadro,14 if nome=="maestria" else 10)
	if nome=="pausa":
		for b in _telas[nome].find_children("*","Button",true,false):
			if not b.has_meta("atualiza_tema_campanha"):
				b.set_meta("atualiza_tema_campanha",true)
				b.pressed.connect(func():_vestir_tela.call_deferred("pausa"))
	if nome=="inventario":
		var titulo: Label=_telas[nome]._titulo
		if titulo!=null:
			titulo.label_settings=LabelSettings.new();titulo.label_settings.font=Estilo.FONTE_TITULO
			titulo.label_settings.font_size=13;titulo.label_settings.font_color=Estilo.VERDE
	if nome=="forja":
		_telas[nome]._nome.add_theme_font_override("font",Estilo.FONTE_TITULO)
		_telas[nome]._nome.add_theme_color_override("font_color",Estilo.VERDE)
	if nome=="maestria":
		var arvore: Control=_telas[nome]
		arvore._mensagem.text="Selecione um nó para ver detalhes. Arraste para explorar."
		arvore._mensagem.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		Estilo.botao(arvore._familias)
		arvore._familias.get_popup().add_theme_font_override("font",Estilo.FONTE)
		Estilo.painel(arvore._detalhe,false,12)

func mostrar_resultado(destino := "") -> void:
	var cena := get_parent()
	if not _telas_abertas.is_empty() or cena.cinema_cidade_ativa():return
	_destino_resultado=destino
	var titulo := "Expedição concluída"
	if cena.regiao=="chegada" and not cena.controlador.progresso.missao_concluida("sobreviver_queda"):
		titulo="Clareira pacificada"
	var dados: Dictionary=cena.registro_run.dados()
	dados["objetivo"]=cena.controlador.objetivo_atual().get("texto","")
	_telas.resultado.comemorar = not destino.is_empty()
	_telas.resultado.apresentar(dados,cena.regiao,titulo)
	cena.registro_run.apresentada=true
	_paineis["resultado"]=_telas.resultado.painel
	_telas.resultado.show()
	_telas_abertas.append("resultado")
	_definir_acoes_do_jogador_desabilitadas(true)
	_focar_tela("resultado")

func _mapa_resultado() -> void:
	if not _destino_resultado.is_empty():get_tree().set_meta("campanha_regiao_selecionada",_destino_resultado)
	get_parent().voltar_ao_mapa()

func _repetir_resultado() -> void:
	var cena := get_parent()
	_fechar_tela("resultado")
	if cena.sessao!=null and cena.sessao.ativo:
		get_tree().set_meta("campanha_regiao_selecionada",cena.regiao)
		cena.voltar_ao_mapa()
	else:cena._recomecar()
