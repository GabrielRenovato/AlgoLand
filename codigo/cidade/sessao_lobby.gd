extends Node
## Uma sessão global por jogador local, preservada nas trocas de mapa.
signal fala_recebida(jogador_id: String, texto: String)
signal alterada
signal mensagem_confirmada(texto: String, erro: String)
## Golpe, disparo ou esquiva de outro jogador do mesmo mapa (só com o servidor próprio)
signal acao_remota(jogador_id: String, dados: Dictionary)
const Visual := preload("res://codigo/dados/visual_ranking.gd")
var jogador: Node2D
var cidade: Node2D
var online := false
var conectado := false
var estado := "CHAT GLOBAL OFFLINE"
var eu := ""
var participantes := {}
var mensagens: Array = []
var mensagens_nao_lidas := 0
var _historico_recebido := false
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
const INTERVALO_GLOBAL := 3.0
var _intervalo_pedido := INTERVALO_CONSULTA
## Transporte WebSocket (servidor próprio em ferramentas/lobby/servidor): quando há endereço, substitui as consultas HTTP ao banco
const Config := preload("res://codigo/dados/ranking_config.gd")
const INTERVALO_ESTADO_WS := 0.1 # 10 Hz andando; o avatar dos outros interpola com atraso (jogador_lobby.gd)
const INTERVALO_OCIOSO_WS := 4.0
const MAXIMO_AVATARES_WS := 24
var _url_ws := ""
var _ws: WebSocketPeer
var _ws_entrou := false
var _ws_espera := 0.0
var _ws_tempo_conexao := 0.0
var _ws_tempo_estado := 0.0
var _ws_ultimo_envio := 0.0
var _ws_assinatura := ""
var _ws_reenvio := 0.0
var _jogador_ligado: Node2D

## Envelope que o servidor aceita; cada mapa é escalado para ele (a cidade, 1024x576, passa sem mudança)
const ENVELOPE := Vector2(1024,576)

## 0 = mapa sem presença visual; 1 cidade, 2 floresta, 3 praia (definido pelo nó LobbyCidade do mapa)
func mapa_id() -> int:
 if not is_instance_valid(cidade): return 0
 var lobby := cidade.get_node_or_null("LobbyCidade")
 return int(lobby.mapa) if lobby != null else 0

func tem_presenca() -> bool:
 return mapa_id()>0

func _retangulo_do_mapa() -> Rect2:
 var limites = cidade.get("limites") if is_instance_valid(cidade) else null
 return limites if limites is Rect2 and limites.size.x>0 and limites.size.y>0 else Rect2(Vector2.ZERO,ENVELOPE)


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
 _url_ws = _endereco_ws()
 _http = HTTPRequest.new()
 _http.timeout = 8.0
 add_child(_http)
 _http.request_completed.connect(_receber)
 var preferencias := ConfigFile.new()
 preferencias.load("user://opcoes.cfg")
 var escolhido := bool(preferencias.get_value("lobby","online_p2" if jogador.eh_p2 else "online_p1",false))
 _permitido = not(("--script" in OS.get_cmdline_args() or OS.get_user_data_dir().get_file().begins_with("AlgoLand testes")) \
  and not (_url.begins_with("http://127.0.0.1:") or _url_ws.begins_with("ws://127.0.0.1:")))
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
  estado = "CHAT GLOBAL OFFLINE"
 else:
  geracao = Crypto.new().generate_random_bytes(16).hex_encode()
  eu = ""
  _conhecidos.clear()
  _visuais.clear()
  _ultimo_visual = ""
  _depois = 0
  mensagens.clear()
  mensagens_nao_lidas = 0
  _historico_recebido = false
  estado = "CONECTANDO AO CHAT GLOBAL..."
  _tempo = 0.0
  _ws_entrou = false
  _ws_espera = 0.0
  _ws_assinatura = ""
 alterada.emit()

## Servidor próprio fora do ar (PC desligado ou sem rede): usa o canal reserva (banco do Supabase) por 1 minuto antes de tentar o servidor de novo
const PAUSA_SERVIDOR_FORA := 60.0
## Servidor que nunca atendeu nesta sessão (PC desligado): duas tentativas e já cai no canal reserva; queda no meio do jogo tolera três
const FALHAS_SEM_NUNCA_ENTRAR := 2
const FALHAS_APOS_ENTRAR := 3
const TEMPO_MAXIMO_CONEXAO := 5.0
var _ws_falhas := 0
var _ws_ja_entrou := false
var _ws_suspenso_ate := 0.0

func usa_ws() -> bool:
 return not _url_ws.is_empty() and Time.get_ticks_msec()/1000.0>=_ws_suspenso_ate

## Servidor online no Fly.io em São Paulo (o mesmo do duelo). Fica aqui, e não no ranking_config.gd,
## porque aquele é lido por um autoload e o patch de conteúdo não pode trocá-lo.
const LOBBY_WS_FLY := "wss://algoland-duelo.fly.dev"

## Endereço do servidor próprio: --lobby-ws= (testes locais), opcoes.cfg [lobby] servidor, ou LOBBY_WS_FLY.
## Só aceita wss:// (o código secreto do perfil viaja na entrada) ou ws:// local.
func _endereco_ws() -> String:
 var candidato: String = LOBBY_WS_FLY
 var preferencias := ConfigFile.new()
 preferencias.load("user://opcoes.cfg")
 var salvo := str(preferencias.get_value("lobby","servidor",""))
 if not salvo.is_empty(): candidato = salvo
 # Scripts e saves de teste só falam com o servidor local passado por argumento, nunca com o padrão do jogo
 if "--script" in OS.get_cmdline_args() or OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"): candidato = ""
 for argumento in OS.get_cmdline_user_args():
  if argumento.begins_with("--lobby-ws="): candidato = argumento.trim_prefix("--lobby-ws=")
 return candidato if candidato.begins_with("wss://") or candidato.begins_with("ws://127.0.0.1:") or candidato.begins_with("ws://localhost:") else ""

func _maximo_avatares() -> int:
 return MAXIMO_AVATARES_WS if usa_ws() else 8

func _process(delta: float) -> void:
 if not online: return
 if usa_ws():
  _processar_ws(delta)
  return
 _tempo -= delta
 if _ocupado: return
 if _tempo<=0: _sincronizar()

func _processar_ws(delta: float) -> void:
 _ligar_jogador()
 if _ws == null:
  _ws_espera -= delta
  if _ws_espera<=0: _conectar_ws()
  return
 _ws.poll()
 match _ws.get_ready_state():
  WebSocketPeer.STATE_CONNECTING:
   _ws_tempo_conexao += delta
   if _ws_tempo_conexao>TEMPO_MAXIMO_CONEXAO: _ws.close()
  WebSocketPeer.STATE_OPEN:
   if not _ws_entrou: _entrar_ws()
   while _ws != null and _ws.get_available_packet_count()>0: _receber_ws(_ws.get_packet().get_string_from_utf8())
   if _ws == null or not _ws_entrou: return
   _ws_tempo_estado -= delta
   if _ws_tempo_estado<=0: _enviar_estado_ws()
   if not _envio.is_empty():
    _ws_reenvio -= delta
    if _ws_reenvio<=0: _enviar_mensagem_ws()
  WebSocketPeer.STATE_CLOSED:
   var motivo := _ws.get_close_reason()
   var tinha_entrado := _ws_entrou
   _ws = null
   _ws_entrou = false
   if tinha_entrado: _ws_falhas = 0
   elif motivo!="substituida":
    _ws_falhas += 1
    if _ws_falhas>=(FALHAS_APOS_ENTRAR if _ws_ja_entrou else FALHAS_SEM_NUNCA_ENTRAR) and not _url.is_empty() and not _chave.is_empty():
     _ws_falhas = 0
     _ws_suspenso_ate = Time.get_ticks_msec()/1000.0+PAUSA_SERVIDOR_FORA
     conectado = false
     participantes.clear()
     estado = "SERVIDOR PROPRIO FORA DO AR - USANDO O CANAL RESERVA"
     _tempo = 0.0
     alterada.emit()
     return
   if motivo=="substituida":
    # O mesmo perfil entrou em outro lugar: não disputa a vaga em loop
    _falhar("PERFIL ONLINE EM OUTRO LUGAR",30.0)
    _ws_espera = 30.0
   else:
    _falhar("SEM CONEXAO - TENTANDO NOVAMENTE",3.0)
    _ws_espera = 3.0

## Cada mapa traz um Jogador novo: escuta os golpes, disparos e esquivas dele para mostrá-los aos outros
func _ligar_jogador() -> void:
 if jogador == _jogador_ligado or not is_instance_valid(jogador): return
 if is_instance_valid(_jogador_ligado) and _jogador_ligado.acao_visual.is_connected(_ao_acao_visual):
  _jogador_ligado.acao_visual.disconnect(_ao_acao_visual)
 _jogador_ligado = jogador
 jogador.acao_visual.connect(_ao_acao_visual)

func _ao_acao_visual(acao: String, duracao: float, combo: int) -> void:
 if _ws == null or not _ws_entrou or _ws.get_ready_state()!=WebSocketPeer.STATE_OPEN or mapa_id()==0: return
 var vetor: Vector2 = jogador._direcao_ataque
 var direcao := 0
 if absf(vetor.x)>absf(vetor.y): direcao = 3 if vetor.x<0 else 1
 elif vetor.y<0: direcao = 2
 _ws.send_text(JSON.stringify({"t":"acao","acao":acao,"duracao":duracao,"combo":combo,"direcao":direcao}))

## Peixe pescado (sessao_pesca.gd): os outros jogadores do mapa veem o peixe sobre este avatar.
## A qualidade (0 normal .. 3 irídio) vai no campo combo do aviso.
func avisar_peixe(peixe: String, qualidade: int) -> void:
 if _ws == null or not _ws_entrou or _ws.get_ready_state()!=WebSocketPeer.STATE_OPEN or mapa_id()==0: return
 _ws.send_text(JSON.stringify({"t":"acao","acao":"peixe","peixe":peixe,"combo":clampi(qualidade,0,3),"duracao":2.0,"direcao":_direcao_visual()}))

func _conectar_ws() -> void:
 if not is_instance_valid(jogador) or not jogador.is_inside_tree(): return
 _ws = WebSocketPeer.new()
 _ws.heartbeat_interval = 15.0
 # Sem Nagle: as posições pequenas e frequentes saem na hora.
 _ws.set_no_delay(true)
 _ws_entrou = false
 _ws_tempo_conexao = 0.0
 if _ws.connect_to_url(_url_ws)!=OK:
  _ws = null
  _falhar("SEM CONEXAO - TENTANDO NOVAMENTE",5.0)
  _ws_espera = 5.0

func _entrar_ws() -> void:
 var montado := _montar_estado(true)
 if montado.is_empty(): return
 var pedido_entrada := {"t":"entrar","codigo":_codigo,"geracao":geracao,"depois":_depois,"estado":montado.conteudo}
 var token_conta: String = preload("res://codigo/conta/cliente_conta.gd").token_para_servidor(get_tree())
 if not token_conta.is_empty(): pedido_entrada["token"] = token_conta
 _ws.send_text(JSON.stringify(pedido_entrada))
 _ultimo_visual = montado.retrato
 _ws_entrou = true
 _ws_falhas = 0
 _ws_ja_entrou = true
 _ws_tempo_estado = INTERVALO_ESTADO_WS
 _ws_ultimo_envio = Time.get_ticks_msec()/1000.0
 if not _envio.is_empty(): _enviar_mensagem_ws()

func _enviar_estado_ws() -> void:
 var montado := _montar_estado()
 if montado.is_empty(): return
 var conteudo: Dictionary = montado.conteudo
 _ws_tempo_estado = INTERVALO_ESTADO_WS if int(montado.mapa)>0 else INTERVALO_OCIOSO_WS
 # Parado e sem novidade só repete de tempos em tempos, para o servidor saber que está vivo
 var assinatura := "%d|%d|%d|%d|%s|%s|%s|%d" % [int(montado.mapa),roundi(conteudo.x),roundi(conteudo.y),int(conteudo.direcao),str(conteudo.andando),str(conteudo.apelido),str(conteudo.has("aparencia")),int(conteudo.get("pesca",-1))]
 var agora := Time.get_ticks_msec()/1000.0
 if assinatura==_ws_assinatura and agora-_ws_ultimo_envio<2.0: return
 _ws_assinatura = assinatura
 _ws_ultimo_envio = agora
 _ws.send_text(JSON.stringify({"t":"estado","estado":conteudo}))
 if conteudo.has("aparencia"): _ultimo_visual = montado.retrato

func _enviar_mensagem_ws() -> void:
 if _ws == null or not _ws_entrou or _envio.is_empty(): return
 _ws.send_text(JSON.stringify({"t":"msg","texto":_mensagem,"envio":_envio}))
 _ws_reenvio = 2.0

func _receber_ws(texto: String) -> void:
 var dados = JSON.parse_string(texto)
 if not dados is Dictionary:
  _falhar("RESPOSTA INVALIDA DO CHAT",5.0)
  return
 if str(dados.get("aviso",""))=="aguarde_mensagem": _ws_reenvio = 0.6
 _processar(dados,int(dados.get("mapa",0)),_ultimo_visual)

func _sincronizar() -> void:
 # Scripts de testes nunca entram no servidor real, mesmo com preferência antiga ligada.
 var teste := "--script" in OS.get_cmdline_args() or OS.get_user_data_dir().get_file().begins_with("AlgoLand testes")
 if (_url.is_empty() or _chave.is_empty()) or (teste and not _url.begins_with("http://127.0.0.1:")):
  estado = "CHAT GLOBAL OFFLINE"
  _tempo = 60
  alterada.emit()
  return
 var montado := _montar_estado()
 if montado.is_empty(): return
 var mapa: int = montado.mapa
 var retrato: String = montado.retrato
 var dados := {"p_codigo":_codigo,"p_geracao":geracao,"p_estado":montado.conteudo,"p_conhecidos":_conhecidos,"p_depois":_depois,"p_mensagem":_mensagem,"p_envio":_envio}
 _ocupado = true
 _intervalo_pedido = INTERVALO_CONSULTA if mapa>0 else INTERVALO_GLOBAL
 _tempo = _intervalo_pedido
 _http.set_meta("mapa",mapa)
 var erro := _http.request(_url+"/rest/v1/rpc/chat_global",_cabecalhos(),HTTPClient.METHOD_POST,JSON.stringify(dados))
 if erro!=OK:
  _ocupado = false
  _falhar("SEM CONEXAO - TENTANDO NOVAMENTE",5.0)
 else: _http.set_meta("retrato",retrato)

## Quadro 0 a 3 da pose de pesca enquanto o jogador pesca; -1 fora dela
func _quadro_de_pesca(raven: Node) -> int:
 var pesca := jogador.get_node_or_null("AnimacaoPesca")
 if pesca == null or raven == null or not raven.has_method("quadro_pesca"): return -1
 return clampi(int(raven.quadro_pesca(int(pesca._pose))),0,3)

## A direção do compositor 2D fica parada enquanto o modelo 3D está ativo.
func _direcao_visual() -> int:
 var direcao: Vector2 = jogador._direcao_ataque
 if jogador.velocity.length()>2: direcao = jogador.velocity
 if absf(direcao.x)>absf(direcao.y): return 1 if direcao.x>0 else 3
 return 0 if direcao.y>=0 else 2

## Estado do jogador para o servidor ({} se ele ainda não está pronto): "conteudo" é o que vai na rede, "retrato" a aparência serializada
func _montar_estado(incluir_aparencia := false) -> Dictionary:
 if not is_instance_valid(jogador) or not jogador.is_inside_tree() or not is_instance_valid(cidade): return {}
 var mapa := mapa_id()
 var posicao := cidade.to_local(jogador.global_position) if mapa>0 else Vector2.ZERO
 var retangulo := _retangulo_do_mapa()
 var normalizada := (posicao-retangulo.position)/retangulo.size*ENVELOPE if mapa>0 else Vector2.ZERO
 var raven := jogador.get_node_or_null("HeroiRaven")
 var visual := Visual.do_jogador(jogador)
 var arma = jogador.inventario.equipados.get("arma")
 if arma != null:
  visual.arma_mais_usada = preload("res://codigo/dados/armas_ranking.gd").validar(arma.tipo)
  visual.nivel_arma = clampi(arma.nivel,1,99)
 # "cidade" continua indicando a praça para servidores e clientes antigos; "mapa" distingue cidade, floresta e praia
 var conteudo := {"cidade":mapa==1,"mapa":mapa,"x":clampf(normalizada.x,0,1024),"y":clampf(normalizada.y,0,576),"direcao":_direcao_visual(),
  "andando":posicao.distance_to(_ultima_posicao)>1,"apelido":Ranking.apelido_personagem(jogador.apelido),"pesca":_quadro_de_pesca(raven)}
 _ultima_posicao = posicao
 var retrato := JSON.stringify(visual)
 if incluir_aparencia or retrato!=_ultimo_visual: conteudo.aparencia = visual
 return {"conteudo":conteudo,"retrato":retrato,"mapa":mapa}

func _receber(_resultado: int, codigo: int, _cabecalhos_resposta: PackedStringArray, corpo: PackedByteArray) -> void:
 _ocupado = false
 if not online: return
 var dados = JSON.parse_string(corpo.get_string_from_utf8())
 if codigo<200 or codigo>=300 or not dados is Dictionary:
  _falhar("SEM CONEXAO - TENTANDO NOVAMENTE",5.0)
  return
 _processar(dados,int(_http.get_meta("mapa",0)),str(_http.get_meta("retrato","")))

## Resposta do servidor (RPC ou WebSocket, mesmo formato): atualiza participantes, mensagens e confirmações
func _processar(dados: Dictionary, mapa_pedido: int, retrato: String) -> void:
 if not online: return
 var erro := str(dados.get("erro",""))
 if not erro.is_empty():
  if erro=="aguarde": _tempo=0.8; return
  _falhar("LIMITE GRATUITO DO CHAT ATINGIDO" if erro=="limite_gratuito" else "RECONECTANDO AO CHAT GLOBAL...",30.0 if erro=="limite_gratuito" else 8.0)
  return
 if not dados.get("eu") is String or str(dados.get("eu","")).length()!=36 or not dados.get("jogadores") is Array or not dados.get("mensagens") is Array:
  _falhar("RESPOSTA INVALIDA DO CHAT",8.0)
  return
 eu = str(dados.get("eu",""))
 _ultimo_visual = retrato
 var novos := {}
 var presencas: Array = dados.jogadores if mapa_pedido>0 and mapa_id()==mapa_pedido else []
 for item in presencas.slice(0,_maximo_avatares()):
  if not item is Dictionary or not _estado_valido(item): continue
  # Servidores com mapa informam onde cada um está; quem está em outro mapa não aparece aqui
  if item.has("mapa") and int(item.mapa)!=mapa_pedido: continue
  var id := str(item.id)
  var visual := Visual.normalizar(item.get("aparencia"))
  if not visual.is_empty():
   _visuais[id] = visual
   _conhecidos[id] = int(item.get("revisao",1))
  if _visuais.has(id):
   item["aparencia"] = _visuais[id]
   novos[id] = item
 participantes = novos
 if mapa_pedido>0 and mapa_id()==mapa_pedido and dados.get("acoes") is Array:
  for acao in dados.acoes.slice(0,16):
   if acao is Dictionary and str(acao.get("jogador","")).length()==36 and str(acao.get("acao","")) in ["ataque","arco","dash","peixe"]:
    acao_remota.emit(str(acao.jogador),acao)
 for id in _visuais.keys():
  if not novos.has(id): _visuais.erase(id); _conhecidos.erase(id)
 for item in dados.mensagens.slice(0,40):
  if not item is Dictionary or not item.get("texto") is String or not item.get("apelido") is String: continue
  var numero := int(item.get("id",0))
  if numero<=_depois: continue
  _depois = numero
  # O histórico inicial e as próprias falas não geram notificações.
  if _historico_recebido and str(item.get("jogador",""))!=eu: mensagens_nao_lidas += 1
  if conectado: fala_recebida.emit(str(item.get("jogador","")),str(item.texto).left(160))
  mensagens.append({"id":numero,"jogador":str(item.get("jogador","")),"apelido":str(item.apelido).left(16),"texto":str(item.texto).left(160)})
 while mensagens.size()>80: mensagens.pop_front()
 _historico_recebido = true
 if not _envio.is_empty() and dados.get("confirmado")==_envio:
  var texto := _mensagem
  _envio = ""
  _mensagem = ""
  mensagem_confirmada.emit(texto,"MENSAGEM NAO PERMITIDA" if dados.get("aviso")=="mensagem_recusada" else "")
 conectado = true
 # Mostra qual canal está em uso: servidor próprio (todos se enxergam) ou canal reserva do banco
 estado = "CHAT GLOBAL ONLINE" + (" (SERVIDOR PROPRIO)" if usa_ws() else (" (CANAL RESERVA)" if not _url_ws.is_empty() else ""))
 alterada.emit()

func enviar_mensagem(texto: String) -> String:
 if not online or not conectado: return "ATIVE O CHAT GLOBAL E AGUARDE A CONEXAO"
 if not _envio.is_empty(): return "AGUARDE O ENVIO DA MENSAGEM ANTERIOR"
 var limpo := RegEx.create_from_string("[[:cntrl:]]").sub(texto," ",true).strip_edges().left(160)
 if limpo.is_empty(): return "DIGITE UMA MENSAGEM"
 _mensagem = limpo
 _envio = Crypto.new().generate_random_bytes(16).hex_encode()
 if usa_ws():
  _enviar_mensagem_ws()
  return ""
 # O repouso fora da cidade economiza tráfego, mas não atrasa uma nova fala.
 _tempo = minf(_tempo,maxf(0,INTERVALO_CONSULTA-(_intervalo_pedido-_tempo)))
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
 if _ws != null:
  if _ws.get_ready_state()==WebSocketPeer.STATE_OPEN:
   _ws.send_text(JSON.stringify({"t":"sair"}))
   _ws.close(1000,"saiu")
   _ws.poll()
  _ws = null
 _ws_entrou = false
 if usa_ws():
  geracao = ""
  return
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
