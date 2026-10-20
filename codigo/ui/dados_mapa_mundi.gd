extends RefCounted

## Coordenadas normalizadas na carta ilustrada, medidas nos telhados e nas portas.
const CASAS := {
	"carpintaria": {"ponto":Vector2(.881,.239), "icone":"martelo", "nome":"CASA E OFICINA DE OSVALDO", "texto":"Osvaldo, Helena e Clara. Construcao de galinheiros e aves; casa depois da ponte."},
	"casa": {"ponto":Vector2(.134,.207), "icone":"casa", "nome":"SUA CASA", "texto":"Casa da fazenda: dormir e guardar seus itens."},
	"forja": {"ponto":Vector2(.465,.118), "icone":"martelo", "nome":"FORJA DO IVO", "texto":"Fabricacao de equipamentos e melhoria de ferramentas."},
	"sede": {"ponto":Vector2(.574,.135), "icone":"livro", "nome":"COMUNIDADE", "texto":"Lia: melhorias e assuntos da comunidade. Pedidos no mural da praca."},
	"venda": {"ponto":Vector2(.422,.258), "icone":"moeda", "nome":"VENDA DO TOMAS", "texto":"Loja de sementes e suprimentos da vila."},
	"enfermaria": {"ponto":Vector2(.699,.268), "icone":"cura", "nome":"ENFERMARIA", "texto":"Dona Rosa: cuidados e cura."},
	"pousada": {"ponto":Vector2(.538,.489), "icone":"cama", "nome":"POUSADA DO CORETO", "texto":"Caio: refeicoes, descanso e encontros da vila."},
	"casa_bento": {"ponto":Vector2(.436,.492), "icone":"horta", "nome":"CASA DO BENTO", "texto":"Casa do agricultor Bento e sua horta."},
	"mistica": {"ponto":Vector2(.708,.507), "icone":"estrela", "nome":"CASA DA MISTICA", "texto":"Estela: preparacao e escolha do ponto de partida da jornada."},
	"palafita": {"ponto":Vector2(.701,.819), "icone":"peixe", "nome":"LOJA DO NILO", "texto":"Equipamentos de pesca, encomendas e melhoria da vara."},
}

static func projetar(local: String, ponto: Vector2) -> Vector2:
	if local == "fazenda":
		return Vector2(.025,.10) + (ponto / Vector2(1152,768)).clamp(Vector2.ZERO,Vector2.ONE) * Vector2(.31,.48)
	if local == "cidade":
		var x := .38+clampf(ponto.x/704.0,0,1)*.40 if ponto.x<=704 else .78+clampf((ponto.x-704.0)/320.0,0,1)*.20
		return Vector2(x,clampf(ponto.y/576.0,0,1)*.75)
	if local == "praia":
		return Vector2(.34,.6) + (ponto / Vector2(704,576)).clamp(Vector2.ZERO,Vector2.ONE) * Vector2(.44,.34)
	if CASAS.has(local):
		return CASAS[local]["ponto"] + Vector2(0,.05)
	return Vector2(-1,-1)
