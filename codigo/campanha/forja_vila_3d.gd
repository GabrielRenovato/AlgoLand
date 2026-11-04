@tool
extends "res://codigo/campanha/oficina_malha_3d.gd"
## Construção da forja: forno e instalações fixas; acessórios em cenas próprias.
signal quadro_fogo
const INTERVALO_FOGO := 1.0/8.0
var _calor: OmniLight3D
var _pinturas_fogo: Dictionary = {}
var _tempo_fogo := 0.0
var _acumulado_fogo := 0.0

func _ready() -> void:
	name = "ConstrucaoForja"
	_paredes()
	_telhado(Vector3(0,1.78,-0.22),3.56,1.02,0.78,false)
	_chamine()
	_forno()
	_cobertura_forno()
	_janela()
	_lanterna(Vector3(0.50,1.25,0.76))
	_finalizar()
	definir_estacao(0)

func _process(delta: float) -> void:
	_acumulado_fogo += delta
	if _acumulado_fogo < INTERVALO_FOGO: return
	var passos := floori(_acumulado_fogo/INTERVALO_FOGO)
	_acumulado_fogo -= passos*INTERVALO_FOGO
	definir_tempo_fogo(_tempo_fogo+passos*INTERVALO_FOGO)

func definir_tempo_fogo(tempo: float) -> void:
	_tempo_fogo = fposmod(tempo,2.0)
	for pintura in _pinturas_fogo.values(): pintura.set_shader_parameter("tempo",_tempo_fogo)
	if _calor:
		_calor.light_energy = 0.94+0.12*sin(_tempo_fogo*TAU)+0.05*sin(_tempo_fogo*TAU*3.0)
	quadro_fogo.emit()

func definir_estacao(estacao: int) -> void:
	super.definir_estacao(estacao)
	for tipo in ["fogo","brasa"]:
		if not _instancias.has(tipo): continue
		if not _pinturas_fogo.has(tipo):
			var pintura := ShaderMaterial.new()
			pintura.shader = preload("res://codigo/campanha/fogo_forja_3d.gdshader")
			pintura.set_shader_parameter("cor_base",Color("ffd154") if tipo == "fogo" else Color("eb6b1f"))
			_pinturas_fogo[tipo] = pintura
		_instancias[tipo].material_override = _pinturas_fogo[tipo]
	definir_tempo_fogo(_tempo_fogo)

func _paredes() -> void:
	_caixa(Vector3(3.14,1.7,1.28),Vector3(0,0.88,-0.16),"junta")
	# Alvenaria na frente possui relevo e junta entre os blocos, sem imagem de fachada.
	for linha in 9:
		var y := 0.18 + linha*0.18
		for coluna in 12:
			var x := -1.45+coluna*0.264+(0.11 if linha%2 else 0.0)
			if x > 1.48: continue
			if x>0.66 and x<1.24 and y>0.60 and y<1.28: continue
			var cor := Color.WHITE.darkened(float((linha*7+coluna*11)%5)*0.025)
			_caixa(Vector3(0.249,0.165,0.12),Vector3(x,y,0.51),"pedra",cor)
	for lado in [-1.0,1.0]:
		_caixa(Vector3(0.15,1.72,0.18),Vector3(lado*1.49,0.9,0.58),"madeira_escura")
	_caixa(Vector3(3.35,0.12,1.45),Vector3(0,1.73,-0.1),"madeira_escura")
	_caixa(Vector3(3.27,0.12,1.38),Vector3(0,0.07,-0.12),"pedra_escura")
	for x in [-1.25,-0.8,-0.35,0.1,0.55,1.0,1.4]:
		_caixa(Vector3(0.1,0.17,0.28),Vector3(x,1.74,0.57),"madeira")

func _chamine() -> void:
	var p := Vector3(-1.08,0.15,-0.05)
	_cilindro(p,0.235,3.25,"pedra",Color("e7decc"),12)
	for linha in 15:
		_anel(p+Vector3.UP*(linha*0.21+0.12),0.239,0.228,0.018,"junta",12)
		var angulo := (linha%2)*PI/6.0
		for j in 6:
			var a := angulo+j*TAU/6.0
			_viga(p+Vector3(cos(a)*0.237,linha*0.21+0.14,sin(a)*0.237),p+Vector3(cos(a)*0.237,linha*0.21+0.32,sin(a)*0.237),0.012,"junta")
	_anel(p+Vector3.UP*3.27,0.285,0.177,0.19,"pedra_escura",12)
	_cilindro(p+Vector3.UP*3.26,0.176,0.01,"fundo")
	_anel(p+Vector3.UP*3.46,0.286,0.177,0.025,"neve",12)

func _forno() -> void:
	var x := -0.48
	_caixa(Vector3(1.37,0.17,0.94),Vector3(x,0.15,0.8),"pedra_escura")
	_caixa(Vector3(1.13,1.10,0.2),Vector3(x,0.79,0.49),"pedra_escura")
	# Fundo recuado e paredes internas deixam a boca do forno verdadeiramente aberta.
	var fundo := PackedVector2Array([Vector2(x-0.43,0.24),Vector2(x+0.43,0.24),Vector2(x+0.43,0.83)])
	for i in range(1,9): fundo.append(Vector2(x+cos(PI*i/8.0)*0.43,0.83+sin(PI*i/8.0)*0.43))
	_extrudar_xy(fundo,0.64,0.05,"fundo")
	for lado in [-1.0,1.0]:
		for linha in 4:
			_caixa(Vector3(0.18,0.15,0.48),Vector3(x+lado*0.53,0.30+linha*0.16,0.84),"cantaria",Color("b8ae9b").lightened(linha*0.02))
	for i in 9:
		var a := PI*i/9.0+0.023
		var b := PI*(i+1)/9.0-0.023
		var pontos := PackedVector2Array([Vector2(x+cos(a)*0.63,0.83+sin(a)*0.63),Vector2(x+cos(b)*0.63,0.83+sin(b)*0.63),Vector2(x+cos(b)*0.435,0.83+sin(b)*0.435),Vector2(x+cos(a)*0.435,0.83+sin(a)*0.435)])
		_extrudar_biselado_xy(pontos,1.08,0.46,"cantaria",Color("c5baa6").darkened(float(i%3)*0.035))
	_caixa(Vector3(0.86,0.045,0.47),Vector3(x,0.27,0.84),"carvao")
	for i in 7:
		var xx := x-0.31+i*0.1
		_cilindro(Vector3(xx,0.29,0.86+(i%2)*0.08),0.07,0.10,"carvao",Color.WHITE,7)
		_caixa(Vector3(0.07,0.035,0.09),Vector3(xx,0.34,0.87),"brasa")
	for i in 5:
		var xx := x-0.30+i*0.15
		var h: float = [0.21,0.35,0.46,0.32,0.20][i]
		_extrudar_xy(PackedVector2Array([Vector2(xx-0.10,0.36),Vector2(xx+0.10,0.36),Vector2(xx+0.08,0.36+h*0.44),Vector2(xx+0.025,0.36+h),Vector2(xx-0.025,0.36+h*0.65),Vector2(xx-0.08,0.36+h*0.72)]),0.81,0.06,"brasa")
		_extrudar_xy(PackedVector2Array([Vector2(xx-0.06,0.35),Vector2(xx+0.06,0.35),Vector2(xx+0.025,0.35+h*0.4),Vector2(xx-0.015,0.35+h*0.72)]),0.84,0.04,"fogo")
	var calor := OmniLight3D.new()
	calor.name = "LuzDoForno"
	calor.position = Vector3(x,0.68,1.02)
	calor.light_color = Color("ff872e")
	calor.light_energy = 1.0
	calor.omni_range = 1.5
	calor.omni_attenuation = 1.3
	calor.shadow_enabled = false
	add_child(calor)
	_calor = calor

func _cobertura_forno() -> void:
	var x := -0.48
	for lado in [-1.0,1.0]:
		_caixa(Vector3(0.17,1.48,0.18),Vector3(x+lado*0.79,0.91,1.03),"madeira")
		_caixa(Vector3(0.25,0.28,0.26),Vector3(x+lado*0.79,0.2,1.03),"pedra_escura")
		_viga(Vector3(x+lado*0.79,1.15,1.04),Vector3(x+lado*0.39,1.62,1.04),0.13,"madeira")
		_viga(Vector3(x,2.25,1.10),Vector3(x+lado*0.98,1.58,1.10),0.13,"madeira_escura")
		_ferragem(Vector3(x+lado*0.79,1.59,1.145))
		_caixa(Vector3(0.19,0.07,0.20),Vector3(x+lado*0.79,0.33,1.03),"ferro_escuro")
		_rebite(Vector3(x+lado*0.79,0.33,1.145))
	_caixa(Vector3(1.77,0.17,0.18),Vector3(x,1.59,1.04),"madeira")
	_viga(Vector3(x,1.65,1.04),Vector3(x,2.18,1.04),0.13,"madeira")
	for lado in [-1.0,1.0]:
		_viga(Vector3(x+lado*0.54,1.67,1.04),Vector3(x,2.16,1.04),0.09,"madeira")
	_telhado(Vector3(x,1.63,0.56),1.35,0.99,0.68,true)

func _janela() -> void:
	var x := 0.97
	_caixa(Vector3(0.48,0.45,0.10),Vector3(x,0.9,0.59),"fundo")
	for i in 7:
		var a := PI*i/7.0+0.025
		var b := PI*(i+1)/7.0-0.025
		var pontos := PackedVector2Array([Vector2(x+cos(a)*0.36,1.05+sin(a)*0.36),Vector2(x+cos(b)*0.36,1.05+sin(b)*0.36),Vector2(x+cos(b)*0.24,1.05+sin(b)*0.24),Vector2(x+cos(a)*0.24,1.05+sin(a)*0.24)])
		_extrudar_biselado_xy(pontos,0.73,0.16,"cantaria",Color.WHITE.darkened(float(i%3)*0.02),0.015)
	for lado in [-1.0,1.0]:
		_caixa(Vector3(0.13,0.4,0.15),Vector3(x+lado*0.29,0.86,0.65),"cantaria")
	_caixa(Vector3(0.69,0.13,0.25),Vector3(x,0.66,0.68),"cantaria")
	_caixa(Vector3(0.035,0.51,0.05),Vector3(x,0.94,0.67),"madeira_escura")
	for lado in [-1.0,1.0]:
		_cilindro(Vector3(x+lado*0.13,0.73,0.68),0.045,0.12,"ouro",Color.WHITE,6)

func _lanterna(p: Vector3) -> void:
	_caixa(Vector3(0.13,0.23,0.12),p,"vidro")
	for x in [-0.08,0.08]:
		for z in [-0.07,0.07]: _caixa(Vector3(0.025,0.25,0.025),p+Vector3(x,0,z),"ferro_escuro")
	_caixa(Vector3(0.2,0.04,0.18),p+Vector3(0,-0.13,0),"ferro_escuro")
	_cilindro(p+Vector3(0,0.13,0),0.14,0.11,"ferro_escuro",Color.WHITE,4,0.045)
	_viga(p+Vector3(0,0.22,0),p+Vector3(0,0.3,-0.13),0.035,"ferro_escuro")
