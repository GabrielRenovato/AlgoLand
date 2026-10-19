extends RefCounted

## Recursos compartilhados do conjunto Bosque; margens preservam os cantos nativos.
const PAINEL := preload("res://assets/ui/bosque/painel.png")
const PERGAMINHO := preload("res://assets/ui/bosque/pergaminho.png")
const CAMPO := preload("res://assets/ui/bosque/campo.png")
const BOTOES := [preload("res://assets/ui/bosque/botao.png"), preload("res://assets/ui/bosque/botao_hover.png"), preload("res://assets/ui/bosque/botao_pressionado.png"), preload("res://assets/ui/bosque/botao_desabilitado.png")]

static func painel(claro := false, margem := 10.0) -> StyleBoxTexture:
	return recorte(PERGAMINHO if claro else PAINEL, 8.0, margem)

static func recorte(textura: Texture2D, borda: float, margem: float) -> StyleBoxTexture:
	var estilo := StyleBoxTexture.new()
	estilo.texture = textura
	for lado in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		estilo.set_texture_margin(lado, borda)
		estilo.set_content_margin(lado, margem)
	return estilo

static func botao(estado: String, margem := 8.0) -> StyleBoxTexture:
	var indice := 1 if estado in ["hover", "focus"] else (2 if estado in ["pressed", "hover_pressed"] else (3 if estado == "disabled" else 0))
	var estilo := recorte(BOTOES[indice], 6.0, maxf(8.0, margem))
	# A face útil termina antes da sombra inferior: centralizar dentro dela.
	estilo.texture_margin_top = 4.0
	estilo.texture_margin_bottom = 6.0
	estilo.content_margin_top = 6.0
	estilo.content_margin_bottom = 8.0
	return estilo
