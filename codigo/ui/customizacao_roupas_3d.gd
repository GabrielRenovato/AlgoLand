extends CanvasLayer
## Combina peças independentes do protótipo 3D sem mexer nos itens de combate.
const Catalogo := preload("res://codigo/dados/roupas_base_3d.gd")
var heroi: Node
var _original: Dictionary
var _seletores: Dictionary={}
var _painel: PanelContainer
var _estado: Label
var _previa: SubViewport
var _controles: Control
var _rolagem: ScrollContainer
var _corpo: BoxContainer
var _imagem: TextureRect
var _movimento_antes := true
var _ataques_antes := false
func _ready():
    layer=120
    _original=heroi.roupas_3d.duplicate()
    _movimento_antes=heroi._jogador.movimento_habilitado
    _ataques_antes=heroi._jogador.ataques_bloqueados
    heroi._jogador.movimento_habilitado=false
    heroi._jogador.ataques_bloqueados=true
    var fundo:=ColorRect.new()
    fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    fundo.color=Color(0.04,0.04,0.07,0.78)
    add_child(fundo)
    _painel=PanelContainer.new()
    var estilo:=StyleBoxFlat.new()
    estilo.bg_color=Color("302b38")
    estilo.border_color=Color("bf8950")
    estilo.set_border_width_all(2)
    estilo.set_content_margin_all(16)
    _painel.add_theme_stylebox_override("panel",estilo)
    add_child(_painel)
    _controles=VBoxContainer.new()
    _controles.add_theme_constant_override("separation",10)
    _painel.add_child(_controles)
    var titulo:=Label.new()
    titulo.text="APARÊNCIA DO PERSONAGEM"
    titulo.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    titulo.add_theme_font_size_override("font_size",16)
    _controles.add_child(titulo)
    var corpo:=BoxContainer.new()
    _corpo=corpo
    corpo.add_theme_constant_override("separation",12)
    _rolagem=ScrollContainer.new()
    _rolagem.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
    _controles.add_child(corpo)
    corpo.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    _previa=SubViewport.new()
    _previa.size=heroi._vp.size
    _previa.transparent_bg=true
    _previa.world_2d=World2D.new()
    _previa.render_target_update_mode=SubViewport.UPDATE_ALWAYS
    add_child(_previa)
    var sprite:=Sprite2D.new()
    sprite.centered=false
    sprite.texture=heroi._vp.get_texture()
    sprite.texture_filter=heroi._sprite.texture_filter
    sprite.material=heroi._sprite.material
    _previa.add_child(sprite)
    var imagem:=TextureRect.new()
    _imagem=imagem
    var atlas:=AtlasTexture.new()
    atlas.atlas=_previa.get_texture()
    var fator: float=_previa.size.x/160.0
    atlas.region=Rect2(48*fator,40*fator,64*fator,80*fator)
    imagem.texture=atlas
    imagem.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST if heroi.acabamento_pixel_art else CanvasItem.TEXTURE_FILTER_LINEAR
    imagem.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
    imagem.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    imagem.custom_minimum_size=Vector2(80,148)
    corpo.add_child(imagem)
    var coluna:=VBoxContainer.new()
    coluna.add_theme_constant_override("separation",4)
    coluna.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    _rolagem.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    corpo.add_child(_rolagem)
    _rolagem.add_child(coluna)
    for categoria in Catalogo.CATEGORIAS:
        var rotulo:=Label.new()
        rotulo.text={"camisa":"PARTE DE CIMA","calca":"PARTE DE BAIXO","calcado":"CALÇADO","cabelo":"PENTEADO"}[categoria]
        rotulo.add_theme_font_size_override("font_size",12)
        coluna.add_child(rotulo)
        var seletor:=OptionButton.new()
        seletor.clip_text=true
        seletor.fit_to_longest_item=false
        seletor.custom_minimum_size=Vector2(130,28)
        seletor.add_theme_font_size_override("font_size",12)
        for m in Catalogo.MODELOS[categoria]:
            seletor.add_item(m.nome)
            if m.id==heroi.roupas_3d[categoria]: seletor.selected=seletor.item_count-1
        seletor.item_selected.connect(_selecionar.bind(categoria))
        coluna.add_child(seletor)
        _seletores[categoria]=seletor
    _estado=Label.new()
    _estado.text="Combine as peças na prévia."
    _estado.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    _estado.add_theme_font_size_override("font_size",12)
    _controles.add_child(_estado)
    var botoes:=HBoxContainer.new()
    botoes.add_theme_constant_override("separation",10)
    _controles.add_child(botoes)
    for texto in ["CANCELAR","SALVAR"]:
        var botao:=Button.new()
        botao.text=texto
        botao.custom_minimum_size.y=32
        botao.size_flags_horizontal=Control.SIZE_EXPAND_FILL
        botao.add_theme_font_size_override("font_size",12)
        if texto=="SALVAR": botao.pressed.connect(_salvar)
        else: botao.pressed.connect(_cancelar)
        botoes.add_child(botao)
    get_viewport().size_changed.connect(_ajustar)
    _ajustar.call_deferred()
    _seletores.camisa.grab_focus()
func _ajustar():
    var tamanho:=get_viewport().get_visible_rect().size
    _corpo.vertical=tamanho.x<400
    _imagem.custom_minimum_size=Vector2(80,80 if _corpo.vertical else 148)
    _rolagem.custom_minimum_size.y=minf(maxf(70,tamanho.y-155-(92 if _corpo.vertical else 0)),220)
    _painel.size=Vector2(minf(480,tamanho.x-16),0)
    _painel.position=(tamanho-_painel.size)*.5
    _reposicionar.call_deferred()
func _reposicionar():
    var tamanho:=get_viewport().get_visible_rect().size
    var excesso:=_painel.get_combined_minimum_size().y-(tamanho.y-16)
    if excesso>0 and _rolagem.custom_minimum_size.y>60:
        _rolagem.custom_minimum_size.y=maxf(60,_rolagem.custom_minimum_size.y-excesso-2)
        _reposicionar.call_deferred()
        return
    _painel.reset_size()
    _painel.size.x=minf(480,tamanho.x-16)
    _painel.position=((tamanho-_painel.size)*.5).round()
func _selecionar(indice: int,categoria: String):
    var dados: Dictionary=heroi.roupas_3d.duplicate()
    dados[categoria]=Catalogo.MODELOS[categoria][indice].id
    heroi.definir_roupas_3d(dados)
func _salvar():
    if heroi.salvar_roupas_3d(): queue_free()
    else: _estado.text="Não foi possível salvar. Tente novamente."
func _cancelar():
    heroi.definir_roupas_3d(_original)
    queue_free()
func _unhandled_input(evento: InputEvent):
    if evento.is_action_pressed("ui_cancel"):
        _cancelar()
        get_viewport().set_input_as_handled()
func _exit_tree():
    if is_instance_valid(heroi) and is_instance_valid(heroi._jogador):
        heroi._jogador.movimento_habilitado=_movimento_antes
        heroi._jogador.ataques_bloqueados=_ataques_antes
