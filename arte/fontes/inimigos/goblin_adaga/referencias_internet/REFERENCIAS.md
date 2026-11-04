# Referências de movimento — corrida do goblin

Pedido atual: corrigir animação de corrida, preservando aparência e qualidade do personagem. A proposta anterior de trocar o acabamento foi descartada após esclarecimento do usuário.

## Referência principal inspecionada

- Oul Studio, [Top-Down Player Template](https://oul-studio.itch.io/top-down-player-template): prévia pública Run, 8 quadros em quatro direções; página informa corpo 22×28 px e corrida a 12 fps. Página registra CC0; pacote atual é pago e não foi adquirido. Somente prévias públicas foram baixadas para estudo.
- `oul_previa_2.gif`: original da prévia de corrida. `oul_corrida_frontal_limpa.png`: recorte frontal de todos os oito quadros, sem modificar suas poses. A primeira versão de recorte incluiu fragmentos dos personagens laterais e não deve orientar a geração.
- Observações: cabeça conserva a direção e acompanha a altura do tronco; braços em oposição às pernas; perna recuada encurta visualmente; metade oposta do ciclo troca apoios. A referência não faz a cabeça olhar repetidamente para cima/baixo.
- Aplicação: estudar coordenação, apoio e continuidade. Referência de movimento, sem transferência literal de pixels ou proporções. Sequência 4,5,6,7,0,1,2,3 (índices zero) para iniciar com perna direita do goblin.

## Referências complementares inspecionadas

- Calciumtrice, [Animated Goblins](https://opengameart.org/content/animated-goblins), CC-BY 3.0, atribuição Calciumtrice. Folha `calciumtrice_goblins.png`: goblin com faca, caminhada e ataque. Orientação lateral/oblíqua, serve para postura compacta, contrabalanço e gesto da arma; não como molde frontal.
- Gman2099, [RPG Goblin Knife Jab Animation Sprite Sheet](https://opengameart.org/content/rpg-goblin-knife-jab-animation-sprite-sheet), CC0; autor pede crédito. `gman2099_goblin_knife_attack.png`: gesto de jab em seis quadros. Não serve para corrida frontal.
- trexman1234, [Pixelart goblin walkind down](https://opengameart.org/content/pixelart-goblin-walkind-down), CC-BY 4.0; atribuição trexman1234. `trexman1234_frente.png`: quatro quadros de caminhada frontal, não corrida.

Nenhum pacote externo foi integrado como sprite do jogo. Arte nova usa image_gen integrado; as fontes externas são referências de estudo, identificadas acima.

## Contrato da correção

- Somente correr para baixo, direção em discussão; preservar combo e direita.
- Identidade do goblin original `correr_baixo_antes_cabeca.png`; não usar cabeça com pescoço alongado e grandes acenos como padrão.
- 8 quadros, 4×2 células de 640, pivô (320,560), escala 0,071, altura referência 31 px, mesmos tempos 50/60/40/50/50/60/40/50 ms e velocidade 100 px/s.
- Apoios alternados, compressão, passagem e voo; pequena oscilação solidária de quadril/tronco/cabeça, sem reescalar membros.
