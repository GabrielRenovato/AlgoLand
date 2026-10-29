extends SceneTree
## Teste do cliente de conta contra servidor_falso.py. Rodar na cópia de testes:
##   python3 ferramentas/conta/servidor_falso.py 8799 &
##   godot --path /tmp/algoland-testes --script res://ferramentas/conta/teste_conta_local.gd -- --conta-url=http://127.0.0.1:8799
var falhas := 0
func conferir(ok: bool, nome: String) -> void:
	print(("OK    " if ok else "FALHA ") + nome)
	if not ok: falhas += 1
func _initialize(): rodar.call_deferred()
func rodar() -> void:
	assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
	var Cliente = load("res://codigo/conta/cliente_conta.gd")
	var conta = Cliente.obter(self)
	conta._limpar_sessao()
	conferir(conta.disponivel(), "cliente disponivel apontando para o servidor local")
	conferir(Cliente.url_base().begins_with("http://127.0.0.1"), "endereco de teste aceito so em localhost")
	conferir(await conta.criar("a@b", "12345678", "ANA") == "E-MAIL INVALIDO", "e-mail invalido recusado no cliente")
	conferir(await conta.criar("ana@teste.com", "123", "ANA") == "SENHA FRACA: USE 8 OU MAIS CARACTERES", "senha curta recusada no cliente")
	conferir(await conta.criar("ana@teste.com", "12345678", "ANA") == "", "criar conta devolve sucesso")
	conferir(conta.logado() and conta.vinculo == "ok", "conta criada ja entra e vincula o codigo atual")
	conferir(await conta.criar("ana@teste.com", "12345678", "ANA") == "ESTE E-MAIL JA TEM CONTA", "e-mail repetido recusado")
	var codigo_local: String = root.get_node("Ranking").codigo_secreto()
	await conta.sair()
	conferir(not conta.logado(), "sair limpa a sessao")
	conferir(await conta.entrar("ana@teste.com", "errada123") == "E-MAIL OU SENHA INCORRETOS", "senha errada recusada")
	conferir(await conta.entrar("ana@teste.com", "12345678") == "", "entrar com a senha certa")
	conferir(conta.vinculo == "ok", "mesmo codigo continua vinculado")
	# Reabrir o jogo: a renovação guardada no disco restaura a sessão sem pedir senha.
	var anterior: String = conta._renovacao
	conta._acesso = ""
	conta._renovacao = ""
	conta._carregar()
	conferir(conta._renovacao == anterior and not anterior.is_empty(), "renovacao gravada cifrada e relida")
	conferir(await conta.restaurar() and conta.logado(), "restaurar sessao ao abrir o jogo")
	# Outro aparelho: a conta já tem um código e o novo aparelho tem outro.
	var ranking = root.get_node("Ranking")
	var original: String = ranking._codigo
	ranking._codigo = "ff".repeat(18)
	conferir(await conta.vincular() == "outro_codigo" and conta.codigo_da_conta == codigo_local, "outro aparelho recebe o codigo da conta sem sobrescrever o local")
	ranking._codigo = original
	# Segunda conta tentando usar o código da primeira.
	await conta.sair()
	conferir(await conta.criar("beto@teste.com", "12345678", "BETO") == "", "segunda conta criada")
	conferir(conta.vinculo == "codigo_em_uso", "codigo ja ligado a outra conta nao e roubado")
	conferir(await conta.recuperar("beto@teste.com") == "", "recuperar senha envia o link")
	conta._limpar_sessao()
	print("CONTA: ", falhas, " falhas")
	quit(1 if falhas else 0)
