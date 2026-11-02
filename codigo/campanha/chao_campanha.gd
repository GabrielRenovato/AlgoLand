extends "res://codigo/cidade/chao_detalhado.gd"

## Regiões comuns compartilham o chão atual da fazenda; a clareira usa seu TileMap modular.
const CHAO_FAZENDA := preload("res://codigo/cenario/chao_fazenda.gdshader")

func configurar(terreno: TileMapLayer, agua: TileMapLayer, preparar_material := false) -> void:
	super.configurar(terreno,agua,preparar_material)
	if preparar_material and terreno.get_parent().get("regiao")!="vila":
		var parametros := {}
		for parametro in ["distribuicao","origem","tamanho"]:
			parametros[parametro] = _material.get_shader_parameter(parametro)
		_material.shader = CHAO_FAZENDA
		for parametro in parametros:
			_material.set_shader_parameter(parametro,parametros[parametro])

func _alinhar_soleiras() -> void:
	pass

func aplicar(indice: int) -> void:
	if _material!=null and _terreno.get_parent().get("regiao")!="vila":
		estacao=clampi(indice,0,3)
		_material.set_shader_parameter("grama",load("res://assets/cenario/cidade/chao_detalhado/grama_%s.png" % ESTACOES[estacao]))
		_material.set_shader_parameter("terra",load("res://assets/cenario/fazenda/natureza_detalhada/%s/terra.png" % ESTACOES[estacao]))
		return
	super.aplicar(indice)
	if _material!=null: _material.set_shader_parameter("periodo_pedra",48.0)
