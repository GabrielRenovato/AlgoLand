extends RefCounted
## Acessórios físicos iniciais; categoria corresponde a um único slot real.
const TIPOS := {
 "anel_cobre":{"nome":"ANEL DE COBRE","slot":"anel","efeito":"vida","valor":6.0,"texto":"+6 VIDA MAXIMA"},
 "amuleto_madeira":{"nome":"AMULETO DE MADEIRA","slot":"colar","efeito":"folego","valor":8.0,"texto":"+8 FOLEGO MAXIMO"},
 "cinto_couro":{"nome":"CINTO DE COURO","slot":"cinto","efeito":"esquiva","valor":0.04,"texto":"-4% CUSTO DA ESQUIVA"},
 "bracelete_ferro":{"nome":"BRACELETE DE FERRO","slot":"bracelete","efeito":"empurrao","valor":0.08,"texto":"+8% EMPURRAO DOS GOLPES"}
}
const SLOTS := ["anel","colar","cinto","bracelete"]
static func bonus(equipados: Dictionary, efeito: String) -> float:
 var valor:=0.0
 for tipo in TIPOS:
  var d:Dictionary=TIPOS[tipo]
  var item=equipados.get(d.slot)
  if item!=null and item.tipo==tipo and item.categoria==d.slot and d.efeito==efeito:valor+=float(d.valor)
 return valor
static func icone(tipo: String) -> Texture2D:
 return load("res://assets/ui/acessorios_iniciais/%s.svg" % tipo) if TIPOS.has(tipo) else null
