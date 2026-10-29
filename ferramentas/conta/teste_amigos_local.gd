extends SceneTree
## Amigos e convites contra servidor_falso.py (mesmo uso dos outros testes da conta).
var falhas := 0
var recebidos: Array = []
func conferir(ok: bool, nome: String) -> void:
	print(("OK    " if ok else "FALHA ") + nome)
	if not ok: falhas += 1
func _initialize(): rodar.call_deferred()
func rodar() -> void:
	assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
	var conta = load("res://codigo/conta/cliente_conta.gd").obter(self)
	var amigos = conta.amigos
	conta._limpar_sessao()
	# O convite abriria o aviso na tela; aqui só registramos.
	for c in amigos.convite_recebido.get_connections(): amigos.convite_recebido.disconnect(c.callable)
	amigos.convite_recebido.connect(func(c: Dictionary): recebidos.append(c))
	var ranking = root.get_node("Ranking")
	var original: String = ranking._codigo
	ranking._codigo = "a1".repeat(18)
	await conta.criar("ana.amigos@teste.com", "12345678", "ANA")
	await amigos.atualizar()
	var codigo_ana: String = amigos.codigo
	conferir(codigo_ana.length() >= 5, "Ana recebe um codigo de amigo")
	await conta.sair()
	ranking._codigo = "b2".repeat(18)
	await conta.criar("beto.amigos@teste.com", "12345678", "BETO")
	await amigos.atualizar()
	conferir(await amigos.pedir("ZZZZZZ") == "CODIGO NAO ENCONTRADO", "codigo inexistente")
	conferir(await amigos.pedir(amigos.codigo) == "ESTE E O SEU PROPRIO CODIGO", "nao adiciona a si mesmo")
	conferir(await amigos.pedir(codigo_ana.to_lower()) == "PEDIDO ENVIADO", "pedido por codigo (minusculas)")
	conferir(amigos.lista.size() == 1 and amigos.lista[0].estado == "enviado", "Beto ve o pedido como enviado")
	conferir(await amigos.pedir(codigo_ana) == "PEDIDO JA ENVIADO, AGUARDE A RESPOSTA", "pedido repetido")
	var codigo_beto: String = amigos.codigo
	await conta.sair()
	await conta.entrar("ana.amigos@teste.com", "12345678")
	await amigos.atualizar()
	conferir(amigos.lista.size() == 1 and amigos.lista[0].estado == "recebido" and amigos.lista[0].apelido == "BETO", "Ana ve o pedido recebido")
	conferir(await amigos.convidar(codigo_beto, "coop", "ABCDEF012345", 3) == "VOCES NAO SAO AMIGOS", "convite so entre amigos")
	await amigos.responder(codigo_beto, true)
	conferir(amigos.lista[0].estado == "amigo", "pedido aceito vira amizade")
	conferir(await amigos.convidar(codigo_beto, "coop", "ABCDEF012345", 3) == "CONVITE ENVIADO", "convite para a sala enviado")
	await conta.sair()
	await conta.entrar("beto.amigos@teste.com", "12345678")
	await amigos.verificar_convites()
	conferir(recebidos.size() == 1 and recebidos[0].sala == "ABCDEF012345" and recebidos[0].de == "ANA" and int(recebidos[0].andar) == 3, "Beto recebe o convite com sala e andar")
	await amigos.verificar_convites()
	conferir(recebidos.size() == 1, "o mesmo convite nao avisa duas vezes")
	await amigos.descartar(int(recebidos[0].id))
	var r: Dictionary = await conta.chamar("listar_convites")
	conferir(r.lista.is_empty(), "convite descartado some")
	await amigos.atualizar()
	conferir(amigos.lista.size() == 1 and amigos.lista[0].estado == "amigo" and amigos.lista[0].apelido == "ANA", "Beto ve Ana como amiga")
	await amigos.remover(amigos.lista[0].codigo)
	conferir(amigos.lista.is_empty(), "remover amigo")
	ranking._codigo = original
	conta._limpar_sessao()
	print("AMIGOS: ", falhas, " falhas")
	quit(1 if falhas else 0)
