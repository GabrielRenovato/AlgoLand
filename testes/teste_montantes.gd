extends SceneTree
const Receitas=preload("res://codigo/dados/forja_armas.gd")
var falhas=0
var verificacoes=0
func conferir(ok: bool, mensagem: String):
 verificacoes+=1
 if not ok:falhas+=1;push_error(mensagem)
func esperar(n: int):
 for i in n:await process_frame
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
 var jogador=current_scene.get_node("Jogador");var inv=jogador.inventario
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
  indice+=1
 # O id da última espada permanece ao trocar para lança: não pode contaminar o porte.
 var lanca=Receitas.criar_item("lanca_basica");inv.adicionar(lanca);inv.equipar(lanca);jogador.no_reacao.encerrar()
 conferir(inv.equipar(inv.buscar_por_tipo("espada_basica")) and jogador.id_arma_atual=="espada_basica","Trocar montante por espada volta à espada original")

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
