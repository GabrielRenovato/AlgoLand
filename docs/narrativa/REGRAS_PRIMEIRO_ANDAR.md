# Primeiro andar — Regras de trabalho do protótipo

Esta é a especificação inicial das etapas 0 e 1 do [roadmap](ROADMAP_PRIMEIRO_ANDAR.md), preparada após a autorização para começar. As decisões abaixo permitem projetar o protótipo e são revisáveis por testes e preferências do usuário. Não significam implementação pronta, aprovação individual de nomes ou autorização de publicação/reset.

## 1. O que pertence a cada jogador

| Dado | Dono | Ao entrar no grupo de outra pessoa |
| --- | --- | --- |
| Personagem, inventário, equipamento, receitas e fazenda | Perfil do personagem | Preserva seus próprios dados; não recebe nem sobrescreve a fazenda do anfitrião. |
| Campanha, pistas, destinos descobertos, reputação narrativa e relíquias | Perfil do personagem por campanha/temporada | Pode ajudar amigos; não perde conquistas e não ganha capítulos sem cumprir pré-requisitos. |
| Monstros, objetivos ativos, puzzle, portas e recursos consumidos numa expedição | Instância da expedição | Compartilha o estado atual da instância enquanto participar. |
| Presença e conversa na cidade | Sessão social | Encontra outros jogadores; o estado narrativo de um não altera a cidade permanentemente para todos. |
| Alteração narrativa de um lugar, como moinho restaurado | Campanha do personagem; representação na instância | A instância escolhe sua fase ao abrir. Cada participante conserva os fatos que conquistou pessoalmente. |

Isso substitui, para o protótipo, a sugestão anterior de vincular a campanha inteira ao mundo permanente de um grupo. O jogo já possui saves solo/coop locais; a separação acima precisa de implementação própria e migração planejada. Não usar o arquivo atual do anfitrião como se ele já resolvesse esses contratos.

A instância é aberta em uma fase explícita de missão, escolhida entre os participantes elegíveis. Mostrar essa fase antes de confirmar a expedição. A fase fica estável até a sessão terminar: a entrada de um veterano não restaura o moinho de todos nem pula uma cena. Jogadores avançados podem ajudar fases anteriores.

Atividades opcionais têm objetivos próprios. Os acessos iniciais não devem exigir todos os moradores, colecionáveis ou tarefas de ofício. Avanço de história usa o conjunto de evidências definido nas fichas.

## 2. Grupo e sessões

- Exploração comum: um a quatro participantes.
- Túneis do Carvão: um a quatro, com desafio ajustado ao tamanho da equipe.
- Dungeon principal: dois a quatro. Essa é a escolha de trabalho para começar o projeto do puzzle, não uma afirmação de que o requisito já existe no motor.
- Cidade social: aproveitar a presença atual e medir capacidade. Não assumir que suporta cinquenta jogadores nem confundir avatar remoto com simulação compartilhada de NPCs e combate.
- Instâncias continuam hospedadas por um participante no protótipo, conforme a base existente. Cidade/recrutamento e instância de combate são sessões distintas.
- Ao sair o anfitrião, encerrar a expedição com aviso e retorno seguro quando possível. Sem migração automática de anfitrião nesta primeira entrega.
- Guardar conclusões já confirmadas e recompensas pendentes. Combate e puzzle não concluídos voltam ao checkpoint definido; não registrar a vitória apenas porque a conexão encerrou.
- Ao reconectar com a sessão ainda aberta, reenviar o retrato completo da fase, objetivos e recompensas confirmadas. O personagem retorna ao ponto seguro, sem duplicar loot ou ressuscitar uma vitória já registrada.

A cidade pode funcionar localmente para história e serviços quando a rede estiver indisponível. A dungeon principal continua exigindo parceiros; sua interface informa o requisito sem iniciar uma sessão incompletável.

## 3. Regras de objetivos e recompensas

Estados de missão: indisponível → disponível → aceita → objetivos cumpridos → concluída. Entregas em NPC e intervenções no mundo têm confirmação explícita. Retomar uma missão não repete seus efeitos.

Pistas essenciais são registros de diário/campanha, não itens descartáveis de inventário. A mochila cheia não pode impedir o acesso a uma informação nem fazer perder a relíquia de progressão. Materiais e equipamentos continuam itens reais.

Cada conclusão tem identidade persistente por perfil, campanha e missão. Pedidos repetidos e mensagens de rede repetidas retornam o resultado já confirmado. A concessão e o registro da recompensa precisam de tratamento de escrita interrompida; não basta dois comandos independentes de salvar e adicionar item.

Para equipamento ou material sem espaço, deixar uma reivindicação pendente no serviço/NPC correspondente e informar o jogador. Não depender de um item no chão para uma recompensa única. Recursos comuns da expedição precisam de sua regra de loot definida antes da integração com a economia atual.

Para receber uma conclusão principal, o participante precisa estar elegível antes do evento e participar da sessão. Registrar a elegibilidade na entrada e no início de cada objetivo, sem conceder retroativamente etapas já resolvidas. Não usar dano mínimo obrigatório como medida de participação: suporte e puzzle contam.

Chegada tardia ocorre no ponto seguro e usa o estado presente. Um jogador novo não recebe automaticamente objetivos anteriores; sua interface informa se aquela tentativa é de ajuda ou avanço pessoal. Recompensas pendentes já confirmadas podem ser recuperadas mesmo depois de uma desconexão.

## 4. Relíquia fixa e destino seguinte

Identificador de trabalho da campanha: `campanha_primeira_raiz_v1`. É um identificador de conteúdo futuro, não uma troca da temporada ou versão ativa do jogo.

- Andar: `andar_01`, Vale da Primeira Raiz.
- Relíquia: `reliquia_primeira_raiz`, nome de trabalho Relíquia da Primeira Raiz.
- Destino fixo: `andar_02`, nome de trabalho Bosque da Névoa, ainda sem mapa jogável nesta entrega.
- Origem: primeira conclusão pessoal elegível do Custódio do Enxerto, após a intervenção no circuito.
- Posse: chave de campanha por personagem, apresentada no mapa/diário; não negociável nem descartável.
- Uso: confirmar a colocação no Observatório das Passagens registra o destino no mapa-múndi para aquele personagem. Não retira o histórico da relíquia.
- Repetição: não concede outra relíquia principal nem abre uma nova alternativa. Recompensas repetíveis de combate terão tabela própria.
- Próximo conteúdo: mapa-múndi mostra o destino revelado e seu estado real de disponibilidade. Até haver andar 2, mostrar “Em preparação”, sem botão que leve a um mapa inexistente.

Não implementar novas temporadas, apagar fazendas ou converter saves reais por causa desse identificador. Na próxima temporada, uma configuração diferente poderá ser criada sem alterar silenciosamente a campanha anterior.

## 5. Abertura, moradores e reputação

O jogador é invocado pela árvore nas Clareiras da Chegada. Na primeira chegada, a abertura mostra a floresta reagindo, materialização, descida de joelhos, contato com o solo e retomada do controle; pode ser pulada. Revisitas usam uma entrada curta. Durante uma vigília em andamento, quem chega recebe a entrada breve e os demais veem um brilho e poeira no avatar, sem terem o controle interrompido. Espada e escudo vêm do baú de uma antiga rota de resgate, com abertura animada e coleta real. Investigar os vestígios leva à vigília de rebentos e ao Cerne Partido; vencê-lo libera a saída, sem encerrar o andar nem entregar a relíquia principal.

Dara é o nome de trabalho da vigia que o recebe na entrada da vila. Ela reconhece um indício de invocação, mas não conhece o passado do personagem. Lia oferece abrigo e apresenta o problema; Estela relaciona o indício ao chamado da árvore. O conhecimento é dividido em conversas e acontecimentos, evitando uma explicação longa no primeiro contato.

Usar o gerador atual de NPCs para personagens novos ou substituídos, inclusive o trabalhador refugiado da estrada. Preservar identidade, roupa, cabelo, escala e animações; criar peças adicionais quando necessário, sem usar os sprites antigos como fallback.

Manter Árvore-Mãe como nome provisório. Yggdrasil continua uma referência do usuário, não uma exigência de nome definitivo. Bento não participa do elenco permanente planejado.

Reputação narrativa tem três marcos de trabalho: recém-chegado, aliado da vila após a defesa, e defensor reconhecido após a dungeon. É uma alteração de falas e situações, sem criar uma nova moeda ou exigir pontuação de amizade.

## 6. Defesa da vila

A primeira defesa fica disponível após investigar os ataques iniciais e testar as barreiras do pomar. Lia convida o jogador a preparar mantimentos e posições antes de iniciar.

A atividade acontece numa instância de defesa com a geografia da vila. A cidade social permanece disponível para os demais jogadores. Não disparar combate contra todos apenas porque um grupo começou a missão.

Objetivos: proteger a rota de retirada e impedir a ruptura de dois pontos preparados. Derrota permite nova tentativa; reparos e falas reconhecem o ocorrido sem eliminar moradores de serviço ou a fazenda. A vitória confirma um marco de campanha e evidencia o trajeto dos rebentos pelos canais.

Invasões aleatórias repetíveis ficam fora do primeiro percurso integrado. Primeiro validar essa defesa narrativa completa; sua eventual expansão não pode atacar mundos desconectados.

## 7. Escopo da entrega

- Doze destinos regionais com as fichas em [FICHAS_TERRITORIOS.md](FICHAS_TERRITORIOS.md).
- Limite da primeira cidade: 15 moradores no total. Oito centrais: Dara, Lia, Ivo, Rosa, Tomás, Nilo, Osvaldo e Estela. Sete de apoio: Mara, Cora, Ravi, Yuna, Gael, Elia e Noel. Personas em `PERSONAS_PRIMEIRA_CIDADE.md`. A integração atual acrescenta somente caminhada e conversas; não criar novos moradores, serviços ou arcos sem ampliar o escopo com o usuário.
- Três famílias de criaturas: rebentos, cascudos de minério e sentinelas enxertadas.
- Oito funções de inimigo comum a prototipar: perseguidor, lançador, defensor; escavador, guarda pesado, quebrador; sentinela de canal, sentinela de conexão. Compartilhar base visual quando fizer sentido, com silhuetas e ataques distintos.
- Um chefe principal, Custódio do Enxerto, e um encontro especial reutilizando uma base na dungeon secundária.
- Quatorze missões locais/campanha, incluindo abertura, defesa e ativação da relíquia; oito atividades opcionais definidas nas fichas.
- Cultivo, coleta, fabricação e melhorias usando a economia existente como ponto de partida. Não criar uma segunda moeda ou novo sistema de XP antes de avaliar o atual.

Quantidades e nomes são o orçamento inicial de conteúdo. Cortar ou ampliar exige atualizar as fichas e o roadmap, sem declarar regiões vazias como concluídas.

## 8. Preparação e dificuldade

Acesso à campanha usa evidências e acontecimentos. Sobrevivência usa equipamentos, preparo e aprendizado. Antes de definir números de nível, testar os inimigos e a duração dos encontros com a base atual.

A ficha de cada território indica um estágio de preparo: inicial, estabelecido, investigativo ou final. Esses estágios não são atributos nem travas arbitrárias. Servem para escolher materiais, receitas, composição de encontro e sinais de perigo.

O puzzle terá pelo menos duas ações complementares e nenhuma interação que exija quatro pessoas obrigatoriamente. Uma equipe de duas deve conseguir resolvê-lo; a terceira e a quarta pessoa contribuem no combate e na divisão de tarefas. A solução detalhada e o checkpoint interno pertencem à etapa de desenho da dungeon.

## 9. Compatibilidade e validação

Prototipar em saves isolados. Preservar saves antigos e não alterar a versão ativa, resetar recursos, publicar conteúdo ou registrar resultados competitivos de cenários experimentais. A migração para a campanha nova será especificada e testada antes de entrar no fluxo normal.

Esta especificação define comportamento pretendido. A etapa 2 precisa provar armazenamento, idempotência, seleção de fase, troca de grupo e transições. Ela não herda garantias de segurança ou de persistência só porque a sala atual já funciona.
