extends SceneTree
## Duas inicializações reais com o mesmo save isolado: pausar/fechar antes de entrar não apaga a mochila.
var falhas := 0
func _initialize(): rodar.call_deferred()
func verificar(ok: bool, mensagem: String):
 print("OK " if ok else "FALHA ",mensagem)
 if not ok:falhas+=1
func rodar():
 assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
 await process_frame
 var args=OS.get_cmdline_user_args()
 var saves=root.get_node("Saves")
 var inv=root.get_node("InventarioJogador")
 if "--menu-pausa" in args or "--menu-fechar" in args or "--menu-p2" in args:
  change_scene_to_file("res://cenas/inicio_do_jogo.tscn")
  for i in 12:await process_frame
  verificar(inv.esta_vazio(),"inventário ainda não carregado no menu")
  if "--menu-p2" in args:root.get_node("Cooperativo").ativo=true
  saves._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST if "--menu-fechar" in args else Node.NOTIFICATION_APPLICATION_PAUSED)
  quit(falhas);return
 root.get_node("Introducao").pular_prologo()
 inv.limpar();inv.criar_itens_iniciais()
 for tipo in ["picareta","machadinha","enxada","regador"]:inv.buscar_por_tipo(tipo).nivel=3
 verificar(inv.receber_materiais({"ferro":37,"madeira":52,"pedra":41}),"prepara recursos persistentes")
 var esperado=inv.dados_save()
 var inv2=root.get_node("InventarioJogador2")
 verificar(inv2.gravar_dados(inv2.caminho_save,esperado),"prepara inventário do segundo jogador")
 for modo in ["--menu-pausa","--menu-fechar","--menu-p2"]:
  verificar(inv.gravar_dados(inv.caminho_save,esperado),"prepara save antes da reabertura")
  var saida: Array=[]
  var resultado=OS.execute(OS.get_executable_path(),["--headless","--path",ProjectSettings.globalize_path("res://"),"--script","res://testes/teste_save_menu_inventario.gd","--",modo],saida,true)
  verificar(resultado==0,"reabre no menu e encerra: "+modo)
  verificar(inv.carregar(),"inventário continua legível")
  verificar(inv.quantidade_tipo("material:ferro")==37 and inv.quantidade_tipo("material:madeira")==52 and inv.quantidade_tipo("material:pedra")==41,"minérios e materiais preservados: "+modo)
  for tipo in ["picareta","machadinha","enxada","regador"]:verificar(inv.buscar_por_tipo(tipo)!=null and inv.buscar_por_tipo(tipo).nivel==3,"nível 3 preservado: "+tipo+modo)
 var dados_p2=JSON.parse_string(FileAccess.get_file_as_string(inv2.caminho_save))
 verificar(dados_p2==JSON.parse_string(JSON.stringify(esperado)),"inventário ainda não carregado do P2 preservado")
 # Um estado carregado continua salvando alterações, inclusive se ficar vazio.
 inv.buscar_por_tipo("picareta").nivel=2
 inv.adicionar_coletavel("material","ferro",5)
 saves._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
 verificar(inv.carregar() and inv.quantidade_tipo("material:ferro")==42 and inv.buscar_por_tipo("picareta").nivel==2,"suspender depois de carregar grava o progresso novo")
 var principal=inv.caminho_save
 inv.caminho_save="user://mundo_que_nao_foi_carregado.json"
 verificar(not inv.estado_pronto_para_salvar(),"memória do solo não é save de outro mundo")
 inv.caminho_save=principal
 # O prólogo restaura a mochila por um checkpoint temporário.
 var checkpoint="user://checkpoint_preservacao_teste.json"
 verificar(inv.gravar_dados(checkpoint,esperado) and inv.carregar(checkpoint),"restaura checkpoint de outro arquivo")
 saves._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
 verificar(inv.carregar() and inv.quantidade_tipo("material:ferro")==37 and inv.buscar_por_tipo("picareta").nivel==3,"checkpoint restaurado salva no arquivo do mundo")
 inv.limpar()
 saves._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
 var vazio=JSON.parse_string(FileAccess.get_file_as_string(principal))
 verificar(vazio.mochila.all(func(item):return item==null),"esvaziar mochila já carregada continua persistindo")
 print("SAVE NO MENU: ",falhas," falhas")
 quit(falhas)
