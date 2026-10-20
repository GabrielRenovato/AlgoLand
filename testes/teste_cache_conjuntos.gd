extends SceneTree
## Impede que a cartola crie uma textura de cabeça em cada quadro da animação.
const A := preload("res://codigo/dados/aparencia.gd")
func _initialize() -> void:
	for pagina in ["andar", "espada", "fazenda"]:
		var raiz := "res://assets/personagens/conjuntos/cavalheiro/"
		var cabelo := A.cabelo_refinado(1, pagina, 2, 1, {"elmo":raiz})
		var cabecas := {}
		for i in 20:
			var textura := A.compor_cabelo_cartola(cabelo, A.peca_refinada(raiz, "elmo", pagina), Color.WHITE)
			cabecas[textura.get_instance_id()] = true
		assert(cabecas.size() == 1, "A cartola foi recomposta sem mudar aparência, peça ou cor.")
		var antes := A._cache_roupas_refinadas.size()
		for i in 20:
			A.roupa_refinada(2, pagina, 15, {"elmo":raiz,"peitoral":raiz,"luvas":raiz,"botas":raiz})
		assert(A._cache_roupas_refinadas.size() <= antes + 1, "Cache cresce a cada carga do mesmo arquivo.")
		var outra_cor := A.compor_cabelo_cartola(cabelo, A.peca_refinada(raiz, "elmo", pagina), Color.RED)
		assert(not cabecas.has(outra_cor.get_instance_id()), "Trocar cor precisa criar uma composição própria.")
	var oculta := A.cabelo_refinado(1,"andar",2,1,{"elmo":"res://assets/personagens/conjuntos/carrasco/"})
	assert(oculta.get_size() == Vector2(1024,1024) and oculta.get_image().is_invisible(), "Elmo deve ocultar cabelo sem alterar resolução.")
	print("CACHE_CONJUNTOS_OK: 60 quadros reutilizam3 cabeças; cor diferente preservada; cache de arquivo estável; cabelo oculto transparente.")
	quit()
