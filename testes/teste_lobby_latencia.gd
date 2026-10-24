extends SceneTree

var falhas := 0

func _initialize() -> void:
 rodar.call_deferred()

func conferir(ok: bool, texto: String) -> void:
 if not ok:
  falhas += 1
  print("FALHA ",texto)

func rodar() -> void:
 if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"):
  quit(1)
  return
 # Carrega depois dos autoloads, como as sessões reais da cidade.
 var teste := GDScript.new()
 teste.source_code = 'extends "res://codigo/cidade/sessao_lobby.gd"\nvar pedidos := 0\nfunc _ready(): pass\nfunc _sincronizar():\n pedidos += 1\n _ocupado = true\n _tempo = INTERVALO_CONSULTA\n'
 conferir(teste.reload() == OK,"sessão de teste compila")
 var sessao = teste.new()
 root.add_child(sessao)
 sessao.set_process(false)
 sessao._http = HTTPRequest.new()
 sessao.add_child(sessao._http)
 sessao.online = true
 sessao.conectado = true
 sessao._sincronizar()
 conferir(sessao.enviar_mensagem("Oi durante o pedido") == "","aceita mensagem durante atualização em trânsito")
 sessao._process(0.6)
 conferir(sessao.pedidos == 1,"pedido em trânsito não abre outra conexão")
 var resposta := {"eu":"00000000-0000-0000-0000-000000000001","jogadores":[],"mensagens":[]}
 sessao._receber(0,200,[],JSON.stringify(resposta).to_utf8_buffer())
 conferir(sessao._tempo <= 0,"resposta não acrescenta outro intervalo à mensagem pendente")
 sessao._process(0.01)
 conferir(sessao.pedidos == 2 and sessao._mensagem == "Oi durante o pedido","mensagem segue logo após a resposta atrasada")
 sessao._process(0.2)
 resposta.confirmado = sessao._envio
 sessao._receber(0,200,[],JSON.stringify(resposta).to_utf8_buffer())
 conferir(sessao._envio.is_empty(),"confirmação limpa a mensagem uma vez")
 conferir(sessao.enviar_mensagem("Próxima") == "" and sessao.pedidos == 2,"próxima mensagem respeita apenas intervalo restante")
 sessao._process(0.36)
 conferir(sessao.pedidos == 3,"nova mensagem não espera outro ciclo completo")
 sessao.online = false
 sessao.queue_free()

 var remoto = load("res://codigo/cidade/jogador_lobby.gd").new()
 root.add_child(remoto)
 remoto.set_process(false)
 var amostra := {"id":"teste","apelido":"Outro jogador","direcao":1,"x":100.0,"y":100.0,"instante":10.0}
 remoto.atualizar(amostra,{},true)
 amostra.x = 108.0
 amostra.instante = 11.1
 remoto.atualizar(amostra,{})
 conferir(is_equal_approx(remoto._velocidade,8.0/1.1),"amostra atrasada usa o tempo real sem acelerar o movimento")
 remoto._process(0.2)
 var velocidade: float = remoto._velocidade
 remoto.atualizar(amostra,{})
 conferir(is_equal_approx(remoto._velocidade,velocidade),"snapshot repetido não reinicia o movimento")
 var anterior := amostra.duplicate()
 anterior.instante = 10.5
 anterior.x = 102.0
 remoto.atualizar(anterior,{})
 conferir(remoto._ultimo_destino == Vector2(108,100),"snapshot antigo não faz o jogador voltar")
 remoto._process(0.9)
 conferir(remoto.position.distance_to(Vector2(108,100))<0.01,"chega ao destino no tempo da amostra")
 remoto.queue_free()
 print("LOBBY LATENCIA: ",falhas," falhas")
 quit(1 if falhas else 0)
