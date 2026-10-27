extends RefCounted
## Raridade governa o material; nível da bigorna governa somente a energia.
const Raridades=preload("res://codigo/dados/raridades.gd")
const CORES_BRILHO=[Color("e7f5ff"),Color("d4f9ff"),Color("42cbff"),Color("b275ff"),Color("ffc55b")]
const INTENSIDADES=[0.,.28,.50,.75,1.]
const RAMPAS={
 "comum":[],
 "incomum":["315a40","70ad7b","cce8cb"],
 "raro":["304f80","689ed7","cce4ff"],
 "epico":["573477","a373cc","ecdaff"],
 "lendario":["886028","d6a44f","fff0b7"]
}

static func brilho(nivel: int) -> Dictionary:
 var n:=clampi(nivel,1,5)-1
 return {"cor":CORES_BRILHO[n],"intensidade":INTENSIDADES[n],"largura":lerpf(.018,.050,n/4.)}

static func cor_material(raridade: String) -> Color:
 return Raridades.cor(raridade) if Raridades.valida(raridade) else Raridades.cor("comum")
