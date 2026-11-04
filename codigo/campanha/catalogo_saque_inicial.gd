extends RefCounted
## Tabelas exclusivas dos estágios iniciais; não entram no sorteio de equipamentos da arena.
const Acessorios:=preload("res://codigo/dados/acessorios_iniciais.gd")
const Itens:=preload("res://codigo/modelos/dados_item.gd")
const Conjunto:=preload("res://assets/personagens/conjuntos/guarda_novato/definicao.gd")
const Raridades:=preload("res://codigo/dados/raridades.gd")
const ACESSORIOS={"chegada":["anel_cobre","amuleto_madeira"],"estrada":["cinto_couro","bracelete_ferro","anel_cobre","amuleto_madeira"]}
const ARMADURAS_GALERIAS := ["elmo_guarda_novato","peitoral_guarda_novato","luvas_guarda_novato","botas_guarda_novato"]
const CHANCE_ARMADURA_GALERIAS := 0.35
const CHANCE_RARA_GALERIAS := 0.15
static func criar(tipo:String,raridade:String,rng:RandomNumberGenerator) -> Resource:
 if not Conjunto.TIPOS.has(tipo) and not Acessorios.TIPOS.has(tipo): return null
 var item=Itens.new()
 item.id=StringName(tipo);item.tipo=tipo;item.nivel=1;item.duas_maos=false
 item.categoria=Conjunto.TIPOS[tipo].slot if Conjunto.TIPOS.has(tipo) else Acessorios.TIPOS[tipo].slot
 item.raridade="raro" if raridade=="raro" and Conjunto.TIPOS.has(tipo) else "comum"
 item.afixos=Raridades.sortear_afixos(rng,item.categoria,item.raridade)
 return item
static func sortear(regiao:String,rng:RandomNumberGenerator,garantia:String,possuidos:Array) -> Resource:
 if regiao=="moinho":
  if not garantia.is_empty() or rng.randf()>=CHANCE_ARMADURA_GALERIAS:return null
  return criar(ARMADURAS_GALERIAS[rng.randi_range(0,ARMADURAS_GALERIAS.size()-1)],"raro" if rng.randf()<CHANCE_RARA_GALERIAS else "comum",rng)
 if not ACESSORIOS.has(regiao) or garantia=="cerne":return null
 var tipos:Array=ACESSORIOS[regiao].duplicate()
 if garantia.is_empty():
  if rng.randf() >= (0.18 if regiao=="chegada" else 0.24):return null
 else:
  var faltantes:Array=tipos.filter(func(t):return not t in possuidos)
  if not faltantes.is_empty():tipos=faltantes
 return criar(str(tipos[rng.randi_range(0,tipos.size()-1)]),"comum",rng)
