# Pelos faciais dos moradores

- Referência: rosto e cabelo do morador gerado no rig atual, com acabamento pixel art. A tentativa anterior de caixas/esfera é somente referência do defeito.
- Uso: barba curta no queixo e costeletas, bigode curto abaixo do nariz; cor acompanha o cabelo, inclusive grisalho. Jogadores e crianças permanecem sem esse cosmético.
- Fonte editável: `codigo/jogador/cabeca_referencia_3d.gdshader`, parâmetros exclusivos aplicados por `codigo/npcs/acessorios_npc_3d.gd` ao material individual da cabeça pintada.
- Encaixe: mesmos marcos dos olhos e do queixo da pintura de oito direções, incluindo a interpolação das inclinações. Pigmento na própria superfície, sem mudar a silhueta, os pesos ou o pivô. Mesma câmera e resolução de 160×160 do morador.
- Identidade: preservar olhos, nariz, boca, cabelo e nuca. O registro de acessórios na ficha e as probabilidades de geração continuam sendo os existentes.
- Movimento: quatro direções, oito amostras igualmente espaçadas do ciclo `Walk_Loop`, mantendo clipe e duração do consumidor.
- Revisão: teste `pelos_faciais_npcs` em save isolado, sem barba/barba/bigode nas oito vistas, cabelo castanho e grisalho, comparação ampliada por vizinho mais próximo e quadros da caminhada nas quatro direções. Conferir também na cidade real, junto do jogador.
