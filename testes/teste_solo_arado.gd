extends SceneTree
## Executar na cópia de testes com saves isolados; não carrega a fazenda nem altera saves.
const Solo := preload("res://codigo/cenario/solo_arado.gd")
var _falhas := 0

func _initialize() -> void:
	call_deferred("_rodar")

func _verificar(nome: String, condicao: bool) -> void:
	print(("OK " if condicao else "FALHA ") + nome)
	if not condicao:
		_falhas += 1

func _rodar() -> void:
	var origem := Vector2i.ZERO
	var isolado := Solo.textura(0, false, origem)
	var imagem := isolado.get_image()
	_verificar("tile isolado arredonda os quatro cantos", imagem.get_pixel(2, 2).a == 0.0 and imagem.get_pixel(13, 2).a == 0.0 and imagem.get_pixel(2, 13).a == 0.0 and imagem.get_pixel(13, 13).a == 0.0)
	_verificar("tile isolado preserva o centro para plantar", imagem.get_pixel(8, 8).a == 1.0)
	var campo := {origem: {"molhado": false}, Vector2i.RIGHT: {"molhado": true}}
	_verificar("terra seca conecta com a molhada", Solo.vizinhos(campo, origem) == Solo.LESTE and Solo.vizinhos(campo, Vector2i.RIGHT) == Solo.OESTE)
	_verificar("conexoes molhadas respeitam a rega", Solo.vizinhos(campo, origem, true) == Solo.LESTE and Solo.vizinhos(campo, Vector2i.RIGHT, true) == 0)
	var ligado := Solo.textura(0, false, origem, Solo.LESTE)
	_verificar("arar o vizinho atualiza o contorno em cache", ligado != isolado and ligado.get_image().get_pixel(15, 8).a == 1.0 and imagem.get_pixel(15, 8).a == 0.0)
	_verificar("remover o vizinho recupera o contorno isolado", Solo.textura(0, false, origem) == isolado)
	var horizontal := true
	var vertical := true
	var direita := Solo.textura(0, false, Vector2i.RIGHT, Solo.OESTE).get_image()
	var acima := Solo.textura(0, false, origem, Solo.SUL).get_image()
	var abaixo := Solo.textura(0, false, Vector2i.DOWN, Solo.NORTE).get_image()
	for i in range(2, 14):
		horizontal = horizontal and ligado.get_image().get_pixel(15, i).a == 1.0 and direita.get_pixel(0, i).a == 1.0
		vertical = vertical and acima.get_pixel(i, 15).a == 1.0 and abaixo.get_pixel(i, 0).a == 1.0
	_verificar("vizinhos horizontais se unem sem fenda", horizontal)
	_verificar("vizinhos verticais se unem sem fenda", vertical)
	var canto_interno := Solo.textura(0, false, origem, Solo.NORTE | Solo.OESTE).get_image()
	var canto_preenchido := Solo.textura(0, false, origem, Solo.NORTE | Solo.OESTE | Solo.NOROESTE).get_image()
	_verificar("canteiro em L arredonda o canto interno", canto_interno.get_pixel(0, 0).a == 0.0 and canto_interno.get_pixel(3, 3).a == 1.0)
	_verificar("preencher a diagonal fecha o canto interno", canto_preenchido.get_pixel(0, 0).a == 1.0)
	var centro := Solo.textura(0, false, origem, 255).get_image()
	var sem_furos := true
	for y in 16:
		for x in 16:
			sem_furos = sem_furos and centro.get_pixel(x, y).a == 1.0
	_verificar("interior do canteiro não tem buracos ou bordas transparentes", sem_furos)
	var mancha := Solo.textura(0, true, origem, 255, 0).get_image()
	var encharcado := Solo.textura(0, true, origem, 255, 255).get_image()
	_verificar("regar um tile interno arredonda a mancha sem expor o chão", mancha.get_pixel(0, 0) == centro.get_pixel(0, 0) and mancha.get_pixel(8, 8).r < centro.get_pixel(8, 8).r * 0.8)
	_verificar("regar os vizinhos une as manchas molhadas", encharcado.get_pixel(0, 0).r < mancha.get_pixel(0, 0).r * 0.8)
	var silhuetas_iguais := true
	for ligacoes in 256:
		var seca := Solo.textura(0, false, origem, ligacoes).get_image()
		var molhada := Solo.textura(0, true, origem, ligacoes, ligacoes).get_image()
		for y in 16:
			for x in 16:
				silhuetas_iguais = silhuetas_iguais and seca.get_pixel(x, y).a == molhada.get_pixel(x, y).a
	_verificar("256 combinacoes preservam a silhueta ao regar", silhuetas_iguais)
	print("FALHAS: ", _falhas)
	quit(_falhas)
