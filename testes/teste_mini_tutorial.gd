extends SceneTree

## O quadro de controles fechado com o X fica fechado ao reabrir o jogo (user://opcoes.cfg da cópia isolada).
const Opcoes := preload("res://codigo/globais/opcoes_jogo.gd")
var _falhas := 0

func _initialize() -> void:
	_rodar()

func _verificar(nome: String, passou: bool) -> void:
	print("OK " if passou else "FALHA ", nome)
	if not passou:
		_falhas += 1

func _rodar() -> void:
	await process_frame
	if not ProjectSettings.get_setting("application/config/use_custom_user_dir", false) or not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AlgoLand testes"):
		push_error("Use uma cópia com save isolado AlgoLand testes.")
		quit(1)
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Opcoes.CAMINHO))
	_verificar("sem arquivo o quadro aparece", not Opcoes.mini_tutorial_fechado())
	Opcoes.fechar_mini_tutorial()
	_verificar("fechar grava no arquivo", Opcoes.mini_tutorial_fechado())
	# O menu de opções regrava volume etc. com um dicionário antigo: não pode reabrir o quadro
	var opcoes := Opcoes.carregar()
	opcoes["volume"] = 0.5
	Opcoes.salvar(opcoes)
	_verificar("salvar as opções do menu mantém o quadro fechado", Opcoes.mini_tutorial_fechado() and is_equal_approx(Opcoes.carregar()["volume"], 0.5))
	# Nova execução: o estado é lido do arquivo
	# Carregado aqui: o script usa o autoload Controle, que não existe na compilação deste teste
	var mini_tutorial: GDScript = load("res://codigo/ui/mini_tutorial.gd")
	mini_tutorial.set("_fechado", -1)
	_verificar("ao reabrir o jogo o quadro continua fechado", mini_tutorial.call("esta_fechado"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Opcoes.CAMINHO))
	print("Falhas: ", _falhas)
	quit(_falhas)
