extends SceneTree
## Gera as roupas em pixel art (um PNG por modelo do catálogo) medindo a malha real de cada
## peça: barra, gola, punho e bainha caem onde a peça termina. Save isolado; sobrescreve os PNGs.
func _initialize(): rodar.call_deferred()
func esperar(n: int):
	for i in n: await process_frame
func rodar():
	assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
	root.get_node("Ranking").conexao_habilitada=false
	root.get_node("Introducao").pular_prologo()
	change_scene_to_file("res://cenas/fazenda.tscn")
	await esperar(30)
	var h=current_scene.get_node("Jogador/HeroiBase3D")
	var catalogo=h.CATALOGO_ROUPAS
	var gerador=preload("res://codigo/jogador/roupas_pixel_3d.gd")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(gerador.PASTA))
	for i in 3:
		var categoria: String=catalogo.CATEGORIAS[i]
		for modelo in catalogo.MODELOS[categoria]:
			var malha: ArrayMesh
			if categoria=="calca" and modelo.forma>=3:
				malha=preload("res://codigo/jogador/visuais_femininos_3d.gd").saia(h._moldes_roupas[i],h._modelo.find_child("CorpoBase",true,false),h._esqueleto,modelo.forma)
			else:
				malha=catalogo.malha(h._moldes_roupas[i],categoria,modelo.forma)
			var faixas: Dictionary=h.PELE_PIXEL.extensoes(malha,h._pecas[i],h._esqueleto)
			h.PELE_PIXEL.guardar_malha(modelo.id,malha,h.PELE_PIXEL.com_uv_pixel(malha,h._pecas[i],h._esqueleto))
			var imagem: Image=gerador.pintar(categoria,modelo.estilo,faixas)
			assert(imagem.save_png(ProjectSettings.globalize_path(gerador.caminho(modelo.id)))==OK)
			print("ROUPA PIXEL: ",modelo.id," ",faixas)
	# Corpo: a malha original da cena do personagem (a do jogo já recebeu o UV).
	var cena_corpo: Node3D=load("res://cenas/personagem/base_3d/personagem.tscn").instantiate()
	root.add_child(cena_corpo)
	var corpo_original: MeshInstance3D=cena_corpo.find_child("CorpoBase",true,false)
	var esqueleto_original: Skeleton3D=cena_corpo.find_children("*","Skeleton3D",true,false)[0]
	h.PELE_PIXEL.guardar_malha("corpo",corpo_original.mesh,h.PELE_PIXEL.malha_do_corpo(corpo_original,esqueleto_original))
	print("MALHA PRONTA: corpo")
	cena_corpo.queue_free()
	# Cabelos 3D (o raspado não tem malha: o tom é pintado na pele).
	var corpo: MeshInstance3D=h._modelo.find_child("CorpoBase",true,false)
	for modelo in catalogo.MODELOS["cabelo"]:
		var malha: ArrayMesh=preload("res://codigo/jogador/visuais_femininos_3d.gd").cabelo(h._molde_cabelo,corpo,h._esqueleto,modelo.forma)
		if malha.get_surface_count()==0: continue
		h.PELE_PIXEL.guardar_malha(modelo.id,malha,h.PELE_PIXEL.com_uv_pixel(malha,h._pecas[3],h._esqueleto))
		var faixas: Dictionary=h.PELE_PIXEL.extensoes(malha,h._pecas[3],h._esqueleto)
		assert(gerador.pintar("cabelo",modelo.forma,faixas).save_png(ProjectSettings.globalize_path(gerador.caminho(modelo.id)))==OK)
		print("CABELO PIXEL: ",modelo.id," ",faixas)
	quit()
