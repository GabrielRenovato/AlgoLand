extends SceneTree

const Aparencia := preload("res://codigo/dados/aparencia.gd")
const PASTA := "res://arte/previas/personagens/refinado/cabelos/"

func _initialize() -> void:
	_rodar()

func _rodar() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PASTA))
	for refinado in [false,true]:
		var viewport := SubViewport.new()
		viewport.size = Vector2i(896,544)
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
		root.add_child(viewport)
		var fundo := ColorRect.new()
		fundo.size = viewport.size
		fundo.color = Color("303039")
		viewport.add_child(fundo)
		for indice in Aparencia.total_cabelos():
			var nome := Label.new()
			nome.text = Aparencia.nome_cabelo(indice)
			nome.add_theme_font_size_override("font_size",12)
			nome.position = Vector2(indice*128+8,8)
			viewport.add_child(nome)
			for direcao in 4:
				var origem := Node2D.new()
				origem.position = Vector2(indice*128+64,direcao*128+96)
				origem.scale = Vector2(2,2)
				viewport.add_child(origem)
				for camada in ["corpo","roupa","cabelo"]:
					var sprite := Sprite2D.new()
					sprite.hframes = 8
					sprite.vframes = 8
					origem.add_child(sprite)
					match camada:
						"corpo": Aparencia.aplicar_corpo(sprite,"andar",2,0)
						"roupa": sprite.texture = Aparencia.roupa(2,"andar",0)
						"cabelo":
							if refinado:
								Aparencia.aplicar_cabelo(sprite,indice,"andar",2,0)
							else:
								sprite.texture = Aparencia.cabelo(indice,"andar",2,0)
							sprite.modulate = Color("995e36")
					sprite.frame = direcao*8
		await process_frame
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(PASTA+("depois" if refinado else "antes")+".png")
		viewport.queue_free()
		await process_frame
	quit()
