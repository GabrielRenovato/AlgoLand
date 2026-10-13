extends RefCounted

## Contrato compartilhado pela geração, validação e pelos modelos dos próximos conjuntos.
const TAMANHO_FOLHA := Vector2i(512, 512)
const TAMANHO_QUADRO := 64
const ACENTOS := {"Á": "A", "À": "A", "Â": "A", "Ã": "A", "É": "E", "Ê": "E", "Í": "I", "Ó": "O", "Ô": "O", "Õ": "O", "Ú": "U", "Ü": "U", "Ç": "C"}
const PECAS := {
	"elmo": {"slot": "cabeca", "bit": 1},
	"peitoral": {"slot": "corpo", "bit": 2},
	"luvas": {"slot": "luvas", "bit": 4},
	"botas": {"slot": "botas", "bit": 8},
}
const CORPOS := {
	"andar": "Body/body_1.png", "fazenda": "Fazenda/corpo.png",
	"forja": "body_smithing/char_a_p4_0bas_humn_v00.png",
	"sentado": "body_smithing/char_a_p4_0bas_humn_v00.png",
	"espada": "Body_sword_chield/body_attack_sword.png",
	"lanca": "Body_spear_combat/body_spear_combat.png",
	"reacao_um_mao": "Reacao/um_mao/corpo.png", "reacao_lanca": "Reacao/lanca/corpo.png",
	"reacao_arco": "Reacao/arco/corpo.png", "arco_p2": "Arco/corpo_p2.png", "arco_p3": "Arco/corpo_p3.png",
}

static func carregar(caminho: String) -> Dictionary:
	if not FileAccess.file_exists(caminho):
		return {}
	var dados = JSON.parse_string(FileAccess.get_file_as_string(caminho))
	return dados if dados is Dictionary else {}

static func validar(dados: Dictionary) -> Array[String]:
	var erros: Array[String] = []
	if not dados.get("modo_visual", "armadura") in ["armadura", "tecido"]:
		erros.append("Modo visual deve ser armadura ou tecido.")
	if dados.get("modo_visual", "armadura") == "tecido":
		var fim_cartola = dados.get("recortes", {}).get("fim_cartola", 0)
		if not (fim_cartola is float or fim_cartola is int) or float(fim_cartola) <= 0 or float(fim_cartola) >= float(dados.get("recortes", {}).get("fim_elmo", 0)):
			erros.append("Cartola deve terminar antes da face e do peitoral.")
		if bool(dados.get("substituir_cabeca", false)):
			erros.append("Traje de tecido preserva a cabeça original.")
		var encaixe = dados.get("recortes", {}).get("encaixe_cartola", 4)
		if not (encaixe is float or encaixe is int) or float(encaixe) < 0 or float(encaixe) > 12 or float(encaixe) != floorf(float(encaixe)):
			erros.append("Encaixe da cartola deve ser inteiro entre 0 e 12.")
	for chave in ["versao", "id", "nome", "raridade", "arte", "destino", "onda_minima", "chances_drop", "preco_base", "bonus", "bases", "recortes", "paleta"]:
		if not dados.has(chave):
			erros.append("Manifesto sem campo: " + chave)
	if not erros.is_empty():
		return erros
	for chave in ["id", "nome", "raridade", "arte", "destino"]:
		if not dados[chave] is String or dados[chave].strip_edges().is_empty():
			erros.append("Campo deve conter texto: " + chave)
	for chave in ["versao", "onda_minima", "preco_base"]:
		if not (dados[chave] is float or dados[chave] is int):
			erros.append("Campo deve conter número: " + chave)
	if not erros.is_empty():
		return erros
	var regex := RegEx.new()
	regex.compile("^[a-z][a-z0-9_]*$")
	if regex.search(str(dados["id"])) == null:
		erros.append("Id deve usar letras minúsculas, números e sublinhado, começando por letra.")
	if dados["versao"] != 1:
		erros.append("Versão do manifesto deve ser 1.")
	if not dados["raridade"] in ["comum", "incomum", "raro", "epico", "lendario"]:
		erros.append("Raridade desconhecida.")
	if not str(dados["destino"]).begins_with("res://CharacterSprites/") or not str(dados["destino"]).ends_with("/") or ".." in str(dados["destino"]):
		erros.append("Destino deve ficar em res://CharacterSprites/ e terminar com /.")
	if not str(dados["arte"]).begins_with("res://") or ".." in str(dados["arte"]):
		erros.append("Arte deve apontar para um arquivo dentro do projeto.")
	if int(dados["onda_minima"]) < 1 or float(dados["onda_minima"]) != floorf(float(dados["onda_minima"])) or float(dados["preco_base"]) < 0 or float(dados["preco_base"]) != floorf(float(dados["preco_base"])):
		erros.append("Onda mínima e preço inválidos.")
	if not dados["chances_drop"] is Dictionary or not dados["bonus"] is Dictionary or not dados["bases"] is Dictionary or not dados["recortes"] is Dictionary:
		erros.append("Chances, bônus, bases e recortes devem ser objetos.")
		return erros
	for categoria in ["normal", "mutante", "chefe"]:
		var valor = dados["chances_drop"].get(categoria, -1)
		if not (valor is float or valor is int) or float(valor) < 0 or float(valor) > 1:
			erros.append("Chance inválida: " + categoria)
	for chave in ["tipo", "pecas", "chance", "recarga", "multiplicador_dano", "aviso"]:
		if not dados["bonus"].has(chave):
			erros.append("Bônus sem campo: " + chave)
	for chave in ["pecas", "chance", "recarga", "multiplicador_dano", "aviso"]:
		var valor = dados["bonus"].get(chave)
		if not (valor is float or valor is int):
			erros.append("Bônus deve conter número: " + chave)
	for chave in ["fim_elmo", "fim_peitoral"]:
		var valor = dados["recortes"].get(chave)
		if not (valor is float or valor is int):
			erros.append("Recorte deve conter número: " + chave)
	for chave in ["largura_elmo", "altura_elmo"]:
		if dados["recortes"].has(chave):
			var valor = dados["recortes"][chave]
			if not (valor is float or valor is int) or float(valor) < 8 or float(valor) > 20 or float(valor) != floorf(float(valor)):
				erros.append("Dimensão de elmo deve ser um inteiro entre 8 e 20: " + chave)
	for chave in ["alinhar_calota", "ajustar_calota_corpo", "elmo_rigido"]:
		if dados["recortes"].has(chave) and not dados["recortes"][chave] is bool:
			erros.append("Ajuste de calota deve ser booleano: " + chave)
	var borda = dados["recortes"].get("borda_calota", 0)
	if not (borda is float or borda is int) or not float(borda) in [0.0, 1.0]:
		erros.append("Borda da calota deve ser 0 ou 1.")
	var deslocamentos = dados["recortes"].get("deslocamento_vertical_elmo", [0, 0, 0, 0])
	if not deslocamentos is Array or deslocamentos.size() != 4:
		erros.append("Deslocamento do elmo exige quatro direções.")
	else:
		for valor in deslocamentos:
			if not (valor is float or valor is int) or float(valor) < -3 or float(valor) > 3 or float(valor) != floorf(float(valor)):
				erros.append("Deslocamento do elmo deve ser um inteiro entre -3 e 3.")
	if dados.has("arte_elmo") and (not dados["arte_elmo"] is String or not dados["arte_elmo"].begins_with("res://") or ".." in dados["arte_elmo"]):
		erros.append("Arte do elmo deve apontar para um arquivo dentro do projeto.")
	if dados.has("substituir_cabeca") and not dados["substituir_cabeca"] is bool:
		erros.append("Substituição da cabeça deve ser booleana.")
	elif bool(dados.get("substituir_cabeca", false)) and (not dados.has("arte_elmo") or not bool(dados["recortes"].get("elmo_rigido", false))):
		erros.append("Substituir a cabeça exige arte própria do elmo e aplicação rígida.")
	var tipo_bonus = dados["bonus"].get("tipo")
	var duracao = dados["bonus"].get("duracao", 0.0)
	if not (duracao is float or duracao is int) or float(duracao) < 0:
		erros.append("Duração do bônus deve ser não negativa.")
	elif tipo_bonus == "congelamento" and float(duracao) <= 0:
		erros.append("Congelamento exige duração positiva.")
	for atributo in ["defesa", "vitalidade"]:
		if dados["bonus"].has(atributo):
			var valor = dados["bonus"][atributo]
			if not (valor is float or valor is int) or float(valor) < 0 or float(valor) > 1:
				erros.append("Bônus percentual inválido: " + atributo)
	for chave in ["fracao_largura_elmo", "fracao_gola_elmo"]:
		if dados["recortes"].has(chave):
			var fracao = dados["recortes"][chave]
			if not (fracao is float or fracao is int) or float(fracao) < 0.25 or float(fracao) > 1.0:
				erros.append("Fração horizontal do elmo deve ficar entre 0,25 e 1: " + chave)
	if not tipo_bonus is String or tipo_bonus.strip_edges().is_empty():
		erros.append("Tipo do bônus deve conter texto.")
	if not erros.is_empty():
		return erros
	if dados["bonus"].get("pecas", 0) != 4:
		erros.append("Este padrão exige quatro peças para ativar o bônus.")
	var chance: float = float(dados["bonus"].get("chance", -1))
	if chance < 0 or chance > 1 or float(dados["bonus"].get("recarga", -1)) < 0 or float(dados["bonus"].get("aviso", -1)) < 0 or float(dados["bonus"].get("multiplicador_dano", -1)) < 0:
		erros.append("Valores inválidos no bônus.")
	for peca in PECAS:
		var slot: String = PECAS[peca]["slot"]
		var base = dados["bases"].get(slot, {})
		if not base is Dictionary:
			erros.append("Base inválida: " + slot)
			continue
		for atributo in ["vitalidade", "defesa"]:
			var niveis = base.get(atributo, [])
			if not niveis is Array or niveis.size() != 5:
				erros.append(slot + "/" + atributo + " deve conter os cinco níveis.")
				continue
			for valor in niveis:
				if not (valor is float or valor is int) or float(valor) < 0 or float(valor) != floorf(float(valor)):
					erros.append("Status deve ser um inteiro não negativo: " + slot + "/" + atributo)
	var fim_elmo: float = float(dados["recortes"].get("fim_elmo", 0))
	var fim_peitoral: float = float(dados["recortes"].get("fim_peitoral", 0))
	if not (fim_elmo > 0 and fim_elmo < fim_peitoral and fim_peitoral < 1):
		erros.append("Recortes devem respeitar 0 < fim_elmo < fim_peitoral < 1.")
	if not dados["paleta"] is Array or dados["paleta"].size() != 12:
		erros.append("Paleta deve conter 12 cores: oito do metal e quatro do forro.")
	else:
		var cor_regex := RegEx.new()
		cor_regex.compile("^[0-9a-fA-F]{6}$")
		for cor in dados["paleta"]:
			if cor_regex.search(str(cor)) == null:
				erros.append("Cor inválida na paleta: " + str(cor))
	return erros

static func nome_pixel(texto: String) -> String:
	var nome := texto.to_upper()
	for origem in ACENTOS:
		nome = nome.replace(origem, ACENTOS[origem])
	return nome

## Emite o cadastro sem duplicar as regras de máscara, níveis, chances e ativação.
static func roteiro_definicao(config: Dictionary) -> String:
	var tipos := {}
	for peca in PECAS:
		tipos[peca + "_" + String(config["id"])] = {
			"slot": PECAS[peca]["slot"], "peca": peca, "bit": PECAS[peca]["bit"],
			"nome": peca.to_upper() + " DO " + nome_pixel(config["nome"]),
		}
	var valores := {
		"ID": config["id"], "NOME": nome_pixel(config["nome"]), "RARIDADE": config["raridade"],
		"RAIZ_SPRITES": config["destino"], "PRECO_BASE": int(config["preco_base"]),
		"SUBSTITUIR_CABECA": bool(config.get("substituir_cabeca", false)),
		"MODO_VISUAL": config.get("modo_visual", "armadura"),
		"ONDA_MINIMA": int(config["onda_minima"]),
		"CHANCE_DROP_NORMAL": float(config["chances_drop"]["normal"]),
		"CHANCE_DROP_MUTANTE": float(config["chances_drop"]["mutante"]),
		"CHANCE_DROP_CHEFE": float(config["chances_drop"]["chefe"]),
		"TIPO_BONUS": config["bonus"]["tipo"], "PECAS_BONUS": int(config["bonus"]["pecas"]),
		"DURACAO_BONUS": float(config["bonus"].get("duracao", 0.0)),
		"CHANCE_BONUS": float(config["bonus"]["chance"]), "RECARGA_BONUS": float(config["bonus"]["recarga"]),
		"MULT_DANO_BONUS": float(config["bonus"]["multiplicador_dano"]), "AVISO_BONUS": float(config["bonus"]["aviso"]),
		"BONUS_DEFESA": float(config["bonus"].get("defesa", 0.0)),
		"BONUS_VITALIDADE": float(config["bonus"].get("vitalidade", 0.0)),
		"TIPOS": tipos, "BASES": config["bases"],
	}
	var texto := "extends RefCounted\n\n## GERADO pelo manifesto do conjunto; regras em base_conjunto_armadura.gd.\n"
	texto += "const Base := preload(\"res://Codigos/DadosLocais/base_conjunto_armadura.gd\")\n"
	for chave in valores:
		texto += "const %s := %s\n" % [chave, JSON.stringify(valores[chave], "\t", false)]
	texto += "\nstatic func chance_drop(onda: int, mutante: bool, chefe: bool) -> float:\n"
	texto += "\treturn Base.chance_drop(onda, ONDA_MINIMA, {\"normal\": CHANCE_DROP_NORMAL, \"mutante\": CHANCE_DROP_MUTANTE, \"chefe\": CHANCE_DROP_CHEFE}, mutante, chefe)\n"
	texto += "\nstatic func mascara(equipados: Dictionary) -> int:\n\treturn Base.mascara(TIPOS, equipados)\n"
	texto += "\nstatic func quantidade(equipados: Dictionary) -> int:\n\treturn Base.quantidade(TIPOS, equipados)\n"
	texto += "\nstatic func pode_ativar(equipados: Dictionary, recarga: float, sorteio: float) -> bool:\n\treturn Base.pode_ativar(TIPOS, equipados, recarga, sorteio, CHANCE_BONUS)\n"
	texto += "\nstatic func dados(tipo: String, nivel: int) -> Dictionary:\n\treturn Base.dados(TIPOS, BASES, tipo, nivel)\n"
	return texto
