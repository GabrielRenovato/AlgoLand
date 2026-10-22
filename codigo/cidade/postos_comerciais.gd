extends RefCounted

## Posições atrás do móvel real; calendários e trajetos permanecem com as rotinas.
const POSTOS := {
	"mercador": ["venda",Vector2(240,212)],
	"curandeira": ["enfermaria",Vector2(96,190)],
	"mistica": ["mistica",Vector2(320,60)],
	"lia": ["sede",Vector2(272,108)],
	"bardo": ["pousada",Vector2(251,84)],
	"ferreiro": ["forja",Vector2(464,112)],
	"osvaldo": ["carpintaria",Vector2(264,328)],
	"nilo": ["palafita",Vector2(152,100)],
}

static func agenda(id: String) -> Dictionary:
	var posto: Array=POSTOS[id]
	return {"local":posto[0],"ponto":posto[1],"atividade":"Atendendo no balcao","comercial":true}
