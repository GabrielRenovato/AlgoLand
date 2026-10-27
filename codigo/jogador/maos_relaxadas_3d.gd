extends SkeletonModifier3D
## Punho relaxado em todas as animações: copia, depois da animação, a rotação dos dedos do
## Idle_Loop da Quaternius. Clipes do Mixamo deixavam o indicador apontando ou a mão aberta.
var rotacoes := {} # índice do osso -> Quaternion

## Lê os dedos do primeiro quadro de `animacao` (trilhas de rotação "...:DEF-f_*" e "DEF-thumb*").
func capturar(esqueleto: Skeleton3D, animacao: Animation) -> void:
	rotacoes.clear()
	for trilha in animacao.get_track_count():
		if animacao.track_get_type(trilha) != Animation.TYPE_ROTATION_3D:
			continue
		var osso_nome := String(animacao.track_get_path(trilha).get_concatenated_subnames())
		if not (osso_nome.begins_with("DEF-f_") or osso_nome.begins_with("DEF-thumb")):
			continue
		var osso := esqueleto.find_bone(osso_nome)
		if osso >= 0:
			rotacoes[osso] = animacao.rotation_track_interpolate(trilha, 0.0)

func _process_modification_with_delta(_delta: float) -> void:
	_aplicar()

func _process_modification() -> void:
	_aplicar()

func _aplicar() -> void:
	var esqueleto := get_skeleton()
	if esqueleto == null:
		return
	for osso in rotacoes:
		esqueleto.set_bone_pose_rotation(osso, rotacoes[osso])
