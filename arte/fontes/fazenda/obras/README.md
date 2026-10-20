# Obra do galinheiro

Originais produzidos com o imagegen integrado para esta tarefa, usando os três galinheiros e o sprite aceito de Osvaldo como referências. `primavera.png`, `verao.png`, `outono.png` e `inverno.png` são a mesma folha com fundação, estrutura e acabamento; a segunda e terceira fileiras são sobreposições de ampliação, com o centro transparente para preservar o abrigo anterior.

Contrato em `manifesto.json`. Preparação determinística: `python3 ferramentas/fazenda/preparar_obras.py`. A ferramenta apenas recorta, reduz por vizinho mais próximo, quantiza o alfa e encaixa pelas bases medidas; não desenha arte.

Pedido da geração do cenário: manter arquitetura, madeira quente, pedra e palha dos galinheiros existentes, perspectiva elevada de três quartos, pixels legíveis na escala nativa; três colunas de progresso e três fileiras por nível, sem texto nem personagens. Porta principal e portinha das aves permanecem livres nas ampliações. As variações sazonais preservam tela, posições e transparências: verão seco/dourado, outono avermelhado com folhas nas bases e inverno com neve nos topos expostos.

Pedido da animação: preservar cabelo grisalho, olhos pequenos e avental do Osvaldo; seis fases reais de preparar, levantar, armar, descer, bater e recuperar, nas direções baixo/direita/cima/esquerda. Célula64×64, pés y45, sem bancada embutida. `osvaldo_construindo.png` é o original da geração e o recurso preparado fica em `assets/npcs/cidade/`.

Integração: `galinheiro_exterior.gd` escolhe a etapa e a estação; `ambiente_obra.gd` compartilha ator e trajetos com a vila; `trabalho_carpinteiro.gd` anima apenas quando o carpinteiro chegou ao posto no expediente. Validação visual/funcional: `teste_obra_carpinteiro.gd -- --capturar`, executado em save isolado pelo runner do projeto.
