# Vestuário infantil

Modelagem própria no rig canônico e no manequim infantil existente. As peças são malhas separadas, com Skin e pesos compartilhados; a geometria do corpo não é recortada ou repintada. Material próprio com cores de tecido e detalhes presos à superfície. Os cabelos usam volumes presos ao osso da cabeça; a pintura de rosto continua separada.

Três trajes: `campestre`, `jardineira`, `vestido`. Três penteados: `franjinha`, `chiquinhas`, `cacheado`. Os IDs são exclusivos deste guarda-roupa, sem entrar no sorteio de roupas dos adultos. A jardineira tem peitilho curvo e alças modeladas, e as bermudas têm barras dobradas. A cobertura do corpo usa a altura da barra para preservar joelhos e canelas. O padrão de cobertura adulto permanece igual.

Uso no manequim:

```gdscript
var manequim=preload("res://codigo/npcs/manequim_infantil_3d.gd").new()
manequim.aparencia=ficha.aparencia
manequim.traje_infantil="jardineira"
manequim.cabelo_infantil="chiquinhas"
add_child(manequim)
# Troca depois de pronto:
manequim.vestir_infantil("campestre","cacheado")
```

Fonte consumida: `codigo/npcs/vestuario_infantil_3d.gd` e `vestuario_infantil.gdshader`. As malhas são construídas e mantidas em cache por manequim. `mostrar()` conserva o traje ao trocar aparência. A cor do cabelo vem da aparência, independente da escolha da roupa.

Validação em save isolado: `harness.py testar --perfil selecionado --teste vestuario_infantil_3d --teste manequim_infantil_3d --teste roupas_base_3d`. O teste captura todas as nove combinações nas quatro vistas e a caminhada dos três pares principais. `montar_previas.py <capturas-vestuario-infantil>` monta imagens de comparação e GIF com os mesmos quadros/durações do motor, sem retocar sprites. O manequim continua sendo um estudo para revisão; não adiciona novos moradores ao elenco da cidade.
