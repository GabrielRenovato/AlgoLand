extends RefCounted
## Três estocadas de duas mãos sobre os clipes Polearm do Kevin Iglesias.
const NOMES := ["combo_lanca_3d/lanca_1","combo_lanca_3d/lanca_2","combo_lanca_3d/lanca_3"]
const DURACOES := [0.32,0.36,0.50]
static func instalar(player: AnimationPlayer):
    var biblioteca := AnimationLibrary.new()
    var fontes := ["melee/HumanM_AttackPolearm01","melee/HumanF_AttackPolearm01","melee/HumanM_AttackPolearm01"]
    for golpe in 3:
        var fonte := player.get_animation(fontes[golpe])
        var animacao := Animation.new()
        animacao.length = DURACOES[golpe]
        for trilha in fonte.get_track_count():
            var tipo := fonte.track_get_type(trilha)
            if tipo not in [Animation.TYPE_POSITION_3D,Animation.TYPE_ROTATION_3D,Animation.TYPE_SCALE_3D]: continue
            var destino := animacao.add_track(tipo)
            animacao.track_set_path(destino,fonte.track_get_path(trilha))
            for q in 31:
                var p := q/30.0
                # O finalizador tem uma preparação mais longa e avanço rápido.
                var progresso := p
                if golpe==2:
                    progresso=lerpf(0.0,0.22,p/0.30) if p<0.30 else lerpf(0.22,1.0,(p-0.30)/0.70)
                var valor = preload("combo_espada_base_3d.gd").amostrar(fonte,trilha,tipo,fonte.length*progresso)
                animacao.track_insert_key(destino,p*animacao.length,valor)
        biblioteca.add_animation("lanca_%d" % (golpe+1),animacao)
    player.add_animation_library("combo_lanca_3d",biblioteca)
