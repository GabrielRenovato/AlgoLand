extends SceneTree
var falhas := 0
func _initialize() -> void: rodar.call_deferred()
func conferir(ok: bool,texto: String) -> void:
 print("OK " if ok else "FALHA ",texto)
 if not ok: falhas+=1
func rodar() -> void:
 assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
 root.get_node("Ranking").conexao_habilitada=false
 root.get_node("Introducao").pular_prologo()
 root.get_node("Transicao").hora_salva=12
 root.mode=Window.MODE_WINDOWED
 root.content_scale_size=Vector2i(576,324)
 root.size=Vector2i(1152,648)
 change_scene_to_file("res://cenas/cidade.tscn")
 for i in 35: await process_frame
 var npc: Node2D=current_scene.moradores.values()[0]
 for outro in current_scene.moradores.values(): outro.set_physics_process(false)
 npc.visible=true
 npc.position=Vector2(400,320)
 for hud in get_nodes_in_group("hud"): hud.hide()
 var jogador=current_scene.get_node("Jogador")
 jogador.set_physics_process(false)
 var camera: Camera2D=jogador.camera
 camera.set_as_top_level(true)
 camera.position_smoothing_enabled=false
 camera.limit_left=-100000
 camera.limit_right=100000
 camera.limit_top=-100000
 camera.limit_bottom=100000
 camera.global_position=Vector2(400,320)
 camera.force_update_scroll()
 npc.dizer("A cidade esta cheia de novidades!",12.0)
 var pontos: Array[Vector2]=[]
 var ancora := Vector2.INF
 for quadro in 60:
  camera.global_position=Vector2(400+quadro*0.7,320+quadro*0.3)
  camera.force_update_scroll()
  await process_frame
  await process_frame
  var transformacao: Transform2D=npc.get_global_transform_with_canvas()
  var fala: Label=npc._balao
  pontos.append(transformacao*fala.position-transformacao.origin)
  if quadro==4: ancora=fala.global_position-npc.global_position
  if quadro%10==0 and DisplayServer.get_name()!="headless":
   RenderingServer.force_draw()
   root.get_texture().get_image().save_png("/tmp/algoland-balao-corrida-%d.png"%quadro)
 var maior:=0.0
 for i in range(1,pontos.size()): maior=maxf(maior,pontos[i].distance_to(pontos[i-1]))
 conferir(maior<1.5,"balão mantém apoio no NPC com câmera em movimento; maior variação "+str(maior))
 for deslocamento in [Vector2(2000,0),Vector2(-2000,0),Vector2(0,2000),Vector2(0,-2000)]:
  camera.global_position=Vector2(400,320)+deslocamento
  camera.force_update_scroll()
  for i in 4: await process_frame
  conferir((npc._balao.global_position-npc.global_position).is_equal_approx(ancora),"balão continua preso ao NPC fora da tela "+str(deslocamento))
  var area: Rect2=npc._balao.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,npc._balao.size)
  conferir(not root.get_visible_rect().intersects(area),"balão não fica preso na borda da câmera")
 camera.global_position=Vector2(400,320)
 camera.force_update_scroll()
 var antes: Vector2=npc._balao.global_position
 npc.position+=Vector2(48,0)
 for i in 4: await process_frame
 conferir((npc._balao.global_position-antes).is_equal_approx(Vector2(48,0)),"balão acompanha somente o morador")
 root.content_scale_size=Vector2i(288,216)
 for i in 4: await process_frame
 conferir((npc._balao.global_position-npc.global_position).is_equal_approx(ancora),"tela pequena não reposiciona a fala no mundo")
 print("BALAO CIDADE: ",falhas," falhas")
 quit(1 if falhas else 0)
