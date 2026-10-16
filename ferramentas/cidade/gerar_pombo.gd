extends SceneTree

## Gera o pombo-correio a partir do gavião do Mana Seed (Harrowing Hawk A v01): mesma folha 4x8 de 32x32, mesma
## perspectiva e contorno, só trocando a paleta marrom/laranja pela de um pombo (cinza-azulado, olho laranja, pés
## rosados). Também desenha o envelope (7x5) que ele carrega. Rodar da raiz do projeto:
##   godot --headless --path . --script res://ferramentas/cidade/gerar_pombo.gd
## Saída: assets/npcs/pombo_correio/pombo.png, envelope.png, envelope_misterio.png e a prévia 4x em arte/previas/pombo_correio.png

const ORIGEM := "res://assets/inimigos/mana_seed/22.11a - Harrowing Hawk 2.0/harrowing hawk A v01.png"
const DESTINO := "res://assets/npcs/pombo_correio/"
const PREVIA := "res://arte/previas/pombo_correio.png"

## Cor do gavião -> cor do pombo (as 15 cores da folha)
const PALETA := {
	"181818": "26252e",  # contorno
	"421c1f": "363847",  # penas mais escuras
	"421c2a": "363847",
	"623528": "4d5164",  # sombra das penas
	"813431": "5d6178",  # barras escuras da asa
	"916944": "7f849c",  # corpo
	"bb605a": "6c7189",  # pontas das penas
	"cca874": "aeb3c6",  # peito claro
	"f8f0e0": "e4e6ee",  # brilho
	"902800": "7c3846",  # pés (escuro)
	"e87000": "c0687a",  # pés
	"f8c800": "e396a4",  # pés (claro)
	"2d5191": "7a2e10",  # olho (laranja de pombo)
	"5693c0": "e07a2a",
	"c7e7e7": "f2dcb0",
}

## O gavião pinta bico e garras com o mesmo laranja; no pombo o bico é cinza-escuro com a cera clara. Acima desta linha
## do quadro (32 px) o laranja é bico
const LINHA_BICO := 19
const BICO := {"902800": "34323c", "e87000": "5a5866", "f8c800": "d8d2d8"}

## Envelope de 7x5: contorno, papel, aba e o selo vermelho
const ENVELOPE := [
	"0000000",
	"0211120",
	"0122210",
	"0113110",
	"0000000",
]
const CORES_ENVELOPE := {"0": "4a3a2c", "1": "f4ead2", "2": "cbb994", "3": "c0392b"}
## Carta sem remetente: papel mais escuro e selo roxo
const CORES_MISTERIO := {"0": "2e2433", "1": "d9cfe0", "2": "a596b4", "3": "7d3cb5"}

func _initialize() -> void:
	var folha := Image.load_from_file(ProjectSettings.globalize_path(ORIGEM))
	folha.convert(Image.FORMAT_RGBA8)
	var faltando := {}
	for y in folha.get_height():
		for x in folha.get_width():
			var cor := folha.get_pixel(x, y)
			if cor.a == 0.0:
				continue
			var chave := cor.to_html(false)
			if BICO.has(chave) and y % 32 < LINHA_BICO:
				var bico := Color(BICO[chave])
				bico.a = cor.a
				folha.set_pixel(x, y, bico)
			elif PALETA.has(chave):
				var nova := Color(PALETA[chave])
				nova.a = cor.a
				folha.set_pixel(x, y, nova)
			else:
				faltando[chave] = true
	if not faltando.is_empty():
		push_error("Cores sem mapeamento: %s" % [faltando.keys()])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DESTINO))
	folha.save_png(ProjectSettings.globalize_path(DESTINO + "pombo.png"))
	_envelope(CORES_ENVELOPE).save_png(ProjectSettings.globalize_path(DESTINO + "envelope.png"))
	_envelope(CORES_MISTERIO).save_png(ProjectSettings.globalize_path(DESTINO + "envelope_misterio.png"))
	var previa := folha.duplicate()
	previa.resize(folha.get_width() * 4, folha.get_height() * 4, Image.INTERPOLATE_NEAREST)
	previa.save_png(ProjectSettings.globalize_path(PREVIA))
	print("Pombo gerado em ", DESTINO)
	quit()

func _envelope(cores: Dictionary) -> Image:
	var envelope := Image.create(7, 5, false, Image.FORMAT_RGBA8)
	for y in ENVELOPE.size():
		for x in String(ENVELOPE[y]).length():
			envelope.set_pixel(x, y, Color(cores[ENVELOPE[y][x]]))
	return envelope
