# Animações e golpes — Bacia do Moinho

## Contrato dos quadros
Spritesheets 4×4, 320×320 por célula, mesma câmera, escala e base. As linhas 1–3 preservam as poses aprovadas; a linha 4 foi redesenhada para o golpe e é executada uma vez, sem loop. As fontes editadas por IA estão ao lado em `ataque_*.png`; os atlas finais ficam em `assets/inimigos/bacia_moinho/`.

- Arraia: encolhe (antecipação), avança com as nadadeiras fechadas, impacto com respingo, recua. Bote curto e rápido em linha; janela de dano só durante o avanço.
- Besouro: baixa os chifres, fecha o casco, rola em investida, derrapa e se recompõe. Investida mais lenta e forte; a silhueta enrolada marca o perigo.
- Válvula: gira para mirar, comprime o núcleo, dispara um jato reto, apaga o núcleo. Projétil de água atravessa uma faixa estreita; exige sair da linha.

A duração, telegraph e recuperação são definidos em `codigo/inimigos/inimigo_bacia.gd`. Checagem de movimento: preservar o pivô do chão nos corpos terrestres; a Válvula mantém o centro do aro no pivô. Revisar no motor antes de incluir no mapa jogável.
