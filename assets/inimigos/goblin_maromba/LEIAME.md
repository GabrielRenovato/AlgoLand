# Goblin Maromba — chefe da onda 30

Goblin musculoso inspirado na referência enviada, com couro marrom, presas e porrete de madeira com cravos. Aparece nas ondas 30, 80, 130… no rodízio existente. Não causa dano por contato.

- **Porretada:** golpe frontal curto, com preparação de 0,45 s.
- **Varrida:** golpe circular de alcance intermediário, preparação de 0,7 s.
- **Salto esmagador:** aproximação de até 300 unidades, com marca no destino e impacto na aterrissagem.
- **Fúria:** especial de três golpes próximos em sequência; recarga de 13 s.
- **Execução:** área fatal de raio 180 no local do jogador, aviso fixo de 2,5 s, salto e esmagamento. Usada uma vez aos 50% e uma vez aos 10% de vida. Sair da área evita a morte instantânea.

A IA escolhe salto à distância e golpes de proximidade quando perto; navega ao redor dos obstáculos e volta a agir após a recuperação. Colisão de dano acompanha a silhueta, independentemente da colisão dos pés.

## Arte e importação

Gerado com a ferramenta integrada **image_gen**, com transparência. Prompts e fontes em `arte/fontes/inimigos/goblin_maromba/prompt_*.txt` e `arte/fontes/efeitos/goblin_maromba/prompt_efeitos.txt`. A porretada v2 corrige arma cortada/oculta.

Seis páginas de corpo, células de 256 px, ordem frente/costas/direita/esquerda. Movimento possui 12 quadros por direção; as cinco páginas de ataques mantêm seis. A caminhada lateral inclui apoio, transferência de peso e passagem com as pernas próximas nas duas metades do ciclo. Frente e costas preservam as seis poses anteriores, com dois tempos por pose. O ciclo acompanha 72 unidades de deslocamento e para no quadro zero quando imóvel. O importador ancora o tronco para evitar deslocamentos laterais causados pelo balanço do porrete.

Efeitos independentes em `assets/efeitos/goblin_maromba`, seis quadros por efeito. Importação nearest, alpha binário, sem trilinear. O importador encontra poses completas e reúne ilhas de alpha da arma para não cortá-la na grade.

Ferramentas: `ferramentas/inimigos/preparar_goblin_maromba.gd`, `ferramentas/efeitos/importar_efeitos_goblin_maromba.gd`, `ferramentas/inimigos/previa_goblin_maromba.gd`, `ferramentas/inimigos/previa_execucao_goblin.gd`.

## Teste

F3 → **GOBLIN** permite ir à onda do chefe e testar os cinco ataques. `testes/teste_goblin_maromba.gd` verifica seleção por distância, contato, preparação, acertos únicos, três golpes, fuga do hit kill, limiares e recuperação. Executar na cópia preparada por `ferramentas/projeto/preparar_testes.py`, sem tocar no save da partida.

Prévias em `arte/previas/inimigos/goblin_maromba/`.
