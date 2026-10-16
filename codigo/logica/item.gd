extends Control  # Ou Button, dependendo do seu caso.

var item_data: Dictionary
signal item_clicado(item_data)
func definir_dados_item(data: Dictionary) -> void:
	item_data = data
	print("data", data)
	# Verifique se os nomes dos nós abaixo são EXATAMENTE os mesmos que aparecem na sua cena.
	# Pela imagem: "TextureButton" > "TextureRect" e "Label"
	$TextureButton/Label.text = str(data["preco"])
	$TextureButton/TextureRect.texture = load(data["icone"])
	$TextureButton/background.texture = load("res://assets/ui/sem org/2 Bars/Band2_off.png")
func _ready() -> void:
	pass
	# (Opcional) Você pode testar um texto fixo para ver se aparece no editor
	# $TextureButton/Label.text = "Teste estático"


func _on_texture_button_pressed() -> void:
	emit_signal("item_clicado", item_data)
