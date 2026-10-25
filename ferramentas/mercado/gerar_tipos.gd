extends SceneTree
## Gera tipos_mercado.sql: a lista de tipos de item que existem no jogo, para o banco recusar itens inventados.
## Rodar de novo (e aplicar o SQL) quando entrar arma, peça, material, peixe, planta, poção ou comida nova.
## godot --headless --path <copia_isolada> --script res://ferramentas/mercado/gerar_tipos.gd

const Forja := preload("res://codigo/dados/forja_armas.gd")
const Encantamentos := preload("res://codigo/dados/encantamentos.gd")
const Plantas := preload("res://codigo/dados/plantas.gd")
const Pocoes := preload("res://codigo/dados/pocoes.gd")
const Refeicoes := preload("res://codigo/dados/refeicoes.gd")
const Peixes := preload("res://codigo/pesca/peixes.gd")
const SAIDA := "res://ferramentas/mercado/tipos_mercado.sql"

func _initialize() -> void:
	var linhas: Array[String] = []
	var equipamentos: Array = Forja.RECEITAS.keys()
	for tipo in Forja.INICIAIS_LIVRES:
		if not tipo in equipamentos:
			equipamentos.append(tipo)
	for tipo in equipamentos:
		var item = Forja.criar_item(tipo)
		if item == null or item.categoria in ["ferramenta", "vara"]:
			continue
		linhas.append(_linha(tipo, item.categoria, false, tipo in Encantamentos.TIPOS_ENCANTAVEIS, item.duas_maos))
	for id in Forja.MATERIAIS:
		linhas.append(_linha("material:" + id, "material", true))
	for tipo in Forja.RECEITAS:
		linhas.append(_linha("receita:" + tipo, "receita", true))
	for id in Plantas.PLANTAS:
		linhas.append(_linha("colheita:" + id, "colheita", true))
		linhas.append(_linha(Plantas.PREFIXO_SEMENTE + id, "semente", true))
	for id in Pocoes.POCOES:
		linhas.append(_linha("pocao:" + id, "pocao", true))
	for id in Refeicoes.REFEICOES:
		linhas.append(_linha("comida:" + id, "comida", true))
	for id in Peixes.DADOS:
		linhas.append(_linha("peixe:" + id, "peixe", true))
	for id in ["ovo", "feno"]:
		linhas.append(_linha("produto:" + id, "produto", true))
	var sql := "-- Gerado por gerar_tipos.gd; não editar à mão.\nbegin;\ndelete from public.mercado_tipos;\ninsert into public.mercado_tipos(tipo,categoria,empilhavel,encantavel,duas_maos) values\n"
	sql += ",\n".join(linhas) + ";\ncommit;\n"
	var arquivo := FileAccess.open(SAIDA, FileAccess.WRITE)
	arquivo.store_string(sql)
	arquivo.close()
	print("TIPOS GERADOS: ", linhas.size())
	quit()

func _linha(tipo: String, categoria: String, empilhavel: bool, encantavel := false, duas_maos := false) -> String:
	return "('%s','%s',%s,%s,%s)" % [tipo, categoria, empilhavel, encantavel, duas_maos]
