extends MeshInstance3D
## Faixa curta varrida pela lâmina no espaço do modelo; não acompanha a mão
## depois de emitida e respeita a oclusão real do corpo no viewport 3D.
const VIDA := 0.09
## Ponta da lâmina no espaço da arma; o herói 3D ajusta ao tamanho das espadas.
var ponta_espada := 0.79
var ponta_montante := 1.02
const JANELAS := [Vector2(0.26,0.68),Vector2(0.25,0.70),Vector2(0.26,0.70)]
const VIDA_CORTE := 0.13
const CORES_CORTE := [Color("e6d5b8"),Color("fff0cb"),Color("fff0cb")]
const CORES := [Color("71a2b2"),Color("a6c6c0"),Color("fff0cb")]
var _amostras: Array = []
var _tempo := 0.0
var _golpe := ""
var _malha := ImmediateMesh.new()
func _init():
    name = "RastroEspada"
    mesh = _malha
    cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    material.vertex_color_use_as_albedo = true
    material_override = material
func limpar():
    _amostras.clear()
    _malha.clear_surfaces()
    visible = false
func atualizar(delta: float,transformacao: Transform3D,golpe: String,progresso: float,fase: int,lanca: bool = false,duas_maos: bool = false):
    var corte_curto: bool=not lanca and not duas_maos
    var vida: float=VIDA if lanca else (0.075 if corte_curto else VIDA_CORTE)
    _tempo += delta
    if golpe != _golpe:
        limpar()
        _golpe = golpe
    while not _amostras.is_empty() and _tempo-_amostras[0][0] > vida:
        _amostras.pop_front()
    var indice := clampi(fase,1,3)-1
    var janela: Vector2 = Vector2(0.25,0.75) if lanca else JANELAS[indice]
    if not golpe.is_empty() and progresso >= janela.x and progresso <= janela.y:
        var inicio_lamina: float=lerpf(0.31,ponta_espada,0.65) if corte_curto else 0.31
        var base := transformacao*Vector3(-0.035 if lanca else 0.0,0.84 if lanca else inicio_lamina,0)
        var ponta := transformacao*Vector3(0.035 if lanca else 0.0,1.08 if lanca else (ponta_montante if duas_maos else ponta_espada),0)
        if _amostras.is_empty() or ponta.distance_to(_amostras[-1][2]) > 0.012:
            _amostras.append([_tempo,base,ponta])
    _malha.clear_surfaces()
    visible = _amostras.size() > 1
    if not visible: return
    _malha.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
    for i in range(1,_amostras.size()):
        var a: Array = _amostras[i-1]
        var b: Array = _amostras[i]
        # Três faixas de cor, sem textura borrada ou halo transparente.
        for faixa in 3:
            var inicio := faixa/3.0
            var fim := (faixa+1)/3.0
            var cauda_a: Vector3 = a[1].lerp(a[2],clampf((_tempo-a[0])/vida,0.0,1.0))
            var cauda_b: Vector3 = b[1].lerp(b[2],clampf((_tempo-b[0])/vida,0.0,1.0))
            var a0: Vector3 = cauda_a.lerp(a[2],inicio)
            var a1: Vector3 = cauda_a.lerp(a[2],fim)
            var b0: Vector3 = cauda_b.lerp(b[2],inicio)
            var b1: Vector3 = cauda_b.lerp(b[2],fim)
            _malha.surface_set_color(CORES[faixa] if lanca else CORES_CORTE[faixa])
            for ponto in [a0,b0,b1,a0,b1,a1]: _malha.surface_add_vertex(ponto)
    _malha.surface_end()
