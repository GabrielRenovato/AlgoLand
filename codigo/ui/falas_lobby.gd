extends Control
## Balões do chat na vista de cada jogador, com o acabamento das falas dos moradores.
const Fonte := preload("res://assets/ui/Planes_ValMore.ttf")
const Escala := preload("res://codigo/ui/escala_interface.gd")
var sessao: Node
var _falas := {}

func _ready() -> void:
 mouse_filter = MOUSE_FILTER_IGNORE
 z_index = 950

func mostrar(id: String, texto: String) -> void:
 if _falas.has(id): _falas[id].rotulo.queue_free()
 var rotulo := Label.new()
 rotulo.mouse_filter = MOUSE_FILTER_IGNORE
 rotulo.texture_filter = TEXTURE_FILTER_NEAREST
 rotulo.add_theme_font_override("font",Fonte)
 rotulo.add_theme_font_size_override("font_size",8)
 rotulo.add_theme_color_override("font_color",Color("493629"))
 rotulo.add_theme_constant_override("line_spacing",-5)
 rotulo.add_theme_stylebox_override("normal",preload("res://codigo/ui/estilo_interface.gd").painel(true,10.0))
 rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 rotulo.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
 rotulo.text = texto.left(160)
 var cauda := Polygon2D.new()
 cauda.polygon = PackedVector2Array([Vector2.ZERO,Vector2(8,0),Vector2(4,5)])
 cauda.color = Color("804b20")
 rotulo.add_child(cauda)
 var miolo := Polygon2D.new()
 miolo.polygon = PackedVector2Array([Vector2(1,0),Vector2(7,0),Vector2(4,3)])
 miolo.color = Color("eed1ab")
 cauda.add_child(miolo)
 add_child(rotulo)
 _falas[id] = {"rotulo":rotulo,"cauda":cauda,"tempo":clampf(3.5+texto.length()/16.0,3.5,14.0),"inicio":Time.get_ticks_msec()}

func limpar() -> void:
 for fala in _falas.values(): fala.rotulo.queue_free()
 _falas.clear()

func _alvo(id: String) -> Node2D:
 if not is_instance_valid(sessao): return null
 return sessao.get_parent().alvo_da_fala(id, get_viewport().world_2d)

func _process(delta: float) -> void:
 if not is_instance_valid(sessao) or not sessao.online or not sessao.conectado:
  limpar()
  return
 # Interfaces são diferentes no cooperativo: cada balão usa a câmera e a escala da própria vista.
 var escala := Escala.fator(self)
 var tela := get_viewport().get_visible_rect().size/escala
 var interior := Rect2(Vector2.ONE*8,tela-Vector2.ONE*16)
 var ocupados: Array[Rect2] = []
 for grupo in ["hud","toque_hud"]:
  for no in get_tree().get_nodes_in_group(grupo):
   if no.get_viewport()!=get_viewport(): continue
   if no is Control and no.is_visible_in_tree(): ocupados.append(_area_controle(no,escala))
   elif grupo=="hud":
    for nome in ["Status","CantoDireito","ObjetivoPrincipal","PainelChefe","FaixaBanner"]:
     var controle:=no.get_node_or_null(nome) as Control
     if controle!=null and controle.is_visible_in_tree(): ocupados.append(_area_controle(controle,escala))
 for hud in get_tree().get_nodes_in_group("hud"):
  if hud.get_viewport()!=get_viewport(): continue
  var tutorial:=hud.get_node_or_null("MiniTutorial")
  if tutorial!=null and tutorial.is_visible_in_tree(): ocupados.append(_area_controle(tutorial._painel,escala))
  if is_instance_valid(hud.barra_armas): ocupados.append(_area_controle(hud.barra_armas._painel,escala))
 for controles in get_tree().get_nodes_in_group("controles_toque"):
  if controles.get_viewport()!=get_viewport() or not controles._ativo: continue
  for botao: Dictionary in controles._botoes:
   if botao.visivel: ocupados.append(Rect2((botao.centro-Vector2.ONE*botao.raio)/escala,Vector2.ONE*botao.raio*2/escala))
 var ordem := _falas.keys()
 ordem.sort_custom(func(a: String,b: String) -> bool: return int(_falas[a].inicio)>int(_falas[b].inicio))
 for id in ordem:
  var fala: Dictionary = _falas[id]
  fala.tempo-=delta
  if fala.tempo<=0:
   fala.rotulo.queue_free(); _falas.erase(id); continue
  var alvo := _alvo(id)
  var rotulo: Label = fala.rotulo
  rotulo.visible = alvo!=null and alvo.is_visible_in_tree()
  if not rotulo.visible: continue
  var origem := (get_viewport().canvas_transform*alvo.global_position)/escala
  if not interior.has_point(origem): rotulo.hide(); continue
  rotulo.size.x = minf(136,minf(tela.x-16,Fonte.get_string_size(rotulo.text,HORIZONTAL_ALIGNMENT_LEFT,-1,8).x+20))
  rotulo.max_lines_visible = -1
  rotulo.lines_skipped = 0
  var total_linhas := maxi(1,rotulo.get_line_count())
  rotulo.max_lines_visible = 3
  rotulo.lines_skipped = mini(int((total_linhas-1)/3)*3,int((Time.get_ticks_msec()-int(fala.inicio))/1600.0)*3)
  rotulo.size.y = rotulo.get_combined_minimum_size().y
  var desejado := origem-Vector2(rotulo.size.x/2,54/escala+rotulo.size.y)
  var ponto := _encaixar(rotulo.size,desejado,interior,ocupados)
  if not ponto.is_finite():
   # Como nos NPCs, textos extensos passam uma linha por vez quando o espaço é estreito.
   var linhas := maxi(1,rotulo.get_line_count())
   rotulo.max_lines_visible = 1
   rotulo.size.x = minf(104,rotulo.size.x)
   rotulo.lines_skipped = mini(linhas-1,int((Time.get_ticks_msec()-int(fala.inicio))/1000.0/0.9))
   rotulo.size.y = rotulo.get_combined_minimum_size().y
   ponto = _encaixar(rotulo.size,desejado,interior,ocupados)
  if not ponto.is_finite(): rotulo.hide(); continue
  rotulo.position = ponto.round()
  rotulo.modulate.a = minf(1.0,fala.tempo/0.25)
  var embaixo := ponto.y>origem.y
  fala.cauda.scale.y = -1 if embaixo else 1
  fala.cauda.position = Vector2(clampf(origem.x-ponto.x-4,10,rotulo.size.x-18),1 if embaixo else rotulo.size.y-1)
  fala.cauda.visible = origem.x>=ponto.x and origem.x<=ponto.x+rotulo.size.x
  ocupados.append(Rect2(ponto,rotulo.size).grow(4))

func _area_controle(controle: Control, escala: float) -> Rect2:
 var area := controle.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,controle.size)
 return Rect2(area.position/escala,area.size/escala)

func _encaixar(tamanho: Vector2, desejado: Vector2, interior: Rect2, obstaculos: Array[Rect2]) -> Vector2:
 var inicio := desejado.clamp(interior.position,interior.end-tamanho)
 var primeira := Rect2(inicio,tamanho)
 if interior.encloses(primeira) and not obstaculos.any(func(area: Rect2) -> bool: return area.intersects(primeira)): return inicio
 var xs := [inicio.x,interior.position.x,interior.end.x-tamanho.x]
 var ys := [inicio.y,interior.position.y,interior.end.y-tamanho.y]
 for area in obstaculos:
  xs.append(clampf(area.position.x-tamanho.x-4,interior.position.x,interior.end.x-tamanho.x))
  xs.append(clampf(area.end.x+4,interior.position.x,interior.end.x-tamanho.x))
  ys.append(clampf(area.position.y-tamanho.y-4,interior.position.y,interior.end.y-tamanho.y))
  ys.append(clampf(area.end.y+4,interior.position.y,interior.end.y-tamanho.y))
 var melhor := Vector2.INF
 var distancia := INF
 for y in ys:
  for x in xs:
   var ponto := Vector2(x,y)
   var caixa := Rect2(ponto,tamanho)
   var custo := ponto.distance_squared_to(desejado)
   if custo<distancia and interior.encloses(caixa) and not obstaculos.any(func(area: Rect2) -> bool: return area.intersects(caixa)):
    melhor=ponto; distancia=custo
 return melhor
