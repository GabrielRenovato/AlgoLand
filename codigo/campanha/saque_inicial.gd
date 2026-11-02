extends Node
## Rolagens pessoais e garantias gravadas junto da mochila. Pendências reaparecem ao voltar à região.
const Catalogo:=preload("res://codigo/campanha/catalogo_saque_inicial.gd")
const Drop:=preload("res://codigo/campanha/drop_inicial.gd")
var cena:Node2D
var inventario:Node
var rng:=RandomNumberGenerator.new()
var _visiveis:Dictionary={}
var _regiao:=""
var _pronto:=false
var _seq:=0
var _sessao:=""
func iniciar(raiz:Node2D) -> void:
 cena=raiz;inventario=cena.jogador.inventario;rng.randomize()
 _sessao=str(Time.get_unix_time_from_system())+"-"+str(rng.randi())
 if inventario.saque_campanha.is_empty():inventario.saque_campanha={"pendentes":{},"garantias":[],"recibos":[]}
 _pronto=validar_estado(inventario.saque_campanha)
 if not _pronto:push_error("Saque inicial inválido; inventário preservado.")
func iniciar_instancia(regiao: String) -> Error:
 if not _pronto: return ERR_UNCONFIGURED
 var antes: Dictionary = inventario.saque_campanha.duplicate(true)
 var garantias: Array = ["guarda","cerne"] if regiao=="chegada" else (["resgate"] if regiao=="estrada" else [])
 for g in garantias: inventario.saque_campanha.garantias.erase(g)
 # Drops de tentativas encerradas não são eventos da nova instância. A mochila permanece intacta.
 for id in inventario.saque_campanha.pendentes.keys():
  if inventario.saque_campanha.pendentes[id].regiao==regiao: inventario.saque_campanha.pendentes.erase(id)
 for no in _visiveis.values():
  if is_instance_valid(no): no.queue_free()
 _visiveis.clear()
 _regiao=""
 if not inventario.salvar():
  inventario.saque_campanha=antes
  return ERR_CANT_CREATE
 return OK

func registrar(inimigo:Node2D,garantia:="") -> void:
 if inimigo.has_meta("saque_inicial"):return
 inimigo.set_meta("saque_inicial",true)
 if cena.get("registro_run")!=null:cena.registro_run.registrar_inimigo(inimigo,garantia=="cerne")
 inimigo.inimigo_morreu.connect(_abate.bind(inimigo,garantia),CONNECT_ONE_SHOT)
func _abate(inimigo:Node2D,garantia:String) -> void:
 _seq+=1
 var evento:="%s:%d" % [_sessao,_seq]
 var p:Vector2=inimigo.global_position
 receber(evento,cena.regiao,p,garantia)
 if cena.sessao!=null and cena.sessao.ativo and cena.sessao.sou_host():
  cena.sessao.enviar({"t":"saque_inicial","andar":1,"evento":evento,"regiao":cena.regiao,"x":p.x,"y":p.y,"garantia":garantia})
func receber(evento:String,regiao:String,p:Vector2,garantia:="") -> Error:
 if not _pronto:return ERR_UNCONFIGURED
 if not regiao in ["chegada","estrada"] or not p.is_finite() or p.length()>5000 or evento.is_empty() or evento.length()>128:return ERR_INVALID_PARAMETER
 if not garantia in ["","guarda","cerne","resgate"]:return ERR_INVALID_PARAMETER
 if garantia=="resgate" and regiao!="estrada" or garantia in ["guarda","cerne"] and regiao!="chegada":return ERR_INVALID_PARAMETER
 var estado:Dictionary=inventario.saque_campanha
 if evento in estado.recibos:return ERR_ALREADY_EXISTS
 if not garantia.is_empty() and garantia in estado.garantias:return ERR_ALREADY_EXISTS
 var antes:Dictionary=estado.duplicate(true)
 var possuidos:Array=[]
 for tipo in Catalogo.Conjunto.TIPOS:
  if inventario.buscar_por_tipo(tipo)!=null:possuidos.append(tipo)
 for pendente in estado.pendentes.values():
  if pendente is Dictionary:possuidos.append(pendente.get("item",{}).get("tipo",""))
 var item=Catalogo.sortear(regiao,rng,garantia,possuidos)
 estado.recibos.append(evento)
 if estado.recibos.size()>256:estado.recibos.pop_front()
 if not garantia.is_empty():estado.garantias.append(garantia)
 if item!=null:estado.pendentes[evento]={"regiao":regiao,"posicao":[p.x,p.y],"item":item.para_dict()}
 if not inventario.salvar():inventario.saque_campanha=antes;return ERR_CANT_CREATE
 if item!=null and cena.get("registro_run")!=null:cena.registro_run.drop_sorteado(evento,item)
 if item!=null and cena.regiao==regiao:_mostrar(evento)
 return OK
func _mostrar(id:String) -> void:
 if _visiveis.has(id) and is_instance_valid(_visiveis[id]):return
 var dado:Dictionary=inventario.saque_campanha.pendentes[id]
 var tipo:String=dado.get("item",{}).get("tipo","")
 var item=Catalogo.criar(tipo,str(dado.get("item",{}).get("raridade","comum")),rng)
 if item==null:return
 # Restaura os mesmos afixos sorteados, sem rolar outra vez na retomada.
 item=Catalogo.Itens.de_dict(dado.item)
 var drop:=Drop.new();drop.item=item;drop.registro=id;drop.saque=self
 var ponto:=Vector2(float(dado.posicao[0]),float(dado.posicao[1]))
 if is_instance_valid(cena.terreno):ponto=cena.terreno.ponto_livre(ponto)
 drop.preparar_pulo(ponto,ponto+Vector2(6,0))
 cena.add_child(drop);_visiveis[id]=drop
func _process(_delta:float) -> void:
 if not _pronto or not is_instance_valid(cena) or inventario==null or not is_instance_valid(cena.terreno):return
 if _regiao!=cena.regiao:
  for no in _visiveis.values():
   if is_instance_valid(no):no.queue_free()
  _visiveis.clear();_regiao=cena.regiao
  for id in inventario.saque_campanha.pendentes:
   if inventario.saque_campanha.pendentes[id].get("regiao")==_regiao:_mostrar(id)
 var progresso=cena.controlador.progresso
 # Garante recuperação de saves anteriores e falhas de escrita sem exigir repetir um combate concluído.
 var objetivos:Array=progresso.objetivos_cumpridos("sobreviver_queda")
 if _regiao=="chegada":
  if "combate" in objetivos:_recuperar("guarda",cena.jogador.position)
  if "vigilia" in objetivos:_recuperar("cerne",cena.jogador.position)
 if _regiao=="estrada" and "trabalhador" in progresso.objetivos_cumpridos("estrada_interrompida"):_recuperar("resgate",cena.jogador.position)
func _recuperar(garantia:String,p:Vector2) -> void:
 if not garantia in inventario.saque_campanha.garantias:receber("garantia:"+garantia,_regiao,p,garantia)

static func validar_estado(d:Dictionary) -> bool:
 if not d.get("pendentes") is Dictionary or not d.get("garantias") is Array or not d.get("recibos") is Array:return false
 if d.recibos.size()>256 or d.garantias.size()>3:return false
 for g in d.garantias:
  if not g in ["guarda","cerne","resgate"]:return false
 for id in d.recibos:
  if not id is String or id.is_empty() or id.length()>128:return false
 for id in d.pendentes:
  var p=d.pendentes[id]
  if not id is String or not p is Dictionary or not p.get("regiao") in ["chegada","estrada"] or not p.get("item") is Dictionary:return false
  var item:Dictionary=p.item
  var tipo:String=str(item.get("tipo",""))
  if not Catalogo.Conjunto.TIPOS.has(tipo) and not Catalogo.Acessorios.TIPOS.has(tipo):return false
  var slot:String=Catalogo.Conjunto.TIPOS[tipo].slot if Catalogo.Conjunto.TIPOS.has(tipo) else Catalogo.Acessorios.TIPOS[tipo].slot
  if item.get("categoria")!=slot or item.get("nivel")!=1 or not item.get("raridade") in ["comum","raro"]:return false
  if not p.get("posicao") is Array or p.posicao.size()!=2:return false
  for v in p.posicao:
   if not (v is float or v is int) or not is_finite(float(v)) or absf(float(v))>5000:return false
 return true
