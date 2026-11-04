extends SceneTree
## Reentradas por região e pelo fluxo de carregar a cena; somente saves isolados.
var falhas:=0
var cena:Node2D
func _initialize():rodar.call_deferred()
func verificar(nome:String,ok:bool):
 print("OK " if ok else "FALHA ",nome)
 if not ok:falhas+=1
func quadros(n:=8):
 for i in n:await process_frame;await physics_frame
func parar_cinema():
 for no in cena.get_children():
  if no.has_method("pular") and no.get("ativa"):no.pular()
 if cena.cinema_cidade_ativa():cena.cinema_cidade.pular()
 await quadros(30)
func capturar(nome:String):
 await RenderingServer.frame_post_draw
 verificar("captura "+nome,root.get_texture().get_image().save_png("res://capturas-instancias/"+nome+".png")==OK)
func rodar():
 if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"):quit(1);return
 DirAccess.make_dir_recursive_absolute("res://capturas-instancias")
 var catalogo=load("res://codigo/campanha/catalogo_campanha.gd").dados()
 var classe=load("res://codigo/campanha/progresso_campanha.gd")
 var progresso=classe.new();verificar("prepara historico isolado",progresso.iniciar("user://percurso_primeira_raiz","prototipo")==OK)
 for missao in ["sobreviver_queda","estrada_interrompida","acolhimento","pomar_sulcos"]:
  for o in catalogo.missoes[missao].objetivos:verificar("conclusao historica "+o.id,progresso.registrar_objetivo(missao,o.id)==OK)
 progresso.salvar_retorno("chegada",Vector2(100,100))
 root.mode=Window.MODE_WINDOWED;root.content_scale_size=Vector2i(576,324);root.size=Vector2i(1152,648)
 get_tree_meta("chegada")
 change_scene_to_file("res://cenas/campanha/percurso_prototipo.tscn")
 await quadros(80);cena=current_scene
 var j:Node=cena.jogador
 j.invulneravel=true
 var inv:Node=j.inventario
 var maestria:Node=j.maestria
 maestria.modelo.adicionar_xp("espada",100)
 var xp:int=maestria.modelo.experiencia.espada
 var arma=inv.equipados.arma
 verificar("entrada real comeca do zero",cena.controlador.progresso.objetivos_cumpridos("sobreviver_queda").is_empty() and not cena.controlador.progresso.bau_resgate_aberto)
 verificar("abertura longa reaparece e pode pular",cena.get_children().any(func(no):return no.has_method("pular") and no.get("ativa")))
 await parar_cinema()
 verificar("pular devolve controle",j.movimento_habilitado and not j.has_meta("invocacao"))
 var antes_cidade=cena.controlador.progresso.objetivos_cumpridos("acolhimento").duplicate()
 verificar("cidade abre sem expedição",cena.abrir_regiao("vila")==OK)
 await quadros(35)
 verificar("cidade conserva missões e não repete acolhimento",cena.controlador.progresso.objetivos_cumpridos("acolhimento")==antes_cidade and is_instance_valid(cena.lobby_cidade) and cena.lobby_cidade.mapa==4 and not cena.cinema_cidade_ativa())
 verificar("nova visita conserva missões da cidade",cena.abrir_regiao("vila")==OK and cena.controlador.progresso.objetivos_cumpridos("acolhimento")==antes_cidade)
 var correspondencias:Dictionary={"chegada":"sobreviver_queda","estrada":"estrada_interrompida","pomar":"pomar_sulcos"}
 for regiao in correspondencias:
  var missao:String=correspondencias[regiao]
  for tentativa in 2:
   verificar("abre nova instancia %s %d" % [regiao,tentativa],cena.abrir_regiao(regiao)==OK)
   await quadros(35)
   var p=cena.controlador.progresso
   verificar("objetivos reiniciam %s %d" % [regiao,tentativa],p.objetivos_cumpridos(missao)==(["pedido"] if regiao=="pomar" else []) and not p.missao_concluida(missao))
   verificar("tempo reinicia "+regiao,cena.controlador.tempo_ativo(regiao)<10)
   if regiao=="vila":
    verificar("cinema de Dara reaparece",cena.cinema_cidade_ativa())
    for i in 180:
     if cena.cinema_cidade._preparada:break
     await quadros(1)
    for medida in [Vector2i(576,324),Vector2i(288,512),Vector2i(320,324)]:
     root.content_scale_size=medida;root.size=medida*2;await quadros(5)
     verificar("pular cinema cabe "+str(medida),Rect2(Vector2.ZERO,Vector2(medida)).encloses(cena.cinema_cidade._pular.get_global_rect()))
     await capturar("pular-vila-%d-%d" % [tentativa,medida.x])
    root.content_scale_size=Vector2i(576,324);root.size=Vector2i(1152,648)
   await parar_cinema()
   verificar("equipamento e dominio permanecem",inv.equipados.arma==arma and maestria.modelo.experiencia.espada==xp)
   verificar("acessos historicos permanecem",p.acesso_liberado("estrada") and p.acesso_liberado("vila") and p.acesso_liberado("pomar"))
   if regiao=="chegada":
    verificar("bau fechado na reentrada",not p.bau_resgate_aberto and cena.terreno.estado_bau==cena.terreno.EstadoBau.FECHADO)
   if regiao=="estrada":
    verificar("rebentos da estrada renascem",not get_nodes_in_group("enemy").filter(func(n):return is_instance_valid(n) and not n.get("esta_morto") and cena.terreno.is_ancestor_of(n)).is_empty())
   # Eventos validados avançam também quando o histórico já tinha a missão completa.
   cena.controlador.progresso.tempos_regioes[regiao]=200
   for o in catalogo.missoes[missao].objetivos:
    if o.id in p.objetivos_cumpridos(missao):continue
    if regiao=="pomar" and o.id=="relato":
     var guia=cena.get_children().filter(func(n):return n.has_method("_alvo_atual"))[0]
     var alvo:Dictionary=guia._alvo_atual()
     verificar("seta e distancia apontam saida para entregar",alvo.get("base")==cena.alvos.saida_regiao.no.global_position)
     verificar("retorno à cidade preserva a praça pública",cena.abrir_regiao("vila")==OK)
     await quadros(35);await parar_cinema()
     var salvo=classe.new();salvo.iniciar("user://percurso_primeira_raiz","prototipo")
     verificar("entrega pendente persiste entre cenas", "canal" in salvo.objetivos_cumpridos(missao) and not salvo.missao_concluida(missao))
    if regiao=="chegada" and o.id=="vigilia":
     verificar("encontro do chefe reinicia",cena.encontro.iniciar()==OK)
     for onda in 3:
      cena.encontro._process(2.1)
      for rebento in cena.encontro.criaturas:
       if is_instance_valid(rebento):rebento.queue_free()
      await quadros(1)
     cena.encontro._process(2.1)
     verificar("Cerne renasce vivo",is_instance_valid(cena.encontro.chefe) and not cena.encontro.chefe.esta_morto)
     cena.encontro.chefe.morrer()
     cena.encontro.chefe._physics_process(3.1)
     verificar("morte real libera objetivo e azul novamente",o.id in p.objetivos_cumpridos(missao) and "cerne" in inv.saque_campanha.garantias)
     continue
    verificar("objetivo repetivel "+o.id,cena.controlador.interagir(o.tipo,o.alvo)==OK)
    if regiao=="chegada" and o.id=="resgate":
     cena._preparar_criatura()
     verificar("guardiao inicial renasce",is_instance_valid(cena.inimigo) and not cena.inimigo.esta_morto)
   verificar("tentativa conclui novamente "+regiao,p.missao_concluida(missao))
   if regiao=="chegada":
    verificar("garantia do boss nao duplica nesta tentativa",cena.saque_inicial.receber("boss:%d" % tentativa,"chegada",j.position,"cerne")==ERR_ALREADY_EXISTS)
   var reaberto=classe.new()
   verificar("save conserva historico completo",reaberto.iniciar("user://percurso_primeira_raiz","prototipo")==OK and missao in reaberto.retrato().concluidas)
 # Voltar ao seletor e entrar pelo mesmo caminho do botão Rejogar.
 await parar_cinema()
 change_scene_to_file("res://cenas/campanha/seletor_campanha.tscn");await quadros(30)
 current_scene.selecionado="chegada";current_scene.jogar_solo()
 await quadros(80);cena=current_scene
 verificar("Rejogar cria instancia nova",cena.regiao=="chegada" and cena.controlador.progresso.objetivos_cumpridos("sobreviver_queda").is_empty())
 verificar("maestria persiste entre cenas",cena.jogador.maestria.modelo.experiencia.espada==xp)
 await parar_cinema()
 # Sair antes de coletar novamente não pode apagar armas já conquistadas.
 change_scene_to_file("res://cenas/campanha/seletor_campanha.tscn");await quadros(20)
 current_scene.selecionado="chegada";current_scene.jogar_solo()
 await quadros(50);cena=current_scene
 verificar("replay interrompido conserva espada e escudo",cena.jogador.inventario.buscar_por_tipo("espada_basica")!=null and cena.jogador.inventario.buscar_por_tipo("escudo_basico")!=null)
 await parar_cinema()
 await parar_cinema()
 verificar("pode trocar de estagio com replay incompleto",cena.abrir_regiao("estrada")==OK)
 await quadros(5)
 verificar("combate da estrada independe do replay da chegada",not cena.jogador.ataques_bloqueados)
 print("FALHAS: ",falhas);quit(1 if falhas else 0)
func get_tree_meta(regiao:String):
 root.get_tree().set_meta("campanha_destino",regiao)
 root.get_tree().set_meta("campanha_nova_instancia",true)
