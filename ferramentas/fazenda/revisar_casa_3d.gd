extends SceneTree
var falhas := 0
func _initialize():rodar.call_deferred()
func conferir(ok: bool,mensagem: String):
 if not ok:falhas+=1;push_error(mensagem)
func rodar():
 assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
 root.get_node("Ranking").conexao_habilitada=false
 root.get_node("Introducao").pular_prologo()
 root.get_node("Transicao").hora_salva=12.
 change_scene_to_file("res://cenas/fazenda.tscn")
 for i in 45:await process_frame
 root.get_node("Transicao").limpar()
 var casa=current_scene.get_node("Terrains/Objetos3D/Casa")
 var j=current_scene.get_node("Jogador")
 j.set_physics_process(false)
 j.global_position=casa.global_position+Vector2(0,30)
 var terreno=current_scene.get_node("Terrains")
 var estacoes=terreno.get_node("Estacoes")
 conferir(casa.modelo.get_child_count()>100,"Casa usa geometria 3D real")
 var fachada=casa.get_node("Fachada")
 conferir(fachada.texture_filter==CanvasItem.TEXTURE_FILTER_NEAREST,"Pixels sem suavização")
 conferir(casa.viewport_3d.msaa_3d==Viewport.MSAA_DISABLED,"Grade sem antialiasing")
 conferir(fachada.material is ShaderMaterial,"Acabamento pixel aplicado sobre o volume 3D")
 var soleira: Vector2=casa.camera_3d.unproject_position(Vector3(0,0,1.05))
 conferir(((fachada.offset+soleira)*fachada.scale).length()<.01,"Soleira mantém pivô da porta")
 for m in casa.modelo.get_children():
  if not m is MeshInstance3D:continue
  var caixa: AABB=m.get_aabb()
  for canto in 8:
   var ponto: Vector3=m.transform*caixa.get_endpoint(canto)
   var tela: Vector2=casa.camera_3d.unproject_position(ponto)
   conferir(Rect2(Vector2(8,8),Vector2(casa.viewport_3d.size)-Vector2(16,16)).has_point(tela),"Modelo inteiro cabe na captura: "+str(m.name))
 conferir(current_scene.get_node("Terrains/PortaCasa").cena_destino=="res://cenas/casa.tscn","Entrada preservada")
 for e in 4:
  estacoes.estacao_do_mapa=e
  estacoes.definir_estacao(e,true)
  for i in 5:await process_frame
  conferir(casa.estacao_3d==e,"Estação integrada "+str(e))
  await RenderingServer.frame_post_draw
  casa.viewport_3d.get_texture().get_image().save_png("/dev/shm/casa3d-%d.png"%e)
  root.get_texture().get_image().save_png("/dev/shm/casa3d-mapa-%d.png"%e)
 print("CASA 3D: quatro estações, geometria e porta; falhas=",falhas)
 quit(1 if falhas else 0)
