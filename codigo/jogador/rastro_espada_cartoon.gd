extends Polygon2D
## Efeito nativo: faixa elíptica afilada, sem alterar os sprites aprovados.
var corpo: AnimatedSprite2D
var forma: Dictionary
var amostras: int
var direcoes: Dictionary
var acrescimo_raio := 0.0

func configurar(ator: AnimatedSprite2D, direcao: String, golpe: int = 1):
	corpo = ator
	var arquivo = "rastros_espada_golpe2.json" if golpe == 2 else "rastros_espada.json"
	var dados = JSON.parse_string(FileAccess.get_file_as_string("res://assets/personagens/raven_cartoon/"+arquivo))
	var pegadas = JSON.parse_string(FileAccess.get_file_as_string("res://assets/personagens/raven_cartoon/"+("pegadas_espada_golpe2.json" if golpe == 2 else "pegadas_espada_base.json")))
	acrescimo_raio = float(pegadas.get("acrescimo_raio_rastro",0.0))
	direcoes = dados.direcoes
	forma = direcoes[direcao]
	amostras = int(dados.amostras)
	color = Color(dados.cor)
	antialiased = true
	# Acima da espada (-1/+1) e do recorte do punho (+2).
	z_index = 3
	corpo.frame_changed.connect(atualizar)
	atualizar()

func atualizar():
	var fase = forma.fases[corpo.frame]
	visible = fase != null
	if not visible:
		return
	var centro = corpo.offset+Vector2(forma.centro[0], forma.centro[1])
	var raios = Vector2(forma.raios[0], forma.raios[1])+Vector2.ONE*acrescimo_raio
	var pontos = PackedVector2Array()
	for i in range(amostras+1):
		var t = float(i)/amostras
		var angulo = deg_to_rad(lerpf(float(fase.inicio), float(fase.fim), t))
		pontos.append(centro+Vector2(cos(angulo), sin(angulo))*raios)
	for i in range(amostras-1, 0, -1):
		var t = float(i)/amostras
		var angulo = deg_to_rad(lerpf(float(fase.inicio), float(fase.fim), t))
		var largura = float(fase.espessura)*pow(sin(PI*t), 0.65)
		pontos.append(centro+Vector2(cos(angulo), sin(angulo))*(raios-Vector2.ONE*largura))
	polygon = pontos
