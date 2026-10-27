extends SceneTree
## Testa os botões reais da criação e o personagem carregado; somente save isolado.
var falhas:=0
var verificacoes:=0
var pasta="res://arte/previas/personagens/base_3d/tintura_cabelo/fluxo/"
func _initialize():rodar.call_deferred()
func conferir(ok: bool,msg: String):
 verificacoes+=1
 if not ok:falhas+=1;push_error(msg)
func esperar(n: int):
 for i in n:await process_frame
func foto(h: Node,nome: String):
 await RenderingServer.frame_post_draw
 await RenderingServer.frame_post_draw
 h._vp.get_texture().get_image().save_png(pasta+nome+".png")
func rodar():
 assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
 root.get_node("Ranking").conexao_habilitada=false
 root.get_node("Introducao").pular_prologo()
 root.get_node("Transicao").hora_salva=12.
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(pasta))
 var tela=load("res://cenas/criacao_personagem.tscn").instantiate()
 tela.trocar_cena=false;tela.caminho_save="user://configuracao_jogador.json"
 root.add_child(tela)
 await esperar(8)
 conferir(not tela._opcoes_3d.cabelo.any(func(par):return par[0]=="cabelo_cacheado"),"Penteado removido não aparece na criação")
 var catalogo=load("res://codigo/dados/roupas_base_3d.gd")
 conferir(catalogo.modelo("cabelo","cabelo_cacheado").id=="cabelo_longo" and catalogo.modelo("cabelo","cabelo_trancas").id=="cabelo_longo","Saves antigos usam cabelo longo solto")
 for estilo in ["cabelo_chanel","cabelo_longo"]:
  for par in tela._opcoes_3d.cabelo:
   if par[0]==estilo:par[1].pressed.emit()
  tela._abrir_aba(tela.Aba.COR)
  tela._casas_cor[6].pressed.emit()
  await esperar(3)
  var cor: Color=tela.PALETA[6]
  conferir(tela.cor.is_equal_approx(cor),"Botão ruivo conserva a cor selecionada")
  var h=tela._previa_3d.heroi
  conferir(h._pecas[3].material_override.get_shader_parameter("cor_cabelo").is_equal_approx(cor),"Prévia recebe o ruivo "+estilo)
  for d in 4:
   tela._direcao=d;tela._atualizar_previa()
   await foto(h,"criacao_%s_%d"%[estilo,d])
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(pasta+"interface_"+estilo+".png")
 tela.confirmar()
 await esperar(3)
 var dados: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(tela.caminho_save))
 conferir(Color(dados.aparencia_raven.cor[0],dados.aparencia_raven.cor[1],dados.aparencia_raven.cor[2]).is_equal_approx(tela.cor),"Save mantém o ruivo escolhido")
 conferir(Color(dados.cor_cabelo.r,dados.cor_cabelo.g,dados.cor_cabelo.b).is_equal_approx(tela.cor),"Campo legado recebe a mesma cor da criação")
 # Simula save anterior: o branco legado não pode apagar o ruivo atual.
 dados.cor_cabelo={"r":1.,"g":1.,"b":1.,"a":1.}
 FileAccess.open(tela.caminho_save,FileAccess.WRITE).store_string(JSON.stringify(dados))
 tela.queue_free();await esperar(2)
 change_scene_to_file("res://cenas/fazenda.tscn")
 await esperar(40)
 var j=current_scene.get_node("Jogador");j.set_physics_process(false)
 j.no_fazenda.set_process(false)
 var h=j.get_node("HeroiBase3D");h.set_process(false)
 for slot in j.inventario.equipados:j.inventario.equipados[slot]=null
 j._aplicar_modelo();h._armaduras.atualizar()
 var cor_jogo: Array=j.aparencia_raven.cor
 conferir(Color(cor_jogo[0],cor_jogo[1],cor_jogo[2]).is_equal_approx(Color(.95,.42,.20)),"Jogo carrega a cor da criação")
 conferir(h.roupas_3d.cabelo=="cabelo_longo","Jogo mantém cabelo longo solto")
 conferir(j.cor_cabelo.is_equal_approx(Color(.95,.42,.20)),"Campo branco antigo não apaga o ruivo escolhido")
 h._aplicar_cores()
 for d in 4:
  h._modelo.rotation.y=d*PI*.5
  await foto(h,"jogo_%d"%d)
 var shader=h._pecas[3].material_override
 conferir(shader.get_shader_parameter("cor_cabelo").is_equal_approx(Color(.95,.42,.20)),"Material do jogo mantém ruivo")
 j.definir_cor_cabelo(Color(.75,.25,.18))
 conferir(shader.get_shader_parameter("cor_cabelo").is_equal_approx(Color(.75,.25,.18)),"API de tintura atualiza o material 3D imediatamente")
 var editor=load("res://codigo/ui/editor_visual.gd").abrir(j)
 root.add_child(editor);await esperar(5)
 editor._tela._casas_cor[6].pressed.emit();editor._tela.confirmar()
 await esperar(3)
 conferir(j.cor_cabelo.is_equal_approx(Color(.95,.42,.20)) and shader.get_shader_parameter("cor_cabelo").is_equal_approx(Color(.95,.42,.20)),"Editor real sincroniza o ruivo no personagem e no material")
 print("RUIVO CRIACAO/JOGO: ",verificacoes," verificações; ",falhas," falhas")
 quit(0 if falhas==0 else 1)
