extends SceneTree

## Recursos controlados exercitam a espera real da thread sem depender da velocidade do computador.
class CenaTeste extends ResourceFormatLoader:
	func _get_recognized_extensions() -> PackedStringArray:
		return PackedStringArray(["cena_espera"])
	func _handles_type(tipo: StringName) -> bool:
		return tipo == &"PackedScene"
	func _get_resource_type(caminho: String) -> String:
		return "PackedScene" if caminho.ends_with(".cena_espera") else ""
	func _exists(caminho: String) -> bool:
		return caminho.ends_with(".cena_espera")
	func _load(caminho: String, _original: String, _subthreads: bool, _cache: int):
		if caminho.contains("lenta"): OS.delay_msec(650)
		var no := Node2D.new()
		no.name = "CenaTeste"
		var cena := PackedScene.new()
		cena.pack(no)
		no.free()
		return cena

var falhas := 0
func _initialize() -> void: rodar.call_deferred()
func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ",nome)
	if not ok: falhas += 1
func rodar() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name","")).begins_with("AlgoLand testes"):
		quit(1)
		return
	await process_frame
	var carregador := CenaTeste.new()
	ResourceLoader.add_resource_format_loader(carregador,true)
	var transicao = root.get_node("Transicao")
	var aparicoes := []
	transicao._carregador.visibility_changed.connect(func():
		if transicao._carregador.visible: aparicoes.append(Time.get_ticks_msec()))
	# Manter a referencia garante uma troca com recurso ja disponivel no cache.
	var pronta: Resource = ResourceLoader.load("res://rapida.cena_espera","PackedScene")
	var erro: Error = await transicao.carregar_cena("res://rapida.cena_espera")
	verificar("troca rapida abre o destino sem mostrar loading",pronta != null and erro==OK and current_scene.name=="CenaTeste" and aparicoes.is_empty())
	var inicio := Time.get_ticks_msec()
	erro = await transicao.carregar_cena("res://lenta.cena_espera")
	verificar("carga demorada mostra painel somente depois da espera",erro==OK and aparicoes.size()==1 and aparicoes[0]-inicio >= transicao.ESPERA_PAINEL_CARREGAMENTO_MS)
	verificar("painel fecha e libera proxima troca",not transicao._carregador.visible and not transicao._carregando)
	transicao.carregar_na_thread_principal = true
	aparicoes.clear()
	erro = await transicao.carregar_cena("res://android.cena_espera")
	verificar("caminho Android mostra painel antes de abrir a cena", erro == OK and aparicoes.size() == 1 and current_scene.name == "CenaTeste")
	verificar("caminho Android libera o carregador",not transicao._carregador.visible and not transicao._carregando)
	erro = await transicao.carregar_cena("res://cena_ausente.tscn")
	verificar("recurso ausente preserva cena e libera carregamento",erro == ERR_FILE_NOT_FOUND and current_scene.name == "CenaTeste" and not transicao._carregando)
	ResourceLoader.remove_resource_format_loader(carregador)
	current_scene.queue_free()
	current_scene = null
	await process_frame
	print("Carregamento condicional: %d falhas" % falhas)
	quit(1 if falhas else 0)
