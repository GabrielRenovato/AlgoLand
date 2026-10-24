extends Node
## Uma sessão por jogador local, só enquanto ele escolheu ficar online na cidade.
signal fala_recebida(jogador_id: String, texto: String)
signal alterada
signal mensagem_confirmada(texto: String, erro: String)
const Visual := preload("res://codigo/dados/visual_ranking.gd")
var jogador: Node2D
var cidade: Node2D
var online := false
var conectado := false
var estado := "CIDADE OFFLINE"
var eu := ""
var participantes := {}
var mensagens: Array = []
var geracao := ""
var _conhecidos := {}
var _visuais := {}
var _ultimo_visual := ""
var _ultima_posicao := Vector2.ZERO
var _depois := 0
var _tempo := 0.0
var _ocupado := false
var _mensagem := ""
var _envio := ""
var _http: HTTPRequest
var _perfil: Node
var _url := ""
var _chave := ""
var _codigo := ""
var _permitido := true
## Conta desde o início do pedido: a latência da rede não acrescenta outra espera.
## O servidor recusa menos de 0,5 s entre atualizações.
const INTERVALO_CONSULTA := 0.55


func _ready() -> void:
 process_mode = Node.PROCESS_MODE_ALWAYS
 _perfil = Ranking.para_jogador(jogador)
 _url = _perfil.url_servico
 _chave = _perfil.chave_servico
 _codigo = _perfil._codigo
 for argumento in OS.get_cmdline_user_args():
  if argumento.begins_with("--lobby-url=http://127.0.0.1:"):
   _url = argumento.trim_prefix("--lobby-url=")
   _chave = "teste_local"
 _http = HTTPRequest.new()
 _http.timeout = 8.0
 add_child(_http)
 _http.request_completed.connect(_receber)
 var preferencias := ConfigFile.new()
 preferencias.load("user://opcoes.cfg")
 var escolhido := bool(preferencias.get_value("lobby","online_p2" if jogador.eh_p2 else "online_p1",false))
 _permitido = not(("--script" in OS.get_cmdline_args() or OS.get_user_data_dir().get_file().begins_with("AlgoLand testes")) and not _url.begins_with("http://127.0.0.1:"))
 if not _permitido: escolhido=false
 definir_online(escolhido,false)

func definir_online(valor: bool, salvar := true) -> void:
 if valor and not _permitido: return
 if online == valor:
  alterada.emit()
  return
 online = valor
 if salvar:
  var preferencias := ConfigFile.new()
  preferencias.load("user://opcoes.cfg")
  preferencias.set_value("lobby","online_p2" if jogador.eh_p2 else "online_p1",online)
  if preferencias.save("user://opcoes.cfg") != OK: estado = "NAO FOI POSSIVEL SALVAR A PREFERENCIA"
 if not online:
  _sair()
  estado = "CIDADE OFFLINE"
 else:
  geracao = Crypto.new().generate_random_bytes(16).hex_encode()
  eu = ""
  _conhecidos.clear()
  _visuais.clear()
  _ultimo_visual = ""
  _depois = 0
  mensagens.clear()
  estado = "CONECTANDO A CIDADE..."
  _tempo = 0.0
 alterada.emit()

func _process(delta: float) -> void:
 if not online: return
 _tempo -= delta
 if _ocupado: return
 if _tempo<=0: _sincronizar()

func _sincronizar() -> void:
 # Scripts de testes nunca entram no servidor real, mesmo com preferência antiga ligada.
 var teste := "--script" in OS.get_cmdline_args() or OS.get_user_data_dir().get_file().begins_with("AlgoLand testes")
 if (_url.is_empty() or _chave.is_empty()) or (teste and not _url.begins_with("http://127.0.0.1:")):
  estado = "CIDADE OFFLINE"
  _tempo = 60
  alterada.emit()
  return
 if not is_instance_valid(jogador): return
 var posicao := cidade.to_local(jogador.global_position)
 var raven := jogador.get_node_or_null("HeroiRaven")
 var visual := Visual.do_jogador(jogador)
 var arma = jogador.inventario.equipados.get("arma")
 if arma != null:
  visual.arma_mais_usada = preload("res://codigo/dados/armas_ranking.gd").validar(arma.tipo)
  visual.nivel_arma = clampi(arma.nivel,1,99)
 var conteudo := {"x":clampf(posicao.x,0,1024),"y":clampf(posicao.y,0,576),"direcao":raven._direcao if raven!=null else 0,
  "andando":posicao.distance_to(_ultima_posicao)>1,"apelido":Ranking.apelido_personagem(jogador.apelido)}
 _ultima_posicao = posicao
 var retrato := JSON.stringify(visual)
 if retrato!=_ultimo_visual: conteudo.aparencia = visual
 var dados := {"p_codigo":_codigo,"p_geracao":geracao,"p_estado":conteudo,"p_conhecidos":_conhecidos,"p_depois":_depois,"p_mensagem":_mensagem,"p_envio":_envio}
 _ocupado = true
 _tempo = INTERVALO_CONSULTA
 var erro := _http.request(_url+"/rest/v1/rpc/lobby_cidade",_cabecalhos(),HTTPClient.METHOD_POST,JSON.stringify(dados))
 if erro!=OK:
  _ocupado = false
  _falhar("SEM CONEXAO - TENTANDO NOVAMENTE",5.0)
 else: _http.set_meta("retrato",retrato)

func _receber(_resultado: int, codigo: int, _cabecalhos_resposta: PackedStringArray, corpo: PackedByteArray) -> void:
 _ocupado = false
 if not online: return
 var dados = JSON.parse_string(corpo.get_string_from_utf8())
 if codigo<200 or codigo>=300 or not dados is Dictionary:
  _falhar("SEM CONEXAO - TENTANDO NOVAMENTE",5.0)
  return
 var erro := str(dados.get("erro",""))
 if not erro.is_empty():
  if erro=="aguarde": _tempo=0.8; return
  _falhar("CIDADE CHEIA - TENTANDO NOVAMENTE" if erro=="cidade_cheia" else "LIMITE GRATUITO DO LOBBY ATINGIDO" if erro=="limite_gratuito" else "RECONECTANDO A CIDADE...",30.0 if erro=="limite_gratuito" else 8.0)
  return
 if not dados.get("eu") is String or str(dados.get("eu","")).length()!=36 or not dados.get("jogadores") is Array or not dados.get("mensagens") is Array:
  _falhar("RESPOSTA INVALIDA DO LOBBY",8.0)
  return
 eu = str(dados.get("eu",""))
 _ultimo_visual = str(_http.get_meta("retrato",""))
 var novos := {}
 for item in dados.jogadores.slice(0,8):
  if not item is Dictionary or not _estado_valido(item): continue
  var id := str(item.id)
  var visual := Visual.normalizar(item.get("aparencia"))
  if not visual.is_empty():
   _visuais[id] = visual
   _conhecidos[id] = int(item.get("revisao",1))
  if _visuais.has(id):
   item["aparencia"] = _visuais[id]
   novos[id] = item
 participantes = novos
 for id in _visuais.keys():
  if not novos.has(id): _visuais.erase(id); _conhecidos.erase(id)
 for item in dados.mensagens.slice(0,40):
  if not item is Dictionary or not item.get("texto") is String or not item.get("apelido") is String: continue
  var numero := int(item.get("id",0))
  if numero<=_depois: continue
  _depois = numero
  if conectado: fala_recebida.emit(str(item.get("jogador","")),str(item.texto).left(160))
  mensagens.append({"id":numero,"jogador":str(item.get("jogador","")),"apelido":str(item.apelido).left(16),"texto":str(item.texto).left(160)})
 while mensagens.size()>80: mensagens.pop_front()
 if not _envio.is_empty() and dados.get("confirmado")==_envio:
  var texto := _mensagem
  _envio = ""
  _mensagem = ""
  mensagem_confirmada.emit(texto,"MENSAGEM NAO PERMITIDA" if dados.get("aviso")=="mensagem_recusada" else "")
 conectado = true
 estado = "CIDADE ONLINE - %d / 8 JOGADORES" % participantes.size()
 alterada.emit()

func enviar_mensagem(texto: String) -> String:
 if not online or not conectado: return "ATIVE A CIDADE ONLINE E AGUARDE A CONEXAO"
 if not _envio.is_empty(): return "AGUARDE O ENVIO DA MENSAGEM ANTERIOR"
 var limpo := RegEx.create_from_string("[[:cntrl:]]").sub(texto," ",true).strip_edges().left(160)
 if limpo.is_empty(): return "DIGITE UMA MENSAGEM"
 _mensagem = limpo
 _envio = Crypto.new().generate_random_bytes(16).hex_encode()
 # Respeita só o restante do intervalo do pedido anterior. Se ele ainda está
 # em trânsito, sua resposta não pode adiar a mensagem por mais um ciclo.
 if not _ocupado and _tempo<=0: _sincronizar()
 return ""

func _estado_valido(item: Dictionary) -> bool:
 if not item.get("id") is String or not item.get("apelido") is String: return false
 if item.id.length()!=36: return false
 for chave in ["x","y","direcao"]:
  if not(item.get(chave) is float or item.get(chave) is int) or not is_finite(float(item[chave])): return false
 return float(item.x)>=0 and float(item.x)<=1024 and float(item.y)>=0 and float(item.y)<=576

func _falhar(texto: String, espera: float) -> void:
 conectado = false
 participantes.clear()
 _ultimo_visual = ""
 estado = texto
 _tempo = espera
 alterada.emit()

func _cabecalhos() -> PackedStringArray:
 var cabecalhos := PackedStringArray(["apikey: "+_chave,"Content-Type: application/json"])
 if _chave.begins_with("eyJ"): cabecalhos.append("Authorization: Bearer "+_chave)
 return cabecalhos

func _sair() -> void:
 if is_instance_valid(_http): _http.cancel_request()
 _ocupado = false
 conectado = false
 participantes.clear()
 if not _envio.is_empty(): mensagem_confirmada.emit(_mensagem,"MENSAGEM NAO ENVIADA: VOCE SAIU DO LOBBY")
 _mensagem = ""
 _envio = ""
 if not _permitido or geracao.is_empty() or _url.is_empty(): return
 var saida := HTTPRequest.new()
 saida.process_mode = Node.PROCESS_MODE_ALWAYS
 saida.timeout = 4.0
 var url_saida := _url+"/rest/v1/rpc/lobby_cidade_sair"
 var cabecalhos := _cabecalhos()
 var corpo := JSON.stringify({"p_codigo":_codigo,"p_geracao":geracao})
 saida.request_completed.connect(func(_r: int,_c: int,_h: PackedStringArray,_b: PackedByteArray) -> void: saida.queue_free())
 # A cidade pode estar saindo da árvore. O pedido independente só começa depois de entrar na raiz.
 saida.ready.connect(func() -> void:
  if saida.request(url_saida,cabecalhos,HTTPClient.METHOD_POST,corpo)!=OK: saida.queue_free(),CONNECT_ONE_SHOT)
 get_tree().root.add_child.call_deferred(saida)
 geracao = ""

func _exit_tree() -> void:
 if online: _sair()
