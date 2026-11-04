# Revisão — ataques gratuitos e tornado

Ataques prontos KayKit 1.1 (Kay Lousberg, CC0), transferidos ao modelo original
em lorde_goblin_kaykit.blend. A versão autoral anterior foi substituída.
Fontes, nomes e hashes em arte/fontes/inimigos/lorde_goblin_3d/animacoes_kaykit.json.

Capturas reais do Godot, frente/lateral, detalhe das pegadas e escala 224².
Folhas de contato inspecionadas em sequência para avaliar gesto, preparação,
contato e retorno. GIFs usam os mesmos quadros a 20 FPS; o GLB tem chaves a
60 FPS. Não foi alegado assistir ao GIF no leitor estático de imagens.

- Varrida e martelada usam os clipes de duas mãos da biblioteca.
- Giratório repete três ciclos do clipe contínuo Melee_2H_Attack_Spinning.
- Pegada corrigida: direita perto do final do cabo, esquerda acima, sem
  afundar a mão de apoio no tórax. Mãos rigidamente vinculadas na fase ativa.
- Pedra toca o chão sem enterramento; repouso inicial/final preservado.
- Tornado de três fitas em funil, cinza esverdeado semitransparente. Rotação
  acompanha o tempo do ataque, com aparição/desaparecimento suaves. Silhueta
  do chefe e martelo permanecem legíveis na escala de jogo.
- Efeito oculto fora da janela ativa e no cancelamento; não altera dano.
- 16 verificações aprovadas, zero falhas; importação sem erros; estado
  preservado pelo harness. Relatório em validacao_harness.json.

A cena visual emite eventos de área e impacto. A IA da batalha ainda usa os
sprites anteriores e não está conectada aos sinais de dano deste recurso.
Caminhada e morte permanecem pendentes.

Atualização solicitada: arco vertical de0,50m durante o giratório, subida e
descida suaves; rig e arma sobem juntos. Funil acompanha em altura sem mover
a base do efeito. Prévias normal e pixel art atualizadas e inspecionadas.
