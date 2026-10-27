extends "res://ferramentas/armaduras/revisar_mordomo_3d.gd"
## Corrida normal, arco guardado e um único disparo real; save isolado.
func rodar():
 assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
 assert(DisplayServer.get_name()!="headless")
 saida="res://arte/previas/armas_brilho_3d/arco_costas/"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(saida))
 root.get_node("Ranking").conexao_habilitada=false
 root.get_node("Introducao").pular_prologo()
 root.get_node("Transicao").hora_salva=12.
 change_scene_to_file("res://cenas/fazenda.tscn")
 await esperar(40)
 j=current_scene.get_node("Jogador");j.set_physics_process(false)
 j.no_fazenda.set_process(false);j.no_arco.set_process(false)
 h=j.get_node("HeroiBase3D");h.set_process(false)
 j.aparencia_raven={"pele":0,"cabelo":1,"roupa":1,"cor":[1.,1.,1.,1.]}
 h.definir_roupas_3d(h.CATALOGO_ROUPAS.padrao());h._aplicar_cores()
 j.roupa_atual=0
 for slot in j.inventario.equipados:j.inventario.equipados[slot]=null
 h._armaduras.atualizar()
 var arco=Receitas.criar_item("arco_curto");arco.nivel=3
 var aljava=Receitas.criar_item("aljava_basica")
 j.inventario.mochila[22]=arco;j.inventario.mochila[23]=aljava
 conferir(j.inventario.equipar(aljava) and j.inventario.equipar(arco),"Equipar arco e aljava reais")
 j.modo_fazenda=false
 vp=SubViewport.new();vp.size=h._vp.size;vp.transparent_bg=true;vp.world_2d=World2D.new();vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(vp)
 sprite=Sprite2D.new();sprite.centered=false;sprite.texture=h._vp.get_texture();sprite.material=h._sprite.material;sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;vp.add_child(sprite)
 var ciclo: float=h.PASSADA/114.
 for d in 8:
  j.velocity=Vector2(sin(d*TAU/8.),cos(d*TAU/8.))*114.
  h._process(0)
  conferir(h._acao=="correr" and h._player.assigned_animation=="mixamo/Running","Arco usa a corrida normal")
  for q in 24:
   pose("correr",d,q/24.)
   await foto("correr_%d_%02d"%[d,q])
   conferir(h._arco_visual.visible and h._arco_visual.get_parent()==h._costas,"Arco único acompanha o dorso")
   conferir(is_zero_approx(h._arco_visual.position.x) and is_zero_approx(h._arco_visual._aljava.position.x),"Arco e aljava centralizados nas costas")
   conferir(h._arco_visual.basis.y.is_equal_approx(Vector3.RIGHT) and h._arco_visual.basis.z.is_equal_approx(Vector3.UP),"Arco deitado e paralelo ao dorso")
   conferir(not h._arco_visual._flecha.visible,"Corrida não deixa flecha na mão")
  j.velocity=Vector2.ZERO;h._process(0)
  await foto("parado_%d"%d)
  conferir(h._arco_visual.get_parent()==h._costas,"Repouso mantém arco guardado")
 for d in [0,2,4,6]:
  j.no_arco.disparar(Vector2(sin(d*TAU/8.),cos(d*TAU/8.)),1.)
  for q in 24:
   pose("arco",d,q/24.)
   await foto("disparo_%d_%02d"%[d,q])
   conferir(h._arco_visual.visible and h._arco_visual.get_parent()==h._modelo,"Disparo leva o mesmo arco à mão")
   conferir(h._arco_visual._flecha.visible==(j.no_arco._indice<j.no_arco.QUADRO_SOLTAR),"Soltura conserva a flecha sincronizada")
  j.no_arco.parar_disparo()
  j.velocity=Vector2.DOWN*114.;h._process(0)
  await foto("retorno_%d"%d)
  conferir(h._arco_visual.get_parent()==h._costas,"Fim do disparo guarda arco ao voltar a correr")
 var disparos: Array=[]
 j.no_arco.disparo_liberado.connect(func(dir):disparos.append(dir))
 h.set_process(true);j.no_arco.visible=true;j.no_arco.set_process(true)
 j.velocity=Vector2.ZERO;j._direcao_ataque=Vector2.DOWN
 j._iniciar_disparo()
 await create_timer(1.3).timeout
 conferir(disparos.size()==1 and not j.no_arco.esta_disparando(),"Um sinal de soltura por disparo real")
 j.velocity=Vector2.UP*114.
 for q in 24:
  await esperar(1);await foto("corrida_motor_%02d"%q)
 conferir(h._acao=="correr" and h._arco_visual.get_parent()==h._costas,"Processamento real retoma corrida com arco nas costas")
 j.velocity=Vector2.ZERO;h.set_process(false)
 FileAccess.open(saida+"tempos.json",FileAccess.WRITE).store_string(JSON.stringify({"correr":ciclo,"disparo":duracao("arco"),"amostras":24},"  "))
 print("ARCO NAS COSTAS: ",verificacoes," verificações; ",falhas," falhas; oito direções e disparo real")
 quit(0 if falhas==0 else 1)
