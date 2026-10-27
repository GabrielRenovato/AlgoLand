extends RefCounted
## Um corte com a direita, seguido de recuperação contínua para a pose inicial.
## Preserva o FBX importado; a recuperação longa do clipe de combate fazia
## o tronco girar e a ferramenta atravessar a silhueta na ação curta da fazenda.
const DURACAO := .68
const IMPACTO := .30
const FIM_GOLPE := .36
const CONTATO_FONTE := .82
const FIM_FONTE := .90
static func gerar(fonte: Animation) -> Animation:
    var corte:=Animation.new()
    corte.length=DURACAO
    corte.loop_mode=Animation.LOOP_NONE
    for meta in fonte.get_meta_list(): corte.set_meta(meta,fonte.get_meta(meta))
    corte.set_meta("clipe_origem","mixamo/AxeHorizontal")
    for trilha in fonte.get_track_count():
        var tipo:=fonte.track_get_type(trilha)
        if tipo not in [Animation.TYPE_ROTATION_3D,Animation.TYPE_POSITION_3D]: continue
        var destino:=corte.add_track(tipo)
        corte.track_set_path(destino,fonte.track_get_path(trilha))
        for q in range(83):
            var t:=DURACAO*q/82.0
            var instante:=lerpf(0,CONTATO_FONTE,t/IMPACTO) if t<=IMPACTO else lerpf(CONTATO_FONTE,FIM_FONTE,clampf((t-IMPACTO)/(FIM_GOLPE-IMPACTO),0,1))
            var retorno:=smoothstep(FIM_GOLPE,DURACAO,t)
            if tipo==Animation.TYPE_ROTATION_3D:
                var pose:=fonte.rotation_track_interpolate(trilha,instante)
                var inicio:=fonte.rotation_track_interpolate(trilha,0)
                corte.rotation_track_insert_key(destino,t,pose.slerp(inicio,retorno))
            else:
                var pose:=fonte.position_track_interpolate(trilha,instante)
                var inicio:=fonte.position_track_interpolate(trilha,0)
                corte.position_track_insert_key(destino,t,pose.lerp(inicio,retorno))
    return corte
