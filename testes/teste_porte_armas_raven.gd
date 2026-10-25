extends "res://testes/teste_acoes_fazenda_raven.gd"
const Porte=preload("res://codigo/dados/porte_armas_raven.gd")
const Conjuntos=preload("res://codigo/dados/conjuntos_armadura.gd")
const PASTA="/tmp/algoland-porte-raven/"
func _initialize():revisar.call_deferred()
func revisar():
 assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
 assert(DisplayServer.get_name()!="headless")
 root.get_node("Introducao").pular_prologo();root.get_node("Fazenda").definir_clima_hoje(0);root.get_node("Transicao").hora_salva=12
 change_scene_to_file("res://cenas/fazenda.tscn");await esperar(30);root.get_node("Transicao").limpar();current_scene.process_mode=Node.PROCESS_MODE_DISABLED
 var jogador=current_scene.get_node("Jogador");var visual=jogador.get_node("HeroiRaven")
 var vp=SubViewport.new();vp.size=Vector2i(1120,720);vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS;vp.canvas_item_default_texture_filter=Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST;root.add_child(vp)
 var fundo=ColorRect.new();fundo.color=Color("515e47");fundo.size=vp.size;vp.add_child(fundo);DirAccess.make_dir_recursive_absolute(PASTA)
 for roupa in [1,8,9,10,11,12,13,14,15,16,17,18]:
  jogador.aparencia_raven={"pele":0,"roupa":mini(roupa,8),"cabelo":1,"cor":[1,1,1,1]}
  for slot in ["cabeca","corpo","luvas","botas"]:jogador.inventario.equipados[slot]=null
  if roupa>=9:
   var indice=0 if roupa==9 else (roupa-16 if roupa>=17 else roupa-7)
   var conjunto=Conjuntos.CONJUNTOS[indice]
   for tipo in conjunto.TIPOS:
    var item=Receitas.criar_item(tipo);jogador.inventario.equipados[item.categoria]=item
  for tipo in ["espada","espada_dupla","lanca","arco"]:
   var id={"espada":"espada_basica","espada_dupla":"espada_gemea","lanca":"lanca_basica","arco":"arco_curvo"}[tipo]
   jogador.inventario.equipados.arma=Receitas.criar_item(id)
   jogador.usando_espada=tipo in ["espada","espada_dupla"];jogador.usando_lanca=tipo=="lanca";jogador.usando_arco=tipo=="arco"
   jogador.id_arma_atual=id if tipo in ["espada","espada_dupla"] else "espada_basica";jogador.id_lanca_atual="lanca_basica"
   if tipo in ["espada","espada_dupla"]:
    var inteira=Porte.textura(tipo).get_image();var cabo=Porte.textura_cabo(tipo).get_image();var pixels_cabo=0
    for y in cabo.get_height():
     for x in cabo.get_width():
      var cor=cabo.get_pixel(x,y)
      if cor.a>0.5:
       pixels_cabo+=1
       conferir(cor==Color("745c42") and cor==inteira.get_pixel(x,y),"Camada dianteira contém só o couro original do cabo")
      else:conferir(inteira.get_pixel(x,y)!=Color("745c42"),"Nenhum pixel do cabo desaparece")
    conferir(pixels_cabo>0,"Cabo preserva os pixels visíveis")
   var copias=[]
   for d in 4:
    jogador._direcao_ataque=[Vector2.DOWN,Vector2.RIGHT,Vector2.UP,Vector2.LEFT][d]
    var tempo=0.0
    for q in 7:
     jogador._esta_atacando=false;jogador.velocity=Vector2.ZERO if q==0 else jogador._direcao_ataque*80
     visual._animacao="parado" if q==0 else "correr";visual._direcao=d;visual._tempo=tempo+0.001;visual._process(0)
     conferir(visual._arma_costas.visible==(tipo!="arco"),"Porte acompanha seleção real "+tipo)
     if tipo!="arco":
      var pose=Porte.pose(tipo,visual._animacao,d,maxi(0,q-1))
      conferir(visual._arma_costas.position==Vector2(pose.posicao[0],pose.posicao[1]),"Posição gravada sincronizada")
      var cabo_frente=visual._animacao=="correr" and d==2 and tipo in ["espada","espada_dupla"]
      conferir(visual._arma_costas.z_index==int(pose.z),"Lâmina conserva a profundidade do porte")
      conferir(visual._cabo_arma_costas.visible==cabo_frente,"Só o cabo das espadas sobe na corrida de costas")
      if cabo_frente:
       conferir(visual._arma_costas.z_index+visual._cabo_arma_costas.z_index>visual._camadas[9].z_index,"Cabo visível diante do elmo na corrida de costas, traje %d quadro %d"%[roupa,q-1])
       conferir(visual._cabo_arma_costas.texture.get_size()==visual._arma_costas.texture.get_size(),"Cabo mantém o pivô e acompanha a rotação da espada")
      var rastro=visual.criar_rastro();conferir(rastro.has_node("ArmaNasCostas"),"Rastro inclui objeto separado")
      conferir(rastro.has_node("ArmaNasCostas/CaboArmaNasCostas")==cabo_frente,"Rastro preserva a profundidade do cabo");rastro.free()
      var previa=visual.criar_previa();conferir(not previa.has_node("ArmaNasCostas") and visual._arma_costas.visible,"Prévia não altera porte do mundo");previa.free()
     else:conferir(visual._camadas[13].texture==Raven.folha("aljava",visual._animacao),"Arco mantém somente aljava")
     var copia=visual.criar_rastro();copia.scale=Vector2(3,3);copia.position=Vector2(q*160+80,d*180+165);vp.add_child(copia);copias.append(copia)
     if q>0:tempo+=[0.10,0.06,0.14,0.10,0.06,0.14][q-1]
    jogador._esta_atacando=true;visual._process(0);conferir(not visual._arma_costas.visible,"Ataque retira arma das costas")
    jogador._esta_atacando=false;jogador.velocity=Vector2.ZERO
    jogador.esta_em_acao_fazenda=true;jogador.no_fazenda.tocar("regar",jogador._direcao_ataque);visual._process(0);conferir(not visual._arma_costas.visible,"Ferramenta retira arma das costas");jogador.cancelar_acao_fazenda()
   await RenderingServer.frame_post_draw;vp.get_texture().get_image().save_png(PASTA+tipo+"_roupa%d.png"%roupa)
   for c in copias:c.queue_free()
   await process_frame
 jogador.usando_espada=false;jogador.usando_lanca=false;jogador.usando_arco=false;visual._process(0);conferir(not visual._arma_costas.visible,"Desarmado não deixa arma fantasma")
 print("PORTE RAVEN: ",verificacoes," verificações; ",falhas," falhas")
 vp.queue_free();current_scene.queue_free();current_scene=null;await esperar(3);quit(1 if falhas else 0)
