# Minotauro

Chefe da onda 10, repetindo a cada 50 ondas. O Dragão Vermelho permanece na onda 50.

Três ataques normais: investida reta de 280 unidades com aviso e atropelamento de mobs pequenos; pisão circular; varrida de machado em cone. Sem dano por contato. Obstáculos bloqueiam a investida e o dano através de paredes.

Especial Fúria do Labirinto: abaixo de 40% de vida, uma vez por combate, rugido, três investidas consecutivas com novos avisos e um pisão maior. Disponível também no F3, junto dos ataques normais e do salto para a onda do chefe.

Fontes, referência e prompts em `fontes/`. Arte gerada pela ferramenta integrada de imagens, com revisão da arma. O importador `ferramentas/inimigos/preparar_minotauro.gd` usa fontes `*_arma_v2.png`, exceto `machado_arma_v3.png`. A margem horizontal uniforme recupera lâminas que ultrapassam a grade da fonte; isolamento de silhueta elimina fragmentos vizinhos. Faixas verticais permanecem independentes. Folhas nativas: 6 colunas, 4 direções, células 192×192 com conteúdo 176×176 e paleta de 41 cores; Sprite na escala nativa 1 e nearest. A resolução foi duplicada para preservar os detalhes das fontes sem ampliar blocos de pixels, mantendo o tamanho e a posição no jogo.

Efeitos separados em `Efeitos/minotauro/`; configuração e sincronização em `Codigos/Inimigos/minotauro.gd`. A área de acerto acompanha a silhueta de cada quadro. Testes e prévias devem executar no projeto com saves isolados.

Prévia dos ataques: `previas/ataques.gif`, gerada pelo script `ferramentas/inimigos/previa_minotauro.gd`.

Ritmo: perseguição 72 unidades/s, aceleração 420, investida 420 unidades/s (480 na Fúria), recuperação de 0,4 s (0,2 s no combo) e recarga normal de 0,75 s. Avisos prévios preservados.

Caminhada: `fontes/caminhada_v2.png` e `fontes/prompt_caminhada_v2.txt`, gerados pela ferramenta integrada usando a sequência de seis poses do personagem em `fontes/referencia_passos_mana_seed.png` como referência. A folha foi mantida conforme solicitado, incluindo a limitação visual da passada lateral. O ciclo avança a cada 8 unidades de deslocamento e para quando o corpo não se move. A folha antiga `movimento.png` continua sendo usada no repouso.

Decisão de ataques: até 65 unidades alterna machado e pisão; até 90 usa pisão; mais longe usa investida para alcançar ou fechar a distância. Não força área pela ordem dos golpes. Paredes bloqueiam o início automático, mantendo a navegação. No especial, aproxima antes do pisão final se o alvo estiver fora dos 125 de alcance.

Retomada de perseguição: perto do jogador e sem linha de ataque livre, ignora temporariamente o raio de parada para continuar contornando o obstáculo pela navegação. A espera pelo pisão final libera o estado de ataque durante a aproximação. Regressão em `testes/teste_chefe_parado.gd`.
