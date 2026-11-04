extends RefCounted
## Elenco fechado da primeira cidade: oito centrais e sete moradores de apoio.
const FONTE=preload("res://codigo/dados/moradores_primeira_raiz.json")
const Gerador=preload("res://codigo/dados/gerador_npcs.gd")
const LIMITE:=15

static func dados() -> Dictionary:
	var resultado:Dictionary={}
	for pessoa in FONTE.data.moradores:
		assert(not resultado.has(pessoa.id) and resultado.size()<LIMITE)
		resultado[pessoa.id]=pessoa.duplicate(true)
	return resultado

static func ficha(id: String) -> Dictionary:
	var pessoas:=dados()
	if not pessoas.has(id):return {}
	var pessoa:Dictionary=pessoas[id]
	var resultado:=Gerador.gerar(int(pessoa.semente),pessoa.perfil)
	resultado.nome=pessoa.nome
	resultado.movimento=pessoa.get("movimento","neutro")
	if pessoa.has("armadura_npc"):resultado.armadura_npc=pessoa.armadura_npc
	for campo in ["faixa_etaria","traje_infantil","cabelo_infantil"]:
		if pessoa.has(campo):resultado[campo]=pessoa[campo]
	var aparencia:Dictionary=resultado.aparencia
	var pele:=Color(pessoa.pele)
	var cabelo:=Color(pessoa.tom_cabelo)
	aparencia.cor_pele=[pele.r,pele.g,pele.b]
	aparencia.cor=[cabelo.r,cabelo.g,cabelo.b,1.0]
	aparencia.olhos=int(pessoa.olhos)
	aparencia.roupas_3d.cabelo=pessoa.cabelo
	for categoria in pessoa.get("roupas",{}):aparencia.roupas_3d[categoria]=pessoa.roupas[categoria]
	return Gerador.normalizar(resultado)

static func conversa(id: String,visita: int) -> Array[String]:
	var pessoa:Dictionary=dados().get(id,{})
	var paginas:Array[String]=[]
	if pessoa.is_empty():return paginas
	if visita==0:
		for fala in pessoa.apresentacao:paginas.append(fala)
	else:
		paginas.append(pessoa.conversas[posmod(visita-1,pessoa.conversas.size())])
	return paginas
