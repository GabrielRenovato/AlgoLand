extends Node
## Arte 4x na geometria original: UVs, bases, células, alvos e escala física permanecem iguais.
const SHADER := preload("res://codigo/cenario/natureza_fazenda.gdshader")
const BARRANCO := preload("res://codigo/cenario/barranco_fazenda.gdshader")
const PASTA := "res://assets/cenario/fazenda/natureza_detalhada/"
const NOMES := ["primavera","verao","outono","inverno"]
var estacao := -1
var ativo := true
var _terreno: Node2D
var _estacoes: Node
var _originais := {}
var _materiais := {}
var _fontes_paredao := {}
var _detalhes: TileMapLayer
var _paredao: TileMapLayer

func configurar(terreno: Node2D) -> void:
	name="NaturezaFazenda"
	_terreno=terreno
	_estacoes=terreno.get_node("Estacoes")
	terreno.add_child(self)
	_detalhes=terreno.get_node("Detalhes")
	_detalhes.tile_set=_detalhes.tile_set.duplicate(true)
	_paredao=terreno.get_node("Penhasco")
	_paredao.tile_set=_paredao.tile_set.duplicate(true)
	for i in _paredao.tile_set.get_source_count():
		var id:=_paredao.tile_set.get_source_id(i)
		var fonte:=_paredao.tile_set.get_source(id) as TileSetAtlasSource
		fonte.use_texture_padding=false
		var material_parede:=ShaderMaterial.new()
		material_parede.shader=BARRANCO
		material_parede.set_shader_parameter("folha_tamanho",fonte.texture.get_size())
		material_parede.set_shader_parameter("faixa","/penhasco/" in fonte.texture.resource_path)
		material_parede.set_shader_parameter("pe",float(_paredao.get_used_rect().end.y*16))
		_fontes_paredao[id]={"fonte":fonte,"material":material_parede}
	for celula in _paredao.get_used_cells():
		var fonte: TileSetAtlasSource=_fontes_paredao[_paredao.get_cell_source_id(celula)].fonte
		fonte.get_tile_data(_paredao.get_cell_atlas_coords(celula),0).material=_fontes_paredao[_paredao.get_cell_source_id(celula)].material
	var fonte:=_detalhes.tile_set.get_source(0) as TileSetAtlasSource
	fonte.use_texture_padding=false
	for v in 4:
		var atlas:=Vector2i(4,6+v)
		var material_pedra:=_material("pedra_%d" % v)
		material_pedra.set_shader_parameter("uv_origem",Vector2(atlas*16)/fonte.texture.get_size())
		material_pedra.set_shader_parameter("uv_tamanho",Vector2(16,16)/fonte.texture.get_size())
		fonte.get_tile_data(atlas,0).material=material_pedra
	_estacoes.estacao_mudou.connect(aplicar)
	aplicar(maxi(_estacoes.estacao_atual,0))

func _material(peca: String) -> ShaderMaterial:
	if not _materiais.has(peca):
		var novo:=ShaderMaterial.new()
		novo.shader=SHADER
		_materiais[peca]=novo
	return _materiais[peca]

func vestir(sprite: Sprite2D,peca: String) -> void:
	if not _originais.has(sprite): _originais[sprite]=sprite.material
	# Pedras em TileMap têm UVs de atlas; sprites de entulho usam o quadro inteiro.
	var chave:=peca+"_sprite" if peca.begins_with("pedra_") else peca
	if not ativo:
		sprite.material=_originais[sprite]
		return
	var acabamento:=_material(chave)
	acabamento.set_shader_parameter("arte",load(PASTA+NOMES[estacao]+"/"+peca+".png"))
	sprite.material=acabamento
	sprite.set_meta("arte_natureza",peca)

func aplicar(indice: int) -> void:
	estacao=clampi(indice,0,3)
	ativo=not bool(_terreno.get_meta("visual_tiny",false))
	for sprite in _originais.keys():
		if not is_instance_valid(sprite): _originais.erase(sprite)
	for v in 4:
		_material("pedra_%d" % v).set_shader_parameter("arte",load(PASTA+NOMES[estacao]+"/pedra_%d.png" % v))
	var fonte:=_detalhes.tile_set.get_source(0) as TileSetAtlasSource
	fonte.texture=_estacoes._fonte_chao.texture
	for v in 4: fonte.get_tile_data(Vector2i(4,6+v),0).material=_material("pedra_%d" % v) if ativo else null
	for dados: Dictionary in _fontes_paredao.values():
		var faixa: bool=dados.material.get_shader_parameter("faixa")
		dados.fonte.texture=_estacoes._penhasco_original._fonte.texture if faixa else _estacoes._fonte_chao.texture
		dados.material.set_shader_parameter("barranco",load(PASTA+NOMES[estacao]+"/barranco.png"))
		dados.material.set_shader_parameter("grama",load("res://assets/cenario/cidade/chao_detalhado/grama_%s.png" % NOMES[estacao]))
	for celula in _paredao.get_used_cells():
		var dados: Dictionary=_fontes_paredao[_paredao.get_cell_source_id(celula)]
		dados.fonte.get_tile_data(_paredao.get_cell_atlas_coords(celula),0).material=dados.material if ativo else null
	for sprite in _terreno.get_node("Objetos3D").get_children():
		if sprite is Sprite2D and sprite.texture is AtlasTexture:
			var nome: String=sprite.texture.resource_name
			if nome in ["arvore","arvore_var"]: vestir(sprite,"carvalho" if nome=="arvore" else "pinheiro")
	var extracao:=_terreno.get_node("Extracao")
	for registro: Dictionary in extracao._entulho.values():
		if registro.has("sprite") and (registro.peca.begins_with("pedra_") or registro.peca=="arvoreta"): vestir(registro.sprite,registro.peca)
	for chave in extracao._crescimentos:
		var sprite: Sprite2D=extracao._crescimentos[chave]
		var estagio: int=Fazenda.estagio_arvore(chave)
		if estagio in [2,3]: vestir(sprite,"muda" if estagio==2 else "jovem")
		elif _originais.has(sprite): sprite.material=_originais[sprite]
	# O Tiny repõe suas próprias texturas depois da troca de estação.
	if not ativo:
		for sprite in _originais:
			if is_instance_valid(sprite): sprite.material=_originais[sprite]
