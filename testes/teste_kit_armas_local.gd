extends SceneTree
## Lê uma cópia do save local em /tmp; nunca grava a partida do usuário.
func _initialize(): rodar.call_deferred()
func rodar():
    assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
    var inv=root.get_node("InventarioJogador")
    assert(inv.carregar("/tmp/algoland-inventario-local-verificar.json"))
    assert(inv.capacidade()>=32)
    var total:=0
    for tipo in preload("res://codigo/dados/equipamentos.gd").TIPOS_DROP:
        assert(inv.buscar_por_tipo(tipo)!=null,"Arma ausente: "+tipo)
        total+=1
    print("SAVE LOCAL: ",total," modelos carregados pelo jogo; capacidade=",inv.capacidade())
    quit()
