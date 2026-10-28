extends SceneTree
## Exercita o caminho de carga Android com cidade, andar e retorno reais.
var falhas := 0
var aparicoes := 0
func _initialize(): rodar.call_deferred()
func conferir(nome: String, ok: bool):
 print("OK " if ok else "FALHA ", nome)
 if not ok: falhas += 1
func rodar():
 if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"):
  quit(1)
  return
 root.get_node("Ranking").conexao_habilitada = false
 root.get_node("Introducao").pular_prologo()
 root.get_node("Transicao").hora_salva = 12.0
 var transicao = root.get_node("Transicao")
 transicao.carregar_na_thread_principal = true
 transicao._carregador.visibility_changed.connect(func():
  if transicao._carregador.visible: aparicoes += 1)
 var erro: Error = await transicao.carregar_cena("res://cenas/cidade.tscn")
 conferir("cidade abre pelo caminho Android", erro == OK)
 for destino in ["res://cenas/fendas/andar_01.tscn", "res://cenas/cidade.tscn", "res://cenas/fendas/andar_01.tscn"]:
  await transicao.ir_para(destino,"portal")
  conferir("destino carregado: " + destino,current_scene.scene_file_path == destino)
  conferir("fade clareia e libera troca", not transicao.esta_escuro() and not transicao.ocupada)
  conferir("painel de carga fecha",not transicao._carregando and not transicao._carregador.visible)
  var jogador = current_scene.get_node("Jogador")
  conferir("jogador e camera presentes",is_instance_valid(jogador) and jogador.camera.is_current())
  if destino.contains("andar_01"):
   var terreno = current_scene.get_node("Terrains")
   conferir("chao e trilha renderizaveis",terreno.has_node("FlorestaDetalhada") and terreno.get_node("FlorestaDetalhada")._solo.get_shader_parameter("distribuicao") != null)
   if DisplayServer.get_name() != "headless":
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("/tmp/algoland-andar1-android-carga.png")
 conferir("todas as cargas mostraram painel",aparicoes == 4)
 print("ENTRADA ANDAR ANDROID: ",falhas," falhas")
 quit(1 if falhas else 0)
