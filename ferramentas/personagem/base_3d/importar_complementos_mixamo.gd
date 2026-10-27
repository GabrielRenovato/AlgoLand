extends "res://ferramentas/personagem/base_3d/importar_mixamo.gd"
## Usa o mesmo retarget validado dos FBX atuais. A biblioteca complementar
## fica separada; sua geração ainda não ativa os clipes no personagem.
const CATALOGO := "res://arte/fontes/personagens/base_3d/mixamo/complementos.json"
const BIBLIOTECA := "res://assets/personagens/base_3d/mixamo_complementos.res"
const RELATORIO := "res://arte/fontes/personagens/base_3d/mixamo/importacao_complementos.json"
func rodar():
    assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
    var catalogo: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(CATALOGO))
    var presentes: Dictionary={}
    for id in catalogo:
        var dados: Dictionary=catalogo[id]
        var caminho: String="res://arte/fontes/personagens/base_3d/mixamo/"+dados.arquivo
        if FileAccess.file_exists(caminho): presentes[id]=dados
        else: print("FBX PENDENTE: ",dados.arquivo)
    if presentes.is_empty():
        print("COMPLEMENTOS: nenhum FBX disponível. Biblioteca e jogo preservados.")
        quit(2)
        return
    cena_alvo=load("res://cenas/personagem/base_3d/personagem.tscn").instantiate()
    root.add_child(cena_alvo)
    alvo=cena_alvo.find_children("*","Skeleton3D",true,false)[0]
    for modificador in alvo.find_children("*","SkeletonModifier3D",true,false): modificador.active=false
    if ResourceLoader.exists(BIBLIOTECA): biblioteca=load(BIBLIOTECA).duplicate()
    for id in presentes:
        var dados: Dictionary=presentes[id]
        if biblioteca.has_animation(id): biblioteca.remove_animation(id)
        await importar(ProjectSettings.globalize_path("res://arte/fontes/personagens/base_3d/mixamo/"+dados.arquivo),id,dados.loop)
    assert(ResourceSaver.save(biblioteca,BIBLIOTECA,ResourceSaver.FLAG_COMPRESS)==OK)
    FileAccess.open(RELATORIO,FileAccess.WRITE).store_string(JSON.stringify(relatorio,"  "))
    print("COMPLEMENTOS: ",presentes.size()," importados. Aguardam revisão no rig antes da ativação.")
    cena_alvo.queue_free()
    await process_frame
    quit()
