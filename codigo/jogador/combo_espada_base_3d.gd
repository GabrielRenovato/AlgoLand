extends RefCounted
## Combo CC0 do Quaternius UAL2; mantém os três tempos do combate existente.
const NOMES := ["combo_3d/espada_1", "combo_3d/espada_2", "combo_3d/espada_3"]
const FONTES := ["quaternius/Sword_Regular_A","quaternius/Sword_Regular_B","quaternius/Sword_Regular_C"]
# Início, contato e recuperação medidos no clipe original.
const TRECHOS := [Vector3(0.0,0.25,13.0/30.0),Vector3(0.0,0.37,16.0/30.0),Vector3(0.0,0.80,2.0)]
const DURACOES := [0.38, 0.38, 0.50]
static func instalar(player: AnimationPlayer) -> void:
    var biblioteca := AnimationLibrary.new()
    for golpe in 3:
        var fonte := player.get_animation(FONTES[golpe])
        var animacao := Animation.new()
        animacao.length = DURACOES[golpe]
        animacao.set_meta("fonte",FONTES[golpe])
        animacao.set_meta("familia","um_mao")
        animacao.set_meta("tipo_golpe","corte")
        animacao.set_meta("rotacao_arma",fonte.get_meta("rotacao_arma",Quaternion.IDENTITY))
        for trilha in fonte.get_track_count():
            var tipo := fonte.track_get_type(trilha)
            if tipo not in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D]:
                continue
            var destino := animacao.add_track(tipo)
            animacao.track_set_path(destino, fonte.track_get_path(trilha))
            # Amostragem comum: interpola também os limites dos trechos originais.
            for q in 31:
                var p := q/30.0
                var tempo: float = tempo_do_trecho(TRECHOS[golpe],p)
                var valor = amostrar(fonte,trilha,tipo,tempo)
                animacao.track_insert_key(destino,p*animacao.length,valor)
        biblioteca.add_animation("espada_%d" % (golpe+1),animacao)
    player.add_animation_library("combo_3d",biblioteca)
static func amostrar(fonte: Animation,trilha: int,tipo: int,tempo: float):
    match tipo:
        Animation.TYPE_POSITION_3D: return fonte.position_track_interpolate(trilha,tempo)
        Animation.TYPE_ROTATION_3D: return fonte.rotation_track_interpolate(trilha,tempo)
        _: return fonte.scale_track_interpolate(trilha,tempo)

static func tempo_do_trecho(trecho: Vector3,p: float) -> float:
    return lerpf(trecho.x,trecho.y,p/0.45) if p<=0.45 else lerpf(trecho.y,trecho.z,(p-0.45)/0.55)
