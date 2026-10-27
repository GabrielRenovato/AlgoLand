extends SkeletonModifier3D
## Ajusta apenas escalas dos ossos depois da animação.
## A compensação vertical fica no nó 3D do modelo, sem acumular na pose do quadril.
const ESCALAS := {
	"DEF-spine.001": 0.85, "DEF-head": Vector3(2.38, 1.75, 2.3), # Rosto mais estreito; altura original, cabelo e olhos acompanham o osso.
	"DEF-upper_arm.L": 0.85, "DEF-upper_arm.R": 0.85, "DEF-hand.L": 1.4, "DEF-hand.R": 1.4,
	"DEF-thigh.L": 0.6, "DEF-thigh.R": 0.6, "DEF-foot.L": 1.15, "DEF-foot.R": 1.15, # Pés menores: 1.35 pareciam chinelos.
}
const DESLOCAMENTO_CABECA := Vector3(0.0, 0.06, -0.015)
const COMPRIMENTO_PERNA := 0.83 # Metros do quadril ao tornozelo no manequim.

const DESCIDA_QUADRIL := COMPRIMENTO_PERNA*(1.0-0.6)

func _process_modification_with_delta(_delta: float) -> void:
	_aplicar()

func _process_modification() -> void:
	_aplicar()

func _aplicar() -> void:
	var esqueleto := get_skeleton()
	if esqueleto == null:
		return
	for nome in ESCALAS:
		var osso := esqueleto.find_bone(nome)
		if osso >= 0:
			var escala = ESCALAS[nome]
			esqueleto.set_bone_pose_scale(osso, escala if escala is Vector3 else Vector3.ONE*float(escala))

	# Pescoço visível: a cabeça ampliada apoiava o queixo direto na gola. Sobe e recua
	# um pouco a cabeça (espaço do pescoço, em metros), deixando um pescoço curto.
	var osso_cabeca := esqueleto.find_bone("DEF-head")
	if osso_cabeca >= 0:
		esqueleto.set_bone_pose_position(osso_cabeca, esqueleto.get_bone_rest(osso_cabeca).origin + DESLOCAMENTO_CABECA)

	# Evita que a testa esconda os olhos na câmera elevada. Mantém os giros
	# da animação e só reduz a inclinação para baixo em poses de cabeça erguida.
	var cabeca:=esqueleto.find_bone("DEF-head")
	var base:=esqueleto.get_bone_global_pose(cabeca).basis.orthonormalized()
	var inclinacao:=atan2(-base.z.y,base.z.z)
	if inclinacao>deg_to_rad(8.0) and inclinacao<deg_to_rad(45.0) and base.z.z>0.7:
		var correcao:=minf(deg_to_rad(16.0),inclinacao-deg_to_rad(4.0))
		var pai:=esqueleto.get_bone_parent(cabeca)
		var acima:=esqueleto.get_bone_global_pose(pai).basis.orthonormalized()
		esqueleto.set_bone_pose_rotation(cabeca,(acima.inverse()*Basis(Vector3.RIGHT,-correcao)*base).get_rotation_quaternion())
