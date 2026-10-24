# Ranking e pódio da cidade

O pódio fica em `layout_vila.json::podio_ranking`, com área e piso definidos no mesmo arquivo. A construção exibe128×48 lógicos; os personagens mantêm a escala nativa do jogador. Os apoios, os medalhões e a base física114×20 seguem essa escala. A fonte permanece no lugar; mural, iluminação e placa deixam a circulação e a leitura livres.

`codigo/cidade/podio_ranking.gd` coloca o1º ao centro, o2º à esquerda e o3º à direita. Os números são recortados pela tinta do algarismo e alinhados aos centros dos medalhões, sem depender das métricas verticais de um Label. Nicknames preservam a grafia de `apelido` no ranking, aparecem acima do cabelo/elmo e usam quebra de linha e a folga lateral para não se sobreporem. Lugares sem jogador ficam desocupados; um registro antigo sem aparência mostra `VISUAL PENDENTE`.

Interagir com a frente da construção abre `codigo/ui/tela_ranking.gd`, com o top15, atualização, rolagem e botão de retorno. Cada jogador do cooperativo abre a consulta na própria metade. Mouse, toque, teclado e analógico direito permitem percorrer a lista.

## Custo

Usar somente o plano gratuito e os recursos existentes. Qualquer mudança que envolva pagamento, cobrança, mudança de plano ou recurso pago exige avisar o usuário e obter autorização antes. Não criar projetos, branches ou recursos pagos por conveniência de testes.

## Banco e dados públicos

Migrações de aparência, armas e temporada inicial aplicadas em23/10/2026 ao projeto configurado. Organização confirmada no plano `free`. `supabase.sql` é a instalação completa idempotente, preserva registros e temporada. `aparencia.sql` e `armas.sql` são etapas históricas: não reaplicar depois da migração da temporada. `temporada_inicial.sql` é a migração destrutiva pontual autorizada: **não reaplicar**, pois limpa ranking e partidas.

A visão `ranking_publico` publica `apelido`, `andar`, `atualizado_em`, `aparencia`, `arma_mais_usada` e `temporada`, filtrando a temporada ativa. Código secreto, hash e contagens permanecem privados. Os RPCs atuais `iniciar_partida_ranking`, `enviar_pontuacao_ranking` e `atualizar_perfil_ranking` exigem `p_temporada=1`. Entradas de clientes antigos retornam `atualize_o_jogo`. O servidor começa jogadores novos no andar1 e mantém o limite de tempo por andar.

O perfil agrega golpes iniciados e disparos liberados por id de arma (não por acerto ou flecha). Aceita apenas os oito ids de `armas_ranking.gd`; contagens inteiras até1 bilhão, JSON até2048 bytes. Repetir envios usa o máximo por id, sem somar novamente. A favorita é a maior contagem; empate usa ordem alfabética. Só a favorita é pública. O envio de perfil não altera andar nem data de desempate; aparência deve ser objeto JSON até4096 bytes.

P1 e P2 têm códigos, apelidos, contagens e filas separados em `ranking.json` e `ranking_p2.json`. São identidades locais do aparelho, sem conta ou recuperação em outro dispositivo. Usa automaticamente o nickname atual do personagem; vazio aparece como `sem apelido`. Não há formulário de cadastro no ranking nem no fim de partida. Apelidos podem se repetir: a identidade é o código por player. Acentos, espaços e nomes de um caractere são preservados, dentro do limite de16 caracteres. A migração `migracoes/20261023191228_ranking_apelido_automatico.sql` remove a exclusividade de apelidos e atualiza o RPC sem limpar registros ou temporadas. As contagens são gravadas localmente e enviadas em lote; não há chamada de rede por golpe.

A atualização2026.10.23.1 eleva `versao_save.ATUAL` para2: reinicia solo e cooperativo uma única vez, incluindo os perfis de ranking antigos, antes de carregar os autoloads. Preserva opções. O cliente também descarta perfil de temporada anterior. Release2026.10.23.1 publicada em23/10/2026 para Android, Windows e Linux em `https://github.com/GabrielRenovato/Wiki-Algoland/releases/tag/v2026.10.23.1`; Web e manifesto da wiki confirmados por hash após a publicação. Android usa código18. Os instaladores anteriores recebem o aviso para baixar a nova base, pois ainda não possuem o autoload Ranking.

Formato v1: `versao`, `pele`, `cabelo`, `roupa`, `cor` RGBA, `roupa_visual`, `pecas_visuais` e `equipamentos` (ids de catálogo por `cabeca`, `corpo`, `luvas`, `botas`). `visual_ranking.gd` valida intervalos, cores e correspondência entre peça e slot, ignorando campos desconhecidos. Nunca carrega caminhos recebidos da rede. `personagem_ranking.gd` reutiliza o compositor Raven do jogador para preservar oclusões, roupa, tintura e armaduras reais ou cosméticas, sem inventário funcional, colisões ou rotinas. Sem favorita, anima repouso; com favorita, usa o primeiro quadro da mesma pose de guarda do jogador, mantendo a arma nas mãos.

Concluir cada andar envia automaticamente pontuação, apelido e aparência; morrer envia o andar alcançado, fotografando antes de reiniciar o equipamento. O visual também é acompanhado na cidade. A fila continua durante pausas/menus e drena um andar maior recebido durante outra requisição. O envio pendente fica nos arquivos de cada perfil, repete após falhas e funciona mesmo sem novo recorde. O retrato confirmado corresponde ao conteúdo efetivamente enviado, inclusive se a aparência mudar durante a requisição. Consultas simultâneas são agrupadas; falhas preservam a última lista da sessão e exibem o estado de conexão. A praça consulta novamente a cada60 segundos; a tela permite atualização manual.

A migração foi validada pelo cliente público e por chamadas sob o papel `anon`, em transação revertida: envio de aparência sem alterar pontuação/desempate, rejeição de código sem cadastro e JSON inválido, sem acesso direto à tabela. Também foram validados dois perfis, repetição das contagens, favorita, temporada inválida, cliente antigo e id de arma malicioso. Nenhum jogador fictício permaneceu no servidor.

## Arte e verificação

Arte gerada com a ferramenta integrada de imagens. Original, contrato e prompt em `arte/fontes/cidade/podio_ranking/`. `preparar_podio_ranking.py` recorta as quatro variantes pelo mesmo canvas e rasteriza os números da fonte existente. Recursos consumidos em `assets/cenario/cidade/podio_ranking/`; variantes entram na troca sazonal da cidade, inclusive préviaF3.

`teste_podio_ranking.gd -- --capturar` exige save isolado e renderização gráfica. Confere dimensões, números pelo centro dos medalhões da fonte original, nicknames longos, igualdade das camadas com o compositor real, armaduras básicas/mistas/cosméticas, quatro estações, repouso, consulta responsiva e cooperativa, ranking vazio/parcial e captura antes do reset. Prévias ficam em `arte/previas/cidade/podio_ranking/`, com personagens apenas de demonstração local.

`python3 testes/teste_ranking_http.py` prepara um save exclusivo e um servidor HTTP local. Valida envio, repetição após falha, atualização sem recorde, mudança durante requisição, cache, deduplicação e persistência. `--fluxo` executa `teste_ranking_automatico.gd`: conclusão de andar, morte do jogador real, apelido com acento/espaço, padrão sem apelido, ausência de cadastro, fila concorrente e envio com a árvore pausada. `--fluxo --visual` captura a tela da morte em computador/celular. Nunca acessa o Supabase real.

`teste_praca_ranking.gd` verifica calçamento, obstáculos alheios à construção, percursos e estações. Requer a cópia com diretório de usuário `AlgoLand testes praca ranking 20261023`. `teste_urbanismo_cidade.gd` cobre os acessos gerais da vila.

Conteúdo1 da versão2026.10.23.1 publicado em23/10/2026: cinco scripts em dois pacotes assinados (61.844 bytes por plataforma), sem alterar o núcleo, os saves ou a temporada. Android/Windows/Linux atualizam e reabrem; Web0c4e92af290d foi confirmada por SHA-256 após a publicação. Teste da dungeon e morte também aprovado sobre a base Linux com os pacotes finais montados.
