extends SceneTree
## Verifica pivô, recortes e sincronização dos desenhos realmente consumidos.
const Poses := preload("res://codigo/inimigos/poses_medusa.gd")
var falhas := 0

func verificar(nome: String, condicao: bool) -> void:
	print("OK " if condicao else "FALHA ", nome)
	if not condicao:
		falhas += 1

func _initialize() -> void:
	var poses := Poses.new()
	verificar("Garras redesenhadas disponíveis", poses.possui("garras"))
	if not poses.possui("garras"):
		quit(1)
		return
	var animacao := load("res://assets/inimigos/medusa/poses/garras.tres") as SpriteFrames
	var original: Image = load("res://assets/inimigos/medusa/garras.png").get_image()
	verificar("Raiz mantém o mesmo apoio no mundo", animacao.get_meta("raiz") - Vector2(128, 128) + Vector2(0, -54) == Vector2(0, 2))
	verificar("Volta à guarda termina em até 450 ms", is_equal_approx(Poses.recuperacao(0.45 / 0.95), 6.0))
	verificar("Preparação já está armada antes do fim do aviso", is_equal_approx(Poses.preparo(0.8), 2.0))
	for linha in 4:
		var nome: String = Poses.DIRECOES[linha]
		var quantidade := animacao.get_frame_count(nome)
		var completas := quantidade >= 10
		for quadro in quantidade:
			var imagem := animacao.get_frame_texture(nome, quadro).get_image()
			var limites := imagem.get_used_rect()
			completas = completas and imagem.get_size() == Vector2i(256, 256) and limites.has_area() and limites.position.x > 0 and limites.position.y > 0 and limites.end.x < 256 and limites.end.y < 256
		verificar(nome + ": poses completas sem cortes", completas)
		var primeira := animacao.get_frame_texture(nome, 0).get_image().get_region(Rect2i(48, 48, 160, 160))
		var modelo := original.get_region(Rect2i(0, linha * 160, 160, 160))
		var preservado := true
		for y in 160:
			for x in 160:
				if modelo.get_pixel(x, y).a >= 0.5:
					preservado = preservado and primeira.get_pixel(x, y).to_rgba32() == Color(modelo.get_pixel(x, y), 1).to_rgba32()
		verificar(nome + ": modelo e registro preservados na guarda", preservado)
		var chaves: PackedInt32Array = animacao.get_meta("chaves_" + nome)
		verificar(nome + ": pose de impacto no instante do dano", poses.indice("garras", linha, Poses.golpe(0.3)) == chaves[3])
		verificar(nome + ": preparo e ataque conectados", is_equal_approx(Poses.preparo(1), Poses.golpe(0)))
		verificar(nome + ": ataque e recuperação conectados", is_equal_approx(Poses.golpe(1), Poses.recuperacao(0)))
		verificar(nome + ": retorno à guarda fecha o ciclo", poses.indice("garras", linha, Poses.recuperacao(1)) == 0)
	print("Falhas: ", falhas)
	quit(1 if falhas else 0)
