extends RefCounted

## Coordenadas locais compartilhadas pelo aviso, pela arte e pela colisão.
const MEIO_CONE := PI / 6.0
const DURACOES := {"sopro": 0.9, "cauda": 0.35, "asas": 0.3, "patada": 0.25}

static func boca(linha: int) -> Vector2:
	return [Vector2(0, -25), Vector2(0, -91), Vector2(42, -67), Vector2(-42, -67)][clampi(linha, 0, 3)]

static func quadro(tipo: String, tempo: float) -> int:
	return clampi(int(tempo / float(DURACOES[tipo]) * 6), 0, 5)

static func fator_dano(tipo: String, tempo: float) -> float:
	var frame := quadro(tipo, tempo)
	if tipo == "sopro":
		return [0.0, 0.72, 1.0, 1.0, 0.78, 0.0][frame]
	# O impacto acontece quando a onda atinge a expansão máxima, sem dano na dissipação.
	return 1.0 if frame == 2 else 0.0

static func cone(origem: Vector2, direcao: Vector2, alcance: float) -> PackedVector2Array:
	var pontos := PackedVector2Array([origem])
	for i in 17:
		pontos.append(origem + Vector2.from_angle(direcao.angle() - MEIO_CONE + 2.0 * MEIO_CONE * i / 16.0) * alcance)
	return pontos
