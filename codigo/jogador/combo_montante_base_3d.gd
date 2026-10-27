extends RefCounted
## Corte simples seguido do ataque com salto escolhidos no Mixamo.
const NOMES := ["combo_montante_3d/golpe_1","combo_montante_3d/golpe_2"]
const DURACOES := [0.52,0.86]
const FONTES := ["mixamo/GreatSwordSlash","mixamo/GreatSwordJumpAttack"]
const TRECHOS := [Vector3(0.0,0.65,1.266666667),Vector3(0.0,1.10,2.166666667)]
static func instalar(player: AnimationPlayer):
    var biblioteca := AnimationLibrary.new()
    for golpe in NOMES.size():
        var fonte := player.get_animation(FONTES[golpe])
        var animacao := Animation.new()
        animacao.length=DURACOES[golpe]
        animacao.set_meta("fonte",FONTES[golpe])
        animacao.set_meta("familia","duas_maos")
        animacao.set_meta("rotacao_arma",fonte.get_meta("rotacao_arma",Quaternion.IDENTITY))
        for trilha in fonte.get_track_count():
            var tipo := fonte.track_get_type(trilha)
            if tipo not in [Animation.TYPE_POSITION_3D,Animation.TYPE_ROTATION_3D,Animation.TYPE_SCALE_3D]: continue
            var destino := animacao.add_track(tipo)
            animacao.track_set_path(destino,fonte.track_get_path(trilha))
            for q in 31:
                var p := q/30.0
                var valor=preload("combo_espada_base_3d.gd").amostrar(fonte,trilha,tipo,preload("combo_espada_base_3d.gd").tempo_do_trecho(TRECHOS[golpe],p))
                animacao.track_insert_key(destino,p*animacao.length,valor)
        biblioteca.add_animation("golpe_%d" % (golpe+1),animacao)
    player.add_animation_library("combo_montante_3d",biblioteca)
