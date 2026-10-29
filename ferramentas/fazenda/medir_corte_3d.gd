extends SceneTree
var ativas: Array[Node] = []
func _initialize():rodar.call_deferred()
func esperar(n: int):
 for i in n:await process_frame
func medir(nome: String):
 var cpu: Array[float]=[]
 var fisica: Array[float]=[]
 var desenhos: Array[float]=[]
 for i in 120:
  for ativa in ativas:ativa.desde_golpe=0
  await process_frame
  cpu.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000.)
  fisica.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.)
  desenhos.append(float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)))
 var soma := 0.
 for v in cpu:soma+=v
 var soma_fisica := 0.
 for v in fisica:soma_fisica+=v
 var soma_desenhos := 0.
 for v in desenhos:soma_desenhos+=v
 cpu.sort();fisica.sort()
 print("PERFIL_CORTE ",JSON.stringify({"fase":nome,"cpu_media_ms":soma/cpu.size(),"cpu_p95_ms":cpu[int(cpu.size()*.95)],"fisica_media_ms":soma_fisica/fisica.size(),"draw_calls_media":soma_desenhos/desenhos.size(),"ativas":ativas.size()}))
func rodar():
 assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
 root.get_node("Ranking").conexao_habilitada=false
 root.get_node("Introducao").pular_prologo()
 root.get_node("Transicao").hora_salva=12.
 change_scene_to_file("res://cenas/fazenda.tscn")
 await esperar(45)
 root.get_node("Transicao").limpar()
 var terreno=current_scene.get_node("Terrains")
 var arvores=terreno.get_node("ArvoresFazenda3D")
 var j=current_scene.get_node("Jogador");j.set_physics_process(false)
 await medir("paradas")
 var disponiveis: Array=[]
 for r in arvores.registros:
  if r.tipo==0 and r.sprite.visible:disponiveis.append(r.sprite)
 for quantidade in [1,2]:
  var s: Sprite2D=disponiveis[quantidade-1]
  arvores.reagir_ao_corte(s,s.global_position-Vector2(20,0))
  ativas.append(arvores.ativas[s])
  await esperar(4)
  await medir("corte_%d"%quantidade)
 # Limite do modo celular recusa um terceiro corpo, deixando a apresentação legada disponível.
 var terceiro: Sprite2D=disponiveis[2]
 var aceitou: bool=arvores.reagir_ao_corte(terceiro,terceiro.global_position-Vector2(20,0))
 print("LIMITE_MOBILE_OK ",not aceitou and arvores.ativas.size()==2)
 for ativa in ativas:ativa._finalizar()
 await esperar(4)
 print("LIMPEZA_OK ",arvores.ativas.is_empty())
 quit()
