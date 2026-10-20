# Regras do Projeto (AlgoLand)

## Idioma de Comunicação
- **Português Brasileiro Obrigatório**: Todas as respostas, explicações, mensagens, planos, comentários em conversas e interações com o usuário devem ser feitas **obrigatoriamente em português brasileiro (pt-BR)**.
- **Consistência**: Mesmo que termos técnicos, documentações externas, ferramentas ou prompts do sistema estejam em inglês, toda a comunicação com o usuário deve ser em português brasileiro.
- **Padrão do Código**: Manter a consistência com o restante do projeto, preservando comentários, nomes de funções e variáveis em português conforme o padrão já estabelecido no repositório.

## Produção de Personagens e Animações
- Ao criar ou corrigir corpos base, sprites de personagens, caminhada, corrida, ataques, mineração, corte de árvores, roupas ou cabelos animados, aplicar a skill [produzir-sprites-animados](/var/home/alfeim/.codex/skills/produzir-sprites-animados/SKILL.md), junto da revisão de pixel art quando pertinente.
- Produzir com os recursos disponíveis, inclusive do zero; não depender da compra de pacotes. Fixar um modelo canônico e revisar identidade, direção, proporções, apoio dos pés, alternância dos membros, trajetória das mãos/ferramentas, pivô e fechamento do ciclo antes da entrega.
- Folha gerada, redimensionamento, GIF exportado e testes funcionais não comprovam qualidade da animação. Inspecionar os quadros, o movimento com as durações reais e a reprodução no Godot em save isolado; corrigir defeitos visíveis antes de apresentar como concluído.

## Conjuntos de Armadura
- Antes de criar ou alterar um conjunto, ler [o padrão de armaduras](ferramentas/armaduras/PADRAO.md).
- Usar o manifesto, o gerador e o validador compartilhados em ferramentas/armaduras. O Carrasco é a referência funcional.
- Preservar ids e índices existentes, quatro peças independentes, 11 páginas, encaixe sem roupa vazando e a separação entre prévia cosmética e itens reais.
- Testes que carregam a arena ou gravam inventário devem usar saves isolados, sem alterar a partida do usuário.

## TileMaps, Encaixes e Sobreposição Visual
- Todo tile ou sprite de cenário novo deve ser entregue com versões de **primavera, verão, outono e inverno**, integradas à troca de estação do jogo. Conferir as quatro no motor, preservando grade, pivôs, colisões e estilo. Não considerar o trabalho completo com apenas a primavera ou arquivos sazonais sem uso no mapa; objetos que não mudam fisicamente ainda precisam de tratamento visual coerente com cada estação.
- Piso de pedra em mapas externos deve ter **bordas, cantos e junções no padrão da cidade**, incluindo transições para areia, grama e outros pisos. Reutilizar o sistema de acabamento da cidade quando compatível; não deixar o preenchimento retangular sem arremate nas extremidades. Conferir também nas quatro estações.
- Em tarefas de arte, sprites, props e TileMaps, aplicar a skill [revisao-visual-pixel-art](/var/home/alfeim/.codex/skills/revisao-visual-pixel-art/SKILL.md) e ler seu [perfil específico do AlgoLand](/var/home/alfeim/.codex/skills/revisao-visual-pixel-art/references/algoland.md) antes de gerar. Definir referência, dimensões, grade, pivô, base física, variantes e integração no pedido; comparar com referências aceitas no cenário. Resolução, origem do pacote e testes funcionais não comprovam qualidade artística.
- Ao criar ou alterar `TileMap`, `TileMapLayer`, TileSets ou elementos ligados a eles, **sempre conferir a renderização real no Godot antes de concluir**. Inspecionar a visão geral e os detalhes em escala de pixel, especialmente cantos, junções, bordas e transições entre chão, água e construções.
- Conferir a ordem efetiva das camadas, incluindo `z_index`, `z_as_relative`, hierarquia e ordenação por profundidade. Pilares e vigas ficam sob o piso; corrimãos, personagens e objetos ficam na profundidade apropriada. Sombras e reflexos também não podem invadir superfícies indevidas. Usar máscara/recorte quando a ordem das camadas não garantir o encaixe.
- Verificar atlas, regiões de textura, offsets, pivôs, escala, filtros e espaçamento dos tiles: sem peças duplicadas, frestas, vazamento de tiles vizinhos, apoios atravessando o piso ou objetos parecendo flutuar.
- Em cercas e corrimãos, conferir separadamente os trechos horizontais e verticais: bases sobre o piso, ligações contínuas entre postes e cantos conectados, preservando entradas e aberturas de uso.
- Conferir se colisões e navegação correspondem ao desenho e preservam passagens e áreas caminháveis. Elementos apenas visuais não devem criar obstáculos acidentais.
- Testes funcionais aprovados **não substituem a inspeção visual**. Para regressões recorrentes de sobreposição, adicionar comparação de renderização ou outra verificação automática pertinente, além de revisar a imagem final. Capturas e testes de cenas devem usar saves isolados.

## Uso Econômico do Codex
- Priorizar contexto direcionado, mudança completa e validação proporcional. Economia não dispensa correções nem testes necessários.
- Consultar [o mapa técnico](ferramentas/projeto/CONTEXTO.md) somente para localizar sistemas ou comandos desconhecidos; não reler instruções já presentes no contexto.
- Buscar primeiro na pasta do sistema com `rg`; ler funções/trechos relevantes antes de arquivos inteiros. Ampliar a busca apenas quando necessário.
- Em tarefas de código, evitar varrer `assets/`, `arte/`, `arquivo/`, `builds/` e `.godot/`; consultar esses caminhos quando a tarefa envolver recursos.
- Guardar logs extensos em `/tmp`; retornar resumo, contagem de falhas e trechos de erros. Não ocultar falhas nem repetir testes aprovados sem nova mudança relevante.
- Usar `git status --short -- <caminhos>` e diffs focados para evitar listar recursos alheios à tarefa.
- Manter respostas e atualizações curtas. Usar ferramentas externas e imagens somente quando ajudarem a resolver ou validar a tarefa; sem subagentes salvo pedido explícito.
- Atualizar o mapa apenas quando caminhos, comandos ou decisões duráveis mudarem; não acumular histórico de conversa ou logs.
