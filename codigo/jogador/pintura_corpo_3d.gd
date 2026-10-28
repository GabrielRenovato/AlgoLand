extends RefCounted
## Só cria UVs de pintura no repouso. Não modifica posição, normal, peso ou rig.
const ATLAS := "res://assets/personagens/base_3d/pintura_corpo/atlas.png"

static func uv(p: Vector3,painel: Vector2i) -> Vector2:
	var local: Vector2
	if painel.y==1 and painel.x>=2: # Short: frente/costas.
		local=Vector2((p.x+.25)/.50,(1.025-p.y)/.34)
	elif painel.y==1: # Pernas: os dois lados estão pintados no mesmo painel.
		local=Vector2((p.x+.25)/.50,(.88-p.y)/.85)
	elif painel.x>=2: # Braço no repouso em T; longitudinal ombro→mão.
		local=Vector2(clampf((p.z+.16)/.20,0,1)*.42+.04,(.92-absf(p.x))/.74)
		local.y=1.0-local.y
	else: # Tronco: clavícula→cintura.
		local=Vector2((p.x+.25)/.50,(1.565-p.y)/.60)
	local=local.clamp(Vector2(.025,.025),Vector2(.975,.975))
	return (local+Vector2(painel))/Vector2(4,2)

static func aplicar(corpo: MeshInstance3D) -> void:
	var base:=corpo.mesh as ArrayMesh
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for superficie in base.get_surface_count():
		var a:=base.surface_get_arrays(superficie)
		var vertices: PackedVector3Array=a[Mesh.ARRAY_VERTEX]
		var cores: PackedColorArray=a[Mesh.ARRAY_COLOR]
		var indices: PackedInt32Array=a[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			for i in vertices.size():indices.append(i)
		for t in range(0,indices.size(),3):
			var centro: Vector3=(vertices[indices[t]]+vertices[indices[t+1]]+vertices[indices[t+2]])/3.0
			var cor: Color=(cores[indices[t]]+cores[indices[t+1]]+cores[indices[t+2]])/3.0
			var braco:=absf(centro.x)>.24 and centro.y>1.2
			var frente:=centro.z>(-.065 if braco else -.025)
			var painel:=Vector2i(0 if frente else 1,0)
			if cor.r>.75:painel=Vector2i(2 if frente else 3,1)
			elif braco:painel=Vector2i(2 if frente else 3,0)
			elif centro.y<.90:painel=Vector2i(0 if frente else 1,1)
			for k in 3:
				var i:=indices[t+k]
				st.set_normal(a[Mesh.ARRAY_NORMAL][i])
				st.set_color(cores[i])
				st.set_uv(uv(vertices[i],painel))
				st.set_uv2(a[Mesh.ARRAY_TEX_UV2][i])
				st.set_bones((a[Mesh.ARRAY_BONES] as PackedInt32Array).slice(i*4,i*4+4))
				st.set_weights((a[Mesh.ARRAY_WEIGHTS] as PackedFloat32Array).slice(i*4,i*4+4))
				st.add_vertex(vertices[i])
	st.index()
	corpo.mesh=st.commit()
	corpo.material_override.set_shader_parameter("desenho_pixel_corpo",true)
	corpo.material_override.set_shader_parameter("desenho_corpo",load(ATLAS))
