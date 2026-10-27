extends SceneTree
func _initialize(): rodar.call_deferred()
func rodar():
    assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
    var inv=root.get_node("InventarioJogador")
    var onda: int=root.get_node("Progresso").maior_onda_vencida
    root.get_node("Progresso").maior_onda_vencida=0
    inv.limpar()
    inv.definir_linhas_extras(0)
    assert(inv.capacidade()==24)
    inv.linhas_liberadas=1
    inv.definir_linhas_extras(0)
    assert(inv.capacidade()==32)
    assert(inv.salvar("user://teste_expansao.json"))
    inv.limpar()
    inv.definir_linhas_extras(0)
    assert(inv.capacidade()==24)
    assert(inv.carregar("user://teste_expansao.json"))
    assert(inv.capacidade()==32 and inv.linhas_liberadas==1)
    inv.definir_linhas_extras(2)
    assert(inv.capacidade()==40)
    assert(root.get_node("Progresso").maior_onda_vencida==0)
    root.get_node("Progresso").maior_onda_vencida=onda
    print("EXPANSÃO MOCHILA: persistência e progressão independente verificadas")
    quit()
