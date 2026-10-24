extends SceneTree
var falhas := 0
var sessao: Node
var lobby: Node
var jogador: Node2D
var papel := "A"
func _initialize() -> void: rodar.call_deferred()
func conferir(ok: bool, texto: String) -> void:
 print("OK " if ok else "FALHA ",papel," ",texto)
 if not ok: falhas+=1
func esperar(condicao: Callable, descricao: String, segundos := 12.0) -> void:
 var limite := Time.get_ticks_msec()+int(segundos*1000)
 while not condicao.call() and Time.get_ticks_msec()<limite: await create_timer(0.05).timeout
 conferir(condicao.call(),descricao)
func quadros(n := 12) -> void:
 for i in n: await process_frame
func foto(nome: String) -> void:
 if DisplayServer.get_name()=="headless": return
 await quadros(4)
 RenderingServer.force_draw()
 root.get_texture().get_image().save_png("/tmp/algoland-lobby-"+papel+"-"+nome+".png")
func rodar() -> void:
 assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes lobby rede"))
 papel = "B" if "--papel=B" in OS.get_cmdline_user_args() else "A"
 root.mode=Window.MODE_WINDOWED
 root.size=Vector2i(1152,648)
 root.content_scale_size=Vector2i(576,324)
 var opcoes := ConfigFile.new()
 opcoes.set_value("opcoes","volume_musica",0.37)
 opcoes.save("user://opcoes.cfg")
 root.get_node("Ranking").conexao_habilitada=false
 root.get_node("Introducao").pular_prologo()
 root.get_node("Transicao").hora_salva=12
 change_scene_to_file("res://cenas/cidade.tscn")
 await quadros(30)
 jogador=current_scene.get_node("Jogador")
 jogador.set_physics_process(false)
 jogador.position=Vector2(336,352) if papel=="A" else Vector2(392,312)
 jogador.apelido="ALFEIM_TESTE" if papel=="A" else ""
 jogador.aparencia_raven={"pele":1 if papel=="A" else 2,"cabelo":12 if papel=="A" else 28,"roupa":8 if papel=="A" else 3,"cor":[0.3,0.6,1,1]}
 jogador.camera.position_smoothing_enabled=false
 jogador.camera.set_as_top_level(true)
 jogador.camera.global_position=Vector2(380,320)
 lobby=current_scene.get_node("LobbyCidade")
 sessao=lobby.sessao_de(jogador)
 await create_timer(0.4).timeout
 conferir(not sessao.online and not sessao.conectado,"cidade começa offline")
 conferir(lobby.remotos.is_empty(),"offline não cria avatares de outros jogadores")
 var ui:=current_scene.get_node("Interface")
 var tela: Control=ui._telas.lobby
 conferir(not tela._botao_hud.visible and tela._botao_hud.icon!=null and tela._botao_hud.text.is_empty(),"PC não mostra o ícone: o registro do chat fica no canto")
 conferir(tela._historico.visible and not tela._historico_campo.visible,"PC mostra o registro offline sem campo de texto")
 tela._botao_hud.pressed.emit()
 await quadros()
 conferir(ui._telas_abertas.has("lobby"),"clicar no ícone abre o chat")
 await foto("offline")
 tela._alternar.pressed.emit()
 await esperar(func(): return sessao.conectado and sessao.participantes.size()==2,"duas instâncias reais se encontram")
 await esperar(func(): return lobby.remotos.size()==1,"outro jogador aparece uma única vez")
 conferir(sessao.online,"modo online ativo após o botão")
 opcoes.load("user://opcoes.cfg")
 conferir(opcoes.get_value("lobby","online_p1",false) and is_equal_approx(float(opcoes.get_value("opcoes","volume_musica")),0.37),"preferência salva sem alterar outras opções")
 if papel=="A":
  jogador.position.y+=24
  conferir(sessao.enviar_mensagem("OI GALERA DO LOBBY")=="","chat aceita mensagem")
  await esperar(func(): return sessao.mensagens.size()>=2,"recebe resposta do outro cliente")
 else:
  await esperar(func(): return sessao.mensagens.size()>=1,"recebe a mensagem de A")
  await esperar(func(): return not lobby.remotos.is_empty() and lobby.remotos.values()[0].position.y>370,"movimento remoto acompanha a posição enviada")
  conferir(sessao.enviar_mensagem("RESPOSTA "+"W".repeat(140))=="","envia texto longo de volta")
  await esperar(func(): return sessao.mensagens.size()>=2,"confirma própria mensagem sem duplicar")
 await esperar(func(): return sessao._envio.is_empty(),"envio confirmado limpa a fila")
 conferir(sessao.mensagens.size()==2,"cada mensagem aparece uma vez")
 await create_timer(1.6).timeout
 var parado_antes: Vector2=lobby.remotos.values()[0].position
 for i in 5:
  await create_timer(0.5).timeout
  pass
 conferir(lobby.remotos.values()[0].position.distance_to(parado_antes)<1.0,"avatar remoto parado não anda sozinho")
 await quadros(8)
 conferir(not tela._falas._falas.is_empty(),"mensagem nova cria balão sobre o personagem")
 ui._fechar_tela("lobby")
 await quadros(8)
 await foto("balao-recebido")
 conferir(tela._historico.visible and tela._historico_campo.visible,"PC mostra o registro e o campo no canto quando online")
 conferir(tela._historico_texto.get_parsed_text().count("\n")>=1 and tela._historico_texto.get_parsed_text().contains(": "),"registro do canto lista as mensagens")
 conferir(tela._historico.position.x>=0 and tela._historico.position.y>=0 and tela._historico.position.y+tela._historico.size.y<=tela.size.y and tela._historico.position.x+tela._historico.size.x<=tela.size.x,"registro do canto cabe na tela")
 tela._historico_campo.grab_focus()
 await quadros(2)
 var controle: Node=root.get_node("Controle")
 conferir(controle.digitando and controle.vetor_movimento()==Vector2.ZERO,"digitar no canto não move o personagem")
 var tecla_m:=InputEventKey.new()
 tecla_m.keycode=KEY_M
 tecla_m.physical_keycode=KEY_M
 tecla_m.pressed=true
 root.push_input(tecla_m)
 await quadros(3)
 conferir(not ui._telas_abertas.has("mapa_mundi"),"digitar M no chat do canto não abre o mapa")
 tela._historico_campo.text=""
 tela._enviar_do_canto("")
 await quadros(2)
 conferir(not controle.digitando and not tela._historico_campo.has_focus(),"enviar vazio devolve o controle ao jogo")
 for fala in tela._falas._falas.values():
  conferir(fala.rotulo.max_lines_visible<=3,"balão longo mostra no máximo três linhas por trecho")
  conferir(fala.rotulo.get_theme_stylebox("normal")!=null,"balão usa moldura das falas dos NPCs")
 ui._abrir_tela("lobby")
 if papel=="A":
  for medida in [Vector2i(576,324),Vector2i(288,216),Vector2i(288,512),Vector2i(320,324)]:
   root.content_scale_size=medida; root.size=medida*2
   await quadros(25)
   conferir(Rect2(Vector2.ZERO,tela.size).encloses(tela.painel.get_global_rect()),"painel cabe em "+str(medida))
   for botao: Button in [tela._alternar,tela._enviar,tela._fechar]: conferir(tela.painel.get_global_rect().grow(-8).encloses(botao.get_global_rect()),"botão com margens em "+str(medida))
   for linha in tela._lista.get_children(): conferir(linha.size.x<=tela._rolagem.size.x-6,"mensagem longa cabe na coluna")
   await foto("chat-%dx%d" % [medida.x,medida.y])
   ui._fechar_tela("lobby")
   var outro_id: String=lobby.remotos.keys()[0]
   tela._falas.mostrar(outro_id,"Mensagem longa "+"W".repeat(140))
   await quadros(10)
   var rotulo: Label=tela._falas._falas[outro_id].rotulo
   conferir(rotulo.visible and rotulo.max_lines_visible<=3,"balão visível e compacto em "+str(medida))
   conferir(Rect2(Vector2.ONE*6,tela.size-Vector2.ONE*12).encloses(rotulo.get_global_rect()),"balão cabe com margem em "+str(medida))
   await foto("balao-%dx%d" % [medida.x,medida.y])
   ui._abrir_tela("lobby")
  root.content_scale_size=Vector2i(576,324);root.size=Vector2i(1152,648)
  ui._fechar_tela("lobby")
  conferir(Rect2(Vector2.ZERO,tela.size).grow(-6).encloses(tela._botao_hud.get_global_rect()),"botão da cidade cabe com margem inferior")
  for estacao in 4:
   root.get_node("Calendario").dia=estacao*30+1
   current_scene.get_node("Terrains/Estacoes").definir_estacao(estacao,true)
   current_scene._ao_estacao(estacao)
   await quadros(12)
   await foto("cidade-estacao-%d"%estacao)
  var remoto: Node2D=lobby.remotos.values()[0]
  remoto.set_process(false)
  for direcao in 4:
   for quadro in 6:
    remoto.corpo.pose(true,direcao,quadro*0.1)
    await foto("corrida-%d-%d"%[direcao,quadro])
  remoto.set_process(true)
  ui._abrir_tela("lobby")
  await quadros()
  tela._abrir_teclado()
  tela._teclado.texto="W".repeat(160)
  tela._teclado._atualizar_rotulo()
  await foto("teclado")
  tela._teclado.fechar()
  sessao.enviar_mensagem("VOU FICAR OFFLINE")
  await esperar(func(): return sessao._envio.is_empty(),"mensagem antes de sair foi confirmada")
  await create_timer(1.0).timeout
  tela._alternar.pressed.emit()
  await quadros()
  conferir(not sessao.online and not sessao.conectado and lobby.remotos.is_empty(),"offline desconecta e remove os avatares")
  opcoes.load("user://opcoes.cfg")
  conferir(not opcoes.get_value("lobby","online_p1",true),"preferência offline salva")
  await foto("voltou-offline")
  ui._fechar_tela("lobby")
  root.get_node("Controle").usando_toque=true
  root.content_scale_size=Vector2i(288,216);root.size=Vector2i(864,648)
  await quadros(20)
  conferir(tela._botao_hud.visible,"ícone de chat também aparece no celular")
  conferir(Rect2(Vector2.ZERO,tela.size).grow(-6).encloses(tela._botao_hud.get_global_rect()),"ícone com margens no celular")
  tela._falas.mostrar(sessao.eu,"Balao longo "+"W".repeat(145))
  # Offline não pode manter uma fala antiga na cidade.
  await quadros(4)
  conferir(tela._falas._falas.is_empty(),"ficar offline limpa os balões")
  var botao_mapa: Control=null
  for no in get_nodes_in_group("toque_hud"):
   if no.name=="BotaoMapaMundi": botao_mapa=no
  conferir(botao_mapa!=null,"botão do mapa existe no celular")
  if botao_mapa!=null:
   var tr_mapa: Transform2D=botao_mapa.get_global_transform_with_canvas()
   var tr_chat: Transform2D=tela._botao_hud.get_global_transform_with_canvas()
   var rect_mapa: Rect2=Rect2(tr_mapa.origin,botao_mapa.size*tr_mapa.get_scale())
   var rect_chat: Rect2=Rect2(tr_chat.origin,tela._botao_hud.size*tr_chat.get_scale())
   conferir(rect_chat.end.x<=rect_mapa.position.x+0.5 and rect_chat.end.x>=rect_mapa.position.x-14 and absf(rect_chat.get_center().y-rect_mapa.get_center().y)<3,"ícone de chat fica ao lado esquerdo do botão do mapa")
  await foto("toque-cidade")
  tela._botao_hud.pressed.emit()
  await quadros()
  conferir(ui._telas_abertas.has("lobby"),"toque no ícone abre o chat offline")
  await foto("toque-chat-icone")
  ui._fechar_tela("lobby")
  ui._abrir_tela("pausa")
  await quadros(20)
  await foto("toque-pausa")
  ui._fechar_tela("pausa")
  ui._abrir_tela("lobby")
  await quadros(20)
  tela._abrir_teclado()
  await foto("toque-teclado")
  tela._teclado.fechar()
  ui._fechar_tela("lobby")
  root.get_node("Controle").usando_toque=false
  root.content_scale_size=Vector2i(576,324);root.size=Vector2i(1152,648)
  root.get_node("Cooperativo").entrar(-2)
  await quadros(40)
  var coop:=root.get_node("Cooperativo")
  var p2: Node2D=coop.jogador2()
  p2.set_physics_process(false)
  var outra: Node=lobby.sessao_de(p2)
  conferir(not outra.online,"P2 começa offline independentemente de P1")
  outra.definir_online(true)
  await esperar(func(): return outra.conectado,"P2 pode ficar online sozinho")
  conferir(not sessao.online,"preferência de P2 não altera P1")
  sessao.definir_online(true)
  await esperar(func(): return sessao.conectado and outra.participantes.size()==2,"P1 e P2 têm perfis separados no lobby")
  await quadros(30)
  conferir(lobby.remotos.is_empty(),"jogadores locais não aparecem duplicados")
  var ui2: Node=coop.interface_p2()
  ui2._abrir_tela("lobby")
  await quadros(20)
  conferir(ui2._telas.lobby._sessao==outra,"chat de P2 controla a sessão de P2")
  conferir(ui2._telas.lobby._falas._falas.is_empty(),"histórico antigo não reaparece em balões ao conectar")
  await foto("coop-chat")
  ui2._fechar_tela("lobby")
  outra.definir_online(false)
  conferir(sessao.online,"P2 ficar offline mantém P1 online")
  sessao.definir_online(false)
  ui=coop._vistas[1].get_node("Interface")
  ui._abrir_tela("pausa")
  await quadros(20)
  await foto("coop-pausa")
  ui._fechar_tela("pausa")
  coop.sair()
  await quadros(20)
  sessao.definir_online(true)
  await esperar(func(): return sessao.conectado,"reconecta antes de sair da cidade")
  change_scene_to_file("res://cenas/inicio_do_jogo.tscn")
  await quadros(30)
  await create_timer(3.3).timeout
  conferir(get_nodes_in_group("lobby_cidade").is_empty(),"voltar ao menu remove os avatares da cidade")
 else:
  await esperar(func(): return sessao.mensagens.size()>=3,"A avisa que vai sair",60)
  await esperar(func(): return sessao.participantes.size()==1 and lobby.remotos.is_empty(),"saída de A é refletida no outro cliente")
  conferir(sessao.online and sessao.conectado,"A ficar offline não desconecta B")
  sessao.definir_online(false)
 await create_timer(0.7).timeout
 print("LOBBY ",papel,": ",falhas," falhas")
 quit(1 if falhas else 0)
