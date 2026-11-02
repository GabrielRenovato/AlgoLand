extends RefCounted
## Tabelas exclusivas dos estágios iniciais; não entram no sorteio de equipamentos da arena.
const Acessorios:=preload("res://codigo/dados/acessorios_iniciais.gd")
const Itens:=preload("res://codigo/modelos/dados_item.gd")
const Conjunto:=preload("res://assets/personagens/conjuntos/guarda_novato/definicao.gd")
const Raridades:=preload("res://codigo/dados/raridades.gd")
const ARMADURAS={"chegada":["peitoral_guarda_novato","botas_guarda_novato"],"estrada":["elmo_guarda_novato","luvas_guarda_novato","peitoral_guarda_novato","botas_guarda_novato"]}
const ACESSORIOS={"chegada":["anel_cobre","amuleto_madeira"],"estrada":["cinto_couro","bracelete_ferro","anel_cobre","amuleto_madeira"]}
static func criar(tipo:String,raridade:String,rng:RandomNumberGenerator) -> Resource:
 if not Conjunto.TIPOS.has(tipo) and not Acessorios.TIPOS.has(tipo): return null
 var item=Itens.new()
 item.id=StringName(tipo);item.tipo=tipo;item.nivel=1;item.duas_maos=false
 item.categoria=Conjunto.TIPOS[tipo].slot if Conjunto.TIPOS.has(tipo) else Acessorios.TIPOS[tipo].slot
 item.raridade="raro" if raridade=="raro" and Conjunto.TIPOS.has(tipo) else "comum"
 item.afixos=Raridades.sortear_afixos(rng,item.categoria,item.raridade)
 return item
static func sortear(regiao:String,rng:RandomNumberGenerator,garantia:String,possuidos:Array) -> Resource:
 if not ARMADURAS.has(regiao):return null
 var tipos:Array=ARMADURAS[regiao].duplicate()
 var raro:=garantia=="cerne"
 if garantia=="resgate":tipos=["elmo_guarda_novato","luvas_guarda_novato"]
 if garantia.is_empty():
  if rng.randf() >= (0.18 if regiao=="chegada" else 0.24):return null
  if rng.randf()<0.25:tipos=ACESSORIOS[regiao]
  raro=regiao=="estrada" and rng.randf()<0.10
 else:
  var faltantes:Array=tipos.filter(func(t):return not t in possuidos)
  if not faltantes.is_empty():tipos=faltantes
 return criar(str(tipos[rng.randi_range(0,tipos.size()-1)]),"raro" if raro else "comum",rng)
