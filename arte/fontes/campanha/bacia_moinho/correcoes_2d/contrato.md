# Correções 2D — animação de ataque

Preservar desenho, perspectiva, paleta e identidade dos atlas originais. Nenhum modelo 3D. Os mobs ficam com 75% do tamanho anterior, inclusive corpo físico; manter os quadros originais de caminhada lateral e frontal. Caminhada traseira complementar em oito poses corrige a vista que mostrava a frente ao subir; duração da passada original preservada.

Produção de uma ação/direção por vez: rolamento do besouro e bote da arraia com vistas lateral, frontal (baixo) e traseira (cima). Oito poses: duas de antecipação, duas de entrada no golpe, duas de impacto, duas de recuperação. Esquerda espelhada. Quadro final 512×512, pivô do corpo documentado e estável; não recentralizar cada pose por bbox nem deformar os originais. A ação é uma sequência sem loop, ligada à janela de dano existente. Válvula usa uma sequência própria de canalização. Os respingos da arraia acompanham as poses do bote; o jato da válvula permanece independente do corpo. Não inverter ataque para fazer morte.

Besouro: baixar cabeça, dobrar as seis patas, fechar casco, rolar com eixo corporal horizontal coerente, frear, abrir e recompor. Arraia: abaixar/recolher nadadeiras, projetar corpo, impulsionar com nadadeiras, estender e recuperar; mesma cauda e volume em todas as poses.

Fontes e prompts aqui; sprites consumidos em assets/inimigos/bacia_moinho/; capturas iniciais em arte/previas/campanha/revisao_mobs_moinho/ e revisão final em arte/previas/campanha/mobs_moinho_2d/. Fontes antigas preservadas.

## Reversão

Os quatro arquivos anteriores às correções estão em `antes/`, com os caminhos relativos do projeto. Os três atlas originais em `assets/inimigos/bacia_moinho/` não foram sobrescritos. Para reverter, restaurar somente esses quatro arquivos; as folhas complementares deixam de ser referenciadas. Preservar eventuais edições posteriores antes de restaurar.
