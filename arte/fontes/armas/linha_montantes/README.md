# Montantes de duas mãos

Cinco modelos novos; a Espada de Duas Mãos original e seus ids permanecem disponíveis.

| Modelo | Raridade inicial | Andar da receita | Dano da arma no nível 1, com raridade | Efeito inicial |
|---|---|---:|---:|---|
| Ferro | Comum | 8 | 9 | Último golpe do combo +25% |
| Sentinela | Incomum | 12 | 11 | Último golpe do combo +25% |
| Geada | Raro | 18 | 13 | Lentidão de 25% por 2s |
| Trovão | Épico | 25 | 16 | Raio de 40% do golpe em outro alvo até 70px |
| Astral | Lendário | 35 | 20 | Choque de 30%; 20% de chance de paralisar por 0,6s |

Todos preservam o bônus do último golpe, podem evoluir nos cinco níveis da bigorna e usam as regras existentes de encantamentos. A raridade indicada é a de fabricação; a ascensão continua disponível. A receita exige descoberta e materiais, além do andar mínimo. A fabricação leva dois dias.

## Arte e integração

Conceitos produzidos pela ferramenta integrada de imagem, sem CLI. Os prompts exatos estão em `../montante_{ferro,sentinela,geada,trovao,astral}/prompt.txt`, junto de cada `conceito.png`. Os conceitos orientam o desenho; não são reduzidos automaticamente para virar sprites.

O desenho canônico foi feito em pixels nativos no PixelLab, id `fb3b7ee2-b0b1-4701-b183-0a526d4319b0`. `receita_pixellab.json` reproduz o desenho e `montantes_nativos.png` contém cinco células 24×32. Cada modelo também guarda seu `sprite_nativo.png`.

`ferramentas/armas/preparar_montantes.py` recorta as células sem escala e usa as pegadas da espada Raven para as rotações rígidas. O quadro de passagem conserva o arco original, tingido no material da nova arma. Porte e cabo são texturas independentes com o mesmo pivô; o cabo sobe diante do elmo na corrida de costas. Os níveis da bigorna preservam a paleta própria de cada modelo.

Recursos consumidos pelo jogo: `assets/personagens/armas/montantes/` e `assets/personagens/raven_fantasy/icones/montante_*.png`. Dados em `codigo/dados/armas_montantes.gd`. O ranking agrega o uso à família de espada de duas mãos, compatível com o contrato atual do servidor.

## Teste e revisão

F3 → COMBATE → MONTANTES → RECEBER CINCO (MOCHILA) → EXECUTAR. Selecione cada arma na barra da mochila. Repetir a entrega preserva as instâncias existentes.

`testes/teste_montantes.gd`: 416 verificações, zero falhas, no Godot gráfico com save isolado. Inclui os callbacks reais do F3, raridades, ícones, seleção, escudo suspenso, persistência, efeitos no combate, quatro direções, cabo diante do elmo, retorno à lança/espada antigas e 20 ataques com temporizador real de 300ms. Revistos os quadros, a sequência e o painel em 576×324 e 288×512. Evidências em `arte/previas/armas/montantes/`, incluindo os tempos medidos e GIF com 75ms por pose.

Fabricação: 605 verificações, zero falhas. Especialidades e combate: zero falhas funcionais. A suíte legada `teste_raridade.gd` apresenta as mesmas 11 falhas e o mesmo erro de StyleBox antes e depois desta mudança. `teste_escudo_condicional.gd` também para antes e depois ao acessar o campo antigo `no_reacao._escudo`, que está nulo no compositor atual. Esses problemas anteriores não foram alterados aqui. O motor também registra avisos de recursos ao encerrar as cenas, já presentes na versão anterior.

O conteúdo 31 publicado usa o código `f9d42411e`; estes cinco modelos são uma alteração posterior, disponível no projeto para testar pelo F3.
