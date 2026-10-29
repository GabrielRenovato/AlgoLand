extends SceneTree
var falhas := 0
var verificacoes := 0
const SAIDA := "/dev/shm/algoland-arvores-3d/"
func _initialize():rodar.call_deferred()
func conferir(ok: bool,msg: String):
 verificacoes+=1
 if not ok:falhas+=1;push_error(msg)
func esperar(n: int):
 for i in n:await process_frame
func rodar():
 assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
 assert(DisplayServer.get_name()!="headless")
 DirAccess.make_dir_recursive_absolute(SAIDA)
 root.get_node("Ranking").conexao_habilitada=false
 root.get_node("Introducao").pular_prologo()
 root.get_node("Transicao").hora_salva=12.
 change_scene_to_file("res://cenas/fazenda.tscn")
 await esperar(45)
 root.get_node("Transicao").limpar()
 var terreno=current_scene.get_node("Terrains")
 var arvores=terreno.get_node("ArvoresFazenda3D")
 var estacoes=terreno.get_node("Estacoes")
 var j=current_scene.get_node("Jogador")
 j.set_physics_process(false)
 j.global_position=Vector2(376,246)
 var vp:=SubViewport.new()
 vp.size=Vector2i(768,384);vp.transparent_bg=true;vp.world_2d=World2D.new()
 vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(vp)
 for tipo in 2:
  var sprite:=Sprite2D.new()
  sprite.centered=false;sprite.position=Vector2(tipo*384,0)
  sprite.texture=arvores.maquetes[tipo].viewport.get_texture()
  sprite.material=arvores.maquetes[tipo].acabamento
  sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
  vp.add_child(sprite)
 conferir(arvores.maquetes.size()==2,"Duas maquetes compartilhadas, sem viewport por árvore")
 conferir(arvores.registros.size()>30,"Árvores adultas do mapa integradas")
 for r in arvores.registros:
  var s: Sprite2D=r.sprite
  conferir(s.texture==arvores.maquetes[r.tipo].viewport.get_texture(),"Espécie usa modelo correspondente")
  conferir((s.offset+arvores.maquetes[r.tipo].camera.unproject_position(Vector3.ZERO)).length()<.01,"Raiz no pivô original")
 for e in 4:
  estacoes.estacao_do_mapa=e;estacoes.definir_estacao(e,true)
  await esperar(6)
  conferir(arvores.estacao==e,"Troca integrada de estação")
  for tipo in 2:
   var dados: Dictionary=arvores.maquetes[tipo]
   for copa in dados.copas:
    conferir(not copa.mesh is SphereMesh,"Folhagem é desenhada com folhas, sem bolas")
    conferir(copa.visible==(tipo==1 or e!=3),"Carvalho perde folhas e pinheiro mantém agulhas no inverno")
   var img: Image=dados.viewport.get_texture().get_image()
   var area: Rect2i=img.get_used_rect()
   conferir(Rect2i(3,3,378,378).encloses(area),"Copa e raízes sem cortes na captura")
  await RenderingServer.frame_post_draw
  vp.get_texture().get_image().save_png(SAIDA+"estacao_%d.png"%e)
  root.get_texture().get_image().save_png(SAIDA+"mapa_%d.png"%e)
 # O F3 deve restaurar o modo 3D após comparar com o Tiny.
 var tiny=current_scene.get_node("ComparacaoTiny")
 tiny.definir_ativo(true);await esperar(3)
 tiny.definir_ativo(false);await esperar(4)
 for r in arvores.registros:
  conferir(r.sprite.texture==arvores.maquetes[r.tipo].viewport.get_texture(),"Retorno do Tiny restaura maquete")
 # Queda conserva a altura física do corte apesar da grade de renderização 3x.
 var extracao=terreno.get_node("Extracao")
 for recurso in extracao.recursos:
  if recurso.tipo!="arvore":continue
  var original: Sprite2D=extracao._sprite(recurso)
  if not original.visible:continue
  extracao._derrubar(recurso,recurso.pos-Vector2(20,0))
  var queda=arvores.ativas.get(original)
  conferir(queda!=null and queda.cortada,"Queda usa corpo 3D físico")
  conferir(queda.corpo is RigidBody3D,"Tronco tem massa e colisão real")
  conferir(not original.visible,"Árvore estática sai durante queda")
  break
 print("ÁRVORES 3D: ",verificacoes," verificações; quatro estações, folhagem, pivôs, Tiny e queda; falhas=",falhas)
 quit(1 if falhas else 0)
