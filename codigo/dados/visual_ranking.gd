extends RefCounted
## Retrato público limitado aos catálogos locais. Nunca aceita caminhos enviados pelo servidor.
const Raven := preload("res://codigo/dados/aparencia_raven.gd")
const Aparencia := preload("res://codigo/dados/aparencia.gd")
const Conjuntos := preload("res://codigo/dados/conjuntos_armadura.gd")
const Armas := preload("res://codigo/dados/armas_ranking.gd")
const BASICOS := {"cabeca":"cabeca_basica","corpo":"armadura_basica","luvas":"luvas_basicas","botas":"botas_basicas"}

static func _inteiro(dados: Dictionary, chave: String, minimo: int, maximo: int, padrao := 0) -> int:
	var valor = dados.get(chave,padrao)
	if not (valor is int or valor is float) or not is_finite(float(valor)): return padrao
	return int(clampf(float(valor),minimo,maximo))

static func tipo_valido(tipo: String, slot: String) -> bool:
	if tipo == BASICOS.get(slot,""): return true
	var conjunto := Conjuntos.de_tipo(tipo)
	return conjunto != null and conjunto.TIPOS[tipo].slot == slot

static func normalizar(valor: Variant) -> Dictionary:
	if not valor is Dictionary or valor.get("versao") != 1: return {}
	var cor: Array = [1.0,1.0,1.0,1.0]
	var entrada = valor.get("cor")
	if entrada is Array and entrada.size() == 4:
		for i in 3:
			if (entrada[i] is int or entrada[i] is float) and is_finite(float(entrada[i])):
				cor[i] = clampf(float(entrada[i]),0.0,1.0)
	var equipamentos := {}
	var enviados = valor.get("equipamentos",{})
	if enviados is Dictionary:
		for slot: String in BASICOS:
			var tipo = enviados.get(slot)
			if tipo is String and tipo_valido(tipo,slot): equipamentos[slot] = tipo
	return {"versao":1,"pele":_inteiro(valor,"pele",0,2),"cabelo":_inteiro(valor,"cabelo",0,28),
		"roupa":_inteiro(valor,"roupa",0,8),"cor":cor,"equipamentos":equipamentos,
		"roupa_visual":_inteiro(valor,"roupa_visual",0,Aparencia.total_roupas()-1),
		"pecas_visuais":_inteiro(valor,"pecas_visuais",0,15,15),"arma_mais_usada":Armas.validar(valor.get("arma_mais_usada")),"nivel_arma":_inteiro(valor,"nivel_arma",1,99,1)}

static func do_jogador(jogador: Node2D) -> Dictionary:
	var dados: Dictionary = jogador.aparencia_raven.duplicate(true)
	dados["versao"] = 1
	dados["roupa_visual"] = jogador.roupa_atual
	dados["pecas_visuais"] = jogador.pecas_cavaleiro
	dados["equipamentos"] = {}
	for slot: String in BASICOS:
		var item = jogador.inventario.equipados.get(slot)
		if item != null and item.categoria == slot and tipo_valido(item.tipo,slot):
			dados.equipamentos[slot] = item.tipo
	return normalizar(dados)

class ItemVisual extends RefCounted:
	var tipo := ""
	var categoria := ""
	var nivel := 1
	var duas_maos := false

class InventarioVisual extends RefCounted:
	var equipados := {}
	var vara_na_mao := false

class Modelo extends Node2D:
	var aparencia_raven := {}
	var inventario := InventarioVisual.new()
	var roupa_atual := 0
	var _pecas_cavaleiro_debug := 15
	var usando_arco := false
	var usando_lanca := false
	var usando_espada := false
	var id_lanca_atual := "lanca_basica"
	var id_arma_atual := "espada_basica"
	var esta_em_acao_fazenda := false
	var raizes_armadura: Dictionary:
		get:
			return {} if not Aparencia.raiz_armadura_visual(roupa_atual).is_empty() else Conjuntos.raizes(inventario.equipados)
	var pecas_cavaleiro: int:
		get:
			return _pecas_cavaleiro_debug if not Aparencia.raiz_armadura_visual(roupa_atual).is_empty() else Conjuntos.mascara(inventario.equipados)

static func criar_modelo(dados: Dictionary) -> Node2D:
	var modelo := Modelo.new()
	modelo.aparencia_raven = normalizar(dados)
	modelo.roupa_atual = int(modelo.aparencia_raven.roupa_visual)
	modelo._pecas_cavaleiro_debug = int(modelo.aparencia_raven.pecas_visuais)
	var arma: String = modelo.aparencia_raven.arma_mais_usada
	if not arma.is_empty():
		var item := ItemVisual.new()
		item.tipo = arma
		item.nivel = int(modelo.aparencia_raven.nivel_arma)
		item.categoria = "arma"
		item.duas_maos = arma=="espada_gemea"
		modelo.inventario.equipados.arma = item
		modelo.id_arma_atual = arma
		modelo.usando_arco = Armas.ARMAS[arma]=="arco"
		modelo.usando_lanca = Armas.ARMAS[arma]=="lanca"
		modelo.usando_espada = not modelo.usando_arco and not modelo.usando_lanca
	for slot: String in modelo.aparencia_raven.equipamentos:
		var item := ItemVisual.new()
		item.tipo = modelo.aparencia_raven.equipamentos[slot]
		item.categoria = slot
		modelo.inventario.equipados[slot] = item
	return modelo
