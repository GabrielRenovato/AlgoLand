# Morte do goblin de adaga

Modelo canônico modelo_base.png, mesmas roupas leves/cabelo/rosto e adaga dos combos vigentes. Referência de gesto: morte articulada do goblin de machado, sem copiar corpo ou arma. Direita, baixo/frente e cima/costas desenhadas; esquerda espelha direita. Célula640, grade4x2, raiz320/560, escala.071, corpo31px. Uma transformação por folha, sem recorte ou escala por pose.

8quadros,80/100/110/100/100/120/160/500ms (1270ms), sem loop. Golpe fatal/recuo, perda de apoio, joelho no chão, queda lateral com apoio da mão livre, contato de ombro/cabeça, corpo deitado, acomodação, repouso. Mão direita mantém adaga até soltar durante a queda; arma termina ao lado, sem reaparecer ou trocar de mão. Sem sangue ou arco de corte na morte.

Guia representativo direita: cabeça350/200→325/245→290/330→250/400→210/465→200/490→200/495→200/495; quadril310/430→300/450→310/485→330/510→345/525→345/535→345/535→345/535. Ombros seguem cabeça, cotovelo esquerdo dobra antes da mão apoiar; joelhos flexionam antes da queda e pés param de sustentar o corpo. Frente e costas adaptam a perda de apoio no plano do chão com rosto/dorso correspondentes.

Consumidores: animacoes.tres/SpriteFrames e mob ativo goblin_pomar.gd. Substituir giro rígido/fade antigo pela sequência; segurar corpo no último quadro antes de limpar a instância. Preservar efeitos de morte, drops, colisão desativada e uma emissão de inimigo_morreu. Fontes/prompts e capturas preservados. Harness goblins-pomar + revisão real no Godot com save isolado.

## Preparação e integração efetiva
Fontes1774x887, grade4x2. Direita lado512/deslocamento(64,73); baixo lado505/(67,80); cima lado534/(53,56). Limiar de alfa128/255, transformação comum às oito poses. Esquerda espelha direita exportada. Queda1270ms; no mob ativo, repouso adicional900ms, fade350ms, remoção ao fim. Clock da morte independe de fatores de lentidão para não travar cadáveres. A cena visual segura último quadro e sinaliza término uma vez; inimigo ativo preserva efeitos, drops/sinal único e desliga colisão.
