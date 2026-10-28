extends SceneTree
const Pedidos = preload("res://codigo/pesca/desafios_pesca.gd")
const Peixes = preload("res://codigo/pesca/peixes.gd")
const Progressao = preload("res://codigo/pesca/progressao_pesca.gd")
class Dono extends Node2D:
 var eh_p2 := true
 func acao(nome: String): return nome + "_p2"
var falhas := 0
func _initialize(): rodar.call_deferred()
func conferir(nome: String, ok: bool):
 print("OK " if ok else "FALHA ",nome)
 if not ok: falhas+=1
func rodar():
 if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"): quit(1);return
 var valido := true
 var avancados := false
 for nv in [1,5,25,50,99]:
  for vara in range(1,6):
   for estacao in 4:
    for dia in range(1,31):
     var pedidos = Pedidos.pedidos_do_dia(dia,estacao,nv,vara)
     valido = valido and pedidos.size()==2
     for p in pedidos:
      valido = valido and Peixes.nivel_pesca(p.peixe)<=nv and int(Peixes.DADOS[p.peixe].get("nivel_vara",1))<=vara
      if nv==99 and vara==5 and int(Peixes.DADOS[p.peixe].get("nivel_vara",1))==5:avancados=true
 conferir("6000 encomendas respeitam habilidade e vara",valido)
 conferir("varas e habilidade altas liberam encomendas avançadas",avancados)
 var f=root.get_node("Fazenda")
 f._zerar()
 root.get_node("Calendario").dia=1
 f.pesca_xp={"p1":Progressao.xp_para_nivel(99),"p2":0}
 f.varas_pesca={"p1":5,"p2":1}
 var p2=Dono.new()
 root.add_child(p2)
 var p1=f.pedidos_pesca()
 var segundo=f.pedidos_pesca(p2)
 conferir("P2 recebe metas dos próprios níveis",segundo.all(func(p):return Peixes.nivel_pesca(p.peixe)<=1 and int(Peixes.DADOS[p.peixe].get("nivel_vara",1))==1 and p.id.ends_with("_p2")))
 f.varas_pesca.p2=5
 f.pesca_xp.p2=Progressao.xp_para_nivel(99)
 conferir("encomenda permanece estável após melhoria",f.pedidos_pesca(p2)==segundo)
 var inventario2=root.get_node("InventarioJogador2")
 inventario2.limpar()
 inventario2.adicionar_peixe(segundo[1].peixe,0,segundo[1].quantidade)
 var quantidade_p1=f.quantidade_peixes(segundo[1].peixe)
 conferir("P2 entrega usando a própria mochila",f.entregar_pedido_pesca(segundo[1].id,p2)==segundo[1].brasas and f.quantidade_peixes(segundo[1].peixe,p2)==0 and f.quantidade_peixes(segundo[1].peixe)==quantidade_p1)
 conferir("P2 não recebe a mesma recompensa duas vezes",f.entregar_pedido_pesca(segundo[1].id,p2)==0)
 f.pesca_pedidos_entregues[segundo[0].id]=true
 f.salvar()
 f.carregar()
 conferir("save preserva perfil e entrega de P2",f.pedidos_pesca(p2)==segundo and f.pesca_pedidos_entregues.has(segundo[0].id) and f.pedidos_pesca()==p1)
 var controle=root.get_node("Controle")
 controle.usando_toque=true
 for tamanho in [Vector2i(576,324),Vector2i(320,216),Vector2i(288,512),Vector2i(288,216)]:
  var vp=SubViewport.new()
  vp.size=tamanho
  vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS
  root.add_child(vp)
  var mini=load("res://codigo/pesca/minijogo_pesca.gd").new()
  vp.add_child(mini)
  mini.iniciar(p2,"IMPERADOR ABISSAL",60,5)
  mini.set_process(false)
  mini._novo_check()
  await create_timer(.35).timeout
  for i in 3:await process_frame
  conferir("circulo maior no toque "+str(tamanho),mini.raio>=38 or tamanho.y<216)
  var area=Rect2(Vector2.ZERO,Vector2(tamanho)).grow(-6)
  for no in [mini._titulo,mini._feedback,mini._dica,mini._barra_fundo,mini._tecla_caixa]:
   conferir("margem do minijogo "+str(tamanho)+" "+str(no.get_class()),area.encloses(no.get_global_rect()))
  conferir("titulo não invade circulo",mini._titulo.get_rect().end.y<=mini.centro.y-mini.raio-4)
  if DisplayServer.get_name()!="headless":
   await RenderingServer.frame_post_draw
   vp.get_texture().get_image().save_png("/tmp/algoland-pesca-mobile-%dx%d.png"%[tamanho.x,tamanho.y])
  vp.queue_free()
  await process_frame
 p2.queue_free()
 print("PESCA MOBILE E PEDIDOS: ",falhas," falhas")
 quit(1 if falhas else 0)
