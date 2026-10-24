extends SceneTree
const Encaixe=preload("res://ferramentas/personagem/encaixe_corrida_raven.gd")
func _initialize():
 assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
 Encaixe.preparar()
 if "--somente-camadas" in OS.get_cmdline_user_args():
  quit();return
 for conjunto in ["carrasco","cavaleiro_rubro","cavalheiro"]:Encaixe.preparar_conjunto("res://assets/personagens/conjuntos/"+conjunto+"/")
 quit()
