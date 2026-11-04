@tool
extends "res://codigo/campanha/cora_malha_3d.gd"
@export_enum("jardineira_cora","vaso_cora") var tipo := "jardineira_cora"

func _ready() -> void:
	if tipo == "jardineira_cora": _jardineira()
	else: _vaso()
	_finalizar()
	definir_estacao(0)

func _jardineira() -> void:
	_caixa(Vector3(0.94,0.35,0.46),Vector3(0,0.23,0),"madeira_escura")
	for y in [0.12,0.23,0.34]: _caixa(Vector3(0.98,0.09,0.035),Vector3(0,y,0.25),"madeira")
	for lado in [-1.0,1.0]:
		_caixa(Vector3(0.07,0.43,0.54),Vector3(lado*0.44,0.25,0),"madeira")
		_caixa(Vector3(0.09,0.10,0.47),Vector3(lado*0.35,0.06,0),"madeira_escura")
	for x in [-0.32,-0.11,0.11,0.32]: _moita(Vector3(x,0.41,0),0.38,x<0)
	_caixa(Vector3(0.98,0.025,0.10),Vector3(0,0.46,0.24),"neve")

func _vaso() -> void:
	_cilindro(Vector3(0,0.02,0),0.14,0.27,"telha_borda",Color("d5b187"),10,0.20)
	_anel(Vector3(0,0.28,0),0.215,0.165,0.06,"telha_borda",10)
	_moita(Vector3(0,0.33,0),0.54,true)
	_anel(Vector3(0,0.35,0),0.21,0.16,0.025,"neve",10)
