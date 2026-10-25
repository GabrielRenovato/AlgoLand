extends "res://testes/teste_acoes_fazenda_raven.gd"
const Montantes=preload("res://codigo/dados/armas_montantes.gd")
const Equipamentos=preload("res://codigo/dados/equipamentos.gd")
const Raridades=preload("res://codigo/dados/raridades.gd")
const Icones=preload("res://codigo/ui/icones_itens.gd")
const Estilos=preload("res://codigo/dados/estilos_arma.gd")
const ArmasRanking=preload("res://codigo/dados/armas_ranking.gd")
const PASTA="res://arte/previas/armas/montantes/"
func copiar(fonte: Sprite2D) -> Sprite2D:
 var novo=Sprite2D.new()
 for prop in ["texture","material","centered","offset","hframes","vframes","frame","modulate","self_modulate","visible","z_index","position","rotation","scale"]:novo.set(prop,fonte.get(prop))
 novo.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
 for filho in fonte.get_children():
  if filho is Sprite2D:novo.add_child(copiar(filho))
 return novo
class AlvoTeste extends Node2D:
 var esta_morto=false
 var lentidao=0.0
 var dano=0
 func aplicar_lentidao(fracao: float,_duracao: float):lentidao=fracao
 func receber_dano_efeito(valor: int,_cor: Color):dano+=valor
func _initialize():revisar.call_deferred()
func revisar():
 assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
 assert(DisplayServer.get_name()!="headless")
 root.mode=Window.MODE_WINDOWED
 root.get_node("Introducao").pular_prologo();root.get_node("Fazenda").definir_clima_hoje(0);root.get_node("Transicao").hora_salva=12
 change_scene_to_file("res://cenas/fazenda.tscn");await esperar(30);root.get_node("Transicao").limpar()
 var jogador=current_scene.get_node("Jogador");var visual=jogador.get_node("HeroiRaven");var inv=jogador.inventario
 inv.limpar();inv.criar_itens_iniciais();jogador.troca_sem_pose=true
 var painel=root.get_node("PainelDebug")
 conferir(painel.AREAS.COMBATE.has("MONTANTES"),"F3 torna montantes acessíveis na área Combate")
 painel._opcoes.MONTANTES[0][1].call()
 for id_modelo in Montantes.MODELOS:conferir(inv.buscar_por_tipo(id_modelo)!=null,"Callback real do F3 entrega "+id_modelo)
 var antes=inv.mochila.duplicate();painel._opcoes.MONTANTES[0][1].call()
 conferir(inv.mochila==antes,"Repetir entrega no F3 não duplica armas")
 current_scene.process_mode=Node.PROCESS_MODE_DISABLED
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PASTA))
 var vp=SubViewport.new();vp.size=Vector2i(800,720);vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS;vp.canvas_item_default_texture_filter=Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST;root.add_child(vp)
 var fundo=ColorRect.new();fundo.color=Color("414e46");fundo.size=vp.size;vp.add_child(fundo)
 var anteriores=[0,0,0,0,0];var indice=0
 for tipo in Montantes.MODELOS:
  var modelo: Dictionary=Montantes.MODELOS[tipo];var item=Receitas.criar_item(tipo)
  conferir(item.duas_maos and item.raridade==modelo.raridade,"Modelo e raridade próprios: "+tipo)
  conferir(item.encantamento==modelo.get("encantamento","") and item.nivel_encantamento==modelo.get("nivel_encantamento",0),"Encantamento inicial: "+tipo)
  conferir(Receitas.onda_receita(tipo)==modelo.andar and Receitas.RECEITAS[tipo]==modelo.materiais,"Progressão da receita: "+tipo)
  conferir(ArmasRanking.validar(tipo)=="espada_gemea","Estatística compatível com ranking: "+tipo)
  conferir(Estilos.efeito(tipo,3,0).dano==1.25 and Estilos.efeito(tipo,1,0).dano==1.0,"Último golpe preserva especialidade: "+tipo)
  conferir(DadosItem.de_dict(item.para_dict()).para_dict()==item.para_dict(),"Save mantém identidade, raridade e encantamento: "+tipo)
  conferir(Icones.obter(item,null)!=null and Icones.obter(item,null).get_size().y<=32,"Ícone nativo disponível: "+tipo)
  for n in range(1,6):
   var dano=Raridades.escalar(int(modelo.dano[n-1]),modelo.raridade)
   conferir(dano>=anteriores[n-1],"Dano cresce entre modelos no nível %d"%n);anteriores[n-1]=dano
  inv.adicionar(item);conferir(inv.equipar(item),"Seleciona montante pela mochila: "+tipo)
  conferir(jogador.usando_espada and jogador.id_arma_atual==tipo and not jogador.usando_escudo,"Duas mãos suspendem escudo: "+tipo)
  var alvo=AlvoTeste.new();var vizinho=AlvoTeste.new();current_scene.add_child(alvo);current_scene.add_child(vizinho)
  vizinho.position=alvo.position+Vector2(20,0);vizinho.add_to_group("enemy")
  jogador._aplicar_encantamento(alvo,100)
  if tipo=="montante_geada":conferir(is_equal_approx(alvo.lentidao,0.25),"Geada aplica 25% de lentidão no combate")
  elif tipo=="montante_trovao":conferir(vizinho.dano==40 and alvo.dano==0,"Trovão causa 40% de dano no alvo vizinho")
  elif tipo=="montante_astral":conferir(alvo.dano==30,"Astral causa choque extra de 30% no próprio alvo")
  else:conferir(alvo.dano==0 and vizinho.dano==0 and alvo.lentidao==0,"Modelo inicial sem efeito elemental oculto")
  alvo.free();vizinho.free()
  jogador.no_reacao.encerrar();jogador._temporizador.stop();jogador._esta_atacando=false
  jogador.aparencia_raven={"pele":0,"roupa":1,"cabelo":1,"cor":[1,1,1,1]}
  for slot in ["cabeca","corpo","luvas","botas"]:inv.equipados[slot]=null
  var label=Label.new();label.text=tipo.trim_prefix("montante_").to_upper()+"\n"+modelo.raridade.to_upper();label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.position=Vector2(indice*160,12);label.size=Vector2(160,48);label.add_theme_font_size_override("font_size",14);vp.add_child(label)
  var folha=Image.create(320,320,false,Image.FORMAT_RGBA8)
  for d in 4:
   jogador._direcao_ataque=[Vector2.DOWN,Vector2.RIGHT,Vector2.UP,Vector2.LEFT][d]
   jogador.velocity=Vector2.ZERO;jogador._esta_atacando=true
   # Os mesmos instantes usados pelo temporizador real do ataque.
   for q in 4:
    jogador._temporizador.start(4.0);jogador._temporizador.paused=true
    # Define duração para o instante da pose, sem alterar o controlador de frames.
    jogador._temporizador.wait_time=4.0/(1.0-(q+0.1)/4.0)
    visual._process(0)
    conferir(visual._animacao=="espada_dupla" and visual.frame==d*4+q,"Grade e quadro do golpe: %s/%d/%d"%[tipo,d,q])
    conferir(visual._camadas[5].texture==Montantes.folha(tipo) and not visual._arma_costas.visible,"Modelo correto sem espada duplicada no golpe")
    var mini=SubViewport.new();mini.size=Vector2i(80,80);mini.transparent_bg=true;mini.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(mini)
    var copia=copiar(visual);copia.position=Vector2(40,40);mini.add_child(copia);await esperar(2);await RenderingServer.frame_post_draw
    folha.blend_rect(mini.get_texture().get_image(),Rect2i(0,0,80,80),Vector2i(q*80,d*80));mini.queue_free()
    if q==0 and d in [0,1]:
     var vitrine=copiar(visual);vitrine.position=Vector2(indice*160+80,150 if d==0 else 370);vitrine.scale=Vector2(3,3);vp.add_child(vitrine)
   jogador._temporizador.stop();jogador._temporizador.paused=false;jogador._esta_atacando=false
   jogador.velocity=jogador._direcao_ataque*80;visual._animacao="correr";visual._direcao=d
   var tempo=0.0
   for q in 6:
    visual._tempo=tempo+0.001;visual._process(0)
    conferir(visual._arma_costas.texture==Montantes.porte(tipo),"Porte usa desenho correto")
    if d==2:conferir(visual._cabo_arma_costas.visible and visual._arma_costas.z_index+visual._cabo_arma_costas.z_index>visual._camadas[9].z_index,"Cabo fica diante do elmo")
    if d==2 and q==0:
     var vitrine=copiar(visual);vitrine.position=Vector2(indice*160+80,590);vitrine.scale=Vector2(3,3);vp.add_child(vitrine)
    tempo+=[0.10,0.06,0.14,0.10,0.06,0.14][q]
  folha.save_png(PASTA+tipo+"_golpes.png")
  indice+=1
 await esperar(3);await RenderingServer.frame_post_draw;vp.get_texture().get_image().save_png(PASTA+"montantes_em_jogo.png")
 await revisar_movimento(jogador,visual)
 # O id da última espada permanece ao trocar para lança: não pode contaminar o porte.
 var lanca=Receitas.criar_item("lanca_basica");inv.adicionar(lanca);inv.equipar(lanca);jogador.no_reacao.encerrar()
 jogador.velocity=Vector2.ZERO;visual._process(0)
 conferir(visual._arma_costas.texture==preload("res://codigo/dados/porte_armas_raven.gd").textura("lanca"),"Trocar montante por lança preserva a lança nas costas")
 inv.equipar(inv.buscar_por_tipo("espada_basica"));jogador.no_reacao.encerrar();visual._process(0)
 conferir(visual._arma_costas.texture==preload("res://codigo/dados/porte_armas_raven.gd").textura("espada"),"Trocar montante por espada original restaura sua arte")

 # Caminho real do menu e textos nas duas escalas.
 painel._area.select(1);painel._selecionar_area(1)
 var assunto=painel.AREAS.COMBATE.find("MONTANTES")
 painel._categoria.select(assunto);painel._selecionar_categoria(assunto)
 painel._acao.select(2);painel._painel.visible=true
 for tamanho in [Vector2i(576,324),Vector2i(288,512)]:
  root.content_scale_size=tamanho;root.size=tamanho*2;painel._ajustar_altura()
  await esperar(4);await RenderingServer.frame_post_draw
  conferir(painel._painel.get_global_rect().end.x<=tamanho.x and painel._painel.get_global_rect().end.y<=tamanho.y,"Painel F3 cabe na tela %s"%tamanho)
  root.get_texture().get_image().save_png(PASTA+"f3_%d.png"%tamanho.x)
 painel._painel.visible=false
 vp.queue_free();await esperar(3)
 print("MONTANTES: %d verificações; %d falhas"%[verificacoes,falhas]);quit(1 if falhas else 0)

func revisar_movimento(jogador,visual):
 var tempos={}
 jogador._temporizador.process_mode=Node.PROCESS_MODE_ALWAYS
 for tipo in Montantes.MODELOS:
  jogador.inventario.equipar(jogador.inventario.buscar_por_tipo(tipo));jogador.no_reacao.encerrar()
  tempos[tipo]=[]
  for d in 4:
   jogador._direcao_ataque=[Vector2.DOWN,Vector2.RIGHT,Vector2.UP,Vector2.LEFT][d]
   jogador.velocity=Vector2.ZERO;jogador._fase_combo=1;jogador.ataque_enfileirado=false
   jogador.iniciar_slash_ataque("AtaqueEspadaSlash_1",jogador._tempo_slash_1)
   var vistos=[];var inicio=Time.get_ticks_msec();var mudancas=[]
   while jogador._esta_atacando and Time.get_ticks_msec()-inicio<1500:
    visual._process(0)
    var q=visual.frame%4
    if not vistos.has(q):vistos.append(q);mudancas.append([q,Time.get_ticks_msec()-inicio])
    await process_frame
   conferir(vistos==[0,1,2,3] and not jogador._esta_atacando,"Ataque real completa quatro poses e solta a arma: %s/%d"%[tipo,d])
   tempos[tipo].append({"direcao":d,"quadros_ms":mudancas,"duracao_ms":Time.get_ticks_msec()-inicio})
 FileAccess.open(PASTA+"tempos_reais.json",FileAccess.WRITE).store_string(JSON.stringify(tempos,"\t"))
 jogador._temporizador.process_mode=Node.PROCESS_MODE_INHERIT
