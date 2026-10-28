extends RefCounted
## Variante cosmética da malha, calculada uma vez no repouso do rig.
## Preserva vértices do corpo, UVs, pesos, ossos e molde original.
static func ponto_arredondado(p: Vector3) -> Vector3:
	var inferior := 1.0-smoothstep(-0.02,0.12,p.y)
	var frente := smoothstep(-0.05,0.03,p.z)
	var centro := 1.0-smoothstep(0.015,0.065,absf(p.x))
	var novo := p
	novo.y += (0.022+0.010*centro)*inferior*frente
	novo.x *= 1.0+0.20*(1.0-smoothstep(0.015,0.105,p.y))*frente
	return novo

static func construir(base: ArrayMesh, cabeca_para_malha: Transform3D) -> ArrayMesh:
	var nova := ArrayMesh.new()
	nova.resource_name="Rosto curto e arredondado (estudo)"
	var malha_para_cabeca := cabeca_para_malha.affine_inverse()
	var normal_para_malha := cabeca_para_malha.basis.inverse().transposed()
	var passo := 0.0001
	for s in base.get_surface_count():
		var arrays := base.surface_get_arrays(s).duplicate(true)
		var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var normais: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
		var cores: PackedColorArray=arrays[Mesh.ARRAY_COLOR]
		for i in vertices.size():
			if cores[i].r<0.25 or cores[i].r>0.75:continue
			var p := malha_para_cabeca*vertices[i]
			var ajustado := ponto_arredondado(p)
			if ajustado.is_equal_approx(p):continue
			vertices[i]=cabeca_para_malha*ajustado
			# Normal acompanha a deformação local; evita facetas com luz antiga.
			var jacobiano := Basis(
				(ponto_arredondado(p+Vector3(passo,0,0))-ponto_arredondado(p-Vector3(passo,0,0)))/(2.0*passo),
				(ponto_arredondado(p+Vector3(0,passo,0))-ponto_arredondado(p-Vector3(0,passo,0)))/(2.0*passo),
				(ponto_arredondado(p+Vector3(0,0,passo))-ponto_arredondado(p-Vector3(0,0,passo)))/(2.0*passo))
			var normal := cabeca_para_malha.basis.transposed()*normais[i]
			normais[i]=(normal_para_malha*jacobiano.inverse().transposed()*normal).normalized()
		arrays[Mesh.ARRAY_VERTEX]=vertices
		arrays[Mesh.ARRAY_NORMAL]=normais
		nova.add_surface_from_arrays(base.surface_get_primitive_type(s),arrays,[],{},base.surface_get_format(s))
		nova.surface_set_material(s,base.surface_get_material(s))
	return nova
