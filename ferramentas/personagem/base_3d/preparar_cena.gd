extends SceneTree
## Prepara a cena editável e reaproveitada pelo jogo; não altera o GLB adquirido.
func _initialize():
    preparar.call_deferred()
func donos(no: Node,raiz: Node):
    for filho in no.get_children():
        filho.owner = raiz
        donos(filho,raiz)
func preparar():
    assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
    var construtor = load("res://codigo/jogador/heroi_base_3d.gd").new()
    construtor.pecas_visiveis = 15
    construtor._modelo = Node3D.new()
    root.add_child(construtor._modelo)
    construtor._construir_modelo()
    var modelo: Node3D = construtor._modelo.get_child(0)
    modelo.name = "PersonagemBase3D"
    construtor._player.play("Idle_Loop",0.0)
    construtor._player.seek(0,true)
    for modificador in construtor._esqueleto.get_children():
        if modificador is SkeletonModifier3D:modificador._aplicar()
    construtor._espada.visible = false
    construtor._modelo.remove_child(modelo)
    construtor._player.autoplay = "Idle_Loop"
    donos(modelo,modelo)
    var cena := PackedScene.new()
    assert(cena.pack(modelo) == OK)
    assert(ResourceSaver.save(cena,construtor.CENA_COMPILADA,ResourceSaver.FLAG_COMPRESS)==OK)
    print("BASE 3D: cena editável salva, com CorpoBase/Camisa/Calca/Botas/Cabelo e rig original.")
    modelo.free()
    construtor._modelo.queue_free()
    construtor.free()
    await process_frame
    quit()
