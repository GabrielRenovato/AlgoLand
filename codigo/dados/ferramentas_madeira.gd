extends RefCounted

## Um material compartilhado por escala; mantém as folhas, poses e transparências nativas.
const TIPOS := ["enxada","regador","machadinha","picareta"]
const SHADER := preload("res://assets/personagens/Fazenda/materiais/madeira.gdshader")
static var _materiais := {}

static func material(pixels_por_unidade := 1.0, nivel := 1) -> ShaderMaterial:
	var chave := Vector2(pixels_por_unidade,clampi(nivel,1,3))
	if not _materiais.has(chave):
		var acabamento := ShaderMaterial.new()
		acabamento.shader = SHADER
		acabamento.set_shader_parameter("pixels_por_unidade",pixels_por_unidade)
		acabamento.set_shader_parameter("nivel",chave.y)
		_materiais[chave] = acabamento
	return _materiais[chave]

static func do_tipo(tipo: String, nivel := 1) -> Material:
	return material(1.0,nivel) if tipo in TIPOS else null
