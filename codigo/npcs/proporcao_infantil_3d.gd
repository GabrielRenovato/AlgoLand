extends "res://codigo/jogador/proporcao_chibi.gd"
## Estudo infantil no rig canônico: volumes distintos, preservando ossos e encaixes.
const ESCALAS_INFANTIS={
	"DEF-spine.001":Vector3(.76,.74,.78),
	"DEF-head":Vector3(2.9,2.05,2.8),
	"DEF-upper_arm.L":.72,"DEF-upper_arm.R":.72,
	"DEF-hand.L":1.25,"DEF-hand.R":1.25,
	"DEF-thigh.L":.48,"DEF-thigh.R":.48,
	"DEF-foot.L":1.12,"DEF-foot.R":1.12}
const ESCALA_GERAL:=.8
const DESCIDA_INFANTIL:=COMPRIMENTO_PERNA*(1.0-.48)*ESCALA_GERAL

func _aplicar() -> void:
	super._aplicar()
	var s:=get_skeleton()
	if s==null:return
	for nome in ESCALAS_INFANTIS:
		var i:=s.find_bone(nome)
		if i<0:continue
		var escala:Variant=ESCALAS_INFANTIS[nome]
		s.set_bone_pose_scale(i,escala if escala is Vector3 else Vector3.ONE*float(escala))
	var cabeca:=s.find_bone("DEF-head")
	# A nuca deve encontrar o pescoço menor: o deslocamento adulto deixava uma linha vazia.
	s.set_bone_pose_position(cabeca,s.get_bone_rest(cabeca).origin+Vector3(0,-.04,-.012))
