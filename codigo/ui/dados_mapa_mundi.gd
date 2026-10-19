extends RefCounted

## Coordenadas normalizadas na carta ilustrada, medidas nos telhados e nas portas.
const CASAS := {
	"casa": {"ponto":Vector2(.165,.205), "icone":"casa", "nome":"SUA CASA", "texto":"Casa da fazenda: dormir e guardar seus itens."},
	"forja": {"ponto":Vector2(.586,.115), "icone":"martelo", "nome":"FORJA DO IVO", "texto":"Fabricacao de equipamentos e melhoria de ferramentas."},
	"sede": {"ponto":Vector2(.72,.13), "icone":"livro", "nome":"COMUNIDADE", "texto":"Lia: melhorias e assuntos da comunidade. Pedidos no mural da praca."},
	"venda": {"ponto":Vector2(.535,.24), "icone":"moeda", "nome":"VENDA DO TOMAS", "texto":"Loja de sementes e suprimentos da vila."},
	"enfermaria": {"ponto":Vector2(.876,.24), "icone":"cura", "nome":"ENFERMARIA", "texto":"Dona Rosa: cuidados e cura."},
	"pousada": {"ponto":Vector2(.67,.435), "icone":"cama", "nome":"POUSADA DO CORETO", "texto":"Caio: refeicoes, descanso e encontros da vila."},
	"casa_bento": {"ponto":Vector2(.545,.445), "icone":"horta", "nome":"CASA DO BENTO", "texto":"Casa do agricultor Bento e sua horta."},
	"mistica": {"ponto":Vector2(.886,.44), "icone":"estrela", "nome":"CASA DA MISTICA", "texto":"Estela: preparacao e escolha do ponto de partida da jornada."},
	"palafita": {"ponto":Vector2(.879,.76), "icone":"peixe", "nome":"LOJA DO NILO", "texto":"Equipamentos de pesca, encomendas e melhoria da vara."},
}

static func projetar(local: String, ponto: Vector2) -> Vector2:
	if local == "fazenda":
		return Vector2(.025,.10) + (ponto / Vector2(1152,768)).clamp(Vector2.ZERO,Vector2.ONE) * Vector2(.43,.48)
	if local == "cidade":
		return Vector2(.46,0) + (ponto / Vector2(704,576)).clamp(Vector2.ZERO,Vector2.ONE) * Vector2(.52,.68)
	if local == "praia":
		return Vector2(.43,.6) + (ponto / Vector2(704,576)).clamp(Vector2.ZERO,Vector2.ONE) * Vector2(.55,.34)
	if CASAS.has(local):
		return CASAS[local]["ponto"] + Vector2(0,.05)
	return Vector2(-1,-1)
