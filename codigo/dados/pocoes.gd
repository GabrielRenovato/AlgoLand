extends RefCounted

## Poções do caldeirão da fazenda: a colheita vira poção (receita fixa) e a poção é bebida na arena pelo cinto do HUD
## (Q/E trocam, R ou X no controle bebe). Duas receitas por estação, cada uma com plantas da própria estação, para
## que toda estação de plantio dê pelo menos duas poções. Inverno não tem plantio (nem receita nova).
##
## texto: a descrição da tela do caldeirão; efeito: o que a poção faz (codigo/jogador/efeitos_pocao.gd); valor: fração do efeito (0,3 = +30%);
## duracao: segundos (0 = instantânea). icone: célula (coluna, linha) de 16x16 em assets/ui/fazenda/pocoes.png
## (Farm RPG: colunas 1-4 = verde, vermelha, roxa, azul; linhas 2-6 = formatos de frasco).
## A fonte do jogo não tem acentos: os textos ficam sem eles.

const FOLHA := preload("res://assets/ui/fazenda/pocoes.png")
const LADO := 16

const POCOES := {
	"cura": {"nome": "POCAO DE CURA", "efeito": "cura", "valor": 0.4, "duracao": 0.0,
		"texto": "UM GOLE QUENTE DE CENOURA COM MORANGO QUE FECHA AS FERIDAS NA HORA.",
		"descricao": "CURA 40% DA VIDA", "receita": {"cenoura": 2, "morango": 1},
		"icone": Vector2i(2, 2), "cor": Color(1, 0.45, 0.45)},
	"folego": {"nome": "POCAO DE FOLEGO", "efeito": "folego", "valor": 2.0, "duracao": 30.0,
		"texto": "CALDO DE BATATA COM COUVE-FLOR: O FOLEGO VOLTA ANTES DE ACABAR.",
		"descricao": "ESTAMINA 3X MAIS RAPIDA", "receita": {"batata": 2, "couve_flor": 1},
		"icone": Vector2i(1, 3), "cor": Color(0.55, 0.95, 0.45)},
	"forca": {"nome": "POCAO DE FORCA", "efeito": "forca", "valor": 0.3, "duracao": 30.0,
		"texto": "SUCO DE TOMATE COM MELANCIA QUE DEIXA CADA GOLPE MAIS PESADO.",
		"descricao": "+30% DE DANO", "receita": {"tomate": 2, "melancia": 1},
		"icone": Vector2i(3, 4), "cor": Color(0.8, 0.55, 1)},
	"velocidade": {"nome": "POCAO DE VELOCIDADE", "efeito": "velocidade", "valor": 0.25, "duracao": 30.0,
		"texto": "ESSENCIA DE GIRASSOL E MILHO: AS PERNAS FICAM LEVES COMO PLUMA.",
		"descricao": "+25% DE VELOCIDADE", "receita": {"girassol": 2, "milho": 1},
		"icone": Vector2i(4, 3), "cor": Color(0.45, 0.75, 1)},
	"pedra": {"nome": "POCAO DE PEDRA", "efeito": "pedra", "valor": 0.25, "duracao": 30.0,
		"texto": "A CASCA DA ABOBORA ENDURECE A PELE DE QUEM BEBE.",
		"descricao": "-25% DE DANO RECEBIDO", "receita": {"abobora": 2, "beterraba": 1},
		"icone": Vector2i(4, 5), "cor": Color(0.6, 0.8, 0.95)},
	"vampiro": {"nome": "POCAO VAMPIRICA", "efeito": "vampiro", "valor": 0.12, "duracao": 30.0,
		"texto": "UVA E BERINJELA FERMENTADAS: O SANGUE DO INIMIGO VIRA O SEU.",
		"descricao": "12% DO DANO VIRA VIDA", "receita": {"uva": 2, "berinjela": 1},
		"icone": Vector2i(2, 5), "cor": Color(1, 0.35, 0.5)},
}
## Ordem de exibição (caldeirão e cinto): pela estação das plantas
const ORDEM: Array[String] = ["cura", "folego", "forca", "velocidade", "pedra", "vampiro"]

static var _icones: Dictionary = {}

static func dados(id: String) -> Dictionary:
	return POCOES.get(id, {})

## Texto do efeito com a duração ("+30% DE DANO (30S)"); a instantânea fica só com a descrição
static func texto_efeito(id: String) -> String:
	var d := dados(id)
	if d.is_empty():
		return ""
	var duracao := float(d["duracao"])
	return String(d["descricao"]) + (" (%dS)" % roundi(duracao) if duracao > 0.0 else "")

static func icone(id: String) -> Texture2D:
	if not _icones.has(id):
		var atlas := AtlasTexture.new()
		atlas.atlas = FOLHA
		var celula: Vector2i = POCOES[id]["icone"]
		atlas.region = Rect2(celula.x * LADO, celula.y * LADO, LADO, LADO)
		_icones[id] = atlas
	return _icones[id]
