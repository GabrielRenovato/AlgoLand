# Substituição dos combos: adaga com rastro de corte

Pedido: substituir os ataques existentes por golpes semelhantes ao novo machado com efeito, preservando personagem e arma. Modelo canônico assets/inimigos/goblin_adaga/modelo_base.png; referência de gesto/efeito contatos de goblin_machado_2d. Gerar arte própria via image_gen, sem converter o goblin de machado em adaga. Skill produzir-sprites-animados e revisão visual aplicadas.

Quatro direções. Direita, baixo/frente e cima/costas autoradas; esquerda é espelhamento integral da direita conforme pedido persistente. Adaga sempre na mão anatômica direita, outra mão equilibra. Esquerda espelhada preserva a convenção pedida. Roupa marrom sem mangas, faixa ocre, cabelo preto espetado, sem armadura do machado.

Grade4x3, célula640, raiz320/560, escala.071, corpo31px. Doze quadros, três golpes de quatro fases: preparar, impacto, continuar, recuperar/guarda. Golpes: diagonal descendente, reverso ascendente e varrida horizontal. Cabeça e ombros acompanham quadril, joelhos absorvem peso, manter massa e apoio. Crescente branco com azul claro desenhado em1/2/5/6/9/10, mais largo no impacto e fino na continuação; desaparece na guarda.

Tempos preservados100/40/60/270,80/40/60/270,100/40/70/120ms, com200ms acrescentados nas recuperações3/7. Impactos1/5/9 (sinais e controle de dano mantidos). Sem loop. Corrida e dano preservados por hashes em preservacao_antes_corte.json. Destino ativos combo_*.png/animacoes.tres, fontes e prompts versionados, GIF/contatos e capturas no Godot com save isolado.

## Transformações efetivas e revisão das fontes
Direita: fonte1448x1086, lado534, deslocamento(53,49), limiar64. Baixo: fonte1448x1086, lado486, deslocamento(77,93), limiar128. Cima: v1 rejeitada por pés cortados/efeito invadindo linha; v2 mantém pés inteiros e efeitos separados. Fonte1448x1086, lado549, limiar128. A folha v2 tem linhas de apoio distintas entre os três golpes (solas em628,617,587 na célula normalizada640), portanto registra cada linha de quatro quadros no mesmo chão com translações(45,21)/(45,31)/(45,57). Mesma escala em todos os quadros; nenhum recorte ou normalização por contorno individual. As quatro poses de cada golpe recebem a mesma translação, preservando inclinação e apoio. Esquerda espelha célula pronta da direita.

Rosto/costas/roupa e trajetória da adaga inspecionados nos contatos, rastro limpo no alfa exportado. Fontes originais e versões rejeitadas preservadas. A alteração não toca a lógica de dano: mob real carrega o mesmo animacoes.tres substituído, incluindo combo e três subclipes de ataque.
