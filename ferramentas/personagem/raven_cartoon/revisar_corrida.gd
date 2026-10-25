extends SceneTree
const SAIDA="res://arte/previas/personagens/raven_cartoon/corrida_frente_4/motor/"
func _initialize():rodar.call_deferred()
func rodar():
 assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
 assert(DisplayServer.get_name()!="headless")
 root.mode=Window.MODE_WINDOWED;root.content_scale_size=Vector2i(512,720);root.size=Vector2i(512,720)
 var cena=load("res://ferramentas/personagem/raven_cartoon/previa_corrida_frente.tscn").instantiate();root.add_child(cena);current_scene=cena
 var ator=cena.get_node("Raven");var anim=ator.sprite_frames
 assert(anim.get_frame_count("correr_frente")==4 and anim.get_animation_speed("correr_frente")==10.0)
 assert(ator.offset==Vector2(-256,-850))
 var ciclos=[0];ator.animation_looped.connect(func():ciclos[0]+=1)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAIDA))
 var vistos={};var mudancas=[];var anterior=-1;var inicio=Time.get_ticks_msec()
 while (vistos.size()<4 or ciclos[0]<2) and Time.get_ticks_msec()-inicio<5000:
  await RenderingServer.frame_post_draw
  var q=ator.frame
  if q!=anterior:mudancas.append([q,Time.get_ticks_msec()-inicio]);anterior=q
  if not vistos.has(q):
   vistos[q]=true
   root.get_texture().get_image().save_png(SAIDA+"quadro_%02d.png"%(q+1))
  await process_frame
 assert(vistos.size()==4 and ciclos[0]>=2)
 FileAccess.open(SAIDA+"reproducao.json",FileAccess.WRITE).store_string(JSON.stringify({"quadros":4,"fps":10,"ciclo_ms":400,"ciclos_observados":ciclos[0],"trocas":mudancas},"\t"))
 print("CARTOON FRENTE: quatro poses reproduzidas a 10fps, dois ciclos completos; origem estável e sem fase aérea.")
 cena.queue_free();await process_frame;quit()
