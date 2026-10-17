extends TextureRect

## Duas poses de boca. O relógio só anda enquanto o rótulo revela caracteres.
const RAIZ := "res://assets/npcs/retratos/"
const LADO := 128
const TEMPO_BOCA := 0.12
var rotulo: Label
var _quadros: Array[AtlasTexture] = []
var _personagem := ""
var _tempo := 0.0
var quadro := 0
var falando := false

func definir_personagem(personagem: String) -> void:
	if _personagem == personagem and not _quadros.is_empty():
		return
	_personagem = personagem
	_quadros.clear()
	var folha: Texture2D = load(RAIZ+personagem+".png")
	for coluna in 2:
		var atlas := AtlasTexture.new()
		atlas.atlas = folha
		atlas.region = Rect2(coluna*LADO,0,LADO,LADO)
		_quadros.append(atlas)
	_tempo = 0.0
	quadro = 0
	texture = _quadros[0]
	modulate = Color.WHITE

func definir_imagem(imagem: Texture2D) -> void:
	_personagem = ""
	_quadros.clear()
	texture = imagem
	modulate = Color.WHITE
	falando = false
	quadro = 0

func _process(delta: float) -> void:
	if _quadros.is_empty():
		return
	falando = is_visible_in_tree() and rotulo != null and rotulo.is_visible_in_tree() and not rotulo.text.is_empty() and rotulo.visible_ratio < 1.0
	if falando:
		_tempo += delta
		quadro = int(_tempo/TEMPO_BOCA)%2
	else:
		_tempo = 0.0
		quadro = 0
	texture = _quadros[quadro]
