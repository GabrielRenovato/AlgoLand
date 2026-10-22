extends SceneTree

var falhas := 0
const ESTACOES := ["primavera", "verao", "outono", "inverno"]
const ARTE := "res://assets/cenario/praia/detalhada/"

func _initialize() -> void:
	rodar.call_deferred()

func verificar(ok: bool, mensagem: String) -> void:
	if not ok:
		falhas += 1
		push_error(mensagem)

func quadros(n := 12) -> void:
	for i in n:
		await process_frame
		await physics_frame

func assinatura(cena: Node) -> String:
	var caixas := []
	for forma in cena.find_children("*", "CollisionShape2D", true, false):
		if forma.get_parent() is StaticBody2D and forma.shape is RectangleShape2D:
			# Ativações sazonais de enfeites já existentes continuam permitidas.
			caixas.append([str(forma.global_position),str(forma.shape.size)])
	return JSON.stringify(caixas)

func rodar() -> void:
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"):
		push_error("Use saves isolados.")
		quit(1)
		return
	root.get_node("Introducao").pular_prologo()
	for local in ["cidade", "praia"]:
		root.get_node("Transicao").hora_salva=12.0
		change_scene_to_file("res://cenas/"+local+".tscn")
		await quadros(24)
		var fisica := assinatura(current_scene)
		for e in 4:
			root.get_node("Calendario").dia=1+e*30
			var estacoes := current_scene.get_node_or_null("Terrains/Estacoes")
			if estacoes != null: estacoes.definir_estacao(e,true)
			root.get_node("Calendario").estacao_mudou.emit(e)
			await quadros()
			var arvores := 0
			for detalhe in current_scene.find_children("DetalheAmbiente*", "Node", true, false):
				var sprite: Sprite2D = detalhe.imagem
				var caminho := sprite.texture.resource_path
				if "natureza_detalhada" in caminho:
					arvores += 1
					verificar("/"+ESTACOES[e]+"/" in caminho,"Árvore usa a estação local")
					verificar(sprite.scale == Vector2(.25,.25) and sprite.hframes == 1,"Arte4× da fazenda sem o atlas antigo")
					verificar(sprite.offset * sprite.scale == Vector2(-64,-127),"Raiz no mesmo pivô64,127 da fazenda")
					var sombra := sprite.get_parent().get_node("SombraChao/Projecao") as Sprite2D
					verificar(sombra.texture == sprite.texture,"Sombra acompanha a copa nova em cada estação")
			verificar(arvores > 5,"Cidade e orla recebem as árvores da fazenda")
			verificar(assinatura(current_scene)==fisica,"A troca de arte/estação conserva os obstáculos")
			if local == "praia":
				var praia := current_scene
				verificar(praia.material_mar.get_shader_parameter("areia_detalhada").resource_path == ARTE+"materiais/"+ESTACOES[e]+"/areia.png","Areia pintada segue calendário")
				verificar(praia.get_node("Terrains/Pier").material.get_shader_parameter("arte").resource_path == ARTE+"materiais/"+ESTACOES[e]+"/madeira.png","Madeira pintada segue calendário")
				for detalhe in praia.get_node("MobiliarioCais").find_children("DetalheAmbiente*","Node",true,false):
					verificar(detalhe.imagem.texture.resource_path.begins_with(ARTE),"Móveis externos usam o acabamento novo")
				for objeto in praia.get_node("DecoracaoPraia").get_children():
					if not str(objeto.name).begins_with("coqueiro"):continue
					var sprite: Sprite2D=objeto.get_node("Imagem")
					verificar(sprite.texture.resource_path.begins_with(ARTE),"Coqueiro usa fonte pintada")
					var esperado := 6.0 if str(objeto.name).begins_with("coqueiro_a") else -18.0
					var forma: CollisionShape2D=objeto.get_node("Tronco").get_child(0)
					verificar(forma.position==Vector2(esperado,-4),"Colisão continua na raiz inclinada")
					var im := sprite.texture.get_image()
					var x := im.get_width()/2+roundi(esperado*4)
					verificar(im.get_pixel(x,im.get_height()-8).a>0.8,"A raiz desenhada encontra a base física do coqueiro")
					var sombra: Sprite2D=objeto.get_node("Sombra")
					var pe:=Vector2(x,im.get_height())
					verificar(sprite.to_global(sprite.offset+pe).distance_to(sombra.to_global(sombra.offset+pe))<0.5,"Sombra começa na raiz, sem flutuar ao lado")
				for x in [208,432]:
					var banco: Sprite2D=praia.get_node("MobiliarioCais/banco_%d_176" % x)
					verificar(banco.scale==Vector2.ONE and banco.get_node("Assento").global_scale==Vector2.ONE,"Arte4× não encolhe o alcance dos bancos")
		print("PADRÃO VALIDADO: ",local)
		current_scene.queue_free()
		current_scene=null
		await quadros(4)
	print("PRAIA DETALHADA: ",falhas," falhas")
	quit(1 if falhas else 0)
