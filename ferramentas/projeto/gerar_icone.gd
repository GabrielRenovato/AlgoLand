extends SceneTree

## Gera o ícone do jogo (pixel art própria: espada fincada no campo, broto e sol) em assets/icone/:
##   icone.png (512, cantos arredondados: Windows, Linux e ícone do projeto),
##   icone_fundo.png e icone_primeiro_plano.png (432, ícone adaptativo do Android).
## Uso: godot --headless --path . --script res://ferramentas/projeto/gerar_icone.gd
## Não usa nenhuma arte de terceiros: tudo é desenhado aqui, pixel a pixel.

const SAIDA := "res://assets/icone/"
const CEU_TOPO := Color("2a2760")
const CEU_BAIXO := Color("e8793a")
const SOL := Color("ffd166")
const SOL_BORDA := Color("ffb347")
const CAMPO := Color("3f9150")
const CAMPO_ESCURO := Color("2f7440")
const CAMPO_CLARO := Color("57ad60")
const LAMINA := Color("e4ebf2")
const LAMINA_SOMBRA := Color("9fb0c2")
const CONTORNO := Color("1b1a2e")
const OURO := Color("f5b82e")
const OURO_SOMBRA := Color("a8700f")
const CABO := Color("7a4624")
const FOLHA := Color("6fd16a")
const FOLHA_SOMBRA := Color("2f8f46")

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAIDA))
	# Ícone completo: grade 64, ampliada 8x
	var cheio := _nova(64)
	_fundo(cheio, 64, 36)
	_motivo(cheio, 0, 0)
	var grande := _ampliar(_cantos(cheio, 64), 8)
	grande.save_png(ProjectSettings.globalize_path(SAIDA + "icone.png"))
	# Adaptativo do Android: grade 72 (432 px a 6x); o motivo fica na zona segura central
	var fundo := _nova(72)
	_fundo(fundo, 72, 40)
	_ampliar(fundo, 6).save_png(ProjectSettings.globalize_path(SAIDA + "icone_fundo.png"))
	var frente := Image.create(72, 72, false, Image.FORMAT_RGBA8)
	_motivo(frente, 4, 4)
	_ampliar(frente, 6).save_png(ProjectSettings.globalize_path(SAIDA + "icone_primeiro_plano.png"))
	print("Ícones gerados em ", SAIDA)
	quit(0)

func _nova(n: int) -> Image:
	return Image.create(n, n, false, Image.FORMAT_RGBA8)

func _ampliar(img: Image, fator: int) -> Image:
	var copia := img.duplicate() as Image
	copia.resize(img.get_width() * fator, img.get_height() * fator, Image.INTERPOLATE_NEAREST)
	return copia

func _ret(img: Image, x: int, y: int, l: int, a: int, cor: Color) -> void:
	for j in range(y, y + a):
		for i in range(x, x + l):
			if i >= 0 and j >= 0 and i < img.get_width() and j < img.get_height():
				img.set_pixel(i, j, cor)

## Céu em faixas (degradê com passos visíveis), sol, campo com sulcos
func _fundo(img: Image, n: int, horizonte: int) -> void:
	for y in n:
		var t := clampf(float(y) / float(horizonte), 0.0, 1.0)
		t = floorf(t * 7.0) / 7.0
		_ret(img, 0, y, n, 1, CEU_TOPO.lerp(CEU_BAIXO, t))
	var cx := n / 2
	for y in range(horizonte - 15, horizonte):
		for x in range(cx - 15, cx + 16):
			var d := Vector2(x - cx, y - (horizonte - 2)).length()
			if d <= 13.0:
				img.set_pixel(x, y, SOL if d <= 11.0 else SOL_BORDA)
	_ret(img, 0, horizonte, n, n - horizonte, CAMPO)
	var linha := 0
	for y in range(horizonte + 2, n, 4):
		_ret(img, 0, y, n, 1, CAMPO_ESCURO)
		_ret(img, 0, y + 1, n, 1, CAMPO_CLARO)
		linha += 1
	_ret(img, 0, horizonte, n, 1, CAMPO_CLARO)

## Espada de lâmina para cima, com guarda dourada, e dois brotos ao pé dela. (ox, oy) desloca na grade
func _motivo(img: Image, ox: int, oy: int) -> void:
	# contorno da espada (1 px por fora de cada peça)
	_ret(img, ox + 28, oy + 7, 8, 33, CONTORNO)        # lâmina
	_ret(img, ox + 30, oy + 5, 4, 2, CONTORNO)         # ponta
	_ret(img, ox + 31, oy + 4, 2, 1, CONTORNO)
	_ret(img, ox + 20, oy + 38, 24, 6, CONTORNO)       # guarda
	_ret(img, ox + 29, oy + 43, 6, 9, CONTORNO)        # cabo
	_ret(img, ox + 28, oy + 51, 8, 5, CONTORNO)        # pomo
	# lâmina
	_ret(img, ox + 29, oy + 8, 6, 31, LAMINA)
	_ret(img, ox + 31, oy + 6, 2, 2, LAMINA)
	_ret(img, ox + 33, oy + 8, 2, 31, LAMINA_SOMBRA)
	_ret(img, ox + 32, oy + 10, 1, 27, LAMINA_SOMBRA)
	# guarda
	_ret(img, ox + 21, oy + 39, 22, 4, OURO)
	_ret(img, ox + 21, oy + 42, 22, 1, OURO_SOMBRA)
	_ret(img, ox + 21, oy + 39, 2, 4, OURO_SOMBRA)
	_ret(img, ox + 41, oy + 39, 2, 4, OURO_SOMBRA)
	# cabo e pomo
	_ret(img, ox + 30, oy + 44, 4, 7, CABO)
	_ret(img, ox + 33, oy + 44, 1, 7, Color("4e2c14"))
	_ret(img, ox + 29, oy + 52, 6, 3, OURO)
	_ret(img, ox + 29, oy + 54, 6, 1, OURO_SOMBRA)
	# brotos
	_broto(img, ox + 18, oy + 52, -1)
	_broto(img, ox + 45, oy + 52, 1)

func _broto(img: Image, x: int, y: int, lado: int) -> void:
	_ret(img, x - 1, y + 1, 4, 8, CONTORNO)
	_ret(img, x, y + 2, 2, 7, FOLHA_SOMBRA)
	# duas folhas, uma para cada lado
	_ret(img, x - 3, y - 2, 4, 3, CONTORNO)
	_ret(img, x + 1, y - 3, 4, 3, CONTORNO)
	_ret(img, x - 2, y - 1, 3, 2, FOLHA)
	_ret(img, x + 1, y - 2, 3, 2, FOLHA)
	_ret(img, x - 2, y, 3, 1, FOLHA_SOMBRA)
	_ret(img, x + 1, y - 1, 3, 1, FOLHA_SOMBRA)

## Moldura escura de 2 px e cantos arredondados transparentes
func _cantos(img: Image, n: int) -> Image:
	var saida := img.duplicate() as Image
	var raio := 9.0
	for y in n:
		for x in n:
			var dx := maxf(maxf(raio - x - 0.5, x + 0.5 - (n - raio)), 0.0)
			var dy := maxf(maxf(raio - y - 0.5, y + 0.5 - (n - raio)), 0.0)
			var dentro := Vector2(dx, dy).length() <= raio
			if not dentro:
				saida.set_pixel(x, y, Color(0, 0, 0, 0))
			elif x < 2 or y < 2 or x >= n - 2 or y >= n - 2 or Vector2(dx, dy).length() > raio - 2.0:
				saida.set_pixel(x, y, CONTORNO)
	return saida
