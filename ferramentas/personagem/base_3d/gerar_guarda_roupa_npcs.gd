extends SceneTree
## Prepara peças novas e a tampa corrigida do cabelo longo; não toca no corpo.
const Catalogo=preload("res://codigo/dados/roupas_base_3d.gd")
const Pixel=preload("res://codigo/jogador/roupas_pixel_3d.gd")
func _initialize() -> void:rodar.call_deferred()
func rodar() -> void:
	assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
	root.get_node("Ranking").conexao_habilitada=false
	var previa:Node2D=load("res://codigo/ui/previa_heroi_3d.gd").new()
	root.add_child(previa)
	for i in 3:await process_frame
	var h=previa.heroi
	var corpo:MeshInstance3D=h._modelo.find_child("CorpoBase",true,false)
	var rig:=preload("res://codigo/jogador/roupas_modeladas_3d.gd").ligacoes(corpo,h._esqueleto)
	for categoria in ["camisa","calca","cabelo"]:
		for modelo in Catalogo.MODELOS[categoria]:
			if categoria=="camisa" and modelo.forma<6:continue
			if categoria=="calca" and modelo.forma!=5:continue
			if categoria=="cabelo" and modelo.forma<6:continue
			var indice:int=Catalogo.CATEGORIAS.find(categoria)
			var malha:ArrayMesh
			if categoria=="cabelo":malha=preload("res://codigo/jogador/visuais_femininos_3d.gd").cabelo(h._molde_cabelo,corpo,h._esqueleto,modelo.forma)
			elif categoria=="calca":malha=preload("res://codigo/jogador/visuais_femininos_3d.gd").saia(h._moldes_roupas[indice],corpo,h._esqueleto,5)
			else:malha=Catalogo.malha(h._moldes_roupas[indice],categoria,modelo.forma,rig)
			var faixas:Dictionary=h.PELE_PIXEL.extensoes(malha,h._pecas[indice],h._esqueleto)
			h.PELE_PIXEL.guardar_malha(modelo.id,malha,h.PELE_PIXEL.com_uv_pixel(malha,h._pecas[indice],h._esqueleto))
			assert(Pixel.pintar(categoria,modelo.get("estilo",modelo.forma),faixas).save_png(ProjectSettings.globalize_path(Pixel.caminho(modelo.id)))==OK)
			print("PEÇA SEPARADA: ",modelo.id)
	previa.queue_free()
	await process_frame
	quit()
