extends SceneTree

const Biblioteca := preload("res://codigo/cidade/interiores_detalhados.gd")
var falhas := 0

class EstacaoTeste extends Node:
	var estacao_atual := 0

func _initialize() -> void:
	rodar.call_deferred()

func quadros(n := 6) -> void:
	for i in n:
		await process_frame
		await physics_frame

func verificar(ok: bool, mensagem: String) -> void:
	if not ok:
		falhas += 1
		push_error(mensagem)

func assinatura(cena: Node) -> String:
	var caixas := []
	for corpo in cena.find_children("*", "StaticBody2D", true, false):
		for forma in corpo.get_children():
			if forma is CollisionShape2D and forma.shape is RectangleShape2D:
				caixas.append([str(forma.global_position), str(forma.shape.size), forma.disabled])
	return JSON.stringify(caixas)

func verificar_chamas(detalhe: Node) -> void:
	var sprite: Sprite2D = detalhe.imagem
	var textura := sprite.texture.get_image()
	var w := textura.get_width() / sprite.hframes
	var h := textura.get_height()
	var mudou_forma := 0
	var estrutura_imovel := true
	for y in h:
		for x in w:
			var a := textura.get_pixel(x, y)
			var b := textura.get_pixel(x + w, y)
			if y < h * 0.54:
				estrutura_imovel = estrutura_imovel and a == b
			# A silhueta quente muda; só variar o brilho não satisfaz o teste.
			var quente_a := a.r > a.g * 1.12 and a.g > a.b * 1.5 and a.r > 0.7
			var quente_b := b.r > b.g * 1.12 and b.g > b.b * 1.5 and b.r > 0.7
			if quente_a != quente_b:
				mudou_forma += 1
	verificar(mudou_forma > 20, "Chamas mudam de silhueta, não apenas de brilho")
	verificar(estrutura_imovel, "Pedra, viga e decoração não se movem com o fogo")
	var anterior := sprite.frame
	detalhe._process(1.0 / float(detalhe.dados.fps))
	verificar(sprite.frame != anterior, "A animação avança durante a execução")

func contexto_separado() -> void:
	var mundos := []
	for e in [1, 3]:
		var mundo := Node2D.new()
		root.add_child(mundo)
		mundos.append(mundo)
		var terreno := Node2D.new()
		terreno.name = "Terrains"
		mundo.add_child(terreno)
		var estado := EstacaoTeste.new()
		estado.name = "Estacoes"
		estado.estacao_atual = e
		terreno.add_child(estado)
		var sala := Node2D.new()
		mundo.add_child(sala)
		verificar(Biblioteca.estacao(sala) == e, "Cada mundo usa sua própria estação visual")
	for mundo in mundos:
		mundo.queue_free()

func rodar() -> void:
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"):
		push_error("Use projeto e saves isolados.")
		quit(1)
		return
	root.get_node("Introducao").pular_prologo()
	contexto_separado()
	var layout: Dictionary = load("res://codigo/cidade/interior_casa.gd").dados()["casas"]
	var casas := layout.keys()
	casas.append("palafita")
	for id: String in casas:
		root.get_node("Calendario").dia = 1
		root.get_node("Transicao").hora_salva = 12.0
		var caminho := "res://cenas/casa.tscn" if id == "casa_jogador" else ("res://cenas/palafita.tscn" if id == "palafita" else "res://cenas/cidade/" + id + ".tscn")
		change_scene_to_file(caminho)
		await quadros(18)
		var cena := current_scene
		var interior: Node2D = cena.get_node("Interior")
		var sala: Node2D = interior.get_node("Sala")
		var original := assinatura(cena)
		var detalhes := interior.find_children("DetalheAmbiente", "Node", true, false)
		verificar(not detalhes.is_empty(), "Biblioteca detalhada montada: " + id)
		for e in 4:
			root.get_node("Calendario").dia = 1 + e * root.get_node("Calendario").DIAS_POR_ESTACAO
			await quadros()
			verificar(sala.FOLHA.resource_path == Biblioteca.RAIZ + "materiais/" + ["primavera", "verao", "outono", "inverno"][e] + "/piso_medio.png", "Sala segue o calendário: " + id)
			for detalhe in detalhes:
				var imagem: Sprite2D = detalhe.imagem
				verificar(imagem.texture.resource_path.begins_with(Biblioteca.RAIZ), "Nenhum móvel comum usa o atlas antigo: " + id)
				verificar(detalhe.estacao == e and imagem.scale == Vector2(0.25, 0.25), "Móvel4× segue a estação sem alterar escala lógica: " + id)
				var canvas: Array = detalhe.dados["canvas_logico"]
				verificar((imagem.get_rect().size * imagem.scale).is_equal_approx(Vector2(canvas[0], canvas[1])), "Canvas e âncora preservados: " + id)
				if "/lareira/" in imagem.texture.resource_path and e == 0:
					verificar_chamas(detalhe)
				if id == "pousada" and "/pousada/mesa/" in imagem.texture.resource_path:
					verificar(imagem.get_parent().get_node("Candelabro").position.y <= -28, "Vela fica atrás da área servida da mesa")
					var tampo := imagem.texture.get_image()
					for x in [-21, 21]:
						for y in [-28, -10]:
							var pixel := Vector2i((Vector2(x, y) - imagem.offset * imagem.scale) / imagem.scale)
							verificar(tampo.get_pixelv(pixel).a > 0.8, "Travessa e caneca servidas cabem inteiras no tampo")
			verificar(assinatura(cena) == original, "Trocar estação não altera colisões: " + id)
			if id == "sede":
				verificar(cena.get_node("MuralPedidos").nome_tela == "mural_cidade", "Quadro de tarefas mantém a interação de missões")
				var mural: Sprite2D = interior.get_node("Mural/Imagem")
				verificar(mural.get_rect().size * mural.scale == Vector2(56, 57), "Mural conserva os postes e a proporção do quadro da praça")
				if e == 0:
					var externo: Texture2D = load("res://assets/cenario/cidade/enfeites_detalhados/mural/primavera.png")
					verificar(mural.texture.get_image().get_data() == externo.get_image().get_data(), "Sede usa exatamente o sprite do quadro externo")
			if id == "forja":
				var bigorna: Sprite2D = interior.get_node("Fornalha/Imagem")
				var trabalho: GDScript = load("res://codigo/cidade/trabalho_ferreiro.gd")
				var pixel := Vector2i(bigorna.to_local(trabalho.PONTO_IMPACTO) - bigorna.offset)
				verificar(bigorna.texture.get_image().get_pixelv(pixel).a > 0.9, "Martelo e centelhas encontram a bigorna real, sem trabalhar no ar")
		if id == "palafita":
			for movel in interior.get_node("MobiliarioCais").get_children():
				if movel is Sprite2D:
					verificar(movel.texture.resource_path.begins_with(Biblioteca.RAIZ), "Equipamentos de pesca também usam a arte nova")
		if id == "casa_jogador":
			var objetos := cena.get_node("Objetos3D")
			for lado in ["E", "D"]:
				verificar(objetos.get_node("Mesa/Cafe_" + lado).z_index > objetos.get_node("Mesa/ImagemDetalhada").z_index, "Xícara e vapor ficam acima do tampo")
			var faixas := 0
			for filho in objetos.get_children():
				if str(filho.name).begins_with("Cama_f"):
					faixas += 1
					verificar(filho.has_node("FaixaDetalhada"), "Cama conserva suas faixas de profundidade")
			verificar(faixas == 8, "Oito faixas da cama mantidas")
			var cama: Node2D = objetos.get_node("CamaDormindo")
			cama.deitar()
			verificar(cama.resolucao == 4 and cama.get_node("Cobertor").scale.x == 0.25, "Sono usa o cobertor detalhado em escala lógica")
			verificar(not cena.get_node("Jogador").visible and cama.has_node("Cabeca"), "Sono mantém a aparência do jogador")
			cama.levantar()
			verificar(cena.get_node("Jogador").visible, "Acordar restaura o jogador")
		print("INTERIOR VALIDADO: ", id)
		cena.queue_free()
		current_scene = null
		await quadros(4)
	print("INTERIORES DETALHADOS: ", falhas, " falhas; dez interiores, quatro estações, colisões, escala, sono e mundos separados.")
	quit(1 if falhas else 0)
