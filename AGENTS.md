# AlgoLand

- Comunicação obrigatória em pt-BR; preservar o padrão de nomes e comentários do código.
- Nunca apresentar como concluído algo pela metade ou visualmente mal acabado. Corrigir defeitos evidentes antes de entregar; conferir a renderização real, o acabamento e a integração. Se existir impedimento real, declarar a pendência sem chamar o resultado de pronto. Testes funcionais aprovados não comprovam qualidade visual.
- Antes de alterar personagens, animações, armaduras, arte, TileMaps ou cenários (inclusive por código), ler [as regras visuais](ferramentas/projeto/REGRAS_VISUAIS.md). Elas preservam as skills obrigatórias, quatro estações, padrão de armaduras e revisão no Godot.
- Antes de modelar novos objetos 3D de cenário, gerar e inspecionar imagens de referência da peça; guardar referências e prompts vinculados ao modelo, conforme as regras visuais.
- Alterações de interface exigem revisão da renderização real, margens e alinhamento nas resoluções suportadas, inclusive celular e tela dividida. Testes funcionais não substituem essa revisão.
- Todo estágio jogável deve exibir uma seta até o próximo objetivo ativo da missão. A seta e a distância devem usar o mesmo alvo; se o objetivo estiver em outra região, a seta aponta para a saída correta da região atual. Atualizar ambos ao avançar a missão e validar o caminho em cada estágio.
- Testes de cenas, arena e inventário usam saves isolados; preservar a partida do usuário.
- Mapas jogáveis usam terreno reutilizável e objetos independentes, conforme as regras visuais; executar o perfil `mapas-modulares`. Recortar uma ilustração inteira em uma grade não satisfaz esse contrato.
- Água usa animação por quadros, com atlas, tempos e ciclo revisados; seguir o contrato de água nas regras visuais, incluindo encaixes entre tiles e quatro estações.

## Fluxo econômico

- Começar com `python3 ferramentas/projeto/harness.py contexto`; executar `testar --perfil NOME` para o sistema alterado. Consultar [HARNESS.md](ferramentas/projeto/HARNESS.md) somente para comandos desconhecidos.
- Reutilizar testes apenas quando o harness confirmar conteúdo/motor iguais; não repetir aprovações sem mudança relevante. Corrigir falhas e manter as revisões visuais obrigatórias.
- Buscar com `rg` na pasta do sistema e ler trechos relevantes. Evitar varrer `assets/`, `arte/`, `arquivo/`, `builds/` e `.godot/` em tarefas de código sem recursos.
- Logs extensos em `/tmp`; mostrar resumo, contagem de falhas e erros relevantes. Usar status/diffs focados e respostas curtas. Sem subagentes salvo pedido explícito.
- Ler [CONTEXTO.md](ferramentas/projeto/CONTEXTO.md) só para localizar sistemas/comandos desconhecidos; atualizar apenas decisões duráveis, sem histórico ou logs.
- Modelo econômico/raciocínio baixo para tarefas simples; aumentar conforme integração ou dificuldade real, preservando escolhas explícitas. Preferir Standard. Não afirmar troca de modelo sem confirmação efetiva.
- Habilitar plugins/MCPs só quando necessários à tarefa; não remover instalações ou conexões para economizar contexto.
- Uma tarefa grande por conversa quando possível; ao mudar de assunto, preparar resumo com `harness.py retomar` sem abrir outro chat automaticamente nem interromper trabalho pendente.
- Publicar somente quando solicitado, com conferência antes/depois. Economia não dispensa correção completa nem validação necessária.
