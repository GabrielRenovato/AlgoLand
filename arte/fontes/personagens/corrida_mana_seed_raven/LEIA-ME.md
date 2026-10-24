# Corrida modular Raven com movimento Mana Seed

O movimento usa os seis quadros reais da página1 do corpo Mana Seed disponível no projeto, conferidos com `running sample.gif`: colunas0,1,6,3,4,7; linhas4–7. A ordem do jogo é baixo/direita/cima/esquerda. Os tempos são100/60/140/100/60/140ms por ciclo na velocidade80. O ciclo acompanha a velocidade sem alterar o deslocamento físico do jogador.

O compilador usa o movimento como máscara; transfere os pixels nativos do corpo e das roupas com as mesmas coordenadas anatômicas, preservando suas rampas e detalhes. A cabeça é transladada sem escala, e o short neutro fica sob as peças. Roupas,28 cabelos, capa, aljava e quatro peças dos três conjuntos permanecem independentes e acompanham as poses. O estudo antigo de seis quadros, rejeitado, não foi reaproveitado.

Saída em `assets/personagens/raven_fantasy/corrida_mana_seed/`, células80×80, folha480×320, raiz40,47. `corrida_raven.gd` define os tempos; `aparencia_raven.gd` carrega as folhas compactas em todas as plataformas. Somente correr usa seis colunas; ataques, colheita e prévias neutras voltam para quatro. A poeira acompanha os dois contatos; a elevação está nas poses, sem salto adicional do renderizador.

Em projeto com save isolado iniciado em `AlgoLand testes`:

```sh
# Gerar a base/camadas; cada conjunto também pode ser compilado pelo manifesto.
flatpak run --filesystem=/tmp org.godotengine.Godot --headless --path PROJETO_ISOLADO --script res://ferramentas/personagem/preparar_corrida_raven.gd
flatpak run --filesystem=/tmp org.godotengine.Godot --headless --path PROJETO_ISOLADO --script res://ferramentas/armaduras/gerar_conjunto.gd -- res://ferramentas/armaduras/modelos/carrasco.json --somente-corrida
flatpak run --filesystem=/tmp org.godotengine.Godot --headless --path PROJETO_ISOLADO --script res://ferramentas/armaduras/validar_conjunto.gd -- res://ferramentas/armaduras/modelos/carrasco.json --corrida
flatpak run --filesystem=/tmp org.godotengine.Godot --path PROJETO_ISOLADO --script res://testes/teste_corrida_mana_seed_raven.gd
flatpak run --filesystem=/tmp org.godotengine.Godot --path PROJETO_ISOLADO --script res://ferramentas/personagem/revisar_corrida_colheita_raven.gd --fixed-fps 50 -- --somente-corrida
```

O teste verificou2531 condições: limites temporais,28 cabelos nas24 poses, margens, fases aéreas, peças reais, sincronização das camadas e troca de grade ao parar, colher ou gerar prévia do inventário. O validador compartilhado verificou os três manifestos. As folhas de contato e o GIF mostram os sprites renderizados no Godot; a sequência da corrida foi capturada em passos20ms, nas quatro direções, com dois ciclos por direção. O GIF não contém colheita. Foram inspecionados quadros e transições; não foi afirmada reprodução assistida de GIF em visualizador animado.

A revisão02 foi publicada no conteúdo8.

Revisão02: quadril definido pela origem das duas coxas; não usa branco do rosto como marcador de roupa. Capa com comprimento constante no salto, fecho separado e profundidade por direção. As peças de armadura só recebem fechamento nos poucos pixels de borda descobertos; os detalhes internos permanecem amostrados da arte original. Ajuste posterior ao conteúdo8: qualquer movimento do joystick usa a corrida nova de seis quadros e a velocidade normalizada, inclusive no toque leve; teclado também corre. O GIF `comparacao_corrida_revisada.gif` tem o Raven original em cima e a revisão embaixo; ambos são renderizados na mesma escala. O GIF `corrida_revisada.gif` mostra somente a revisão. O GIF anterior foi preservado em `rejeitada_v1/`. A codificação GIF foi comparada às capturas PNG e conserva exatamente as cores em cada quadro.
