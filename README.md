# AlgoLand

Jogo 2D desenvolvido em Godot 4. O ponto de entrada é `cenas/inicio_do_jogo.tscn`.

## Organização

```text
assets/       recursos usados pelo jogo: personagens, inimigos, cenário, UI, efeitos e áudio
codigo/       scripts por responsabilidade: jogador, inimigos, dados, globais, lógica e UI
cenas/        cenas do jogo e componentes reutilizáveis
recursos/     configurações e recursos compartilhados, como o tema de interface
addons/       plugins habilitados do editor e dependências de terceiros
ferramentas/  geradores, importadores, renderizadores de prévias e auditoria do projeto
testes/       regressões; executar com saves isolados
arte/         fontes, referências, prompts, pacotes originais e prévias de desenvolvimento
arquivo/      conteúdo legado e assets sem uso atual, preservados para consulta
docs/         documentação e registro da reorganização
builds/       exports, backups temporários e outros arquivos locais regeneráveis
```

`arte/`, `arquivo/` e `builds/` têm `.gdignore`: não participam da importação do Godot. Fontes são lidas pelos geradores como arquivos. Os presets de exportação também excluem ferramentas, testes e documentação. `builds/`, caches, backups `.tmp` e quadros intermediários de prévias não entram no Git.

Scripts e cenas próprios usam nomes em `snake_case`. Nomes internos de assets e plugins de terceiros foram preservados para manter compatibilidade. Novos assets devem entrar na categoria correspondente em `assets/`; fontes e previews ficam em `arte/`, nunca junto dos sprites de runtime.

Mais detalhes: [estrutura do projeto](docs/estrutura_projeto.md). Antes de alterar conjuntos, ler [o padrão de armaduras](ferramentas/armaduras/PADRAO.md).

## Sistemas principais

**Ondas e chefes.** A arena (`codigo/logica/gerenciador_de_ondas.gd`) roda ondas com vida, dano e ouro crescentes. Ondas de bônus (mímicos) e eventos de clima/modificadores são sorteados, mas nunca na onda de chefe. A cada 10 ondas (`intervalo_chefe`) entra um chefe sozinho, sem escolta, em rodízio; depois do último, o ciclo recomeça mais forte pelos multiplicadores por onda:

| Onda | Chefe | Observação |
|---:|---|---|
| 10 | Minotauro | investida, pisão, machado e pisão em fúria |
| 20 | Medusa | garras, cauda, bote, olhar de pedra e ruína em área |
| 30 | Goblin Maromba | porretada, varrida, salto, fúria e execução |
| 40 | Cogumelo Ancião | escala 2,4; esporos em área e invocação de cogumelos |
| 50 | Dragão Vermelho | sopro, cauda, asas, patada e chuva de fogo |

Chefes têm coroa dourada, barra de vida no HUD e avisos de ataque no chão. Ao morrer, soltam sementes garantidas para a fazenda, sempre soltam equipamento, rendem 15 Brasas e têm 5% de chance de soltar a Moeda de Forja. Cada chefe derrotado libera a onda seguinte (11, 21...) como ponto de partida. Os dados do rodízio ficam em `CHEFES`; habilidades genéricas em `codigo/inimigos/habilidade_chefe.gd`.

**Armaduras.** Quatro peças independentes (elmo, peitoral, luvas, botas). Os três conjuntos são **comuns**, caem desde a onda 1 e sempre no **nível 1**. As peças só caem de **chefes**, por chance: o equipamento que o chefe solta tem 10% de ser peça de cada conjunto (30% no total, nada garantido). Mobs normais e mutantes continuam soltando só sementes, armas e escudo, como antes. Por serem raras, o poder vem de farmar chefes e evoluir cada peça na bigorna. O cadastro está em `codigo/dados/conjuntos_armadura.gd`:

| Conjunto | Efeito (4/4 no nível 1) | Com 2 ou 3 peças |
|---|---|---|
| Carrasco | 10% de chance de raio ao acertar (dano 200%, recarga 2 s) | metade da chance |
| Cavaleiro Rubro | +10% defesa e +10% vitalidade | +5% e +5% |
| Mordomo (`cavalheiro`) | 10% de congelar o alvo por 2 s (recarga 2 s) | metade da chance |

Regras (`codigo/dados/base_conjunto_armadura.gd`): 1 peça não dá bônus; 2 ou 3 dão metade; 4 dão o efeito completo. Cada nível acima do 1 soma 25% ao efeito (nível 5 = 2x), usando o nível da peça equipada mais fraca do conjunto. No Carrasco o nível também aumenta o dano do raio.

**Bigorna de armaduras.** Peças de conjunto sobem na bigorna, uma por vez, pagando o mesmo ouro e a mesma onda mínima das armas **mais 1 Moeda de Forja por nível**. A moeda cai de qualquer chefe com 5% de chance, vai direto para a bolsa (aviso no HUD), é única para todos os conjuntos e, como o equipamento, se perde ao morrer. Fica em `InventarioJogador.moedas_forja` e é salva em `inventario.json`.

**Ascensão de raridade.** No nível 5 a peça de conjunto não sobe mais de nível: cada melhoria na bigorna sobe um degrau de raridade (comum > incomum > raro > épico > lendário) e soma um bônus aleatório que ela ainda não tem (crítico, dano crítico, roubo de vida, velocidade, vitalidade ou defesa). O multiplicador da raridade também passa a valer sobre a vitalidade e a defesa da peça. Cada degrau custa 1 Moeda de Forja e 2500, 3500, 5000 e 7000 de ouro (`Equipamentos.CUSTOS_ASCENSAO`); lendária nível 5 é o máximo, com 4 bônus.

Sets podem ser misturados, e a aparência acompanha as peças equipadas nas 11 páginas de animação. O F3 oferece prévia cosmética (sem bônus) e a ação EQUIPAR, que coloca itens reais nos slots. Para criar ou alterar um conjunto, seguir [o padrão de armaduras](ferramentas/armaduras/PADRAO.md).

**Mochila única (arena e fazenda).** A mochila é a mesma nos dois lugares, e a barra de baixo (teclas 1 a 5, toque) é a primeira linha dela. O kit inicial vem com espada e escudo na mão e enxada, regador e mão (colher) na primeira linha; a lança fica na segunda. Ferramentas e sementes são itens da mochila: arrastam como qualquer item, as sementes empilham (uma casa por planta, com a quantidade no canto) e a dica mostra o tempo de crescimento. Na fazenda, escolher a casa de uma ferramenta ou de uma semente da estação a torna a ferramenta ativa (o nome dela fica fixo acima da barra); arma e escudo não fazem nada lá, e ferramenta e semente não fazem nada na arena. Ao morrer, as ferramentas voltam com o kit e as sementes ficam. Saves antigos têm as sementes passadas da fazenda para a mochila na primeira carga (`Fazenda.migrar_sementes_antigas`). Dados das plantas: `codigo/dados/plantas.gd`.

**Progresso permanente.** Ao morrer, a partida vira Brasas (2 por onda, 15 por chefe, 5 por bônus), gastas em melhorias e moradores do acampamento (`codigo/globais/progresso.gd`).

**Cidade e moradores.** A partida começa na **Vila das Flores** (`cenas/cidade.tscn`), com seis interiores: venda do Tomás, casa da comunidade da Lia, enfermaria da Dona Rosa, pousada do Caio, casa da Estela e casa do Bento. Os NPCs e seus serviços saíram da arena. A trilha oeste leva à fazenda e a leste à arena; a caverna da arena só abre entre ondas. As portas e as conversas usam F ou o botão de interação do controle. As ondas começam no mural de desafio da arena; a bigorna na cidade consulta a onda guardada pela transição.

Os moradores seguem agendas do relógio: trabalham, encontram-se na praça e voltam para casa à noite. No inverno, os encontros externos passam para a pousada. A praça ganha bandeirinhas no último dia de cada estação e lampiões ao anoitecer. A pousada permite passar a noite. Diálogos acompanham horário, estação e amizade; conversar uma vez por dia dá amizade. Os apoios permanentes da curandeira, do bardo e da mística continuam dependendo das contratações existentes, agora feitas com Lia.

O mural da praça e da comunidade mostra a localização dos moradores e seis pedidos: conhecer os vizinhos, visitar os interiores, entregar colheitas, vencer ondas e derrotar o primeiro chefe. Aceitar é gratuito; a entrega acontece com o autor do pedido e concede Brasas e amizade. Pedidos de colheita guardam a estação em que foram aceitos. Bento também oferece duas sementes da estação por dia, quando há espaço na mochila. Missões, amizade e presentes ficam em `user://cidade.json`, separados dos outros saves; novo jogo limpa esse arquivo.

A cidade usa o **kit novo Mana v2**, gerado com as folhas Mana Seed do projeto como referência de estilo. O chão usa `recursos/cidade/tileset_cidade.tres`; as casas usam `recursos/cidade/tileset_construcoes.tres`. As construções em `recursos/cidade/construcoes/` possuem TileMapLayers editáveis para paredes, telhado, portas e janelas. Os PNGs originais de 1254×1254 ficam preservados em `assets/cenario/cidade/tilesets/mana_v2/`, sem redução; os atlas recortam as peças com alturas próprias. Os prompts estão em `arte/fontes/cidade/prompts_mana_v2.json`.

O mapa é uma vila compacta de 864×704, com as seis construções próximas da praça, caminhos curtos, um riacho na borda com ponte, pequeno lago e horta. O cadastro e as agendas ficam em `codigo/cidade/dados_cidade.gd`, e as posições em `codigo/cidade/layout_vila.json`. Gere o kit e os exemplos com `python3 ferramentas/cidade/gerar_tilesets.py`, depois a cidade com `python3 ferramentas/cidade/gerar_cidade.py`. Testes e prévias devem usar a cópia com saves isolados descrita abaixo.


## Verificação

```bash
python3 ferramentas/projeto/auditar_referencias.py
flatpak run org.godotengine.Godot --headless --editor --path . --import --quit
```

Para testes que inicializam cenas ou alteram inventário, preparar uma cópia fora do repositório:

```bash
python3 ferramentas/projeto/preparar_testes.py /tmp/algoland-testes
flatpak run org.godotengine.Godot --path /tmp/algoland-testes \
  --script res://testes/teste_estrutura_projeto.gd
```

A cópia usa o nome `AlgoLand testes Carrasco` por compatibilidade com as proteções existentes dos testes. Seus arquivos `user://` são separados da partida principal.

A casa inicial da fazenda usa uma fachada compacta no mesmo sistema das casas da cidade, com sombra, fumaça e luz nas janelas. O exterior acompanha calendário e F3: flores de primavera, flores amarelas no verão, plantas secas no outono e neve no telhado e nas floreiras no inverno, sem mudar a âncora ou as colisões. O interior tem um cômodo com piso e paredes Mana Seed, cama, baú, estante, mesa com duas cadeiras e lareira. A planta fica em `ferramentas/cidade/layout_interiores.py`; `python3 ferramentas/fazenda/gerar_fazenda.py --somente-casa` atualiza somente a cena interna depois de gerar o layout. A imagem original e o prompt ficam em `arte/fontes/fazenda/casa_inicial/`; `preparar_casa_inicial.py` prepara a fachada e sua máscara de sombra. As cenas identificam o nível inicial com `metadata/nivel_casa = 1`, mantendo os ids e pontos de chegada para futuras ampliações; a compra de melhorias ainda não foi implementada.

Moradores vestem capas de chuva com capuz na chuva leve e forte, somente do lado de fora. Os seis moradores têm 28 quadros em `assets/npcs/cidade/capas_chuva/`, com a mesma célula de 64×64, escala e posição dos pés das folhas normais. `python3 ferramentas/cidade/preparar_npcs_chuva.py` prepara as folhas e prévias a partir das imagens em `arte/fontes/npcs/capas_chuva/`. Em TEMPESTADE, cada morador volta pela porta da própria casa, permanece lá e retoma a rotina quando o temporal termina. As capas são retiradas nos interiores e quando para de chover. `testes/teste_moradores_clima.gd` verifica agendas, troca de traje, volta para casa e moradores nos interiores; executar com saves isolados. A arte e as folhas antigas dos guarda-chuvas foram preservadas como referência, sem uso no visual atual.
