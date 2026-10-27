extends "res://ferramentas/armaduras/revisar_mordomo_3d.gd"
func rodar():
 assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
 root.get_node("Ranking").conexao_habilitada=false
 root.get_node("Introducao").pular_prologo()
 root.get_node("Transicao").hora_salva=12.
 change_scene_to_file("res://cenas/fazenda.tscn")
 await esperar(35)
 j=current_scene.get_node("Jogador");j.set_physics_process(false);j.no_fazenda.set_process(false)
 h=j.get_node("HeroiBase3D");h.set_process(false)
 for slot in j.inventario.equipados:j.inventario.equipados[slot]=null
 j.roupa_atual=0;h._armaduras.atualizar();h._costas.visible=false;h._mao.visible=false;h._mao_esquerda.visible=false;h._rastro.layers=0
 var fase: String="antes" if "--antes" in OS.get_cmdline_user_args() else "depois"
 saida="res://arte/previas/personagens/base_3d/tintura_cabelo/"+fase+"/"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(saida))
 vp=SubViewport.new();vp.size=h._vp.size;vp.transparent_bg=true;vp.world_2d=World2D.new();vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(vp)
 sprite=Sprite2D.new();sprite.centered=false;sprite.texture=h._vp.get_texture();sprite.material=h._sprite.material;sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;vp.add_child(sprite)
 var paleta: Array=load("res://codigo/ui/tela_criacao_personagem.gd").PALETA
 for estilo in ["cabelo_curto","cabelo_chanel","cabelo_longo","cabelo_espetado"]:
  var roupas: Dictionary=h.CATALOGO_ROUPAS.padrao();roupas.cabelo=estilo;h.definir_roupas_3d(roupas)
  for indice in [8,6,7,15]:
   var cor: Color=paleta[indice]
   j.aparencia_raven={"pele":0,"olhos":1,"cor":[cor.r,cor.g,cor.b,1.]}
   h._aplicar_cores()
   conferir(h._pecas[3].material_override.get_shader_parameter("cor_cabelo").is_equal_approx(cor),"Tintura chega ao material "+estilo)
   for d in [0,2,4,6]:
    pose("parado",d,0);await foto("%s_cor%d_%d"%[estilo,indice,d])
 print("TINTURA: ",verificacoes," verificações; ",falhas," falhas; 64 vistas em save isolado")
 quit(0 if falhas==0 else 1)
