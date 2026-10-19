extends SceneTree
const Ritmo := preload("res://codigo/fendas/ritmo_andares.gd")
var Catalogo: GDScript
var falhas := 0
func _initialize() -> void:
	await process_frame
	Catalogo = load("res://codigo/fendas/catalogo_andares.gd")
	for andar in range(1, 31):
		var dados: Dictionary = Catalogo.dados(andar)
		var estoque := float(dados.combate.meta) / float(dados.combate.fracao_exigida)
		var meta: int = Catalogo.meta(andar)
		if meta < 3 or meta >= estoque or meta > int(dados.combate.meta):
			falhas += 1
		if andar <= 10:
			print("RITMO andar=", andar, " pontos=",meta," fracao=",snappedf(meta/estoque,0.01)," antes=",dados.combate.meta)
	print("FALHAS: ", falhas)
	quit(falhas)
