# Armas guardadas no Raven

Referência: animações `idle_*` e `running_*` gravadas pelo autor em `cenas/jogador.tscn`, originalmente usadas com o Mana Seed. `referencia_mana_seed.png` renderiza corpo e objetos originais; `trilhas_mana_seed.json` registra as chaves examinadas antes da adaptação.

O Raven continua sendo o modelo canônico: células80×80, pivô40,47, raiz nos pés, quatro direções baixo/direita/cima/esquerda e seis quadros de corrida com tempos100/60/140ms por passada. Nenhum corpo, roupa, cabelo ou desenho de arma foi gerado ou repintado. O porte usa recortes dos objetos nativos Raven como sprites separados.

`preparar_porte_armas_raven.gd` mede o centro e a direção da ponta metálica nos objetos originais e transfere posição e rotação. A posição é normalizada pela altura real dos corpos em repouso (Raven28/ManaSeed29); a arma mantém seus pixels e tamanho nativos. A sequência de chaves antigas0/0/1/2/2/3 acompanha as seis poses novas. A profundidade é adaptada: atrás de frente/perfil, sobre o dorso de costas, abaixo do cabelo e elmo. As posições continuam em dados editáveis, sem serem pintadas nas roupas.

Dados de execução: `assets/personagens/raven_fantasy/porte_costas.json`. Compositor: `codigo/jogador/heroi_raven.gd` e `codigo/dados/porte_armas_raven.gd`. Espada básica, espada de duas mãos e lança mostram somente a arma selecionada. Arco mantém somente a aljava, conforme solicitado. Ao atacar, defender, regar ou executar outra ação, o porte é ocultado e o compositor nativo da ação assume. Prévia da mochila não muda o objeto no mundo; rastros copiam seu transform.

Validação em projeto/save isolado: `testes/teste_porte_armas_raven.gd`, com roupa comum, capa e quatro peças reais do Carrasco; quatro direções, repouso, seis poses de corrida, ataque, ferramenta, troca de arma e prévia. Regressões: `teste_corrida_mana_seed_raven.gd` e `teste_acoes_fazenda_raven.gd`. A captura `revisar_porte_armas_raven.gd` reproduz o compositor real em passos20ms, com200ms de repouso, dois ciclos de corrida e200ms finais de repouso por direção.

Executar preparador, testes e revisão exclusivamente com projeto cujo `config/custom_user_dir_name` começa por `AlgoLand testes`. Prévia em `arte/previas/personagens/porte_armas_raven/`. Adaptação publicada no conteúdo10 em23/10/2026 para Android, Windows, Linux e navegador, junto da rega de0,7s. Pacotes exportados testados com save isolado; assinaturas e downloads publicados conferidos.
