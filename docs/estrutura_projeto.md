# Estrutura do projeto

A organização separa o conteúdo necessário para jogar do conteúdo necessário para produzir o jogo. Não existe uma única estrutura obrigatória de Godot; aqui usamos pastas por tipo de recurso e subpastas por responsabilidade.

## Código, cenas e recursos

`codigo/` reúne `dados`, `globais`, `jogador`, `inimigos`, `logica`, `cenario`, `efeitos`, `modelos`, `prototipos` e `ui`. Os chefes (Minotauro, Medusa, Goblin Maromba, Cogumelo Ancião e Dragão Vermelho, um a cada 10 ondas) têm scripts em `codigo/inimigos/` e entram no rodízio `CHEFES` de `codigo/logica/gerenciador_de_ondas.gd`; os conjuntos reais são cadastrados em `codigo/dados/conjuntos_armadura.gd`. Arquivos próprios têm nomes em minúsculas com sublinhados. Nomes de classes, nós, autoloads e propriedades usados pelas cenas não foram alterados.

Os interiores das casas são salas do PixelLab montadas por `codigo/cidade/interior_casa.gd` a partir de `assets/cenario/cidade/interiores/interiores.json` (ver `recursos/cidade/COMO_USAR.md`).

A arena só se alcança pelo portal da cidade (`codigo/cidade/portal_arena.gd`, arte animada em `assets/cenario/cidade/objetos/portal_arena.png`): interagir abre o painel `desafio_arena`, que chama `Transicao.entrar_na_arena()`. Na chegada o `GerenciadorOndas` começa a onda sozinho. Ao vencer, depois de um respiro, abre a tela do ferreiro (`codigo/ui/tela_mercante.gd`) em modo arena: uma janela com as abas MELHORIAS (os totens de `DadosDosItems`, pagos com ouro), BIGORNA e ENCANTAR, e um rodapé pequeno com PROXIMA ONDA e CIDADE (`Transicao.sair_da_arena()`, a onda fica guardada). Fechada, a janela se reabre pela fogueira (só entre as ondas). Ao cair, o jogador também volta para a cidade.

`cenas/` contém os pontos de entrada e locais do jogo; `cenas/inimigos`, `cenas/ui` e `cenas/efeitos` agrupam componentes. `recursos/` contém temas e configurações compartilhadas.

## Assets do jogo

- `assets/personagens/`: corpo, cabelos, roupas, armas, camadas de animação e aparências disponíveis.
- `assets/personagens/conjuntos/`: Carrasco, Cavaleiro Rubro e Mordomo, cada um com quatro peças e definição próprias.
- `assets/personagens/prototipos/`: visual de teste ainda acessível pelo F3.
- `assets/inimigos/`: folhas nativas dos mobs e chefes; `mana_seed/` preserva os arquivos originais usados pelas cenas.
- `assets/efeitos/`: avisos, congelamento e efeitos dos ataques.
- `assets/cenario/`, `assets/npcs/`, `assets/ui/`, `assets/audio/`: recursos usados pelos ambientes e pela interface.

Folhas de terceiros conservam seus nomes internos. Renomear imagens de fornecedor sem necessidade dificulta reimportar pacotes; os caminhos externos e a categoria do projeto foram padronizados. Imagens nativas não foram redesenhadas nesta organização.

## Produção de arte

`arte/fontes/` guarda conceitos, referências e prompts dos conjuntos, inimigos e efeitos. `arte/previas/` guarda imagens e GIFs de conferência. `arte/pacotes/` guarda os pacotes originais usados pelos importadores; arquivos compactados originais continuam ignorados pelo Git.

Essas pastas não são recursos de runtime. Geradores leem fontes com acesso direto a arquivos e gravam resultados em `assets/`. Renderizadores de prévias gravam em `arte/previas/`; sequências `quadro_*.png` são intermediários regeneráveis, e os GIFs finais permanecem versionados.

O pipeline compartilhado de armaduras continua em `ferramentas/armaduras/`. Manifestos, definições e caminhos foram atualizados; ids dos itens, índices de aparência, slots e páginas de animação foram preservados.

## Legado e arquivos locais

`arquivo/tiny/` reúne os mobs Tiny removidos das ondas, suas cenas, scripts, ferramenta e teste histórico. `arquivo/editor/` guarda a cópia duplicada do plugin MSCA; o plugin ativo permanece em `addons/msca/`. `arquivo/addons/` preserva o plugin Git que não estava habilitado. `arquivo/cenas/` guarda cenas antigas sem uso, incluindo a pasta explicitamente chamada `nao_usados`.

`arquivo/assets/` contém pacotes e variantes sem referências em código, cenas, configurações, ferramentas ou testes. A ausência de referência não foi usada para apagar arquivos: o material foi preservado e retirado da importação/exportação. Reintegrar conteúdo exige movê-lo de volta para `assets/` e atualizar seus caminhos antes de carregá-lo.

`builds/legado/` conserva localmente os dois exports `.pck` antigos. `builds/temporarios/` conserva backups `.tmp`, incluindo os antigos backups na raiz e nas cenas. Esses arquivos deixam de ser versionados. O histórico anterior do Git também permite recuperar seus conteúdos.

## Conferência e manutenção

`ferramentas/projeto/auditar_referencias.py` detecta caminhos literais ausentes e dependências do jogo em arte, arquivo ou builds. Referências dinâmicas exigem testes adicionais; o auditor não afirma que todo recurso sem referência literal está sem uso.

`testes/teste_estrutura_projeto.gd` carrega os scripts e recursos próprios e inicializa entrada, arena, fazenda e casa. Testes de armaduras, ondas, chefes e inventário verificam os caminhos construídos em código.

`ferramentas/projeto/preparar_testes.py` prepara uma cópia com outro `config/name` e saves separados. Não executar testes de arena/inventário na partida principal.

`docs/reorganizacao_pastas.json` registra os caminhos anteriores, os novos destinos e os arquivos arquivados. As movimentações podem ser revisadas junto ao diff do Git.
