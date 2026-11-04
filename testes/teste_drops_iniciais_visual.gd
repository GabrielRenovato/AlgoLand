extends SceneTree
var falhas:=0
var cena:Node2D
func _initialize():rodar.call_deferred()
func verificar(texto:String,ok:bool):
 print("OK " if ok else "FALHA ",texto)
 if not ok:falhas+=1
func quadros(n:=10):
 for i in n:await process_frame;await physics_frame
func foto(nome:String):
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://capturas-drops-iniciais/"+nome+".png")
func area(no:Control) -> Rect2:return no.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,no.size)
func rodar():
 if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes") or DisplayServer.get_name()=="headless":quit(1);return
 DirAccess.make_dir_recursive_absolute("res://capturas-drops-iniciais")
 var catalogo=load("res://codigo/campanha/catalogo_saque_inicial.gd")
 var progresso=load("res://codigo/campanha/progresso_campanha.gd").new()
 progresso.iniciar("user://percurso_primeira_raiz","prototipo")
 for id in ["sobreviver_queda","estrada_interrompida"]:
  for o in load("res://codigo/campanha/catalogo_campanha.gd").dados().missoes[id].objetivos:progresso.registrar_objetivo(id,o.id)
 for id in ["dara","retorno"]:progresso.registrar_objetivo("acolhimento",id)
 progresso.salvar_retorno("vila",Vector2(0,180))
 root.mode=Window.MODE_WINDOWED;root.content_scale_size=Vector2i(576,324);root.size=Vector2i(1152,648)
 set_meta("campanha_nova_instancia",false)
 change_scene_to_file("res://cenas/campanha/percurso_prototipo.tscn")
 await quadros(60);cena=current_scene
 var jogador:Node=cena.jogador
 var inv:Node=jogador.inventario
 var saque:Node=cena.saque_inicial
 saque.set_process(false)
 verificar("boss sem recompensa provisoria",saque.receber("teste:boss","chegada",Vector2(200,200),"cerne")==OK and inv.saque_campanha.pendentes.is_empty())
 verificar("garantia de acessorio persiste antes de coletar",saque.receber("teste:guarda","chegada",Vector2(200,200),"guarda")==OK and inv.saque_campanha.pendentes.size()==1)
 verificar("pacote repetido nao duplica",saque.receber("teste:guarda","chegada",Vector2.ZERO,"guarda")==ERR_ALREADY_EXISTS)
 var outro=load("res://codigo/modelos/modelo_inventario.gd").new();root.add_child(outro);outro.caminho_save=inv.caminho_save
 verificar("pendencia persiste no inventario",outro.carregar() and outro.saque_campanha.pendentes.size()==1)
 verificar("garantia nao se repete",saque.receber("teste:guarda2","chegada",Vector2.ZERO,"guarda")==ERR_ALREADY_EXISTS)
 # Simula mochila cheia: a recompensa não desaparece nem vira venda automática.
 for i in inv.mochila.size():inv.mochila[i]=catalogo.criar("anel_cobre","comum",saque.rng)
 saque._mostrar("teste:guarda")
 var drop:Node=saque._visiveis["teste:guarda"]
 drop._tentar_pegar()
 verificar("mochila cheia conserva drop",not drop._pego and inv.saque_campanha.pendentes.has("teste:guarda"))
 inv.mochila[23]=null;drop._tentar_pegar()
 verificar("coleta e recibo na mesma gravacao",drop._pego and inv.saque_campanha.pendentes.is_empty() and catalogo.Acessorios.TIPOS.has(inv.mochila[23].tipo))
 verificar("coletado nao reaparece ao recarregar",outro.carregar() and outro.saque_campanha.pendentes.is_empty() and catalogo.Acessorios.TIPOS.has(outro.mochila[23].tipo))
 verificar("entra na estrada sem exigir abates",cena.abrir_regiao("estrada",false)==OK)
 jogador.invulneravel=true;await quadros(20)
 saque._process(0.0)
 verificar("resgate entrega acessorio mesmo sem combate","resgate" in inv.saque_campanha.garantias)
 verificar("retorna a vila",cena.abrir_regiao("vila",false)==OK)
 await quadros(20)
 inv.limpar()
 for tipo in catalogo.Conjunto.TIPOS:
  var item=catalogo.criar(tipo,"comum",saque.rng);inv.adicionar(item);inv.equipar(item)
 for tipo in catalogo.Acessorios.TIPOS:
  var item=catalogo.criar(tipo,"comum",saque.rng);inv.adicionar(item);inv.equipar(item)
 await quadros(15)
 var visual:Node=jogador.get_node("HeroiBase3D")
 verificar("quatro pecas reais no rig",visual._armaduras.mascara==15)
 var pecas:Dictionary={}
 for slot in ["cabeca","corpo","luvas","botas"]:pecas[slot]=inv.equipados[slot]
 for bits in 16:
  for i in 4:
   var slot:String=["cabeca","corpo","luvas","botas"][i]
   inv.equipados[slot]=pecas[slot] if bits & (1<<i) else null
  jogador._aplicar_modelo();await quadros(3)
  verificar("pecas independentes no personagem %d" % bits,visual._armaduras.mascara==bits)
  if bits in [0,1,2,4,8,15]:
   await RenderingServer.frame_post_draw
   visual._vp.get_texture().get_image().save_png("res://capturas-drops-iniciais/pecas-%d.png" % bits)
 
 verificar("vida e folego dos acessorios",jogador.estatisticas.bonus_vida_acessorios==6 and jogador._folego_acessorios==8)
 var vida:int=jogador.estatisticas.hp_maximo;var stamina:float=jogador.stamina_maxima
 jogador._aplicar_modelo();jogador._aplicar_modelo()
 verificar("reaplicar nao acumula atributos",jogador.estatisticas.hp_maximo==vida and is_equal_approx(jogador.stamina_maxima,stamina))
 for slot in catalogo.Acessorios.SLOTS:inv.desequipar(slot)
 verificar("retirar restaura atributos",jogador.estatisticas.bonus_vida_acessorios==0 and jogador._folego_acessorios==0)
 for tipo in catalogo.Acessorios.TIPOS:inv.equipar(inv.buscar_por_tipo(tipo))
 # Quatro orientações e peças no personagem real.
 for d in [Vector2.DOWN,Vector2.UP,Vector2.RIGHT,Vector2.LEFT]:
  jogador.parar_para_conversa(jogador.position+d);await quadros(8);await foto("armadura-"+str(d))
 jogador.set_physics_process(false)
 var tempos:Array=[]
 for d in 4:
  jogador.velocity=[Vector2.DOWN,Vector2.RIGHT,Vector2.UP,Vector2.LEFT][d]*120
  await quadros(3)
  var clipe=visual._player.get_animation(visual._player.assigned_animation)
  var passo:float=clipe.length/maxf(0.01,visual._player.speed_scale)/12.0
  for q in 12:
   await create_timer(passo).timeout
   await RenderingServer.frame_post_draw
   var imagem:Image=visual._vp.get_texture().get_image()
   var usado:Rect2i=imagem.get_used_rect()
   verificar("movimento sem cortes %d/%d" % [d,q],usado.has_area() and usado.position.x>0 and usado.end.x<imagem.get_width() and usado.position.y>0 and usado.end.y<imagem.get_height())
   imagem.save_png("res://capturas-drops-iniciais/movimento-%d-%02d.png" % [d,q])
  tempos.append(passo*1000)
 FileAccess.open("res://capturas-drops-iniciais/tempos.json",FileAccess.WRITE).store_string(JSON.stringify(tempos))
 jogador.velocity=Vector2.ZERO;jogador.set_physics_process(true)
 cena.interface._abrir_tela("inventario");await quadros(15)
 var tela:Node=cena.interface._telas.inventario
 for categoria in catalogo.Acessorios.SLOTS:
  var item=inv.equipados[categoria]
  tela._slots_equipamento[categoria]._equipar_ou_desequipar();await quadros(3)
  verificar("clique retira "+categoria,inv.equipados[categoria]==null and inv.indice_de(item)>=0)
  tela._slots_mochila[inv.indice_de(item)]._equipar_ou_desequipar();await quadros(3)
  verificar("clique equipa "+categoria,inv.equipados[categoria]==item)
 for medida in [Vector2i(576,324),Vector2i(288,512),Vector2i(288,324)]:
  root.content_scale_size=medida;root.size=medida*2;await quadros(15)
  for slot in catalogo.Acessorios.SLOTS:
   verificar("acessorio aparece "+slot,tela._slots_equipamento[slot].item_atual!=null)
   verificar("slot cabe %s %s" % [slot,medida],area(tela._equipamento).encloses(area(tela._slots_equipamento[slot])))
  await foto("inventario-%dx%d" % [medida.x,medida.y])
 print("FALHAS: ",falhas);quit(1 if falhas else 0)
