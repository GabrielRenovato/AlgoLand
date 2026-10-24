extends SceneTree
var falhas := 0
var ranking: Node
func _initialize() -> void: rodar.call_deferred()
func conferir(ok: bool, texto: String) -> void:
 print("OK " if ok else "FALHA ",texto)
 if not ok: falhas += 1
func esperar_envio() -> void:
 var limite := Time.get_ticks_msec()+6000
 await process_frame
 while ranking.ocupado() and Time.get_ticks_msec()<limite: await create_timer(0.01).timeout
 conferir(not ranking.ocupado(),"fila de envio conclui sem cadastro manual")
func rodar() -> void:
 assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
 await process_frame
 ranking = root.get_node("Ranking")
 ranking.url_servico = "http://127.0.0.1:"+OS.get_cmdline_user_args()[0]
 ranking.chave_servico = "teste_local"
 var intro := root.get_node("Introducao")
 intro.pular_prologo()
 intro.aula_arena = false
 var progresso := root.get_node("Progresso")
 progresso.iniciar_partida()
 change_scene_to_file("res://cenas/fendas/andar_01.tscn")
 for i in 30:
  await physics_frame
  await process_frame
 var jogador := current_scene.get_node("Jogador")
 jogador.set_physics_process(false)
 jogador.apelido = "João da Vila"
 progresso.registrar_onda_iniciada(1)
 progresso.registrar_onda_concluida(1,false,false)
 await esperar_envio()
 conferir(ranking._enviado==1 and ranking.apelido==jogador.apelido,"concluir andar registra automaticamente com apelido original e espaço")
 conferir(not ranking.visual_pendente.is_empty(),"vitória fotografa o personagem antes de sair da dungeon")
 jogador.apelido = ""
 progresso.registrar_onda_iniciada(2)
 jogador.morrer(true)
 await esperar_envio()
 conferir(jogador.estaMorto and not progresso.partida_ativa,"morte real encerra a partida")
 conferir(ranking._enviado==2 and ranking.apelido=="sem apelido","morte envia novo andar automaticamente e usa sem apelido")
 var ui := current_scene.get_node("Interface")
 conferir(ui._telas_abertas.has("fim_partida"),"resultado da morte abre normalmente")
 conferir(ui._telas.fim_partida.find_children("*","LineEdit",true,false).is_empty(),"fim de partida não pede cadastro ou nome")
 conferir(ui._telas.ranking.find_children("*","LineEdit",true,false).is_empty(),"consulta do pódio não pede cadastro ou nome")
 if DisplayServer.get_name()!="headless":
  root.mode = Window.MODE_WINDOWED
  for medida in [Vector2i(576,324),Vector2i(288,216)]:
   root.content_scale_size = medida
   root.size = medida*2
   for i in 20: await process_frame
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("/tmp/algoland-ranking-morte-%dx%d.png" % [medida.x,medida.y])

 ranking.enviar(3)
 ranking.enviar(4)
 await esperar_envio()
 conferir(ranking._enviado==4,"andar maior durante requisição é enviado imediatamente")
 paused = true
 ranking.visual_pendente.cabelo = 3
 ranking.sincronizar_visual()
 await esperar_envio()
 conferir(ranking._visual_enviado==JSON.stringify(ranking.visual_pendente),"envio continua com menus ou pausa abertos")
 paused = false
 print("RANKING AUTOMATICO: ",falhas," falhas")
 quit(1 if falhas else 0)
