extends SceneTree
const Estilos := preload("res://codigo/dados/estilos_arma.gd")
var falhas := 0
func _initialize() -> void:
	for caso in [["espada_basica",1,10.0,true,1.5],["espada_basica",1,10.0,false,1.0],["espada_gemea",3,10.0,false,1.25],["espada_gemea",2,10.0,false,1.0],["machado",1,10.0,false,1.25],["lanca_basica",1,40.0,false,1.25],["lanca_basica",1,32.0,false,1.0],["arco_curto",0,90.0,false,1.2],["arco_curto",0,91.0,false,1.0],["arco_curvo",0,120.0,false,1.2],["arco_longo",0,180.0,false,1.15]]:
		if not is_equal_approx(float(Estilos.efeito(caso[0],caso[1],caso[2],caso[3]).dano),caso[4]): falhas += 1
	if Estilos.efeito("maca",3,10).atordoar != 0.35 or Estilos.efeito("maca",2,10).atordoar != 0: falhas += 1
	print("FALHAS: ",falhas)
	quit(falhas)
