extends RefCounted
## Adaptador do pipeline compartilhado: quatro malhas no rig, mantendo as 11 páginas 2D.
const Moldes=preload("res://codigo/jogador/moldes_mordomo_3d.gd")
const Carrasco=preload("res://codigo/jogador/moldes_carrasco_3d.gd")
const Rubro=preload("res://codigo/jogador/moldes_rubro_3d.gd")
const Tecido=preload("res://codigo/jogador/roupas_modeladas_3d.gd")
const PECAS=["elmo","peitoral","luvas","botas"]

static func gerar(config: Dictionary) -> int:
 if config.id not in ["cavalheiro","carrasco","cavaleiro_rubro"] or not config.has("base_3d"):
  push_error("Manifesto sem adaptador 3D suportado");return 1
 var cena=load("res://cenas/personagem/base_3d/personagem.tscn").instantiate()
 (Engine.get_main_loop() as SceneTree).root.add_child(cena)
 var corpo=cena.find_child("CorpoBase",true,false) as MeshInstance3D
 var rig=cena.find_children("*","Skeleton3D",true,false)[0] as Skeleton3D
 var malhas: Array
 if config.id=="cavalheiro":
  malhas=[Moldes.cartola(corpo,rig),Moldes.casaca(corpo,rig,cena.find_child("Camisa",true,false).mesh,cena.find_child("Calca",true,false).mesh),Moldes.luvas(corpo),Moldes.ajustar(cena.find_child("Botas",true,false).mesh,Tecido.ligacoes(corpo,rig),"botas")]
 else:
  var modelo: GDScript=Rubro if config.id=="cavaleiro_rubro" else Carrasco
  malhas=[modelo.elmo(corpo,rig),modelo.peitoral(corpo,rig,cena.find_child("Camisa",true,false).mesh,cena.find_child("Calca",true,false).mesh),modelo.luvas(corpo,rig),modelo.botas(cena.find_child("Botas",true,false).mesh,corpo,rig)]
 var destino: String=config.base_3d.destino
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destino))
 for i in 4:
  var material:=ShaderMaterial.new()
  if config.id in ["carrasco","cavaleiro_rubro"]:
   material.shader=load("res://codigo/jogador/rubro_base_3d.gdshader" if config.id=="cavaleiro_rubro" else "res://codigo/jogador/carrasco_base_3d.gdshader")
   var nomes=["escuro","metal","metal_meio","metal_luz","prata","couro","couro_luz"]
   var tons=[0,1,2,4,5,9,10]
   for j in nomes.size():material.set_shader_parameter(nomes[j],Color(config.paleta[tons[j]]))
   for nome in config.base_3d.get("cores_metal",{}):
    material.set_shader_parameter(nome,Color(config.base_3d.cores_metal[nome]))
  else:
   material.shader=load("res://codigo/jogador/mordomo_base_3d.gdshader")
   var nomes=["sombra","tecido","lapela","camisa","couro","couro_luz","ouro","vinho"]
   var tons=[0,2,3,5,7,8,9,11]
   for j in nomes.size():material.set_shader_parameter(nomes[j],Color(config.paleta[tons[j]]))
   if i in [0,1]:
    for nome in config.base_3d.get("cores_tecido",{}):
     material.set_shader_parameter(nome,Color(config.base_3d.cores_tecido[nome]))
  material.set_shader_parameter("peca",i+1)
  malhas[i].surface_set_material(0,material)
  if ResourceSaver.save(malhas[i],destino+PECAS[i]+".res")!=OK:cena.free();return 1
 cena.free()
 print(String(config.nome).to_upper()+" 3D: quatro peças geradas; páginas legadas e atributos preservados")
 return 0

static func validar(config: Dictionary) -> int:
 var falhas:=0
 if not config.has("base_3d"):push_error("Falta base_3d no manifesto");return 1
 for peca in PECAS:
  var malha=load(String(config.base_3d.destino)+peca+".res") as ArrayMesh
  if malha==null:falhas+=1;continue
  for s in malha.get_surface_count():
   var a:=malha.surface_get_arrays(s)
   for i in a[Mesh.ARRAY_VERTEX].size():
    if not a[Mesh.ARRAY_VERTEX][i].is_finite():falhas+=1
    var soma:=0.
    for j in 4:soma+=a[Mesh.ARRAY_WEIGHTS][i*4+j]
    if absf(soma-1.0)>.001:falhas+=1
   if malha.surface_get_material(s)==null:falhas+=1
  print("3D ",peca,": ",malha.get_aabb())
 print(String(config.nome).to_upper()+" 3D: ",falhas," falhas de geometria/pesos/materiais")
 return 0 if falhas==0 else 1
