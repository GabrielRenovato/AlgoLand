extends SceneTree
## Exporta os itens canônicos; a aplicação ao save é uma operação explícita separada.
func _initialize(): rodar.call_deferred()
func rodar():
    assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
    var itens: Array=[]
    for tipo in preload("res://codigo/dados/equipamentos.gd").TIPOS_DROP:
        var item=preload("res://codigo/dados/forja_armas.gd").criar_item(tipo)
        assert(item!=null)
        itens.append(item.para_dict())
    FileAccess.open("/tmp/algoland-kit-todas-armas.json",FileAccess.WRITE).store_string(JSON.stringify(itens,"  "))
    print("KIT ARMAS: ",itens.size()," modelos canônicos exportados")
    quit()
