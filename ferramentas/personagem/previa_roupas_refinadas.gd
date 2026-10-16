extends SceneTree
const Aparencia := preload("res://codigo/dados/aparencia.gd")
const PASTA := "res://arte/previas/personagens/refinado/roupas/"

func _initialize() -> void:
	_rodar()

func _rodar() -> void:
	var indices: Array[int] = [2,7,10]
	for i in Aparencia.total_roupas():
		if Aparencia.roupas()[i]["id"] in ["armadura_cavaleiro","armadura_cavaleiro_rubro","traje_cavalheiro"]:
			indices.append(i)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PASTA))
	for refinada in [false,true]:
		var viewport := SubViewport.new()
		viewport.size = Vector2i(indices.size()*160,560)
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
		root.add_child(viewport)
		var fundo := ColorRect.new()
		fundo.size = viewport.size
		fundo.color = Color("303039")
		viewport.add_child(fundo)
		for coluna in indices.size():
			var indice := indices[coluna]
			var pecas := 0 if Aparencia.raiz_armadura_visual(indice).is_empty() else 15
			var nome := Label.new()
			var id: String = Aparencia.roupas()[indice]["id"]
			nome.text = {"armadura_cavaleiro":"CARRASCO","armadura_cavaleiro_rubro":"RUBRO","traje_cavalheiro":"MORDOMO"}.get(id,Aparencia.nome_roupa(indice))
			nome.add_theme_font_size_override("font_size",12)
			nome.position = Vector2(coluna*160+8,8)
			viewport.add_child(nome)
			for direcao in 4:
				var origem := Node2D.new()
				origem.position = Vector2(coluna*160+80,direcao*128+104)
				origem.scale = Vector2(2,2)
				viewport.add_child(origem)
				var roupa: Sprite2D
				var cabelo: Sprite2D
				for camada in ["corpo","roupa","cabelo"]:
					var sprite := Sprite2D.new()
					sprite.hframes = 8
					sprite.vframes = 8
					origem.add_child(sprite)
					match camada:
						"corpo": Aparencia.aplicar_corpo(sprite,"andar",indice,pecas)
						"roupa":
							roupa = sprite
							if refinada:
								Aparencia.aplicar_roupa(sprite,indice,"andar",pecas)
							else:
								sprite.texture = Aparencia.roupa(indice,"andar",pecas)
						"cabelo":
							cabelo = sprite
							Aparencia.aplicar_cabelo(sprite,0,"andar",indice,pecas)
							sprite.modulate = Color("995e36")
					sprite.frame = direcao*8
				Aparencia.aplicar_cartola(cabelo,roupa,"andar",indice,pecas)
		await process_frame
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(PASTA+("depois" if refinada else "antes")+".png")
		viewport.queue_free()
		await process_frame
	quit()
