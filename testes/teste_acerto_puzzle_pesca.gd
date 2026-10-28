extends SceneTree
## Compara o quadro mostrado com o julgamento do aperto, inclusive com FPS baixo.
var Minijogo: GDScript
class Dono extends Node2D:
 var eh_p2 := false
 func acao(nome: String) -> String: return "p2_"+nome if eh_p2 else nome
var falhas := 0
var verificacoes := 0
func _initialize(): rodar.call_deferred()
func conferir(nome: String, ok: bool):
 verificacoes += 1
 if not ok:
  falhas += 1
  print("FALHA ",nome)
func preparar(mini: Control, posicao: float, largura: float, base := 0.0):
 mini.ativo = true
 mini.check_ativo = true
 mini.pausa_antes = 0.0
 mini.progresso = 40.0
 mini._feedback.text = ""
 mini.tentativas = 0
 mini.otimos = 0
 mini.ponteiro_base = base
 mini.folga_zona = 2.0
 mini.tamanho_zona = largura
 mini.tamanho_otimo = largura*.35
 mini.percorrido = mini.folga_zona + posicao*largura
 mini.ponteiro_angulo = base+mini.percorrido
 mini.ponteiro_velocidade = TAU*1.5
 mini.ganho_otimo = 18.0
 mini.ganho_bom = 10.0
 mini.perda_erro = 13.0
 mini.modulate.a = 1.0
 mini.queue_redraw()
func rodar():
 if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"):quit(1);return
 Minijogo = load("res://codigo/pesca/minijogo_pesca.gd")
 AudioServer.set_bus_mute(0,true)
 root.get_node("Controle").usando_toque = true
 if not InputMap.has_action("p2_attack"): InputMap.add_action("p2_attack")
 Input.use_accumulated_input = false
 root.mode = Window.MODE_WINDOWED
 root.content_scale_size = Vector2i(576,324)
 root.size = Vector2i(1152,648)
 var dono = Dono.new()
 root.add_child(dono)
 var mini = Minijogo.new()
 root.add_child(mini)
 mini.jogador = dono
 mini.set_process(false)
 await process_frame
 # Um mesmo ponto da imagem deve ser julgado igual em qualquer FPS e jogador.
 for p2 in [false,true]:
  dono.eh_p2 = p2
  for fps in [15,20,30,60,120]:
   for largura in [.03,.30,1.0]:
    for posicao in [0.0,.17,.65,.9999,-.01,1.01]:
     Input.action_release(dono.acao("attack"))
     await process_frame
     preparar(mini,posicao,largura,6.0)
     var evento = InputEventAction.new()
     evento.action = dono.acao("attack")
     evento.pressed = true
     Input.parse_input_event(evento)
     Input.flush_buffered_events()
     mini._process(1.0/fps)
     var esperado = "ERROU" if posicao<0.0 or posicao>1.0 else ("OTIMO!" if posicao<=.35 else "BOM")
     conferir("P%d %d FPS zona %.2f ponto %.4f: %s, esperado %s"%[2 if p2 else 1,fps,largura,posicao,mini._feedback.text,esperado],mini._feedback.text==esperado)
 Input.action_release(dono.acao("attack"))
 dono.eh_p2 = false
 # Toque completo pelo botão real, após desenhar o ponteiro no fim da zona amarela.
 var controles = load("res://codigo/ui/controles_toque.gd").new()
 controles.set_meta("dono",dono)
 root.add_child(controles)
 controles.set_process(false)
 controles._modo_mouse = false
 var botao: Dictionary = controles._botao_da_acao(&"attack")
 await create_timer(.8).timeout
 for fps in [15,30,60]:
  Input.action_release("attack")
  await process_frame
  preparar(mini,.98,.30)
  if DisplayServer.get_name()!="headless":
   for i in 3: await process_frame
   await RenderingServer.frame_post_draw
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("/tmp/algoland-puzzle-pesca-antes-toque-%d.png"%fps)
  var toque = InputEventScreenTouch.new()
  toque.index = 9
  toque.position = controles.transform*botao.centro
  toque.pressed = true
  root.push_input(toque,true)
  toque = toque.duplicate()
  toque.pressed = false
  root.push_input(toque,true)
  Input.flush_buffered_events()
  mini._process(1.0/fps)
  conferir("toque curto real em %d FPS aceita ponteiro exibido"%fps,mini._feedback.text=="BOM" and mini.progresso==50.0)
  conferir("um toque gera um julgamento",mini.tentativas==1)
  mini._process(1.0/fps)
  conferir("mesmo toque não pontua duas vezes",mini.tentativas==1)
  if DisplayServer.get_name()!="headless":
   for i in 3: await process_frame
   await RenderingServer.frame_post_draw
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("/tmp/algoland-puzzle-pesca-depois-toque-%d.png"%fps)
 # Sem entrada, o tempo ainda avança e cobra erro depois da janela.
 await process_frame
 preparar(mini,1.1,.30)
 mini._process(.1)
 conferir("não apertar continua causando perda",mini._feedback.text=="ERROU" and mini.progresso==27.0)
 controles.queue_free()
 mini.queue_free()
 dono.queue_free()
 print("ACERTO PUZZLE PESCA: ",verificacoes," verificações; ",falhas," falhas")
 quit(1 if falhas else 0)
