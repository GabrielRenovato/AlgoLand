extends Node2D
## Representação social: reutiliza o personagem 3D; nunca participa de colisão, combate ou saves.
const Visual := preload("res://codigo/dados/visual_ranking.gd")
const Profundidade := preload("res://codigo/globais/profundidade.gd")
var identificador := ""
var apelido := "sem apelido"
var nome: Label
var corpo: Node2D
var _direcao := 0
var _tempo := 0.0
var _aparencia := {}
var _ultima_amostra := -1.0
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
## Interpolação com atraso (como no duelo): o avatar é desenhado um pouco no passado, entre duas
## posições reais, no relógio do servidor ("instante"). Sem isso, cada pacote fora do ritmo parava
## ou acelerava o boneco. O atraso acompanha o ritmo de envio (10 Hz no servidor próprio, 0,55 s no banco).
const ATRASO_MIN := 0.15
const ATRASO_MAX := 0.9
var _amostras: Array = [] # [instante_servidor, posição]
var _desvio_relogio := INF # relógio local - relógio do servidor (o menor visto)
var _intervalo_medio := 0.1

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
 _desvio_relogio = minf(_desvio_relogio, agora-amostra)
 var destino := Vector2(float(dados.x),float(dados.y))
 if inicial or _amostras.is_empty() or position.distance_to(destino)>240:
  position = destino
  _amostras = [[amostra,destino]]
  _ultima_amostra = amostra
  return
 var anterior: Array = _amostras.back()
 var lacuna := amostra-float(anterior[0])
 var andou := (anterior[1] as Vector2).distance_to(destino)>0.5
 if andou: _intervalo_medio = lerpf(_intervalo_medio, clampf(lacuna,0.03,1.0), 0.2)
 # Parado (só manda sinal de vida a cada 2 s) e voltou a andar: ficou no lugar até um intervalo antes.
 if andou and lacuna>maxf(0.35,_intervalo_medio*2.5):
  _amostras.append([amostra-_intervalo_medio, anterior[1]])
  anterior = _amostras.back()
 # Salto longo (pacote perdido): passa pelos pontos da grade para não atravessar paredes.
 if andou and (anterior[1] as Vector2).distance_to(destino)>TRECHO_DIRETO*3:
  var cidade := get_parent().get_parent()
  if cidade.has_method("caminho_entre"):
   var rota: PackedVector2Array = cidade.caminho_entre(anterior[1],destino)
   var total := 0.0
   var ponto_anterior: Vector2 = anterior[1]
   for ponto in rota: total+=ponto_anterior.distance_to(ponto); ponto_anterior=ponto
   var feito := 0.0
   ponto_anterior = anterior[1]
   var inicio := float(anterior[0])
   for k in rota.size()-1:
    feito += ponto_anterior.distance_to(rota[k]); ponto_anterior = rota[k]
    _amostras.append([lerpf(inicio,amostra,feito/maxf(total,0.001)), rota[k]])
 _amostras.append([amostra,destino])
 while _amostras.size()>24: _amostras.pop_front()
 _ultima_amostra = amostra

func _posicao_no_tempo(t: float) -> Vector2:
 var primeira: Array = _amostras[0]
 if t<=float(primeira[0]): return primeira[1]
 for k in range(1,_amostras.size()):
  var b: Array = _amostras[k]
  if t<=float(b[0]):
   var a: Array = _amostras[k-1]
   return (a[1] as Vector2).lerp(b[1],(t-float(a[0]))/maxf(float(b[0])-float(a[0]),0.001))
 return (_amostras.back() as Array)[1]

## Aviso do servidor: o dono deste avatar acabou de atacar, disparar ou esquivar
func iniciar_acao(dados: Dictionary) -> void:
 if str(dados.get("acao","")) == "peixe":
  _mostrar_peixe(str(dados.get("peixe","")), clampi(int(dados.get("combo",0)),0,3))
  return
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

## Peixe que o outro jogador acabou de pescar: ícone pulando sobre a cabeça e o nome, por ~2,6 s.
## Nome na cor da raridade; a qualidade (prata/ouro/irídio) aparece junto, na cor dela.
const Peixes := preload("res://codigo/pesca/peixes.gd")
const Qualidade := preload("res://codigo/pesca/qualidade_peixe.gd")
const Raridades := preload("res://codigo/dados/raridades.gd")
const FONTE_PEIXE := preload("res://assets/ui/Planes_ValMore.ttf")
var _peixe_mostrado: Node2D

func _mostrar_peixe(id: String, qualidade: int) -> void:
 if id.is_empty() or not Peixes.DADOS.has(id) and id != "pedra_vara": return
 if is_instance_valid(_peixe_mostrado): _peixe_mostrado.queue_free()
 var caixa := Node2D.new()
 # Logo acima do nome do jogador.
 caixa.position = Vector2(0, nome.position.y - 10)
 caixa.z_as_relative = false
 caixa.z_index = 4000
 add_child(caixa)
 _peixe_mostrado = caixa
 var icone := Sprite2D.new()
 icone.texture = Peixes.icone(id)
 icone.scale = Vector2.ONE * (16.0 / maxf(1.0, float(icone.texture.get_width()))) if icone.texture else Vector2.ONE
 caixa.add_child(icone)
 var texto := Label.new()
 texto.text = Peixes.nome(id).to_upper() + ("" if qualidade == 0 else " " + Qualidade.NOMES[qualidade])
 texto.add_theme_font_override("font", FONTE_PEIXE)
 texto.add_theme_font_size_override("font_size", 6)
 texto.add_theme_color_override("font_color", Raridades.cor(Peixes.raridade(id)) if qualidade == 0 else Qualidade.CORES[qualidade])
 texto.add_theme_color_override("font_outline_color", Color(0.13, 0.08, 0.14))
 texto.add_theme_constant_override("outline_size", 2)
 texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 texto.size = Vector2(120, 10)
 texto.position = Vector2(-60, -20)
 caixa.add_child(texto)
 var anim := caixa.create_tween()
 anim.tween_property(icone, "position:y", -6.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
 anim.tween_property(icone, "position:y", 0.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
 anim.tween_property(icone, "position:y", -3.0, 0.12)
 anim.tween_property(icone, "position:y", 0.0, 0.12)
 anim.tween_interval(1.8)
 anim.tween_property(caixa, "modulate:a", 0.0, 0.25)
 anim.tween_callback(caixa.queue_free)

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
 if not _amostras.is_empty() and _desvio_relogio<INF:
  var atraso := clampf(_intervalo_medio*1.8,ATRASO_MIN,ATRASO_MAX)
  position = _posicao_no_tempo(Time.get_ticks_usec()/1000000.0-_desvio_relogio-atraso)
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
