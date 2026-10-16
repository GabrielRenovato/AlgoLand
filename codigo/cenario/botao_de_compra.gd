extends Button

@onready var hover_timer: Timer = $HoverTimer # Certifique-se de ter um Timer como filho

func _ready():
	pass


func _on_HoverTimer_timeout():
	# Mude a cor ou estilo do botão para "hover"
	add_theme_color_override("font_color", Color.YELLOW) 
	# ou faça algo mais elaborado


func _on_mouse_entered() -> void:
	hover_timer.start() 

func _on_mouse_exited() -> void:
	hover_timer.stop() 
