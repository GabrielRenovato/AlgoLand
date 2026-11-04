extends SceneTree
## Transformação comum a cada folha, sem ajustar a escala de poses isoladas.
const FONTES := "res://arte/fontes/inimigos/goblin_machado_2d/"
const DESTINO := "res://assets/inimigos/goblin_machado_2d/"
const CELULA := 640
func _initialize() -> void:
	var dados := {
		"correr_direita":{"fonte":"corrida_modelo_proprio_direita_v2.png","lado":500,"deslocamento":Vector2i(70,88),"duracoes_ms":[60,70,50,60,60,70,50,60],"loop":true},
		"ataque_direita":{"fonte":"ataque_reddit_direita_v4.png","lado":640,"deslocamento":Vector2i(0,-23),"limiar_alfa":200,"duracoes_ms":[80,160,140,45,55,90,130,180],"loop":false},
		"ataque_cima":{"fonte":"ataque_cima_v1.png","lado":600,"deslocamento":Vector2i(20,10),"limiar_alfa":64,"duracoes_ms":[80,160,140,45,55,90,130,180],"loop":false},
		"ataque_baixo":{"fonte":"ataque_baixo_v1.png","lado":500,"deslocamento":Vector2i(70,85),"limiar_alfa":64,"duracoes_ms":[80,160,140,45,55,90,130,180],"loop":false}
	}
	dados["correr_cima"] = {"fonte":"corrida_cima_v2.png","lado":476,"deslocamento":Vector2i(82,97),"limiar_alfa":128,"duracoes_ms":[60,70,50,60,60,70,50,60],"loop":true}
	dados["correr_baixo"] = {"fonte":"corrida_baixo_v1.png","lado":480,"deslocamento":Vector2i(80,92),"limiar_alfa":128,"duracoes_ms":[60,70,50,60,60,70,50,60],"loop":true}
	for acao in ["correr","ataque"]:
		dados[acao+"_esquerda"] = dados[acao+"_direita"].duplicate(true)
		dados[acao+"_esquerda"].espelhar_de = acao+"_direita"
		dados[acao+"_esquerda"].lado = 640
		dados[acao+"_esquerda"].deslocamento = Vector2i.ZERO
	for direcao in ["direita","baixo","cima"]:
		for acao in ["ferido","morte"]:
			dados[acao+"_"+direcao] = {"fonte":"dano_morte_"+direcao+"_v1.png","linha_fonte":0 if acao=="ferido" else 1,"linhas":1 if acao=="ferido" else 2,"quadros":4 if acao=="ferido" else 8,"lado":600,"deslocamento":Vector2i(20,10),"limiar_alfa":128,"duracoes_ms":[45,75,90,90] if acao=="ferido" else [80,100,110,100,100,120,160,500],"loop":false}
	for acao in ["ferido","morte"]:
		dados[acao+"_direita"].lado = 564
		dados[acao+"_direita"].deslocamento = Vector2i(38,43)
		dados[acao+"_baixo"].lado = 582
		dados[acao+"_baixo"].deslocamento = Vector2i(29,0)
		dados[acao+"_cima"].lado = 580
		dados[acao+"_cima"].deslocamento = Vector2i(30,36)
	for acao in ["ferido","morte"]:
		dados[acao+"_esquerda"] = dados[acao+"_direita"].duplicate(true)
		dados[acao+"_esquerda"].espelhar_de = acao+"_direita"
		dados[acao+"_esquerda"].lado = 640
		dados[acao+"_esquerda"].deslocamento = Vector2i.ZERO
		dados[acao+"_esquerda"].erase("linha_fonte")
	var registro := {"celula":[640,640],"pivo":[320,560],"escala":.071,"direcoes":["direita","cima","baixo","esquerda"],"velocidade_corrida_px_s":100,"impacto_ataque":4,"animacoes":{}}
	var subrecursos := 0
	for ficha in dados.values(): subrecursos += int(ficha.get("quadros",8))
	var recursos := '[gd_resource type="SpriteFrames" load_steps=%d format=3]\n\n' % (dados.size()+subrecursos+1)
	for nome in dados:
		recursos += '[ext_resource type="Texture2D" path="%s%s.png" id="%s"]\n' % [DESTINO,nome,nome]
	recursos += "\n"
	var animacoes: Array[String] = []
	for nome in dados:
		var ficha: Dictionary = dados[nome]
		var espelhar_de: String = ficha.get("espelhar_de","")
		var imagem := Image.load_from_file(FONTES+ficha.fonte) if espelhar_de.is_empty() else Image.load_from_file(DESTINO+espelhar_de+".png")
		var origem := imagem.get_size()
		var linhas: int = ficha.get("linhas",2)
		var quantidade: int = ficha.get("quadros",8)
		if ficha.has("linha_fonte"):
			var altura_linha := imagem.get_height()/3
			imagem = imagem.get_region(Rect2i(0,int(ficha.linha_fonte)*altura_linha,imagem.get_width(),linhas*altura_linha))
		imagem.convert(Image.FORMAT_RGBA8)
		var lado: int = ficha.lado
		imagem.resize(lado*4,lado*linhas,Image.INTERPOLATE_LANCZOS)
		for y in imagem.get_height():
			for x in imagem.get_width():
				if imagem.get_pixel(x,y).a<=float(ficha.get("limiar_alfa",16))/255.0: imagem.set_pixel(x,y,Color.TRANSPARENT)
		var atlas := Image.create(CELULA*4,CELULA*linhas,false,Image.FORMAT_RGBA8)
		var efeito: Image
		if nome == "ataque_direita":
			efeito = Image.load_from_file(FONTES+"efeito_corte_reddit_v1.png")
			efeito.convert(Image.FORMAT_RGBA8)
			efeito.resize(CELULA*4,CELULA*2,Image.INTERPOLATE_LANCZOS)
			for y in efeito.get_height():
				for x in efeito.get_width():
					if efeito.get_pixel(x,y).a<=64.0/255.0: efeito.set_pixel(x,y,Color.TRANSPARENT)
		for q in quantidade:
			var indice: int = ficha.get("ordem",range(quantidade))[q]
			var pose := imagem.get_region(Rect2i((indice%4)*lado,(indice/4)*lado,lado,lado))
			if not espelhar_de.is_empty(): pose.flip_x()
			if ficha.get("correcoes",{}).has(str(q)):
				pose = Image.load_from_file(FONTES+ficha.correcoes[str(q)])
				pose.convert(Image.FORMAT_RGBA8)
				pose.resize(lado,lado,Image.INTERPOLATE_LANCZOS)
				for y in lado:
					for x in lado:
						if pose.get_pixel(x,y).a<=16.0/255.0: pose.set_pixel(x,y,Color.TRANSPARENT)
			atlas.blit_rect(pose,Rect2i(0,0,lado,lado),Vector2i((q%4)*CELULA,(q/4)*CELULA)+ficha.deslocamento)
			if efeito != null and q in [3,4,5]:
				var regiao := Rect2i((q%4)*CELULA,(q/4)*CELULA,CELULA,CELULA)
				atlas.blend_rect(efeito,regiao,regiao.position)
			recursos += '[sub_resource type="AtlasTexture" id="%s_%d"]\natlas = ExtResource("%s")\nregion = Rect2(%d,%d,640,640)\n\n' % [nome,q,nome,(q%4)*640,(q/4)*640]
		atlas.save_png(DESTINO+nome+".png")
		registro.animacoes[nome] = {"fonte":ficha.fonte,"resolucao_fonte":[origem.x,origem.y],"grade":[4,linhas],"lado_intermediario":lado,"deslocamento_grade":[ficha.deslocamento.x,ficha.deslocamento.y],"duracoes_ms":ficha.duracoes_ms,"loop":ficha.loop,"correcoes":ficha.get("correcoes",{}),"ordem_fontes":ficha.get("ordem",range(quantidade)),"limiar_alfa":ficha.get("limiar_alfa",16),"espelhada_de":espelhar_de,"linha_fonte":ficha.get("linha_fonte",-1)}
		animacoes.append(_animacao(nome,nome,range(quantidade),ficha.duracoes_ms,ficha.loop))
	animacoes.append(_animacao("parado_direita","ataque_direita",[7],[100],true))
	animacoes.append(_animacao("parado_cima","ataque_cima",[7],[100],true))
	animacoes.append(_animacao("parado_baixo","ataque_baixo",[7],[100],true))
	animacoes.append(_animacao("parado_esquerda","ataque_esquerda",[7],[100],true))
	recursos += "[resource]\nanimations = [%s]\n" % ",\n".join(animacoes)
	FileAccess.open(DESTINO+"animacoes.tres",FileAccess.WRITE).store_string(recursos)
	registro.animacoes.ataque_direita.efeito_corte = {"fonte":"efeito_corte_reddit_v1.png","quadros":[3,4,5],"limiar_alfa":64,"composicao":"sobre o corpo; mesma celula, sem deslocamento"}
	FileAccess.open(DESTINO+"registro_animacoes.json",FileAccess.WRITE).store_string(JSON.stringify(registro,"\t")+"\n")
	print("GOBLIN_MACHADO_2D: corrida direita; ataques direita/cima/baixo, raiz320/560")
	quit()
func _animacao(nome: String, atlas: String, ordem: Array, tempos: Array, repetir: bool) -> String:
	var quadros: Array[String] = []
	for i in ordem.size():
		quadros.append('{"duration":%s,"texture":SubResource("%s_%d")}' % [str(float(tempos[i])/10.0),atlas,ordem[i]])
	return '{"frames":[%s],"loop":%s,"name":&"%s","speed":100.0}' % [",".join(quadros),str(repetir),nome]
