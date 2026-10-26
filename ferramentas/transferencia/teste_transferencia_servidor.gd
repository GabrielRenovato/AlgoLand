extends SceneTree
## Ponta a ponta no servidor real: -- --origem envia e grava o código em /tmp; -- --destino recebe e aplica.
const T := preload("res://codigo/globais/transferencia_save.gd")
const CODIGO := "/tmp/algoland_transferencia_codigo.txt"
var falhas := 0
func conferir(ok: bool, texto: String) -> void:
	print(("OK   " if ok else "FALHA ") + texto)
	if not ok: falhas += 1
func _initialize(): rodar.call_deferred()
func rodar():
	assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
	var cliente: Node = T.new()
	root.add_child(cliente)
	var P = root.get_node("Progresso")
	if "--origem" in OS.get_cmdline_user_args():
		P.brasas = 777
		P.maior_onda_vencida = 21
		P.salvar()
		FileAccess.open("user://configuracao_jogador.json", FileAccess.WRITE).store_string(JSON.stringify({"apelido": "TESTE TRANSFERENCIA"}))
		var r: Dictionary = await cliente.enviar()
		conferir(r.has("codigo"), "servidor devolveu código (%s)" % r)
		if r.has("codigo"): FileAccess.open(CODIGO, FileAccess.WRITE).store_string(r.codigo)
	else:
		var codigo := FileAccess.get_file_as_string(CODIGO)
		var errado: Dictionary = await cliente.receber("ZZZ-ZZZ")
		conferir(errado.get("erro", "") == "CODIGO NAO ENCONTRADO OU EXPIRADO", "código errado recusado (%s)" % errado)
		var r: Dictionary = await cliente.receber(codigo.to_lower().replace("-", " "))
		conferir(r.has("pacote"), "recebeu o pacote com o código digitado em minúsculas")
		if r.has("pacote"):
			conferir(T.aplicar(r.pacote) == "", "aplicou")
			root.get_node("Saves").trocar("solo")
			conferir(P.brasas == 777 and P.maior_onda_vencida == 21, "progresso chegou (brasas=%d)" % P.brasas)
		var de_novo: Dictionary = await cliente.receber(codigo)
		conferir(de_novo.has("erro"), "código não vale duas vezes")
	print("TRANSFERENCIA SERVIDOR: %d falhas" % falhas)
	quit()
