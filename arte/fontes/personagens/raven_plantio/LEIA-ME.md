# Plantio Raven — estudo de corpo base

A primeira tentativa foi rejeitada: inventou um gesto de levar a mão ao chão. Foi consultado o material oficial em `arte/pacotes/Jogador/Base/20.01a - Character Base 2.5c/`: `guides/animations, page 2.png`, `guides/using this base.txt` e o GIF `guides/timing sample gifs/farming sample.gif`.

O plantio original é um arremesso de sementes. Os quadros7–10 do GIF usam300/100/100/100ms: preparação, varrida/arremesso com avanço do corpo, mesma pose com sementes e mesma pose com sementes mais baixas. A animação não é um agachamento para colocar sementes no chão. `mana_seed_quatro_direcoes.png` contém esses quadros na ordem baixo/direita/cima/esquerda.

Após a correção de escopo do usuário, o produto selecionado passou a ser o **corpo base**. `geracao_perfil.png` é apenas o estudo vestido anterior, não a animação modular final. `geracao_corpo_base.png` foi produzida pela ferramenta integrada de geração de imagens, com `molde_base_quatro_direcoes.png` como modelo de identidade e a sequência oficial Mana Seed como referência de poses. O prompt está em `prompt_corpo_base.txt`. Trata-se de uma adaptação gerada; a referência não comprova transferência literal de cada articulação.

Os recursos de estudo ficam em `assets/personagens/raven_fantasy/estudo_plantio/base/`:

- `corpo_0.png`, `corpo_1.png` e `corpo_2.png`: corpo sem cabelo ou roupa, mesmas máscaras/poses e rampas originais das três peles.
- `efeitos.png`: arco e sementes separados do corpo, extraídos da camada original Mana Seed.

Folhas320×320, células80×80, quatro quadros por linha, direções baixo/direita/cima/esquerda e pivô40,47. A imagem gerada veio1254×1254, em vez de1536×1536. O exportador registra uma transformação comum para todas as poses, ajustada à altura do corpo canônico, com alfa binário e paleta nativa; não reenquadra cada silhueta. As três últimas poses do corpo são a mesma, acompanhando a referência; somente o efeito varia.

`revisar_base_no_godot.gd` carrega a fazenda com save isolado, compara as quatro direções simultaneamente com o Mana Seed original e retorna ao repouso após600ms. Confere dimensões, margens, ausência de vazamento, igualdade das máscaras nas peles, poses mantidas e sincronização. Sprites de decoração são ocultados nessa visualização para não encobrir a comparação; o cenário e a partida principal não são alterados. Foram inspecionados os quadros renderizados, incluindo preparação, arremesso, sementes e retorno. Não foi afirmada reprodução assistida do GIF em um visualizador animado.

Para reproduzir em uma cópia isolada com diretório de usuário iniciado em `AlgoLand testes`:

```sh
flatpak run --filesystem=/tmp org.godotengine.Godot --headless --path /tmp/algoland-plantio-revisao --script res://arte/fontes/personagens/raven_plantio/exportar_base.gd
flatpak run --filesystem=/tmp org.godotengine.Godot --path /tmp/algoland-plantio-revisao --script res://arte/fontes/personagens/raven_plantio/revisar_base_no_godot.gd --fixed-fps 50
ffmpeg -framerate 50 -i arte/previas/personagens/raven_plantio/motor_base/%03d.png -filter_complex '[0:v]split[a][b];[a]palettegen=max_colors=128:stats_mode=diff[p];[b][p]paletteuse=dither=none' -loop 0 -y arte/previas/personagens/raven_plantio/plantio_corpo_base.gif
```

O GIF tem600ms de ação e600ms de repouso demonstrativo. A nova base permanece como **estudo sem ativação no jogador**. Roupas, cabelos e peças de armadura ainda precisam de encaixe e revisão nas novas poses. Não publicar esta base como animação completa do personagem personalizável antes disso.
