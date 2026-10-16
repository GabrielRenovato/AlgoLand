extends SceneTree

## Grava assets/personagens/conjuntos/<id>/cobertura/<pagina>.png: a região da roupa que cada peça substitui (bits 1, 2, 4, 8 no canal vermelho).
## Sem esses arquivos o jogo calcula a cobertura na hora, o que trava ~200 ms por página ao equipar uma peça pela primeira vez.
## Uso: godot --headless --path . --script ferramentas/armaduras/gerar_coberturas.gd [-- res://raiz1/ res://raiz2/]
## Sem argumentos, processa todos os conjuntos cadastrados. Rodar de novo depois de mudar as folhas das peças e reimportar.
const Aparencia := preload("res://codigo/dados/aparencia.gd")
const PadraoArmadura := preload("res://codigo/dados/padrao_armadura.gd")
const Conjuntos := preload("res://codigo/dados/conjuntos_armadura.gd")

func _initialize() -> void:
	var raizes: Array[String] = []
	for argumento in OS.get_cmdline_user_args():
		raizes.append(argumento)
	if raizes.is_empty():
		for conjunto in Conjuntos.CONJUNTOS:
			raizes.append(String(conjunto.RAIZ_SPRITES))
	for raiz in raizes:
		var pasta := ProjectSettings.globalize_path(raiz + "cobertura")
		DirAccess.make_dir_recursive_absolute(pasta)
		for pagina in PadraoArmadura.CORPOS:
			var cobertura := Aparencia.calcular_cobertura(pagina, raiz)
			var bytes := PackedByteArray()
			bytes.resize(512 * 512 * 4)
			for i in cobertura.size():
				bytes[i * 4] = cobertura[i]
				bytes[i * 4 + 3] = 255
			var imagem := Image.create_from_data(512, 512, false, Image.FORMAT_RGBA8, bytes)
			var erro := imagem.save_png(pasta + "/" + pagina + ".png")
			print(raiz, pagina, " -> ", "ok" if erro == OK else "ERRO %d" % erro)
	quit(0)
