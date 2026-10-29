extends SceneTree
## Exercita peças reais e prévia cosmética, renderizando o rig ativo em save isolado.
const Receitas=preload("res://codigo/dados/forja_armas.gd")
const Mordomo=preload("res://assets/personagens/conjuntos/cavalheiro/definicao.gd")
const Conjuntos=preload("res://codigo/dados/conjuntos_armadura.gd")
var saida="res://arte/previas/armaduras/mordomo_3d/"
var conjunto: GDScript=Mordomo
var id_conjunto="cavalheiro"
var outro_id="carrasco"
var indice_cosmetico=45
var h: Node
var j: Node
var vp: SubViewport
var sprite: Sprite2D
var falhas:=0
var verificacoes:=0
func _initialize():rodar.call_deferred()
func conferir(ok: bool,mensagem: String):
 verificacoes+=1
 if not ok:falhas+=1;push_error(mensagem)
func esperar(n: int):
 for i in n:await process_frame
func equipar(bits: int):
 j.inventario.equipados.clear()
 var tipos=["elmo_"+id_conjunto,"peitoral_"+id_conjunto,"luvas_"+id_conjunto,"botas_"+id_conjunto]
 for i in 4:
  if bits & (1<<i):
   var item=Receitas.criar_item(tipos[i])
   j.inventario.equipados[item.categoria]=item
 h._armaduras.atualizar()
func duracao(acao: String) -> float:
 if acao=="correr":return h.PASSADA/114.0
 if acao.begins_with("fazenda_"):
  var total:=0.0
  for quadro in j.no_fazenda.ACOES[acao.trim_prefix("fazenda_")].quadros:total+=quadro[1]
  return total
 if acao=="arco":
  var total:=0.0
  for tempo in j.no_arco.DURACAO_DISPARO:total+=tempo
  return total
 return h._player.get_animation(h._nome_animacao(acao)).length
func pose(acao: String,d: int,q: float):
 h._modelo.rotation.y=d*TAU/8.0
 j._direcao_ataque=Vector2(sin(d*TAU/8.0),cos(d*TAU/8.0))
 h._acao=acao
 h._progresso_golpe=q
 if acao.begins_with("fazenda_"):
  var nome: String=acao.trim_prefix("fazenda_")
  var dados: Dictionary=j.no_fazenda.ACOES[nome]
  j.no_fazenda.acao_atual=nome
  j.no_fazenda._quadros=dados.quadros
  var tempo:=duracao(acao)*q
  j.no_fazenda._indice=0
  while tempo>=j.no_fazenda._quadros[j.no_fazenda._indice][1]:
   tempo-=j.no_fazenda._quadros[j.no_fazenda._indice][1]
   j.no_fazenda._indice+=1
  j.no_fazenda._tempo=tempo
  j.no_fazenda._impacto_emitido=true
 if acao=="arco":
  var tempo:=duracao(acao)*q
  j.no_arco._indice=0
  while tempo>=j.no_arco.DURACAO_DISPARO[j.no_arco._indice]:
   tempo-=j.no_arco.DURACAO_DISPARO[j.no_arco._indice]
   j.no_arco._indice+=1
  j.no_arco._tempo=tempo
  j.no_arco._escala_tempo=1.0
 var clipe: String=h._nome_animacao(acao)
 var comprimento: float=h._player.get_animation(clipe).length
 var instante: float=comprimento*q
 if acao.begins_with("fazenda_"):
  instante=0.0 if acao=="fazenda_plantar" else h._progresso_fazenda()*comprimento
  if acao=="fazenda_picareta":instante=h._instante_picareta(comprimento)
  if acao=="fazenda_machado":instante=h._instante_machado()
 if acao=="arco":instante=(minf(q/.4,1.0) if q<.4 else (q-.4)/.6)*comprimento
 h._player.play(clipe,0);h._player.pause()
 h._player.seek(instante,true)
func foto(nome: String):
 await RenderingServer.frame_post_draw
 await RenderingServer.frame_post_draw
 vp.get_texture().get_image().save_png(saida+nome+".png")
func conferir_misturas():
 pass
func rodar():
 assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
 root.get_node("Ranking").conexao_habilitada=false
 root.get_node("Introducao").pular_prologo()
 root.get_node("Transicao").hora_salva=12.
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(saida))
 change_scene_to_file("res://cenas/fazenda.tscn")
 await esperar(40)
 root.get_node("Transicao").limpar()
 j=current_scene.get_node("Jogador")
 j.set_physics_process(false);j.no_fazenda.set_process(false)
 j.roupa_atual=0
 h=j.get_node("HeroiBase3D");h.set_process(false)
 h._costas.visible=false;h._mao.visible=false;h._mao_esquerda.visible=false
 h._rastro.layers=0 # Isola o tecido dos rastros acumulados entre poses de amostragem.
 var roupas: Dictionary=h.roupas_3d.duplicate()
 var mochila: Array=j.inventario.fotografar_mochila()
 var antigos: Dictionary=j.inventario.equipados.duplicate()
 vp=SubViewport.new();vp.size=h._vp.size;vp.transparent_bg=true;vp.world_2d=World2D.new();vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 root.add_child(vp)
 sprite=Sprite2D.new();sprite.centered=false;sprite.texture=h._vp.get_texture();sprite.material=h._sprite.material;sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;vp.add_child(sprite)
 equipar(0);pose("parado",0,0);await foto("sem_conjunto")
 for bits in 16:
  equipar(bits)
  # Reproduz os quadros seguintes: atualizar() usa cache, mas cores atualiza
  # a visibilidade novamente. A roupa base não pode reaparecer por cima.
  for quadro in 3:
   h._armaduras.atualizar()
   h._aplicar_cores()
  conferir(h._armaduras.mascara==bits,"Máscara acompanha equipamento real %d"%bits)
  for i in 4:conferir(h._armaduras.malhas[i].visible==bool(bits & (1<<i)),"Peça independente %d/%d"%[bits,i])
  conferir(h._pecas[0].visible==not bool(bits & 2) and h._pecas[1].visible==not bool(bits & 2),"Roupas ocultas sob casaca")
  conferir(h._pecas[2].visible==not bool(bits & 8),"Calçado oculto só com botas")
  if id_conjunto in ["carrasco","cavaleiro_rubro"]:
   if bits & 1:
    conferir(not h._pecas[3].visible,"Elmo fechado recolhe cabelo")
   else:
    conferir(h._pecas[3].visible or h._cabeca_referencia.visible,"Retirar elmo restaura cabelo ou cabeça pintada")
   var pele=h._modelo.find_child("CorpoBase",true,false).material_override
   conferir(bool(pele.get_shader_parameter("elmo_fechado"))==bool(bits & 1),"Rosto restaurado ao retirar elmo")
  conferir((Conjuntos.fator(conjunto,j.inventario.equipados)>0)==(conjunto.quantidade(j.inventario.equipados)>=2),"Bônus conta itens reais")
  pose("parado",0,0);await foto("pecas_%02d"%bits)
 if "--diagnostico" in OS.get_cmdline_user_args():
  for bits in [2,4,15]:
   equipar(bits);pose("espada",0,7./12.);await foto("diagnostico_%d"%bits)
  quit();return
 equipar(2)
 var alternativa: Dictionary=roupas.duplicate()
 alternativa.camisa="jaqueta_viajante"
 alternativa.calca="calca_cargo"
 h.definir_roupas_3d(alternativa)
 h.set_process(true)
 await esperar(6)
 h.set_process(false)
 conferir(not h._pecas[0].visible and not h._pecas[1].visible,"Peitoral substitui roupa base durante atualização real e troca de roupa")
 pose("parado",0,0);await foto("peitoral_atualizacao_real")
 equipar(0)
 h._aplicar_cores()
 conferir(h._pecas[0].visible and h._pecas[1].visible and h.roupas_3d==alternativa,"Retirar peitoral restaura a roupa escolhida")
 h.definir_roupas_3d(roupas)
 equipar(15)
 for d in 8:
  pose("parado",d,0);await foto("parado_%d"%d)
 if "--amostra" not in OS.get_cmdline_user_args():
  var acoes=["correr","espada","lanca","arco","fazenda_picareta","fazenda_machado","fazenda_regar","fazenda_plantar","fazenda_colher","sentado","ferido"]
  var tempos: Dictionary={}
  for acao in acoes:
   tempos[acao]=duracao(acao)
   for d in [0,2,4,6]:
    for q in 12:
     pose(acao,d,q/12.0);await foto("%s_%d_%02d"%[acao,d,q])
  FileAccess.open(saida+"tempos.json",FileAccess.WRITE).store_string(JSON.stringify(tempos,"  "))
  # Confirmar as seis variações de cabelo sob a cartola, sem mudar tintura.
  for modelo in h.CATALOGO_ROUPAS.MODELOS.cabelo:
   var dados:=roupas.duplicate();dados.cabelo=modelo.id;h.definir_roupas_3d(dados)
   for d in [0,4]:pose("parado",d,0);await foto("cabelo_%s_%d"%[modelo.id,d])
 await conferir_misturas()
 equipar(15)
 j.inventario.equipados.cabeca=Receitas.criar_item("elmo_"+outro_id)
 h._armaduras.atualizar()
 conferir(h._armaduras.mascara==15 and h._armaduras.raizes_pecas[0].contains("/"+outro_id+"/") and h._armaduras.raizes_pecas[1].contains("/"+id_conjunto+"/"),"Misturar outro elmo preserva as outras peças")
 equipar(0)
 j.roupa_atual=indice_cosmetico;j._pecas_cavaleiro_debug=15;h._armaduras.atualizar()
 conferir(h._armaduras.mascara==15,"F3 cosmético disponível sem itens")
 conferir(Conjuntos.fator(conjunto,j.inventario.equipados)==0,"Prévia não concede bônus")
 j.roupa_atual=0;h._armaduras.atualizar()
 conferir(h._armaduras.mascara==0,"Retirada restaura roupa e cabelo")
 h.definir_roupas_3d(roupas)
 conferir(h.roupas_3d==roupas,"Roupas escolhidas preservadas")
 conferir(j.inventario.fotografar_mochila()==mochila,"Mochila preservada")
 equipar(15)
 if "--amostra" not in OS.get_cmdline_user_args():
  j.velocity=Vector2.UP*114.0
  h._acao="";h.set_process(true)
  for q in 24:
   await esperar(1)
   await foto("corrida_motor_%02d"%q)
  h.set_process(false);j.velocity=Vector2.ZERO
 pose("parado",0,0)
 await esperar(5)
 await RenderingServer.frame_post_draw
 root.get_viewport().get_texture().get_image().save_png(saida+"no_mapa.png")
 j.inventario.equipados=antigos
 print(conjunto.NOME+" 3D: ",verificacoes," verificações, ",falhas," falhas; peças, restauração, prévia e captura no mapa")
 quit(0 if falhas==0 else 1)
