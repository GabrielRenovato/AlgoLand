extends SceneTree
## Registra a grade inteira; não muda escala ou centro de poses pelo contorno.
const FONTES := "res://arte/fontes/inimigos/goblin_adaga/"
const DESTINO := "res://assets/inimigos/goblin_adaga/"
const CELULA := 640
const ESCALA := 0.071
const DIRECOES := ["direita", "baixo", "cima", "esquerda"]

func _initialize() -> void:
	var plano: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FONTES + "movimento_direita.json"))
	var duracoes_combo: Array = plano.combo.duracoes_golpes_ms.duplicate()
	for quadro in [3,7]:
		duracoes_combo[quadro] += plano.combo.intervalo_entre_golpes_ms
	var dados := {
		"correr_direita": {"fonte": "corrida_direita_v1.png", "linhas": 2, "quadros": 8, "deslocamento": Vector2i(64, 84), "duracoes_ms": [50,60,40,50,50,60,40,50]},
		"combo_direita": {"fonte": "combo_efeito_direita_v1.png", "linhas": 3, "quadros": 12, "lado":534, "limiar_alfa":64, "deslocamento": Vector2i(53,49), "duracoes_ms": duracoes_combo},
		"correr_baixo": {"fonte": "corrida_baixo_referencia_v1.png", "linhas": 2, "quadros": 8, "lado":640, "deslocamento": Vector2i.ZERO, "duracoes_ms":[50,60,40,50,50,60,40,50]},
		"combo_baixo": {"fonte":"combo_efeito_baixo_v1.png", "linhas":3, "quadros":12, "lado":486, "limiar_alfa":128, "deslocamento":Vector2i(77,93), "duracoes_ms":duracoes_combo},
		"correr_cima": {"fonte":"corrida_cima_v1.png", "linhas":2, "quadros":8, "lado":608, "deslocamento":Vector2i(16,9), "duracoes_ms":[50,60,40,50,50,60,40,50]},
		"combo_cima": {"fonte":"combo_efeito_cima_v2.png", "linhas":3, "quadros":12, "lado":549, "limiar_alfa":128, "deslocamento":Vector2i(45,57), "deslocamentos_linhas":{"0":Vector2i(45,21),"1":Vector2i(45,31),"2":Vector2i(45,57)}, "duracoes_ms":duracoes_combo},
		"correr_esquerda": {"espelhar_de":"correr_direita", "fonte":"corrida_direita_v1.png", "linhas":2, "quadros":8, "lado":640, "deslocamento":Vector2i.ZERO, "duracoes_ms":[50,60,40,50,50,60,40,50]},
		"combo_esquerda": {"espelhar_de":"combo_direita", "fonte":"combo_efeito_direita_v1.png", "linhas":3, "quadros":12, "lado":640, "deslocamento":Vector2i.ZERO, "duracoes_ms":duracoes_combo},
		"ferido_direita": {"fonte":"ferido_tres_direcoes_v1.png", "linha_fonte":0, "linhas":1, "quadros":4, "lado":500, "limiar_alfa":40, "deslocamento":Vector2i(70,94), "duracoes_ms":[45,75,90,90]},
		"ferido_baixo": {"fonte":"ferido_tres_direcoes_v1.png", "linha_fonte":1, "linhas":1, "quadros":4, "lado":500, "limiar_alfa":40, "deslocamento":Vector2i(70,94), "duracoes_ms":[45,75,90,90]},
		"ferido_cima": {"fonte":"ferido_tres_direcoes_v1.png", "linha_fonte":2, "linhas":1, "quadros":4, "lado":500, "limiar_alfa":40, "deslocamento":Vector2i(70,94), "duracoes_ms":[45,75,90,90]},
		"ferido_esquerda": {"fonte":"ferido_tres_direcoes_v1.png", "espelhar_de":"ferido_direita", "linhas":1, "quadros":4, "lado":640, "deslocamento":Vector2i.ZERO, "duracoes_ms":[45,75,90,90]}
	}
	for direcao in ["direita","baixo","cima"]:
		dados["morte_"+direcao] = {"fonte":"morte_"+direcao+"_v1.png","linhas":2,"quadros":8,"lado":600,"deslocamento":Vector2i(20,10),"limiar_alfa":128,"duracoes_ms":[80,100,110,100,100,120,160,500],"loop":false}
	dados["morte_cima"].lado = 534
	dados["morte_cima"].deslocamento = Vector2i(53,56)
	dados["morte_baixo"].lado = 505
	dados["morte_baixo"].deslocamento = Vector2i(67,80)
	dados["morte_direita"].lado = 512
	dados["morte_direita"].deslocamento = Vector2i(64,73)
	dados["morte_esquerda"] = {"espelhar_de":"morte_direita","fonte":"morte_direita_v1.png","linhas":2,"quadros":8,"lado":640,"deslocamento":Vector2i.ZERO,"duracoes_ms":[80,100,110,100,100,120,160,500],"loop":false}
	var registro := {"celula": [CELULA, CELULA], "pivo": [320,560], "escala": ESCALA, "altura_referencia_px": 31, "direcoes":DIRECOES, "animacoes": {}}
	var quantidade_subrecursos := 0
	for nome in dados: quantidade_subrecursos += int(dados[nome].quadros)
	var recursos := '[gd_resource type="SpriteFrames" load_steps=%d format=3]\n\n' % (1+dados.size()+quantidade_subrecursos)
	for nome in dados:
		recursos += '[ext_resource type="Texture2D" path="%s%s.png" id="%s"]\n' % [DESTINO, nome, nome]
	recursos += "\n"
	for nome in dados:
		var ficha: Dictionary = dados[nome]
		var espelhar_de: String = ficha.get("espelhar_de", "")
		var imagem := Image.load_from_file(FONTES + ficha.fonte) if espelhar_de.is_empty() else Image.load_from_file(DESTINO + espelhar_de + ".png")
		var tamanho_fonte := imagem.get_size()
		if ficha.has("linha_fonte"):
			var altura_linha := imagem.get_height()/3
			imagem = imagem.get_region(Rect2i(0,int(ficha.linha_fonte)*altura_linha,imagem.get_width(),altura_linha))
		var lado := int(ficha.get("lado",512))
		var colunas := int(ficha.get("colunas",4))
		imagem.convert(Image.FORMAT_RGBA8)
		# O gerador devolve a mesma grade em resolução variável. Transformação comum à folha.
		imagem.resize(lado * colunas, lado * int(ficha.linhas), Image.INTERPOLATE_LANCZOS)
		# Retira somente ruído residual de alfa no fundo; preserva o desenho e a fonte original.
		_limpar_alfa_residual(imagem,float(ficha.get("limiar_alfa",16)))
		var atlas := Image.create(CELULA * colunas, CELULA * int(ficha.linhas), false, Image.FORMAT_RGBA8)
		for q in int(ficha.quadros):
			var coluna := q % colunas
			var linha := q / colunas
			var origem := int(ficha.get("ordem",range(int(ficha.quadros)))[q])
			var regiao := Rect2i((origem % colunas) * lado, (origem / colunas) * lado, lado, lado)
			var pose := imagem.get_region(regiao)
			if not espelhar_de.is_empty():
				# Espelha cada célula pronta; conserva a ordem temporal e a raiz.
				pose.flip_x()
			var correcoes: Dictionary = ficha.get("correcoes",{})
			if correcoes.has(str(q)):
				pose = Image.load_from_file(FONTES + correcoes[str(q)])
				pose.convert(Image.FORMAT_RGBA8)
				pose.resize(lado,lado,Image.INTERPOLATE_LANCZOS)
				_limpar_alfa_residual(pose)
			var deslocamento: Vector2i = ficha.get("deslocamentos_linhas",{}).get(str(linha),ficha.deslocamento)
			atlas.blit_rect(pose, Rect2i(0,0,lado,lado), Vector2i(coluna * CELULA, linha * CELULA) + deslocamento)
			recursos += '[sub_resource type="AtlasTexture" id="%s_%d"]\natlas = ExtResource("%s")\nregion = Rect2(%d, %d, %d, %d)\n\n' % [nome,q,nome,coluna*CELULA,linha*CELULA,CELULA,CELULA]
		atlas.save_png(DESTINO + nome + ".png")
		registro.animacoes[nome] = {"fonte": ficha.fonte, "espelhada_de":espelhar_de, "linha_fonte":ficha.get("linha_fonte",-1), "resolucao_fonte": [tamanho_fonte.x,tamanho_fonte.y], "grade": [colunas,ficha.linhas], "lado_intermediario":lado, "duracoes_ms": ficha.duracoes_ms, "deslocamento_grade": [ficha.deslocamento.x,ficha.deslocamento.y], "loop": ficha.get("loop",nome.begins_with("correr")), "ordem_fontes":ficha.get("ordem",range(int(ficha.quadros))), "correcoes":ficha.get("correcoes",{}), "deslocamentos_linhas":ficha.get("deslocamentos_linhas",{})}
	var animacoes: Array[String] = []
	for nome in dados:
		animacoes.append(_animacao(nome,nome,0,int(dados[nome].quadros),dados[nome].duracoes_ms,dados[nome].get("loop",nome.begins_with("correr"))))
	for direcao in DIRECOES:
		if not dados.has("combo_"+direcao):
			continue
		for golpe in 3:
			animacoes.append(_animacao("ataque_%d_%s" % [golpe+1,direcao], "combo_"+direcao, golpe*4, 4, plano.combo.duracoes_golpes_ms.slice(golpe*4,golpe*4+4), false))
		animacoes.append(_animacao("parado_"+direcao,"combo_"+direcao,11,1,[100],true))
	recursos += "[resource]\nanimations = [%s]\n" % ",\n".join(animacoes)
	FileAccess.open(DESTINO + "animacoes.tres",FileAccess.WRITE).store_string(recursos)
	registro["impactos_combo"] = [1,5,9]
	registro["efeito_corte_combo"] = {"quadros":[1,2,5,6,9,10],"impactos":[1,5,9],"estilo":"crescente branco com azul claro integrado aos quadros"}
	registro["intervalo_entre_golpes_ms"] = plano.combo.intervalo_entre_golpes_ms
	registro["duracoes_golpes_ms"] = plano.combo.duracoes_golpes_ms
	registro["velocidade_corrida_px_s"] = 100
	registro["direcoes_combo"] = DIRECOES.filter(func(d): return dados.has("combo_"+d))
	FileAccess.open(DESTINO + "registro_animacoes.json",FileAccess.WRITE).store_string(JSON.stringify(registro,"\t") + "\n")
	print("GOBLIN_ADAGA: corrida nas quatro direcoes; combo nas quatro direcoes; pivo 320,560; escala ",ESCALA)
	quit()

func _limpar_alfa_residual(imagem: Image, limiar: float = 16.0) -> void:
	for y in imagem.get_height():
		for x in imagem.get_width():
			if imagem.get_pixel(x,y).a <= limiar / 255.0:
				imagem.set_pixel(x,y,Color.TRANSPARENT)

func _animacao(nome: String, atlas: String, inicio: int, quantidade: int, duracoes: Array, repetir: bool) -> String:
	var frames: Array[String] = []
	for q in quantidade:
		frames.append('{"duration": %s, "texture": SubResource("%s_%d")}' % [str(float(duracoes[q])/10.0),atlas,inicio+q])
	return '{"frames": [%s], "loop": %s, "name": &"%s", "speed": 100.0}' % [", ".join(frames),str(repetir),nome]
