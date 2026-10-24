# Colheita no corpo base Raven com short neutro

Base criada pela ferramenta integrada de geração de imagens, usando o modelo canônico Raven e as poses efetivas do GIF oficial Mana Seed. O usuário autorizou short neutro, coberto pela roupa externa. O arquivo selecionado é `geracao_base_short.png`; o pedido está em `prompt_base_short.txt`. A primeira tentativa no formato anterior foi bloqueada pela ferramenta; ela não é o resultado selecionado.

Referência inspecionada: `arte/pacotes/Jogador/Base/20.01a - Character Base 2.5c/guides/timing sample gifs/farming sample.gif`, quadros20–23. O guia `using this base.txt` confirma Pulling up400/240/180/300ms. Movimento: agachar/gripar, puxar ainda baixo, levantar com duas mãos acima da cabeça e sustentar. A referência de quatro direções está em `mana_seed_colheita_original.png`.

Os sprites ficam em `assets/personagens/raven_fantasy/estudo_colheita/base/`: `corpo_0.png`, `corpo_1.png`, `corpo_2.png` e `efeitos.png`. As três peles usam as mesmas poses e máscaras; o short conserva seus tons de cinza. As folhas têm320×320, grade4×4 com células80×80, direções baixo/direita/cima/esquerda e pivô40,47. O efeito da puxada é separado, assim como será o item colhido. O corpo não contém cabelo, camisa ou equipamentos.

A geração veio1254×1254. `contrato_base.json` registra a transformação de amostragem e as raízes fixas por direção; a última linha veio deslocada no original. A escala é comum a todos os quadros e não há reenquadramento por silhueta. O último quadro repete a pose erguida do terceiro, conforme a sustentação na referência. `exportar_base.gd` aplica a paleta nativa, preserva os tons do short e empacota o efeito original Mana Seed.

`revisar_base_no_godot.gd` foi executado na fazenda real em save isolado `AlgoLand testes colheita base`. A imagem mostra Mana Seed acima e Raven abaixo, em quatro direções. Sprites pequenos da decoração e partículas são ocultados apenas na revisão para não encobrir os corpos. Foram inspecionados os quatro estágios, nas escalas de contato e do motor, incluindo pés, cabeça, costas, mãos, transparência, short e margens dos títulos. As verificações confirmam máscaras iguais nas três peles, short em todos os quadros, células sem vazamento, mesma sequência/tempos e sustentação final estável. Testes não constituem aprovação artística do usuário.

O GIF `arte/previas/personagens/raven_colheita/colheita_corpo_base.gif` usa os mesmos quadros/tempos e acrescenta600ms de sustentação demonstrativa. A ação no motor não repete. Foram analisadas as capturas renderizadas; não foi afirmada reprodução assistida do GIF em visualizador animado.

Para reproduzir numa cópia isolada com diretório de usuário iniciado em `AlgoLand testes`:

```sh
flatpak run --filesystem=/tmp org.godotengine.Godot --headless --path /tmp/algoland-colheita-base-revisao --script res://arte/fontes/personagens/raven_colheita/exportar_base.gd
flatpak run --filesystem=/tmp org.godotengine.Godot --path /tmp/algoland-colheita-base-revisao --script res://arte/fontes/personagens/raven_colheita/revisar_base_no_godot.gd --fixed-fps 50
ffmpeg -framerate 50 -i arte/previas/personagens/raven_colheita/motor_base/%03d.png -filter_complex '[0:v]split[a][b];[a]palettegen=max_colors=128:stats_mode=diff[p];[b][p]paletteuse=dither=none' -loop 0 -y arte/previas/personagens/raven_colheita/colheita_corpo_base.gif
```

A base não foi ativada no jogador. Roupas, cabelos e armaduras atuais seguem outras poses e ainda precisam ser adaptados e revisados. Nenhuma compatibilidade automática foi prometida. A prévia lateral vestida anterior está descrita em `LEIA-ME.md`; ela não substitui esta base modular.
