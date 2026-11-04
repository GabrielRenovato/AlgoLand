# Goblin com adaga — estudo do modelo base

- **Função:** inimigo comum ágil de curta distância; primeiro da sequência de goblins 2D.
- **Referência visual:** `arte/fontes/inimigos/goblins_moinho/modelos_v1.png` para acabamento e anatomia; `arte/previas/inimigos/goblins_moinho/frente-escala.png` para proporção junto do jogador.
- **Formato recebido:** 2172×724, três células de 724×724: frente/baixo, perfil à direita e costas/cima. Pintura 2D com clusters definidos e materiais quentes. Fundo com alfa; fonte preservada sem redimensionamento.
- **Pivô/contato:** centro x=362 por célula; solas em y≈672. Na escala de estudo 0,06, corpo com cerca de 31 px na tela, mesma altura do jogador.
- **Identidade:** goblin compacto, pele verde oliva, orelhas pontudas, presas pequenas, cabelo escuro curto, couro castanho simples e faixa ocre. Uma adaga curta na mão direita; mão esquerda vazia. Sem escudo nem arma longa.
- **Escopo:** modelo estático de referência; não representa caminhada ou ataque e não substitui inimigo ativo. Corrida e combo para direita e para baixo estão documentados em `contrato_animacoes_direita.md` e `contrato_animacoes_baixo.md` e usam uma cena visual própria.
- **Entrega:** fonte e prompt nesta pasta; recurso em `assets/inimigos/goblin_adaga/modelo_base.png`; prévia em `arte/previas/inimigos/goblin_adaga/`.
- **Geração:** image_gen integrado. Na revisão, corrigida a adaga da vista de costas para a mão anatômica direita e mantida a lâmina dentro da célula.
