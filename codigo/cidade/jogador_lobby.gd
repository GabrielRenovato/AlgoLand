extends Node2D
## Representação social: reutiliza as poses Raven; nunca participa de colisão, combate ou saves.
const Visual := preload("res://codigo/dados/visual_ranking.gd")
const Profundidade := preload("res://codigo/globais/profundidade.gd")
const Corrida := preload("res://codigo/dados/corrida_raven.gd")
var identificador := ""
var apelido := "sem apelido"
var nome: Label
var corpo: Sprite2D
var _rota := PackedVector2Array()
var _velocidade := 0.0
var _direcao := 0
var _tempo := 0.0
var _aparencia := {}
var _ultimo_destino := Vector2(-1,-1)
var _ultima_amostra := -1.0
var _ultima_recepcao := -1.0
## Trechos curtos não passam pelo centro das células da grade: o avatar parado não pode "andar" até ele e voltar a cada consulta
const TRECHO_DIRETO := 14.0
const INTERVALO_CONSULTA_REMOTO := 0.55

class Corpo extends "res://codigo/jogador/heroi_raven.gd":
 var aparencia := {}
 func _ready() -> void:
  _jogador = Visual.criar_modelo(aparencia)
  add_child(_jogador)
  centered = false
  offset = Vector2(-40,-47)
  position.y = Profundidade.PES_JOGADOR
  hframes = 4
  vframes = 4
  texture_filter = TEXTURE_FILTER_NEAREST
  _montar_camadas()
  pose(false,0,0)
 func pose(correndo: bool, direcao: int, tempo: float) -> void:
  _direcao = direcao
  var acao := "correr" if correndo else "parado"
  _definir_grade(6 if correndo else 4)
  _aplicar_aparencia(acao)
  var coluna := Corrida.quadro(tempo,0.6) if correndo else int(fposmod(tempo,0.8)/0.2)
  frame = direcao*hframes+coluna
  for camada in _camadas: camada.frame = frame
  _atualizar_arma_costas(acao,direcao,coluna)
 func _process(_delta: float) -> void: pass
 func _exit_tree() -> void: pass

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

func atualizar(dados: Dictionary, visual: Dictionary, inicial := false) -> void:
 identificador = str(dados.id)
 apelido = str(dados.apelido).left(16)
 nome.text = apelido
 if visual != _aparencia:
  _aparencia = visual.duplicate(true)
  if is_instance_valid(corpo): remove_child(corpo); corpo.queue_free()
  corpo = Corpo.new()
  corpo.aparencia = _aparencia
  add_child(corpo)
 _direcao = clampi(int(dados.direcao),0,3)
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
 if is_instance_valid(corpo): corpo.pose(passo.length()>0.05,_direcao,_tempo)
 z_as_relative = false
 z_index = Profundidade.z_de(position.y+Profundidade.PES_JOGADOR)
