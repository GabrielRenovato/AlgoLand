extends SkeletonModifier3D
## Captura na pesca: depois do puxão que tira o peixe da água, a mão esquerda o ergue ao lado
## do rosto para mostrar (o peixe é desenhado em sessao_pesca.gd, na posição desta mão).
## A vara continua na mão direita com o clipe de espera; só o braço esquerdo é movido.
var heroi: Node
## Tempos da sessão no estado PEGOU (segundos): puxão, voo do peixe até a mão, braço já erguido.
const FIM_PUXAO := 0.30
const FIM_VOO := 0.75
const ERGUIDO := 0.85
## Mão ao lado do rosto na TELA (em qualquer direção): distâncias da cabeça em metros, no sentido
## da câmera (lado, para cima e para perto dela). O lado é o do ombro esquerdo (oposto à vara).
const AO_LADO := 0.34
const ACIMA := -0.04
const A_FRENTE := 0.18

func _process_modification_with_delta(_delta: float): _aplicar()
func _process_modification(): _aplicar()

func peso() -> float:
	if heroi == null or not heroi.visible or heroi._acao != "pesca": return 0.0
	var sessao: Node = heroi._jogador.get_node_or_null("SessaoPesca")
	if sessao == null or sessao.estado != sessao.Estado.PEGOU: return 0.0
	return smoothstep(FIM_PUXAO, ERGUIDO, float(sessao._tempo))

func _aplicar():
	var p := peso()
	if p <= 0.0: return
	var s := get_skeleton()
	var mao := s.find_bone("DEF-hand.L")
	var inicial := s.get_bone_global_pose(mao)
	# Palma virada para a câmera, segurando o peixe de pé.
	var base := Basis(Vector3.BACK, -0.5) * Basis(Vector3.UP, 0.4)
	var destino := inicial.origin.lerp(ponto_ao_lado_do_rosto(s), p)
	var giro := inicial.basis.orthonormalized().get_rotation_quaternion().slerp(base.get_rotation_quaternion(), p)
	_braco(s, "L", destino, Basis(giro))

func ponto_ao_lado_do_rosto(s: Skeleton3D) -> Vector3:
	var para_esqueleto := s.global_transform.affine_inverse().basis
	var camera: Camera3D = heroi._camera
	var direita := (para_esqueleto * camera.global_basis.x).normalized()
	var cima := (para_esqueleto * camera.global_basis.y).normalized()
	var perto := (para_esqueleto * camera.global_basis.z).normalized()
	var cabeca := s.get_bone_global_pose(s.find_bone("DEF-head")).origin
	var ombro := s.get_bone_global_pose(s.find_bone("DEF-upper_arm.L")).origin
	var lado := 1.0 if (ombro - cabeca).dot(direita) >= 0.0 else -1.0
	return cabeca + direita * AO_LADO * lado + cima * ACIMA + perto * A_FRENTE

func _orientar(s: Skeleton3D, i: int, base: Basis):
	var pai := s.get_bone_parent(i)
	var acima := s.get_bone_global_pose(pai).basis.orthonormalized()
	s.set_bone_pose_rotation(i, (acima.inverse() * base).get_rotation_quaternion())

func _braco(s: Skeleton3D, lado: String, punho: Vector3, base: Basis):
	var mao := s.find_bone("DEF-hand." + lado)
	# CCD limitado aos dois segmentos (igual à guarda): não move o corpo nem estica o braço.
	for passo in 6:
		for nome in ["DEF-forearm.", "DEF-upper_arm."]:
			var i := s.find_bone(nome + lado)
			var pose := s.get_bone_global_pose(i)
			var atual := s.get_bone_global_pose(mao).origin - pose.origin
			var alvo := punho - pose.origin
			if atual.length() < 0.001 or alvo.length() < 0.001: continue
			_orientar(s, i, Basis(Quaternion(atual.normalized(), alvo.normalized())) * pose.basis.orthonormalized())
	_orientar(s, mao, base)
