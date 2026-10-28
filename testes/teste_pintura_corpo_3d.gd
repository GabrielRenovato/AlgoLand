extends SceneTree
## Garante que pintar o corpo não repete a regressão de deformar o manequim.
const Pintura := preload("res://codigo/jogador/pintura_corpo_3d.gd")
func _initialize(): rodar.call_deferred()
func expandir(malha: ArrayMesh) -> Array:
	var resultado: Array=[]
	for superficie in malha.get_surface_count():
		var a:=malha.surface_get_arrays(superficie)
		var indices: PackedInt32Array=a[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			for i in a[Mesh.ARRAY_VERTEX].size():indices.append(i)
		for i in indices:
			resultado.append([a[Mesh.ARRAY_VERTEX][i],a[Mesh.ARRAY_NORMAL][i],a[Mesh.ARRAY_COLOR][i],
				a[Mesh.ARRAY_TEX_UV2][i],(a[Mesh.ARRAY_BONES] as PackedInt32Array).slice(i*4,i*4+4),
				(a[Mesh.ARRAY_WEIGHTS] as PackedFloat32Array).slice(i*4,i*4+4)])
	return resultado
func rodar():
	assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
	var cena=load("res://cenas/personagem/base_3d/personagem.tscn").instantiate()
	root.add_child(cena)
	var corpo: MeshInstance3D=cena.find_child("CorpoBase",true,false)
	corpo.material_override=corpo.material_override.duplicate()
	var antes:=expandir(corpo.mesh)
	var skin:=corpo.skin
	var transformacao:=corpo.transform
	Pintura.aplicar(corpo)
	var depois:=expandir(corpo.mesh)
	assert(antes.size()==depois.size(),"Mesmos triângulos e mesma ordem")
	for i in antes.size():
		assert(antes[i][0]==depois[i][0],"Posição do vértice preservada")
		# Recompactar normais no ArrayMesh pode variar até um passo da codificação
		# octaédrica do motor; a direção não é recalculada nem suavizada.
		assert(antes[i][1].distance_to(depois[i][1])<.00025,"Normal preservada")
		assert(antes[i][2]==depois[i][2] and antes[i][3]==depois[i][3],"Regiões, rosto e cobertura preservados")
		assert(antes[i][4]==depois[i][4] and antes[i][5]==depois[i][5],"Ossos e pesos preservados")
	assert(corpo.skin==skin and corpo.transform==transformacao,"Skin, proporções e pivô preservados")
	for superficie in corpo.mesh.get_surface_count():
		for uv in corpo.mesh.surface_get_arrays(superficie)[Mesh.ARRAY_TEX_UV]:
			assert(uv.x>0 and uv.x<1 and uv.y>0 and uv.y<1,"Atlas sem vazamento")
	assert(corpo.material_override.get_shader_parameter("desenho_pixel_corpo")==true,"Pintura ativa")
	print("PINTURA CORPO: ",antes.size()/3," triângulos preservados; posições, normais, rosto, cobertura, rig e pesos conferidos; zero falhas")
	cena.free()
	quit()
