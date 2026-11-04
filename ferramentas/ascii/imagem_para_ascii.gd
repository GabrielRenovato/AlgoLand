extends SceneTree
## Converte uma imagem em arte ASCII colorida (texto puro, ANSI 24 bits e HTML).
##   godot --headless --path . --script res://ferramentas/ascii/imagem_para_ascii.gd -- ENTRADA SAIDA_BASE [colunas [X Y L A [vinheta]]]
## Com X Y L A recorta essa região da imagem; com "vinheta" o fundo esmaece para o preto (isola o personagem).
## Brilho vira caractere (rampa de densidade), bordas fortes viram | - / \ e a cor da imagem pinta cada caractere.
const RAMPA := " .,:;ilt1fLCG08@#"

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("uso: -- ENTRADA SAIDA_BASE [colunas]"); quit(1); return
	var colunas := int(args[2]) if args.size() > 2 else 200
	var img := Image.load_from_file(args[0])
	if img == null or img.is_empty():
		push_error("não consegui abrir " + args[0]); quit(1); return
	img.convert(Image.FORMAT_RGB8)
	var vinheta := args.size() > 7 and args[7] == "vinheta"
	if args.size() > 6:
		img = img.get_region(Rect2i(int(args[3]), int(args[4]), int(args[5]), int(args[6])))
	var linhas := int(round(colunas * float(img.get_height()) / img.get_width() * 0.5))
	# redução em duas etapas para fazer média e não serrilhar
	var grande := img.duplicate()
	grande.resize(colunas * 4, linhas * 4, Image.INTERPOLATE_LANCZOS)
	var p := grande.duplicate()
	p.resize(colunas, linhas, Image.INTERPOLATE_BILINEAR)
	var lum := PackedFloat32Array()
	lum.resize(colunas * linhas)
	for y in linhas:
		for x in colunas:
			var c: Color = p.get_pixel(x, y)
			lum[y * colunas + x] = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
	var peso := PackedFloat32Array()
	peso.resize(colunas * linhas)
	for y in linhas:
		for x in colunas:
			var d := Vector2((x + 0.5) / colunas - 0.5, (y + 0.5) / linhas - 0.5)
			var dist := sqrt(pow(d.x / 0.47, 2.0) + pow(d.y / 0.53, 2.0))
			peso[y * colunas + x] = 1.0 - smoothstep(0.72, 1.0, dist) if vinheta else 1.0
	# níveis automáticos (2% a 98%) e gama
	var ordenado := lum.duplicate()
	ordenado.sort()
	var lo := ordenado[int(ordenado.size() * 0.02)]
	var hi := ordenado[int(ordenado.size() * 0.98)]
	for i in lum.size():
		lum[i] = pow(clampf((lum[i] - lo) / maxf(hi - lo, 0.001), 0.0, 1.0), 0.55)
	for i in lum.size():
		lum[i] *= peso[i]
	var txt := PackedStringArray()
	var ansi := PackedStringArray()
	var html := PackedStringArray()
	for y in linhas:
		var l_txt := ""
		var l_ansi := ""
		var l_html := ""
		var anterior := ""
		for x in colunas:
			var l := lum[y * colunas + x]
			# gradiente de Sobel no brilho
			var gx := 0.0
			var gy := 0.0
			if x > 0 and y > 0 and x < colunas - 1 and y < linhas - 1:
				var v := func(dx: int, dy: int) -> float: return lum[(y + dy) * colunas + x + dx]
				gx = (v.call(1, -1) + 2.0 * v.call(1, 0) + v.call(1, 1)) - (v.call(-1, -1) + 2.0 * v.call(-1, 0) + v.call(-1, 1))
				gy = (v.call(-1, 1) + 2.0 * v.call(0, 1) + v.call(1, 1)) - (v.call(-1, -1) + 2.0 * v.call(0, -1) + v.call(1, -1))
			var forca := sqrt(gx * gx + gy * gy)
			var ch := RAMPA[clampi(int(l * (RAMPA.length() - 1)), 0, RAMPA.length() - 1)]
			if forca > 1.7 and l > 0.10:
				if absf(gx) > 2.2 * absf(gy): ch = "|"
				elif absf(gy) > 2.2 * absf(gx): ch = "-"
				elif gx * gy > 0: ch = "/"
				else: ch = "\\"
			# cor: satura e clareia (caractere ralo precisa de cor viva para parecer o mesmo tom)
			var c: Color = p.get_pixel(x, y)
			var h := c.h
			var s := minf(c.s * 1.35, 1.0)
			var vv := clampf(pow(c.v, 0.55) * 1.3 + 0.12, 0.0, 1.0)
			var cor := Color.from_hsv(h, s, vv * peso[y * colunas + x])
			if peso[y * colunas + x] < 0.06: ch = " "
			var r := int(cor.r * 255.0)
			var g := int(cor.g * 255.0)
			var b := int(cor.b * 255.0)
			l_txt += ch
			l_ansi += "\u001b[38;2;%d;%d;%dm%s" % [r, g, b, ch]
			var q := "%02x%02x%02x" % [r & 0xf0, g & 0xf0, b & 0xf0]
			var esc := ch.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
			if q != anterior:
				if anterior != "": l_html += "</span>"
				l_html += "<span style=\"color:#%s\">" % q
				anterior = q
			l_html += esc
		if anterior != "": l_html += "</span>"
		txt.append(l_txt)
		ansi.append(l_ansi + "\u001b[0m")
		html.append(l_html)
	FileAccess.open(args[1] + ".txt", FileAccess.WRITE).store_string("\n".join(txt) + "\n")
	FileAccess.open(args[1] + ".ansi", FileAccess.WRITE).store_string("\n".join(ansi) + "\n")
	var pagina := "<!doctype html><html><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\"><title>Cena em ASCII</title><style>html,body{margin:0;background:#0b0907}pre{margin:0 auto;font-family:'DejaVu Sans Mono',Menlo,Consolas,monospace;font-size:calc(100vw / %d / 0.6);line-height:1.2;letter-spacing:0;white-space:pre;overflow:hidden;width:100vw}</style></head><body><pre>%s</pre></body></html>" % [colunas, "\n".join(html)]
	FileAccess.open(args[1] + ".html", FileAccess.WRITE).store_string(pagina)
	print("ASCII: %dx%d caracteres" % [colunas, linhas])
	quit()
