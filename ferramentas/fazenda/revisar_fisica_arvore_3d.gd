extends SceneTree
const SAIDA := "/dev/shm/algoland-fisica-arvore/"
var falhas := 0
var verificacoes := 0
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
 for arquivo in DirAccess.get_files_at(SAIDA):
  if arquivo.begins_with("queda_"):DirAccess.remove_absolute(SAIDA+arquivo)
 root.get_node("Ranking").conexao_habilitada=false
 root.get_node("Fazenda").apagar()
 root.get_node("Introducao").pular_prologo()
 root.get_node("Transicao").hora_salva=12.
 change_scene_to_file("res://cenas/fazenda.tscn")
 await esperar(40)
 root.get_node("Transicao").limpar()
 var terreno=current_scene.get_node("Terrains")
 var e := 0
 var lado := 1
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--estacao="):e=int(arg.get_slice("=",1))
  if arg.begins_with("--lado="):lado=int(arg.get_slice("=",1))
 var estacoes=terreno.get_node("Estacoes")
 estacoes.estacao_do_mapa=e;estacoes.definir_estacao(e,true)
 await esperar(5)
 var arvores=terreno.get_node("ArvoresFazenda3D")
 var extracao=terreno.get_node("Extracao")
 var j=current_scene.get_node("Jogador")
 j.set_physics_process(false)
 var alvo := {}
 for recurso in extracao.recursos:
  if recurso.tipo=="arvore" and extracao._sprite(recurso).visible:
   alvo=recurso;break
 conferir(not alvo.is_empty(),"Árvore adulta disponível")
 if alvo.is_empty():quit(1);return
 var original: Sprite2D=extracao._sprite(alvo)
 j.global_position=terreno.to_global(alvo.pos-Vector2(lado*22,0))
 var obstaculo=terreno.get_node(alvo.obstaculo)
 var poligono: PackedVector2Array=obstaculo.polygon.duplicate()
 extracao.impacto("machado",terreno.to_global(alvo.pos),1,j.global_position)
 await create_timer(2.5).timeout
 conferir(not arvores.ativas.has(original) and original.visible,"Golpe isolado amortece e restaura árvore parada")
 extracao._vida.erase(alvo.chave)
 extracao.impacto("machado",terreno.to_global(alvo.pos),1,j.global_position)
 await create_timer(.15).timeout
 var ativa=arvores.ativas.get(original)
 conferir(ativa!=null,"Golpe ativa simulação individual")
 if ativa==null:quit(1);return
 conferir(ativa.corpo is RigidBody3D and ativa.dobradica is HingeJoint3D,"Corpo com massa preso às fibras da base")
 conferir(ativa.direcao.x*lado>.9,"Direção usa a origem do jogador que golpeou")
 conferir(ativa.corpo.angular_velocity.length()>.001,"Impulso do machado altera velocidade angular")
 conferir(not ativa.cortada and not original.visible,"Árvore oscila em 3D antes de ser derrubada")
 var copia_original: Texture2D=arvores.maquetes[0].viewport.get_texture()
 var tela:=SubViewport.new();tela.size=Vector2i(768,768);tela.transparent_bg=true;tela.world_2d=World2D.new();tela.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 root.add_child(tela)
 var sprite:=Sprite2D.new();sprite.centered=false;sprite.texture=ativa.viewport_3d.get_texture();sprite.material=ativa.imagem.material;sprite.scale=Vector2.ONE*(768.0/ativa.viewport_3d.size.x);sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;tela.add_child(sprite)
 await RenderingServer.frame_post_draw
 tela.get_texture().get_image().save_png(SAIDA+"primeiro_golpe.png")
 for i in 2:
  extracao.impacto("machado",terreno.to_global(alvo.pos),1,j.global_position)
  await create_timer(.15).timeout
 conferir(not ativa.cortada,"Três golpes não antecipam o corte final")
 extracao.impacto("machado",terreno.to_global(alvo.pos),1,j.global_position)
 conferir(ativa.cortada,"Quarto golpe libera o tombamento")
 conferir(extracao._tocos.has(alvo.chave),"Toco continua disponível para extração")
 var preview_toco:=Sprite2D.new();preview_toco.centered=false
 preview_toco.texture=arvores.toco_3d.viewport.get_texture();preview_toco.material=arvores.maquetes[0].acabamento
 preview_toco.position=ativa.camera.unproject_position(Vector3.ZERO)-arvores.toco_3d.camera.unproject_position(Vector3.ZERO)
 preview_toco.scale=Vector2.ONE*(768.0/ativa.viewport_3d.size.x)
 if ativa.viewport_3d.size.x!=768:
  preview_toco.position=ativa.camera.unproject_position(Vector3.ZERO)*(768.0/ativa.viewport_3d.size.x)-arvores.toco_3d.camera.unproject_position(Vector3.ZERO)
  preview_toco.scale=Vector2.ONE
 preview_toco.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;preview_toco.z_index=-1;tela.add_child(preview_toco)
 var contatos := false
 var inclinacao := 0.
 var tempos: Array[int]=[]
 var inicio := Time.get_ticks_msec()
 for quadro in 72:
  await create_timer(1./30.).timeout
  if not is_instance_valid(ativa):break
  inclinacao=maxf(inclinacao,acos(clampf(ativa.corpo.global_basis.y.dot(Vector3.UP),-1,1)))
  contatos=contatos or ativa.tocou_chao
  await RenderingServer.frame_post_draw
  tela.get_texture().get_image().save_png(SAIDA+"queda_%03d.png"%quadro)
  tempos.append(Time.get_ticks_msec()-inicio)
  if contatos and quadro%12==0:
   root.get_texture().get_image().save_png(SAIDA+"impacto_mapa.png")
 conferir(inclinacao>1.0,"Tronco tomba com gravidade e inércia")
 conferir(contatos,"Colisão real com o chão dispara impacto")
 conferir(obstaculo.polygon==poligono and not obstaculo.disabled,"Queda visual preserva colisão do toco")
 await create_timer(3.).timeout
 conferir(not arvores.ativas.has(original),"Simulação é liberada após assentamento")
 conferir(not original.visible,"Árvore derrubada não reaparece")
 conferir(arvores.maquetes[0].viewport.get_texture()==copia_original,"Outras árvores preservam a maquete compartilhada")
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(SAIDA+"toco_no_mapa.png")
 preview_toco.hide()
 var toco: Sprite2D=extracao._tocos[alvo.chave]
 conferir(toco.get_meta("toco_3d",false),"Toco usa modelo 3D da árvore nova")
 conferir(toco.texture==arvores.toco_3d.viewport.get_texture(),"Tocos compartilham uma maquete pequena")
 for estacao_toco in 4:
  estacoes.estacao_do_mapa=estacao_toco;estacoes.definir_estacao(estacao_toco,true)
  await esperar(5)
  conferir(arvores.toco_3d.neve.visible==(estacao_toco==3),"Neve do toco acompanha estação")
  conferir((toco.offset+arvores.toco_3d.camera.unproject_position(Vector3.ZERO)).length()<.01,"Raízes do toco preservam pivô")
  sprite.texture=toco.texture;sprite.material=toco.material;sprite.scale=Vector2.ONE*6.
  await RenderingServer.frame_post_draw
  tela.get_texture().get_image().save_png(SAIDA+"toco_estacao_%d.png"%estacao_toco)
 var tiny=current_scene.get_node("ComparacaoTiny")
 tiny.definir_ativo(true);await esperar(4)
 conferir(toco.material==null and toco.texture!=arvores.toco_3d.viewport.get_texture(),"Tiny mantém sua representação própria do toco")
 tiny.definir_ativo(false);await esperar(4)
 conferir(toco.texture==arvores.toco_3d.viewport.get_texture(),"Retorno da comparação restaura toco 3D")
 # Uma árvore cortada em sessão anterior também precisa receber o toco novo.
 change_scene_to_file("res://cenas/fazenda.tscn")
 await esperar(40)
 terreno=current_scene.get_node("Terrains");extracao=terreno.get_node("Extracao");arvores=terreno.get_node("ArvoresFazenda3D")
 conferir(extracao._tocos.has(alvo.chave),"Toco persiste ao recarregar mapa")
 toco=extracao._tocos[alvo.chave]
 conferir(toco.texture==arvores.toco_3d.viewport.get_texture(),"Toco de save anterior recebe malha 3D")
 extracao.impacto("machado",terreno.to_global(alvo.pos),1,terreno.to_global(alvo.pos-Vector2(20,0)))
 extracao.impacto("machado",terreno.to_global(alvo.pos),1,terreno.to_global(alvo.pos-Vector2(20,0)))
 await create_timer(.6).timeout
 conferir(not extracao._tocos.has(alvo.chave),"Arrancar toco continua funcionando")
 conferir(terreno.get_node(alvo.obstaculo).disabled,"Remover toco libera a passagem")
 FileAccess.open(SAIDA+"tempos.json",FileAccess.WRITE).store_string(JSON.stringify(tempos))
 print("FÍSICA ÁRVORE: ",verificacoes," verificações; impulso, mola, gravidade, contato, toco e limpeza; estação=",e,"; lado=",lado,"; inclinação=",rad_to_deg(inclinacao),"; falhas=",falhas)
 quit(1 if falhas else 0)
