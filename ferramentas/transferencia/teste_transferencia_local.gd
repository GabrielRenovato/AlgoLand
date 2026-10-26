extends SceneTree
## Testa empacotar/validar/aplicar sem o servidor, em dois saves isolados:
##   -- --origem   cria um save conhecido e grava o pacote em /tmp/algoland_transferencia_pacote.json
##   -- --destino  com save diferente, aplica o pacote, recarrega e confere tudo
const T := preload("res://codigo/globais/transferencia_save.gd")
const PACOTE := "/tmp/algoland_transferencia_pacote.json"
var falhas := 0
func conferir(ok: bool, texto: String) -> void:
	print(("OK   " if ok else "FALHA ") + texto)
	if not ok: falhas += 1
func _initialize(): rodar.call_deferred()
func rodar():
	assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
	var P = root.get_node("Progresso")
	var args := OS.get_cmdline_user_args()
	if "--origem" in args:
		P.brasas = 4321
		P.maior_onda_vencida = 37
		P.salvar()
		var f := FileAccess.open("user://configuracao_jogador.json", FileAccess.WRITE)
		f.store_string(JSON.stringify({"apelido": "PRIMO DO PC"}))
		f.close()
		root.get_node("Ranking").gravar_perfis()
		var pacote := T.empacotar()
		conferir(T.validar(pacote) == "", "pacote da origem é válido")
		conferir(pacote.arquivos.has("progresso.json") and pacote.arquivos.has("ranking.json"), "leva progresso e identidade do ranking")
		var json := JSON.stringify(pacote)
		conferir(json.to_utf8_buffer().size() < 524288, "pacote cabe no limite do servidor (%d bytes)" % json.to_utf8_buffer().size())
		FileAccess.open(PACOTE, FileAccess.WRITE).store_string(json)
		var r := FileAccess.open(PACOTE + ".codigo", FileAccess.WRITE)
		r.store_string(root.get_node("Ranking").codigo_secreto())
		r.close()
	else:
		P.brasas = 5
		P.maior_onda_vencida = 2
		P.salvar()
		var f := FileAccess.open("user://configuracao_jogador.json", FileAccess.WRITE)
		f.store_string(JSON.stringify({"apelido": "CELULAR"}))
		f.close()
		var pacote = JSON.parse_string(FileAccess.get_file_as_string(PACOTE))
		var errado: Dictionary = pacote.duplicate(true)
		errado.versao_app = "0.0.0"
		conferir(T.validar(errado).begins_with("VERSOES DIFERENTES"), "recusa versão diferente")
		var estranho: Dictionary = pacote.duplicate(true)
		estranho.arquivos["../../fora.json"] = "x"
		conferir(T.validar(estranho) == "SAVE RECEBIDO ESTA CORROMPIDO", "recusa arquivo fora da lista")
		conferir(T.aplicar(pacote) == "", "aplica o pacote")
		root.get_node("Saves").trocar("solo")
		root.get_node("Ranking")._carregar()
		conferir(P.brasas == 4321 and P.maior_onda_vencida == 37, "progresso do PC no celular (brasas=%d andar=%d)" % [P.brasas, P.maior_onda_vencida])
		var cfg = JSON.parse_string(FileAccess.get_file_as_string("user://configuracao_jogador.json"))
		conferir(cfg.apelido == "PRIMO DO PC", "personagem do PC")
		conferir(root.get_node("Ranking").codigo_secreto() == FileAccess.get_file_as_string(PACOTE + ".codigo"), "mesma identidade de ranking/mercado")
		var backups := DirAccess.get_directories_at("user://backups")
		var tem_backup := false
		for b in backups:
			if b.begins_with("antes_transferencia_") and FileAccess.file_exists("user://backups/%s/progresso.json" % b):
				var antigo = JSON.parse_string(FileAccess.get_file_as_string("user://backups/%s/progresso.json" % b))
				tem_backup = tem_backup or int(antigo.get("brasas", -1)) == 5
		conferir(tem_backup, "save anterior do celular guardado em backups")
	print("TRANSFERENCIA LOCAL: %d falhas" % falhas)
	quit()
