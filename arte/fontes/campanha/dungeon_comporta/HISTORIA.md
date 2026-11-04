# A água que deixou de voltar

Depois da defesa da vila, o moinho para. A corrente está represada nas galerias antigas, ocupadas por goblins. Sem o moinho, a vila não consegue moer o grão que restou.

As marcas do nível da água revelam o bloqueio. A transmissão externa confirma que o comando principal está no subsolo; examinar a roda indica a entrada de manutenção sob a praça. Essas investigações não liberam a água.

O jogador atravessa a gruta ampliada. Quatro cozinhas com fogueira e panela animada, três áreas de refeição com mesas e cadeiras e depósitos com grão, cordas e ferramentas contam a ocupação dos goblins. Os personagens usam suas poses existentes e ficam voltados à atividade até perceberem o jogador ou sofrerem um ataque. Somente os goblins próprios de adaga e machado povoam as galerias.

Na câmara final fica a alavanca que controla a comporta principal. O portão de madeira isolado foi rejeitado e retirado da montagem. A derrota do guardião libera a interação com a alavanca. Puxá-la abre a comporta, devolve a corrente ao moinho e permite levar a notícia a Nilo. A seta e a distância passam do guardião para a alavanca e depois para a saída da dungeon.

## Escopo desta entrega

O boss fica pendente por pedido do usuário. Não há inimigo substituto nem liberação automática. `DungeonComporta.vincular_guardiao` receberá o futuro ator; o sinal de morte chama `registrar_guardiao_derrotado`. A missão não pode ser concluída normalmente antes dessa integração. O teste simula o sinal exclusivamente para conferir a etapa seguinte.

## Objetos

Produção original por `image_gen` integrado, com prompts em `prompts.json`. Os atlas originais permanecem nesta pasta. `barricada.png` teve fundo rejeitado; `barricada_limpa.png` é a extração corrigida usada na preparação.

- Alavanca: quadro64, pivô32/56, dois estados e quatro estações.
- Portão antigo: recurso rejeitado, sem instância na dungeon.
- Barricada, suprimentos e mesa: quadro64, pivô32/56, quatro estações.
- Cadeira: quadro32, pivô16/28, quatro estações.
- Fogueira com panela: quatro quadros64 em atlas256×64, 6 FPS, quatro estações; chama, vapor e caldo animados.

As peças têm colisão apenas na base e participam da navegação. As variantes internas usam musgo/umidade e tratamento dos materiais, sem neve dentro da caverna. Os canais de água continuam usando o atlas animado já existente no exterior; a peça da comporta não inclui água estática pintada.

Recursos: `assets/cenario/campanha/dungeon_comporta/`; preparação: `ferramentas/campanha/preparar_objetos_comporta.py`; integração: `codigo/campanha/dungeon_comporta.gd` e `roteiro_bacia.gd`.

Os prompts dos novos acampamentos estão em `prompts_acampamentos.json`. Os goblins ocupam pontos distintos nas câmaras; o plantão junto da fogueira fica voltado à panela, enquanto outros vigiam passagens e mesas. As cadeiras são objetos independentes; não há animação de personagem sentado ou mexendo a panela nesta entrega.
