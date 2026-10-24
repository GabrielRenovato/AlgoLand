extends Node2D
## A cidade continua sendo o mundo do jogador; este nó compartilha somente avatares e conversa.
const Sessao := preload("res://codigo/cidade/sessao_lobby.gd")
const Remoto := preload("res://codigo/cidade/jogador_lobby.gd")
## 1 cidade, 2 floresta, 3 praia: o servidor só mostra quem está no mesmo mapa
var mapa := 1
var sessoes := {}
var remotos := {}
var _meus_ids := {}

func _ready() -> void:
 name = "LobbyCidade"
 process_mode = Node.PROCESS_MODE_ALWAYS
 add_to_group("lobby_cidade")

func sessao_de(jogador: Node2D) -> Node:
 if jogador==null or Cooperativo.cena_de(jogador)!=get_parent(): return null
 var lado := 2 if jogador.eh_p2 else 1
 if not sessoes.has(lado) or not is_instance_valid(sessoes[lado]):
  var sessao: Node = Cooperativo.sessao_chat_de(jogador)
  if sessao == null: return null
  sessoes[lado] = sessao
  sessao.alterada.connect(_atualizar_remotos.bind(sessao))
 return sessoes[lado]

func _process(_delta: float) -> void:
 for jogador in [Cooperativo._jogador1(),Cooperativo.jogador2()]:
  if jogador!=null and Cooperativo.cena_de(jogador)==get_parent(): sessao_de(jogador)
 for lado in sessoes.keys():
  var sessao = sessoes[lado]
  if not is_instance_valid(sessao) or not is_instance_valid(sessao.jogador) or Cooperativo.cena_de(sessao.jogador)!=get_parent():
   sessoes.erase(lado)
   if is_instance_valid(sessao) and sessao.alterada.is_connected(_atualizar_remotos.bind(sessao)):
    sessao.alterada.disconnect(_atualizar_remotos.bind(sessao))
 if not sessoes.values().any(func(sessao: Node) -> bool: return sessao.online and sessao.conectado): _limpar_remotos()
 _encaixar_nomes()

func _atualizar_remotos(sessao: Node) -> void:
 if not sessao.eu.is_empty(): _meus_ids[sessao.eu] = true
 if not sessao.online or not sessao.conectado:
  if not sessoes.values().any(func(outra: Node) -> bool: return outra.online and outra.conectado): _limpar_remotos()
  return
 for id in remotos.keys():
  if not sessao.participantes.has(id) or _meus_ids.has(id):
   remove_child(remotos[id]); remotos[id].queue_free(); remotos.erase(id)
 for id: String in sessao.participantes:
  if _meus_ids.has(id): continue
  var dados: Dictionary = sessao.participantes[id].duplicate()
  var ponto := _do_envelope(Vector2(float(dados.x),float(dados.y)))
  dados.x = ponto.x
  dados.y = ponto.y
  var inicial := not remotos.has(id)
  if inicial:
   var remoto := Remoto.new()
   remotos[id] = remoto
   add_child(remoto)
  remotos[id].atualizar(dados,dados.aparencia,inicial)

## O servidor guarda posições no envelope 1024x576; cada mapa as devolve para o próprio tamanho
func _do_envelope(ponto: Vector2) -> Vector2:
 var limites = get_parent().get("limites")
 if not limites is Rect2 or limites.size.x<=0 or limites.size.y<=0: return ponto
 return limites.position+ponto/Sessao.ENVELOPE*limites.size

func _limpar_remotos() -> void:
 for remoto in remotos.values(): remove_child(remoto); remoto.queue_free()
 remotos.clear()

func _encaixar_nomes() -> void:
 var ocupados: Array[Rect2] = []
 var ids := remotos.keys()
 ids.sort()
 for id in ids:
  var remoto: Node2D = remotos[id]
  var nome: Label = remoto.nome
  nome.position = Vector2(-44,-44)
  var area := Rect2(remoto.position+nome.position,nome.size)
  while ocupados.any(func(outra: Rect2) -> bool: return outra.grow(2).intersects(area)):
   nome.position.y-=12; area.position.y-=12
  ocupados.append(area)
