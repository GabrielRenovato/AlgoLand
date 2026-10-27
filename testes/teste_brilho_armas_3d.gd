extends SceneTree
## Bigorna real, materiais privados e capturas no renderizador ativo; somente save isolado.
const Receitas=preload("res://codigo/dados/forja_armas.gd")
const Visual=preload("res://codigo/dados/visual_armas.gd")
const Retrato=preload("res://codigo/dados/visual_ranking.gd")
const Icones=preload("res://codigo/ui/icones_itens.gd")
const Cores=preload("res://codigo/dados/cores_armas_raven.gd")
var h: Node
var j: Node
var vp: SubViewport
var saida="res://arte/previas/armas_brilho_3d/"
var falhas:=0
var verificacoes:=0
func _initialize():rodar.call_deferred()
func conferir(ok: bool,msg: String):
 verificacoes+=1
 if not ok:falhas+=1;push_error(msg)
func esperar(n: int):
 for i in n:await process_frame
func foto(nome: String):
 await RenderingServer.frame_post_draw
 await RenderingServer.frame_post_draw
 var imagem:=vp.get_texture().get_image()
 imagem.save_png(saida+nome+".png")
 return imagem
func posar(tipo: String):
 h._acabamento_armas.atualizar()
 var acao: String="arco" if tipo.begins_with("arco_") else ("lanca" if tipo=="lanca_basica" else ("pesada" if tipo in ["machado","maca"] else "espada"))
 h._acao=acao
 h._modelo.rotation.y=.35
 h._progresso_golpe=.10
 var clipe: String=h._nome_animacao(acao)
 h._player.play(clipe,0);h._player.pause();h._player.seek(.25,true)
 h._encaixar_espada(true);h._encaixar_arma_pesada(true)
 h._arco_visual.atualizar(h._esqueleto)
func rodar():
 assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
 assert(DisplayServer.get_name()!="headless")
 root.get_node("Ranking").conexao_habilitada=false
 root.get_node("Introducao").pular_prologo()
 root.get_node("Transicao").hora_salva=12.
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(saida))
 change_scene_to_file("res://cenas/fazenda.tscn")
 await esperar(40)
 j=current_scene.get_node("Jogador");j.set_physics_process(false)
 j.no_fazenda.set_process(false)
 for slot in j.inventario.equipados:j.inventario.equipados[slot]=null
 j.roupa_atual=0
 h=j.get_node("HeroiBase3D");h.set_process(false);h._rastro.layers=0
 j.aparencia_raven={"pele":0,"cabelo":1,"roupa":1,"cor":[1.,1.,1.,1.]}
 h.definir_roupas_3d(h.CATALOGO_ROUPAS.padrao());h._aplicar_cores()
 h._armaduras.atualizar()
 vp=SubViewport.new();vp.size=h._vp.size;vp.transparent_bg=true;vp.world_2d=World2D.new();vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 root.add_child(vp)
 var s:=Sprite2D.new();s.centered=false;s.texture=h._vp.get_texture();s.material=h._sprite.material;s.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;vp.add_child(s)
 var pele=h._modelo.find_child("CorpoBase",true,false).material_override
 var pele_cor: Color=pele.get_shader_parameter("cor")
 var ferramenta: Material=h._ferramentas._vara.get_child(0).material_override
 var espada=Receitas.criar_item("espada_basica")
 j.inventario.equipados.arma=espada;j._aplicar_modelo()
 var base: Color=h._espada_uma_mao.get_child(0).material_override.get_shader_parameter("cor_base")
 var cabo=h._espada_uma_mao.get_child(2).material_override
 var sem_brilho: Image
 for nivel in range(1,6):
  conferir(espada.nivel==nivel and espada.raridade=="comum","Nível sobe sem ascender antes do máximo")
  posar(espada.tipo)
  var metal: ShaderMaterial=h._espada_uma_mao.get_child(0).material_override
  conferir(metal.get_shader_parameter("cor_base")==base and float(metal.get_shader_parameter("tingimento"))==0.,"Bigorna mantém a cor do material comum")
  conferir(is_equal_approx(float(metal.get_shader_parameter("intensidade")),Visual.brilho(nivel).intensidade),"Brilho acompanha o nível real")
  conferir(h._espada_uma_mao.get_child(0).get_child(0).visible==(nivel>1),"Arma sem melhoria não tem aura")
  conferir(h._espada_uma_mao.get_child(2).material_override==cabo,"Cabo conserva seu material")
  conferir(Icones.obter(espada,self)==Icones.obter_arma(espada.tipo,self,1,"comum"),"Ícone não repinta ao subir nível")
  var imagem: Image=await foto("nivel_%d"%nivel)
  if nivel==1:sem_brilho=imagem
  if nivel==5:
   var pixels_aura:=0
   for y in imagem.get_height():
    for x in imagem.get_width():
     if sem_brilho.get_pixel(x,y).a<.01 and imagem.get_pixel(x,y).a>.05:pixels_aura+=1
   conferir(pixels_aura>=5,"Aura realmente aparece fora da silhueta no viewport final")
  if nivel<5:j.inventario.subir_nivel(espada)
 for raridade in ["comum","incomum","raro","epico","lendario"]:
  conferir(espada.raridade==raridade,"Ascensão real segue as raridades existentes")
  posar(espada.tipo)
  var metal: ShaderMaterial=h._espada_uma_mao.get_child(0).material_override
  conferir(metal.get_shader_parameter("cor_raridade")==Visual.cor_material(raridade),"Ascensão muda o material")
  conferir(float(metal.get_shader_parameter("intensidade"))==1.,"Ascensão preserva o brilho máximo")
  var visual: Dictionary=Retrato.do_jogador(j)
  var modelo=Retrato.criar_modelo(visual)
  conferir(modelo.inventario.equipados.arma.raridade==raridade and modelo.inventario.equipados.arma.nivel==5,"Retrato preserva nível e raridade equipados")
  modelo.free()
  conferir(Cores.paleta(espada.tipo,1,raridade)==Cores.paleta(espada.tipo,5,raridade),"Material dos ícones depende somente da raridade")
  await foto("raridade_"+raridade)
  if raridade!="lendario":j.inventario.subir_nivel(espada)
 # A reserva mais forte não interfere; retirar ou trocar a arma limpa a energia anterior.
 var reserva=Receitas.criar_item("espada_basica");reserva.nivel=5;reserva.raridade="lendario"
 j.inventario.mochila[0]=reserva
 for tipo in ["espada_basica","espada_gemea","montante_ferro","montante_sentinela","montante_geada","montante_trovao","montante_astral","lanca_basica","machado","maca","arco_curto","arco_curvo","arco_longo"]:
  var item=Receitas.criar_item(tipo);item.nivel=1;item.raridade="comum"
  j.inventario.equipados.arma=item;j._aplicar_modelo();posar(tipo)
  conferir(float(h._acabamento_armas.pecas[0].metal.get_shader_parameter("intensidade"))==0.,"Arma comum limpa a aura anterior, ignorando reserva")
  await foto(tipo+"_base")
  item.nivel=5;item.raridade="raro";posar(tipo)
  var icone_base:=Icones.obter_arma(tipo,self,1,"comum").get_image()
  var icone_raro:=Icones.obter(item,self).get_image()
  var diferencas:=0
  var alfa_igual:=true
  for y in icone_base.get_height():
   for x in icone_base.get_width():
    var a:=icone_base.get_pixel(x,y);var b:=icone_raro.get_pixel(x,y)
    if not a.is_equal_approx(b):diferencas+=1
    alfa_igual=alfa_igual and is_equal_approx(a.a,b.a)
  conferir(diferencas>0 and alfa_igual,"Raridade muda o ícone preservando silhueta e alfa "+tipo)
  await foto(tipo+"_melhorada")
 conferir(pele.get_shader_parameter("cor")==pele_cor,"Brilho não tinge a pele")
 conferir(h._ferramentas._vara.get_child(0).material_override==ferramenta,"Ferramentas da fazenda não recebem a aura da arma")
 var retrato=load("res://codigo/jogador/representacao_heroi_3d.gd").new()
 retrato.aparencia=Retrato.normalizar({"versao":1,"arma_mais_usada":"espada_basica","nivel_arma":1,"raridade_arma":"comum"})
 current_scene.add_child(retrato)
 var metal_retrato=retrato.heroi._espada_uma_mao.get_child(0).material_override
 conferir(metal_retrato!=h._espada_uma_mao.get_child(0).material_override,"Personagens e prévias não compartilham material mutável")
 conferir(float(metal_retrato.get_shader_parameter("intensidade"))==0.,"Prévia de arma comum não herda brilho de outra instância")
 retrato.queue_free()
 j.inventario.equipados.arma=espada;j._aplicar_modelo();posar("espada_basica")
 var tempos: Array=[]
 for q in 24:
  await esperar(2);await foto("pulso_%02d"%q)
  tempos.append(Time.get_ticks_usec()/1000000.)
 FileAccess.open(saida+"tempos_pulso.json",FileAccess.WRITE).store_string(JSON.stringify(tempos))
 var clipe: String=h._nome_animacao("espada")
 var duracao: float=h._player.get_animation(clipe).length
 for q in 24:
  h._progresso_golpe=q/24.
  h._player.seek(duracao*q/24.,true);h._encaixar_espada(true)
  await foto("golpe_%02d"%q)
 FileAccess.open(saida+"tempo_golpe.json",FileAccess.WRITE).store_string(JSON.stringify(duracao))
 var ui=root.get_node("EventosJogo").interface_p1()
 ui._abrir_tela("inventario")
 await esperar(5)
 var previa=ui._telas.inventario._previa
 conferir(previa.inventario.equipados.arma.nivel==5 and previa.inventario.equipados.arma.raridade=="lendario","Mochila mostra o nível e raridade reais")
 root.mode=Window.MODE_WINDOWED
 for tamanho in [Vector2i(576,324),Vector2i(288,512)]:
  root.content_scale_size=tamanho;root.size=tamanho*2
  await esperar(5)
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(saida+"inventario_%dx%d.png"%[tamanho.x,tamanho.y])
 j.inventario.equipados.arma=null;h._acabamento_armas.atualizar()
 conferir(float(h._acabamento_armas.pecas[0].metal.get_shader_parameter("intensidade"))==0.,"Retirar arma limpa o brilho")
 print("BRILHO ARMAS 3D: ",verificacoes," verificações; ",falhas," falhas")
 quit(0 if falhas==0 else 1)
