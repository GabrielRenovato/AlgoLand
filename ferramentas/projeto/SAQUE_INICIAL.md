# Equipamentos dos dois estágios iniciais

## Conteúdo

O conjunto Guarda Novato usa as mesmas quatro malhas do uniforme de Noel, no rig e no material aprovados. Itens reais: elmo, peitoral, luvas e botas. O manifesto compartilhado gera os dados; recursos 3D e aparência de Noel permanecem preservados. Ícones próprios em SVG usam grade nativa de 16 pixels e filtro nearest. Não se cria um segundo corpo nem uma nova animação.

As tabelas da campanha não alteram os drops de receitas e materiais da arena. Guarda Novato conserva chance zero no sorteio geral. Versões comum e rara (azul) são nível 1; raras usam o multiplicador comum de raridade e um afixo físico. O terceiro conjunto não é uma raridade nova: as peças azuis continuam contando no mesmo set.

| Região | Tabela de armaduras | Acessórios |
| --- | --- | --- |
| Chegada | Nenhuma | Anel de cobre (+6 vida), amuleto de madeira (+8 fôlego) |
| Estrada | Nenhuma | Cinto de couro (-4% custo da esquiva), bracelete de ferro (+8% empurrão), anel e amuleto |

Acessórios são comuns, cada qual em um slot independente. Valores fixos pequenos, sem magia ou experiência de maestria. Duas peças de Guarda Novato reduzem o consumo do bloqueio em 5%; quatro reduzem também o custo da esquiva em 5%. Os bônus não escalam pela raridade nem se acumulam ao reaplicar o equipamento.

## Rolagens e garantias

- Rebentos da chegada: 18% de chance de acessório por morte; estrada: 24%. Todos esses drops são acessórios comuns.
- O guardião inicial da passagem concede um acessório da chegada uma vez por tentativa, priorizando um ainda não possuído.
- Cerne Partido fica sem drop de equipamento até a definição de sua recompensa.
- Encontrar o trabalhador concede um acessório da estrada uma vez por tentativa, priorizando um ainda não possuído. Não exige abater os encontros da estrada.
- Nenhum dos dois primeiros estágios sorteia peças de armadura. A tabela de armaduras das galerias do moinho é independente.
- As garantias são concedidas após os objetivos da tentativa atual. Uma nova entrada reinicia as garantias do estágio; recibos repetidos da mesma tentativa continuam bloqueados.

## Coleta e persistência

`saque_campanha` é um campo aditivo do inventário da campanha: pendências, garantias já concedidas e recibos recentes da rede. Um drop é salvo antes de aparecer. Ao recolher, inclusão na mochila e remoção da pendência compartilham a gravação atômica do inventário. Falhas restauram mochila e recibo; mochila cheia mantém o objeto e a pendência. Pendências continuam no chão durante a tentativa, inclusive com a mochila cheia. Uma nova entrada ou reinício por derrota descarta o saque não recolhido daquele estágio; itens já coletados permanecem na mochila. O filtro de venda automática da arena não vende essas recompensas.

Em expedições online, somente o anfitrião envia eventos de abate. Cada participante sorteia na própria tabela e persiste seus itens localmente. Convidados rejeitam eventos enviados por outro convidado; recibos repetidos não rolam outro item. O anfitrião não envia atributos de itens arbitrários.

## Comandos

`python3 ferramentas/projeto/harness.py testar --perfil drops-iniciais` valida tabelas, itens, atributos, slots, cliques, persistência, coleta e renderização do conjunto real. Saves isolados. Conferir as capturas, as peças separadas, quatro direções e a sequência de movimento; números de verificações não substituem revisão visual.

Regressões: `campanha-percurso`, `maestria`, `conjuntos` e os testes de inventário/expedição pertinentes. Nunca executar scripts de revisão na partida do usuário.
