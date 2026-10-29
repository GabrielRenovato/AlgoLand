extends RefCounted
## Fallbacks empacotados também funcionam no navegador sem fontes do sistema.
static func preparar(usar_msdf: bool = OS.has_feature("web")) -> void:
	var alternativas: Array[Font] = [preload("res://assets/ui/fontes/NotoSans-Regular.ttf"), preload("res://assets/ui/fontes/NotoSansSymbols2-Regular.ttf")]
	var fontes: Array[FontFile] = []
	for fonte: FontFile in [
		preload("res://assets/ui/Planes_ValMore.ttf"),
		preload("res://assets/ui/craftpix-net-775352-game-user-interface-pixel-art/6 Font/CraftPixNet Survival Kit.otf"),
		preload("res://assets/ui/craftpix-net-420010-pixel-game-user-interface-for-platformer/TinyFontCraftpixPixel.otf"),
	]:
		fonte.fallbacks = alternativas
		fonte.allow_system_fallback = false
		fontes.append(fonte)
	if usar_msdf:
		# O atlas multicanal evita o caminho de máscara das fontes que pode aparecer
		# como retângulos sólidos no WebGL de celulares. A escala e a orientação
		# podem mudar sem reconstruir os glifos em outra resolução.
		for alternativa: FontFile in alternativas:
			fontes.append(alternativa)
		if ThemeDB.fallback_font is FontFile:
			fontes.append(ThemeDB.fallback_font)
		for fonte in fontes:
			fonte.multichannel_signed_distance_field = true
