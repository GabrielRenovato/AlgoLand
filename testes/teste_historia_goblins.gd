extends SceneTree
const Elenco=preload("res://codigo/dados/moradores_primeira_raiz.gd")
var cena:Node2D
var falhas:=0
const CAPTURAS:="res://capturas-historia-goblins"
func _initialize():rodar.call_deferred()
func conferir(texto:String,ok:bool):
 print("OK " if ok else "FALHA ",texto)
 if not ok:falhas+=1
func quadros(n:=8):
 for i in n:await process_frame;await physics_frame
func foto(nome:String):
 await RenderingServer.frame_post_draw
 conferir("captura "+nome,root.get_texture().get_image().save_png(CAPTURAS.path_join(nome+".png"))==OK)
func fechar():
 cena.interface._telas.introducao._fechar_fala()
 await quadros(3)
func rodar():
 if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes") or DisplayServer.get_name()=="headless":quit(1);return
 root.get_node("Ranking").conexao_habilitada=false
 set_meta("dicas_vistas",{"golpe":true,"rebento":true,"vida":true})
 DirAccess.make_dir_recursive_absolute(CAPTURAS)
 var p=load("res://codigo/campanha/progresso_campanha.gd").new()
 p.iniciar("user://percurso_primeira_raiz","prototipo")
 var catalogo=load("res://codigo/campanha/catalogo_campanha.gd").dados()
 for m in ["sobreviver_queda","estrada_interrompida","acolhimento"]:
  for o in catalogo.missoes[m].objetivos:p.registrar_objetivo(m,o.id)
 p.salvar_retorno("vila",Vector2(0,180))
 set_meta("campanha_nova_instancia",false)
 root.mode=Window.MODE_WINDOWED;root.content_scale_size=Vector2i(576,324);root.size=Vector2i(1152,648)
 change_scene_to_file("res://cenas/campanha/percurso_prototipo.tscn")
 await quadros(70);cena=current_scene
 if cena.cinema_cidade_ativa():cena.cinema_cidade.cancelar()
 cena.registro_run.set_process(false)
 cena.registro_run.apresentada=true
 cena.interface._fechar_tela("resultado")
 cena.jogador.invulneravel=true
 conferir("vila real com moradores",cena.regiao=="vila" and cena.moradores.size()==15)
 await conferir_historia_goblins()
 print("FALHAS: ",falhas);quit(1 if falhas else 0)

## Relatos chegam antes do encontro; as reações acompanham as descobertas da campanha.
func conferir_historia_goblins() -> void:
 for id in ["dara","lia","tomas","nilo","osvaldo","ivo"]:
  conferir("apresentacao introduz goblins "+id," ".join(Elenco.conversa(id,0)).to_lower().contains("goblin"))
 conferir("trabalhador avisa da trilha do pomar",cena._fala("trabalhador").contains("goblins") and cena._fala("trabalhador").contains("rebentos"))
 var progresso=cena.controlador.progresso
 var concluidas:Array=progresso._concluidas.duplicate()
 progresso._concluidas.erase("pomar_sulcos")
 progresso._concluidas.erase("moinho_vazao")
 conferir("nao antecipa retomada do moinho",not cena._reacao("nilo").contains("corrente voltou"))
 progresso._concluidas.append("pomar_sulcos")
 conferir("relato do pomar muda Tomas",cena._reacao("tomas").contains("colheita"))
 conferir("Estela preserva misterio das raizes",cena._reacao("estela").contains("Ainda não sabemos"))
 conferir("Nilo prepara encontro no moinho",cena._reacao("nilo").contains("machado"))
 progresso._concluidas.append("moinho_vazao")
 conferir("Dara reage as galerias liberadas",cena._reacao("dara").contains("ronda"))
 conferir("Nilo reconhece agua de volta",cena._reacao("nilo").contains("corrente voltou"))
 cena._visitas_moradores["nilo"]=4
 cena._reacoes_moradores["nilo"]="relato anterior"
 conferir("nova descoberta entra apos varias visitas",cena._conversar_morador("nilo")==OK)
 conferir("reacao nova aparece na conversa real",cena.interface._telas.introducao._paginas[0].contains("corrente voltou"))
 await fechar()
 # Exibe textos reais pelo diálogo usado pelos moradores e pelas missões.
 var falas:Array=[
  ["Tomás",cena.FALAS_PASSOS["pomar_sulcos:pedido"]],
  ["Dara",Elenco.conversa("dara",0)[-1]],
  ["Nilo",cena._reacao("nilo")]]
 for tamanho in [Vector2i(576,324),Vector2i(288,512),Vector2i(288,324)]:
  root.content_scale_size=tamanho;root.size=tamanho*2
  await quadros(3)
  for i in falas.size():
   var paginas:Array[String]=[falas[i][1]]
   var dialogo:Node=cena.interface._telas.introducao
   cena.interface._abrir_tela("introducao")
   dialogo.iniciar(paginas,falas[i][0],"")
   for pagina in dialogo._paginas.size():
    dialogo._digitando.kill();dialogo._texto.visible_ratio=1
    await quadros(20)
    var moldura:Rect2=dialogo.painel.get_global_rect().grow(-8)
    conferir("fala goblins cabe %s/%d/%d" % [tamanho,i,pagina],moldura.encloses(dialogo._texto.get_global_rect()) and not dialogo._texto.get_global_rect().intersects(dialogo._avancar.get_global_rect()) and dialogo._texto.size.y>=dialogo._texto.get_line_count()*dialogo._texto.get_line_height())
    await foto("goblins_%dx%d_%d_%d" % [tamanho.x,tamanho.y,i,pagina])
    if pagina+1<dialogo._paginas.size():dialogo.avancar()
   await fechar()
 progresso._concluidas=concluidas
