extends RefCounted
## Quatro penteados volumétricos independentes, ligados só ao osso da cabeça.
const Modelagem=preload("res://codigo/jogador/roupas_modeladas_3d.gd")
const Cabelo=preload("res://codigo/jogador/visuais_femininos_3d.gd")

static func construir(base: ArrayMesh,corpo: MeshInstance3D,s: Skeleton3D,forma: int) -> ArrayMesh:
	var t:=corpo.global_transform.affine_inverse()*s.global_transform*s.get_bone_global_rest(s.find_bone("DEF-head"))
	var bind:int=Modelagem.ligacoes(corpo,s)["DEF-head"]
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(Cabelo._abrir_franja(base,t),0,Transform3D.IDENTITY)
	st.deindex()
	if forma==7:
		Cabelo._cacho(st,Vector3(0,.23,-.14),Vector3(.075,.075,.070),t,bind)
		for i in 5:
			var a:=TAU*i/5
			Cabelo._cacho(st,Vector3(cos(a)*.035,.23+sin(a)*.035,-.18),Vector3(.035,.038,.025),t,bind)
	elif forma==8:
		Cabelo._mecha(st,[[Vector3(0,.10,-.14),.045,.030],[Vector3(0,.04,-.18),.055,.038],[Vector3(.016,-.04,-.20),.055,.038],[Vector3(.035,-.12,-.18),.035,.025],[Vector3(.025,-.17,-.16),.004,.004]],t,bind)
	elif forma==9:
		for i in 7:
			var y:=.065-i*.037
			for lado in [-1,1]:
				Cabelo._cacho(st,Vector3(.035+lado*.017*cos(i*PI),y,-.165-.012*sin(i*PI*.5)),Vector3(.030,.027,.027),t,bind)
		Cabelo._cacho(st,Vector3(.035,-.21,-.165),Vector3(.020,.035,.020),t,bind)
	elif forma==10:
		for lado in [-1,1]:
			for i in 4:
				var a:=.25+i*.48
				var x:float=lado*(.105+.018*sin(i*2))
				var z:=-.02-i*.033
				Cabelo._mecha(st,[[Vector3(x*.8,.18,z),.028,.035],[Vector3(x,.10,z),.040,.040],[Vector3(x+lado*.017,.025,z-.005),.035,.037],[Vector3(x-lado*.013,-.055,z),.028,.030],[Vector3(x+lado*.008,-.09,z),.003,.003]],t,bind)
		for i in 5:
			Cabelo._mecha(st,[[Vector3((i-2)*.04,.17,-.105),.033,.030],[Vector3((i-2)*.046,.04,-.132),.033,.035],[Vector3((i-2)*.044,-.065,-.130),.030,.030],[Vector3((i-2)*.040,-.10,-.114),.003,.003]],t,bind)
	st.generate_normals()
	st.index()
	return st.commit()
