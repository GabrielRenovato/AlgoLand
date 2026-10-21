extends RefCounted
## Fallbacks empacotados também funcionam no navegador sem fontes do sistema.
static func preparar() -> void:
	var alternativas: Array[Font] = [preload("res://assets/ui/fontes/NotoSans-Regular.ttf"), preload("res://assets/ui/fontes/NotoSansSymbols2-Regular.ttf")]
	for fonte: FontFile in [
		preload("res://assets/ui/Planes_ValMore.ttf"),
		preload("res://assets/ui/craftpix-net-775352-game-user-interface-pixel-art/6 Font/CraftPixNet Survival Kit.otf"),
		preload("res://assets/ui/craftpix-net-420010-pixel-game-user-interface-for-platformer/TinyFontCraftpixPixel.otf"),
	]:
		fonte.fallbacks = alternativas
		fonte.allow_system_fallback = false
