extends Node2D
## Representação social: reutiliza o personagem 3D; nunca participa de colisão, combate ou saves.
const Visual := preload("res://codigo/dados/visual_ranking.gd")
const Profundidade := preload("res://codigo/globais/profundidade.gd")
var identificador := ""
var apelido := "sem apelido"
var nome: Label
var corpo: Node2D
var _rota := PackedVector2Array()
var _velocidade := 0.0
var _direcao := 0
var _tempo := 0.0
var _aparencia := {}
var _ultimo_destino := Vector2(-1,-1)
var _ultima_amostra := -1.0
var _ultima_recepcao := -1.0
## Ação em curso (golpe, disparo ou esquiva) tocada a partir do aviso do servidor; pesca vem do estado (quadro 0 a 3, -1 fora dela)
var _acao := ""
var _acao_inicio := 0.0
var _acao_duracao := 0.0
var _acao_combo := 0
var _acao_direcao := 0
var _pesca := -1
const DURACAO_DISPARO_ARCO: Array[float] = [0.18, 0.1, 0.1, 0.1, 0.4, 0.05, 0.05, 0.1]
const COLUNA_DISPARO_ARCO := [0,0,1,1,1,2,3,3]
## Trechos curtos não passam pelo centro das células da grade: o avatar parado não pode "andar" até ele e voltar a cada consulta
const TRECHO_DIRETO := 14.0
## Menor intervalo entre amostras (o servidor próprio envia a 4 Hz; o banco, a cada 0,55 s)
const INTERVALO_CONSULTA_REMOTO := 0.2

class Corpo extends "res://codigo/jogador/representacao_heroi_3d.gd":
 func _ready() -> void:
  super._ready()
  position.y = Profundidade.PES_JOGADOR

func _ready() -> void:
 nome = Label.new()
 nome.mouse_filter = Control.MOUSE_FILTER_IGNORE
 nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 nome.add_theme_font_override("font",preload("res://assets/ui/Planes_ValMore.ttf"))
 nome.add_theme_font_size_override("font_size",6)
 nome.add_theme_color_override("font_color",Color("bce8ff"))
 nome.add_theme_color_override("font_outline_color",Color("20252d"))
 nome.add_theme_constant_override("outline_size",2)
 nome.size = Vector2(88,10)
 nome.position = Vector2(-44,-44)
 nome.z_as_relative = false
 nome.z_index = 900
 add_child(nome)

func _encaixar_nome() -> void:
 if not is_instance_valid(corpo): return
 nome.position = Vector2(-nome.size.x/2.0,corpo.position.y+corpo.topo_aparente()-nome.size.y-4.0)

func atualizar(dados: Dictionary, visual: Dictionary, inicial := false) -> void:
 identificador = str(dados.id)
 apelido = str(dados.apelido).left(16)
 nome.text = apelido
 if visual != _aparencia or not is_instance_valid(corpo):
  _aparencia = visual.duplicate(true)
  if is_instance_valid(corpo): remove_child(corpo); corpo.queue_free()
  corpo = Corpo.new()
  corpo.aparencia = _aparencia
  add_child(corpo)
  corpo.renderizado.connect(_encaixar_nome)
  _encaixar_nome()
 _direcao = clampi(int(dados.direcao),0,3)
 _pesca = clampi(int(dados.get("pesca",-1)),-1,3)
 var agora := Time.get_ticks_usec()/1000000.0
 var amostra := float(dados.get("instante",agora))
 if _ultima_amostra>=0 and amostra<=_ultima_amostra: return
 var intervalo := INTERVALO_CONSULTA_REMOTO
 if _ultima_amostra>=0:
  intervalo = maxf(INTERVALO_CONSULTA_REMOTO,amostra-_ultima_amostra if dados.has("instante") else agora-_ultima_recepcao)
 _ultima_amostra = amostra
 _ultima_recepcao = agora
 var destino := Vector2(float(dados.x),float(dados.y))
 var mesmo_destino := destino.distance_to(_ultimo_destino)<0.5
 _ultimo_destino = destino
 if inicial or position.distance_to(destino)>240:
  position = destino
  _rota.clear()
 elif mesmo_destino:
  # Uma posição repetida não reinicia nem acelera o trecho ainda em reprodução.
  if _rota.is_empty(): _velocidade = 0.0
 elif position.distance_to(destino)<TRECHO_DIRETO:
  _rota = PackedVector2Array([destino])
  _velocidade = position.distance_to(destino)/intervalo
 else:
  var cidade := get_parent().get_parent()
  # Cidade e praia têm grade de navegação; na floresta o avatar segue em linha reta até a nova posição
  _rota = cidade.caminho_entre(position,destino) if cidade.has_method("caminho_entre") else PackedVector2Array([destino])
  var comprimento := 0.0
  var anterior := position
  for ponto in _rota: comprimento+=anterior.distance_to(ponto); anterior=ponto
  _velocidade = comprimento/intervalo

## Aviso do servidor: o dono deste avatar acabou de atacar, disparar ou esquivar
func iniciar_acao(dados: Dictionary) -> void:
 _acao = str(dados.get("acao",""))
 _acao_inicio = Time.get_ticks_usec()/1000000.0
 _acao_duracao = clampf(float(dados.get("duracao",0.3)),0.05,2.0)
 if _acao == "arco": _acao_duracao = 0.0
 if _acao == "arco":
  var escala := clampf(float(dados.get("duracao",1.0)),0.2,2.0)
  for passo in DURACAO_DISPARO_ARCO: _acao_duracao += passo*escala
  _acao_combo = int(escala*1000.0)
 else:
  _acao_combo = clampi(int(dados.get("combo",0)),0,3)
 _acao_direcao = clampi(int(dados.get("direcao",_direcao)),0,3)
 _direcao = _acao_direcao

func _pose_da_acao(decorrido: float) -> void:
 var progresso := clampf(decorrido/maxf(_acao_duracao,0.01),0.0,0.999)
 match _acao:
  "ataque": corpo.pose_acao(corpo.nome_do_golpe(_acao_combo),int(4.0*progresso),_acao_direcao,progresso)
  "dash": corpo.pose_acao("esquiva",int(4.0*progresso),_acao_direcao,progresso)
  "arco":
   var escala := float(_acao_combo)/1000.0
   var restante := decorrido
   var indice := DURACAO_DISPARO_ARCO.size()-1
   for i in DURACAO_DISPARO_ARCO.size():
    if restante < DURACAO_DISPARO_ARCO[i]*escala:
     indice = i
     break
    restante -= DURACAO_DISPARO_ARCO[i]*escala
   corpo.pose_acao("arco",COLUNA_DISPARO_ARCO[indice],_acao_direcao,progresso)

func _process(delta: float) -> void:
 var antes := position
 var restante := _velocidade*delta
 while not _rota.is_empty():
  var distancia := position.distance_to(_rota[0])
  if distancia>restante:
   position = position.move_toward(_rota[0],restante)
   break
  position = _rota[0]
  _rota.remove_at(0)
  restante -= distancia
 var passo := position-antes
 if passo.length()>0.05:
  _direcao = (1 if passo.x>0 else 3) if absf(passo.x)>absf(passo.y) else (0 if passo.y>0 else 2)
 _tempo += delta
 var agora := Time.get_ticks_usec()/1000000.0
 if not _acao.is_empty() and agora-_acao_inicio>=_acao_duracao: _acao = ""
 if is_instance_valid(corpo):
  if not _acao.is_empty(): _pose_da_acao(agora-_acao_inicio)
  elif _pesca>=0 and passo.length()<=0.05: corpo.pose_pesca(_pesca,_direcao)
  else: corpo.pose(passo.length()>0.05,_direcao,_tempo)
 z_as_relative = false
 z_index = Profundidade.z_de(position.y+Profundidade.PES_JOGADOR)
