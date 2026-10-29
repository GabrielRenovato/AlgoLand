extends SceneTree
## Teste da nuvem contra servidor_falso.py, na cópia de testes (perfil isolado "AlgoLand testes ..."):
##   python3 ferramentas/conta/servidor_falso.py 8799 &
##   godot --path /tmp/algoland-testes --script res://ferramentas/conta/teste_nuvem_local.gd -- --conta-url=http://127.0.0.1:8799
var falhas := 0
func conferir(ok: bool, nome: String) -> void:
	print(("OK    " if ok else "FALHA ") + nome)
	if not ok: falhas += 1
func _initialize(): rodar.call_deferred()

func gravar(nome: String, dados: Dictionary) -> void:
	var f := FileAccess.open("user://" + nome, FileAccess.WRITE)
	f.store_string(JSON.stringify(dados))
	f.close()

func montar_save(dia: int, recorde: int) -> void:
	gravar("configuracao_jogador.json", {"apelido": "T"})
	gravar("calendario.json", {"dia": dia})
	gravar("progresso.json", {"recorde_onda": recorde, "brasas": 7})
	gravar("versao_save.json", {"versao": 2})

func rodar() -> void:
	assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
	var Nuvem = load("res://codigo/conta/nuvem_save.gd")
	var conta = load("res://codigo/conta/cliente_conta.gd").obter(self)
	var nuvem = conta.nuvem
	conta._limpar_sessao()
	nuvem._rev = 0
	nuvem._hash = ""
	nuvem._usuario = ""
	# Codificação ida e volta
	var amostra := {"formato": 1, "arquivos": {"a.json": "{\"x\": 1}"}}
	var voltou: Dictionary = Nuvem.decodificar(Nuvem.codificar(amostra))
	conferir(int(voltou.get("formato", 0)) == 1 and voltou.get("arquivos", {}).get("a.json", "") == "{\"x\": 1}", "codificar e decodificar sem perdas")
	conferir(Nuvem.resumo_de({"arquivos": {"calendario.json": "{\"dia\": 12}", "progresso.json": "{\"recorde_onda\": 5, \"brasas\": 9}"}}) == {"dia": 12, "recorde": 5, "brasas": 9}, "resumo do save")
	# Aparelho A: cria conta e sobe o progresso atual
	montar_save(3, 2)
	conferir(await conta.criar("nuvem@teste.com", "12345678", "NUVEM") == "", "conta criada")
	conferir(await nuvem.sincronizar("login") == "ok" and nuvem._rev == 1, "primeiro envio cria a revisao 1")
	conferir(await nuvem.sincronizar("manual") == "ok" and nuvem._rev == 1, "sem mudancas nao sobe de novo")
	montar_save(4, 3)
	conferir(await nuvem.sincronizar("manual") == "ok" and nuvem._rev == 2, "mudanca sobe a revisao 2")
	# Aparelho B (simulado): sem save local, outra revisao conhecida => baixa so no titulo
	var arquivos_a: Dictionary = Nuvem.decodificar((await conta.chamar("baixar_nuvem", {"p_anterior": false})).pacote)
	conferir(Nuvem.resumo_de(arquivos_a).dia == 4, "nuvem guarda o ultimo save")
	var anterior: Dictionary = await conta.chamar("baixar_nuvem", {"p_anterior": true})
	conferir(bool(anterior.get("existe", false)) and Nuvem.resumo_de(Nuvem.decodificar(str(anterior.pacote))).dia == 3, "versao anterior fica guardada")
	# Conflito: outro aparelho avancou (simulado por rev local antigo) e este tambem mudou
	nuvem._rev = 1
	montar_save(9, 6)
	var resultado: String = await nuvem.sincronizar("manual")
	conferir(resultado == "conflito" and nuvem.conflito.local.dia == 9 and nuvem.conflito.nuvem.dia == 4, "conflito detectado com resumo dos dois lados")
	# Manter este aparelho: sobrescreve a nuvem (a anterior fica guardada)
	conferir(await nuvem.resolver(false) == "ok" and nuvem._rev == 3 and nuvem.conflito.is_empty(), "manter este aparelho grava a revisao 3")
	var atual: Dictionary = Nuvem.decodificar((await conta.chamar("baixar_nuvem", {"p_anterior": false})).pacote)
	conferir(Nuvem.resumo_de(atual).dia == 9, "nuvem agora tem o save mantido")
	# Nuvem adiante sem mudanca local, fora do titulo: avisa e nao aplica
	nuvem._rev = 2
	nuvem._hash = Nuvem.hash_de(load("res://codigo/globais/transferencia_save.gd").empacotar())
	conferir(await nuvem.sincronizar("manual") == "nuvem_adiante", "nuvem adiante fora do menu so avisa")
	conferir(Nuvem.resumo_de(load("res://codigo/globais/transferencia_save.gd").empacotar()).dia == 9, "save local intocado fora do menu")
	conta._limpar_sessao()
	print("NUVEM: ", falhas, " falhas")
	quit(1 if falhas else 0)
