extends SceneTree
var falhas:=0
func _initialize():rodar.call_deferred()
func verificar(texto:String,ok:bool):
 print("OK " if ok else "FALHA ",texto)
 if not ok:falhas+=1
func rodar():
 if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"):quit(1);return
 var catalogo=load("res://codigo/campanha/catalogo_saque_inicial.gd")
 var rng:=RandomNumberGenerator.new();rng.seed=4581
 var inv=root.get_node("InventarioJogador")
 inv.caminho_save="user://inventario_drops.json";inv.limpar()
 for slot in ["anel","colar","cinto","bracelete"]:verificar("slot real "+slot,inv.equipados.has(slot))
 var encontrados:Dictionary={}
 for regiao in ["chegada","estrada"]:
  for i in 1500:
   var item=catalogo.sortear(regiao,rng,"",[])
   if item==null:continue
   encontrados[item.tipo]=true
   verificar("tabela correta "+item.tipo,item.tipo in catalogo.ACESSORIOS[regiao])
   verificar("nivel inicial e sem magia",item.nivel==1 and item.encantamento.is_empty())
   verificar("apenas acessorios comuns sem afixos",item.raridade=="comum" and item.afixos.is_empty())
 verificar("todos os acessorios sorteaveis",catalogo.Acessorios.TIPOS.keys().all(func(t):return encontrados.has(t)))
 for i in 20:
  var chefe=catalogo.sortear("chegada",rng,"cerne",[])
  verificar("boss aguarda definicao de recompensa",chefe==null)
 var item=catalogo.sortear("estrada",rng,"resgate",["cinto_couro","bracelete_ferro","anel_cobre"])
 verificar("resgate prioriza acessorio faltante",item.tipo=="amuleto_madeira")
 item=catalogo.sortear("chegada",rng,"guarda",["anel_cobre"])
 verificar("guardiao garante acessorio faltante",item.tipo=="amuleto_madeira")
 verificar("regiao desconhecida sem drop",catalogo.sortear("inexistente",rng,"",[])==null)
 for tipo in catalogo.Acessorios.TIPOS:
  item=catalogo.criar(tipo,"comum",rng)
  verificar("recebe e equipa "+tipo,inv.adicionar(item)>=0 and inv.equipar(item))
 verificar("salva novos slots",inv.salvar())
 verificar("reabre novos slots",inv.carregar())
 for tipo in catalogo.Acessorios.TIPOS:
  var d:Dictionary=catalogo.Acessorios.TIPOS[tipo]
  verificar("slot persiste "+tipo,inv.equipados[d.slot]!=null and inv.equipados[d.slot].tipo==tipo)
 var pecas:Dictionary={}
 for tipo in catalogo.Conjunto.TIPOS:
  item=catalogo.criar(tipo,"comum",rng);pecas[item.categoria]=item
 var conjuntos=load("res://codigo/dados/conjuntos_armadura.gd")
 verificar("quatro pecas bonus fisico",is_equal_approx(conjuntos.bonus_fisico(pecas).guarda,0.05) and is_equal_approx(conjuntos.bonus_fisico(pecas).esquiva,0.05))
 pecas.erase("botas");pecas.erase("luvas")
 verificar("duas pecas so guarda",is_equal_approx(conjuntos.bonus_fisico(pecas).guarda,0.05) and conjuntos.bonus_fisico(pecas).esquiva==0)
 verificar("manifesto e definicao correspondem",load("res://codigo/dados/padrao_armadura.gd").roteiro_definicao(JSON.parse_string(FileAccess.get_file_as_string("res://ferramentas/armaduras/em_preparacao/guarda_novato/manifesto.json")))==FileAccess.get_file_as_string("res://assets/personagens/conjuntos/guarda_novato/definicao.gd"))
 print("FALHAS: ",falhas);quit(1 if falhas else 0)
