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

**Fenda.** Onze mapas exploráveis, com patrulhas, grupos, elites e um guardião por andar. A barra exige 60–72% dos pontos disponíveis para evitar limpeza obrigatória de becos. Depois do mapa 11, o circuito repete 2–11 com dificuldade crescente. Orion oferece melhorias, refino, encantamentos e avanço depois da vitória. Os checkpoints continuam em blocos de dez.

**Exploração e escolhas.** A partir do segundo andar, ecos opcionais oferecem descanso ou fragmentos, risco por ouro e mudança na meta da caçada. A decisão vale para o grupo e não pode ser repetida ao viajar. Modificadores de clima/combate aparecem a partir do quarto andar. O portal dos mímicos tem 15% de chance por andar; o baú gigante conserva 5% de chance de uma peça de conjunto lendária no nível 5, além de ouro e fragmentos.

**Primeiro arco do Limiar.** Quatro pedidos encadeados de Lia, Bento, Ivo e Estela ligam a primeira vitória, a horta e os andares 6 e 10. Há projetos de equipamento como recompensa e uma conclusão que restaura o selo da praça. A fonte passa a recuperar até 30 de energia por jogador/dia. O diário de missões acompanha a etapa atual, sem reiniciar saves existentes.

**Equipamento.** A arma é selecionada pela barra, sem slot dedicado na tela. Escudo e aljava equipados liberam espaço na mochila; o escudo permanece equipado com armas incompatíveis, mas sem atributos ou animação. As armas têm especialidades de combo, contragolpe, impacto e distância, explicadas nas dicas. Há 24 receitas de equipamento e três conjuntos com quatro peças independentes, refino e ascensão de raridade. A fabricação com Ivo usa materiais físicos e prazo no calendário.

**Fazenda, vila e pesca.** Quatro estações, plantio, ferramentas melhoráveis, refeições e poções ligadas às expedições. A vila tem agendas, conversas, cartas, pedidos e amizade. A pesca tem minijogo, coleção, encomendas e evolução da vara. Escolher a vara funciona também na barra da fazenda.

**Persistência e cooperativo.** Ouro, totens e melhorias temporárias de armas pertencem à partida; conjuntos, ferramentas, materiais e progresso da vila sobrevivem à derrota. O cooperativo local mantém inventários e ambientes individuais, com entrada conjunta na fenda.

**Áudio e controles.** Trilhas instrumentais procedurais de vila, fazenda, praia, fenda e guardião, com ambientes de bosque, mar e caverna. Volumes separados de música, efeitos e ambiente no título e na pausa. Remapeamento persistente de teclado e controle, com comandos de combate próprios para o jogador 2, verificação de conflitos e restauração dos padrões.

O mapa técnico em [ferramentas/projeto/CONTEXTO.md](ferramentas/projeto/CONTEXTO.md) reúne caminhos, contratos e comandos de teste. Para criar ou alterar conjuntos, seguir [o padrão de armaduras](ferramentas/armaduras/PADRAO.md).

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
