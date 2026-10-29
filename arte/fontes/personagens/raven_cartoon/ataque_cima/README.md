# Corte para cima corrigido pela referência Mana Seed

A versão anterior foi rejeitada pelo usuário por parecer um soco: braço levantado e estendido. Ela permanece em `folha_gerada_v1.png` e nas prévias `anterior_rejeitado_soco/`; não é referência de movimento aprovada.

Comparação real: corpo Mana Seed ONE3, linha1 e colunas0–3, e guia do autor com espada/arco. O braço do golpe inicia do lado esquerdo da imagem, abre lateralmente para esquerda e termina cruzado baixo à direita. O tronco gira bastante no término. A orientação anterior que impunha braço direito no lado direito da imagem estava incorreta para esta referência e foi substituída pelo membro observado.

Produção via `image_gen` integrado. `folha_corte_v2_intermediaria.png` fornece somente os quadros1/2. A primeira tentativa de corrigir dois finais continuou trocando membros e foi descartada. O término foi então produzido isoladamente a partir da pose real ampliada: `pose_final_corte_v3.png`, prompt em `prompt_pose_final_v3.txt`. Os dois tempos finais usam essa mesma pose, como os quadros3/4 originais Mana Seed. Não há espada, escudo, cabo ou efeito na animação final.

Preparar: `python3 ferramentas/personagem/raven_cartoon/preparar_ataque_direita.py --direcao cima`. A tela isolada é reduzida uniformemente2x à escala da fonte; depois uma única calibração anatômica comum preserva o tamanho da calota canônica. Pivô320×850, células640×896;490ms em160/60/70/200ms. SpriteFrames mantém quatro tempos; GIF reúne o término idêntico em270ms, ficando com três imagens únicas. Sem redesenho por código ou dimensionamento pela silhueta.

Recursos: `assets/personagens/raven_cartoon/ataque_cima_sem_arma.*`. Prévia independente, sem substituir jogador ativo nem alterar partidas. Demais direções preservadas.

Revisão gráfica no Godot em projeto/save isolado: `revisar_ataque_direita.gd -- --cima` e `-- --cima --comparar-mana`. Duas reproduções, capturas dos quatro tempos, comparação com canônico e referência Mana Seed. `comparacao_mana_seed.gif` mostra a fonte real e a adaptação com os mesmos tempos. Foram conferidos direção, escala, arco da mão, término, pés e margens. As poses são adaptação cartoon, sem afirmar transferência exata das articulações ou aprovação do usuário.
