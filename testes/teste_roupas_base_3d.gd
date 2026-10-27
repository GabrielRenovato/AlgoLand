extends SceneTree
## Valida peças independentes no rig real e fotografa o encaixe no motor.
const SAIDA = "res://arte/previas/personagens/base_3d/"
var falhas := 0
var verificacoes := 0
func _initialize():
    rodar.call_deferred()
func conferir(ok: bool,mensagem: String):
    verificacoes += 1
    if not ok:
        falhas += 1
        push_error(mensagem)
func esperar(n: int):
    for i in n:await process_frame
func foto(heroi: Node,nome: String):
    await RenderingServer.frame_post_draw
    await RenderingServer.frame_post_draw
    heroi._vp.get_texture().get_image().save_png(SAIDA+nome+".png")
## Conta aberturas reais após soldar posições; detecta frestas e costuras não-manifold.
func conferir_costuras(peca: MeshInstance3D,aberturas: int):
    var dados: Array=peca.mesh.surface_get_arrays(0)
    var pontos := {}
    var ids := []
    var arestas := {}
    var sentidos := {}
    for p in dados[Mesh.ARRAY_VERTEX]:
        var chave := Vector3i((p*100000.0).round())
        if not pontos.has(chave):pontos[chave]=pontos.size()
        ids.append(pontos[chave])
    var indices: PackedInt32Array=dados[Mesh.ARRAY_INDEX]
    for t in range(0,indices.size(),3):
        for k in 3:
            var a: int=ids[indices[t+k]]
            var b: int=ids[indices[t+(k+1)%3]]
            var chave := Vector2i(mini(a,b),maxi(a,b))
            arestas[chave]=arestas.get(chave,0)+1
            sentidos[chave]=sentidos.get(chave,0)+(1 if a<b else -1)
    var bordas := {}
    var malha_ok := true
    for aresta in arestas:
        malha_ok=malha_ok and arestas[aresta]<=2
        if arestas[aresta]==2:malha_ok=malha_ok and sentidos[aresta]==0
        if arestas[aresta]!=1:continue
        for ponto in [aresta.x,aresta.y]:
            if not bordas.has(ponto):bordas[ponto]=[]
            bordas[ponto].append(aresta.y if ponto==aresta.x else aresta.x)
    var ciclos := 0
    var visitados := {}
    for ponto in bordas:
        malha_ok=malha_ok and bordas[ponto].size()==2
        if visitados.has(ponto):continue
        ciclos+=1
        var fila := [ponto]
        while not fila.is_empty():
            var atual: int=fila.pop_back()
            if visitados.has(atual):continue
            visitados[atual]=true
            for vizinho in bordas[atual]:fila.append(vizinho)
    conferir(malha_ok and ciclos==aberturas,"Costuras fechadas de %s: %d aberturas previstas, %d encontradas" % [peca.name,aberturas,ciclos])

func rodar():
    assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
    assert(DisplayServer.get_name() != "headless")
    root.get_node("Introducao").pular_prologo()
    root.get_node("Transicao").hora_salva = 12.0
    change_scene_to_file("res://cenas/fazenda.tscn")
    await esperar(35)
    root.get_node("Transicao").limpar()
    var painel = root.get_node("PainelDebug")
    var jogador = current_scene.get_node("Jogador")
    var mochila = jogador.inventario.fotografar_mochila()
    painel._ativar_base_3d(true)
    await esperar(6)
    var heroi = jogador.get_node("HeroiBase3D")
    conferir(heroi.visible and not jogador.get_node("HeroiRaven").visible,"Um único visual do jogador")
    conferir(heroi._pecas.size()==4,"Quatro peças independentes")
    var corpo = heroi._modelo.find_child("CorpoBase",true,false)
    var a: Array = corpo.mesh.surface_get_arrays(0)
    conferir(a[Mesh.ARRAY_INDEX].size()>0 and a[Mesh.ARRAY_BONES].size()==a[Mesh.ARRAY_VERTEX].size()*4,"Corpo com braços contínuos e atributos de rig completos")
    var bracos_ok := true
    var pontos_bracos := 0
    for v in a[Mesh.ARRAY_VERTEX].size():
        var p: Vector3=a[Mesh.ARRAY_VERTEX][v]
        if absf(p.x)<0.30 or absf(p.x)>0.70 or p.y<1.20 or p.y>1.67 or absf(p.z+0.067)>0.23:continue
        pontos_bracos+=1
        var soma := 0.0
        for k in 4:
            var peso: float=a[Mesh.ARRAY_WEIGHTS][v*4+k]
            soma+=peso
            if peso<0.0001:continue
            var ligacao: int=a[Mesh.ARRAY_BONES][v*4+k]
            bracos_ok=bracos_ok and ligacao>=0 and ligacao<corpo.skin.get_bind_count()
            var nome: String=corpo.skin.get_bind_name(ligacao)
            if nome.is_empty():nome=heroi._esqueleto.get_bone_name(corpo.skin.get_bind_bone(ligacao))
            bracos_ok=bracos_ok and nome.ends_with(".L" if p.x>0 else ".R") and (nome.begins_with("DEF-upper_arm") or nome.begins_with("DEF-forearm") or nome.begins_with("DEF-hand"))
        bracos_ok=bracos_ok and absf(soma-1.0)<0.001
    conferir(bracos_ok and pontos_bracos>256,"Braços contínuos com pesos normalizados do próprio lado")
    conferir(heroi._modelo.find_children("*Olho*","MeshInstance3D",true,false).is_empty(),"Olhos na superfície, sem peças flutuantes")
    for i in 4:
        var peca: MeshInstance3D = heroi._pecas[i]
        conferir(peca.name == ["Camisa","Calca","Botas","Cabelo"][i],"Nó editável: "+str(peca.name))
        conferir(peca.skin == corpo.skin and peca.skeleton == corpo.skeleton,"Rig compartilhado: "+str(peca.name))
        var dados: Array = peca.mesh.surface_get_arrays(0)
        var ws: PackedFloat32Array = dados[Mesh.ARRAY_WEIGHTS]
        var bs: PackedInt32Array = dados[Mesh.ARRAY_BONES]
        var ok := true
        for v in dados[Mesh.ARRAY_VERTEX].size():
            var soma := 0.0
            for k in 4:
                var indice: int = v*4+k
                soma += ws[indice]
                ok = ok and bs[indice]>=0 and bs[indice]<peca.skin.get_bind_count()
            ok = ok and absf(soma-1.0)<0.001
        conferir(ok,"Pesos normalizados e ossos válidos: "+str(peca.name))
    conferir_costuras(heroi._pecas[0],4)
    conferir_costuras(heroi._pecas[1],3)
    for indice in [0,1]:
        var peca: MeshInstance3D=heroi._pecas[indice]
        var dados: Array=peca.mesh.surface_get_arrays(0)
        var permitido := true
        for v in dados[Mesh.ARRAY_VERTEX].size():
            for k in 4:
                if dados[Mesh.ARRAY_WEIGHTS][v*4+k]<0.0001:continue
                var ligacao: int=dados[Mesh.ARRAY_BONES][v*4+k]
                var nome: String=peca.skin.get_bind_name(ligacao)
                if nome.is_empty():nome=heroi._esqueleto.get_bone_name(peca.skin.get_bind_bone(ligacao))
                permitido=permitido and (nome=="DEF-hips" or (nome=="DEF-neck" or nome.begins_with("DEF-spine") or nome.begins_with("DEF-shoulder") or nome.begins_with("DEF-upper_arm") if indice==0 else nome.begins_with("DEF-thigh") or nome.begins_with("DEF-shin")))
        conferir(permitido,"Pesos próprios de tecido, sem influências de membros indevidos: "+str(peca.name))
    # Regressão do pescoço: gola sem influência dos braços e recorte contínuo da pele.
    var gola: Array=heroi._pecas[0].mesh.surface_get_arrays(0)
    var gola_ok := true
    var pontos_gola := 0
    for v in gola[Mesh.ARRAY_VERTEX].size():
        var p: Vector3=gola[Mesh.ARRAY_VERTEX][v]
        if p.y<1.4999 or p.y>1.532 or absf(p.x)>0.084 or absf(p.z-0.014)>0.055:continue
        pontos_gola+=1
        for k in 4:
            if gola[Mesh.ARRAY_WEIGHTS][v*4+k]<0.0001:continue
            var ligacao: int=gola[Mesh.ARRAY_BONES][v*4+k]
            var nome: String=corpo.skin.get_bind_name(ligacao)
            if nome.is_empty():nome=heroi._esqueleto.get_bone_name(corpo.skin.get_bind_bone(ligacao))
            gola_ok=gola_ok and nome=="DEF-neck"
    conferir(gola_ok and pontos_gola>=64,"Gola acompanha o pescoço sem puxões de ombros/braços")
    var cortes := []
    var pesos_pescoco_ok := true
    for v in a[Mesh.ARRAY_VERTEX].size():
        var maior := 0
        for k in 4:
            if a[Mesh.ARRAY_WEIGHTS][v*4+k]>a[Mesh.ARRAY_WEIGHTS][v*4+maior]:maior=k
        var ligacao: int=a[Mesh.ARRAY_BONES][v*4+maior]
        var nome: String=corpo.skin.get_bind_name(ligacao)
        if nome.is_empty():nome=heroi._esqueleto.get_bone_name(corpo.skin.get_bind_bone(ligacao))
        if nome=="DEF-neck" and absf(a[Mesh.ARRAY_VERTEX][v].x)<0.075 and a[Mesh.ARRAY_VERTEX][v].z> -0.055:
            cortes.append(a[Mesh.ARRAY_TEX_UV2][v].x)
            pesos_pescoco_ok=pesos_pescoco_ok and a[Mesh.ARRAY_WEIGHTS][v*4+maior]>0.9999
    conferir(cortes.size()>=8 and cortes.all(func(valor):return absf(valor)<0.20 and absf(valor)>0.000001),"Recorte métrico contínuo do pescoço, sem etiquetas booleanas por vértice")
    conferir(pesos_pescoco_ok,"Pescoço central sem torção causada pela cabeça ampliada ou ombros")
    var botas: MeshInstance3D = heroi._pecas[2]
    var bota_arrays: Array = botas.mesh.surface_get_arrays(0)
    var bota_ok := true
    for v in bota_arrays[Mesh.ARRAY_VERTEX].size():
        var lado: String = ".L" if bota_arrays[Mesh.ARRAY_VERTEX][v].x>0 else ".R"
        for k in 4:
            if bota_arrays[Mesh.ARRAY_WEIGHTS][v*4+k]<0.0001:continue
            var ligacao: int = bota_arrays[Mesh.ARRAY_BONES][v*4+k]
            var nome: String = botas.skin.get_bind_name(ligacao)
            if nome.is_empty():nome=heroi._esqueleto.get_bone_name(botas.skin.get_bind_bone(ligacao))
            bota_ok = bota_ok and nome.ends_with(lado) and (nome.begins_with("DEF-foot") or nome.begins_with("DEF-shin"))
    conferir(bota_ok,"Cada bota presa apenas ao pé/canela do próprio lado")
    var material_corpo: ShaderMaterial = corpo.material_override
    conferir(material_corpo.get_shader_parameter("esconder_camisa") and material_corpo.get_shader_parameter("esconder_calca") and material_corpo.get_shader_parameter("esconder_botas"),"Pele coberta oculta por peça")
    heroi.set_process(false)
    heroi._player.play("Idle_Loop",0.0)
    heroi._player.seek(0,true)
    heroi._player.pause()
    heroi._espada.visible = false
    var raiz: Vector3 = heroi._modelo.get_child(0).position
    var quadril = heroi._esqueleto.find_bone("DEF-hips")
    var pose: Vector3 = heroi._esqueleto.get_bone_pose_position(quadril)
    await esperar(30)
    conferir(heroi._modelo.get_child(0).position.is_equal_approx(raiz) and heroi._esqueleto.get_bone_pose_position(quadril).is_equal_approx(pose),"Pausa não acumula deslocamento no quadril")
    for mascara in [0,1,2,4,8,15]:
        heroi.pecas_visiveis = mascara
        for i in 4:
            conferir(heroi._pecas[i].visible == ((mascara & (1<<i))!=0),"Visibilidade independente %d/%d" % [mascara,i])
        await foto(heroi,"pecas_%02d" % mascara)
    heroi.pecas_visiveis = 15
    var duracao: float = heroi._player.get_animation(heroi._nome_animacao("correr")).length
    for d in 4:
        heroi._modelo.rotation.y = [0.0,PI/2.0,PI,-PI/2.0][d]
        heroi._player.play("Idle_Loop",0.0)
        heroi._player.seek(0,true)
        heroi._player.pause()
        await foto(heroi,"vestido_parado_%d" % d)
        heroi._player.play(heroi._nome_animacao("correr"),0.0)
        for q in 12:
            heroi._player.seek(duracao*q/12.0,true)
            heroi._player.pause()
            await foto(heroi,"vestido_correr_%d_%02d" % [d,q])
    heroi.set_process(true)
    var antes: Vector2 = jogador.global_position
    Input.action_press("move_right")
    await esperar(30)
    Input.action_release("move_right")
    conferir(jogador.global_position.distance_to(antes)>10,"Movimento real preservado")
    conferir(jogador.inventario.fotografar_mochila()==mochila,"Inventário preservado")
    painel._ativar_base_3d(false)
    await esperar(4)
    heroi = jogador.get_node("HeroiBase3D")
    conferir(heroi.pecas_visiveis==0 and heroi._pecas.all(func(p):return not p.visible),"Corpo base permanece sem cabelo e roupa opcional")
    painel._reaplicar_personagem()
    await esperar(4)
    conferir(not jogador.has_node("HeroiBase3D") and jogador.get_node("HeroiRaven").visible,"Restaura visual original")
    FileAccess.open(SAIDA+"revisao_roupas.json",FileAccess.WRITE).store_string(JSON.stringify({"falhas":falhas,"verificacoes":verificacoes,"duracao_corrida":duracao,"save":OS.get_user_data_dir()},"  "))
    print("ROUPAS BASE 3D: %d verificações, %d falhas; 48 poses de corrida renderizadas." % [verificacoes,falhas])
    current_scene.queue_free()
    current_scene = null
    await esperar(3)
    quit(1 if falhas else 0)
