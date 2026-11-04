# Caminhada do Lorde Goblin

Modelo canônico: primeiros quadros das marteladas escolhidas, referências `andada_baixo_referencia.png`, `andada_cima_referencia.png` e `andada_direita_referencia.png`. Mesmo corpo, roupa, marreta e paleta já integrados na dungeon do moinho. Câmera elevada do RPG, frontal/baixo, costas/cima e três quartos/direita; esquerda espelha exclusivamente a direita.

Seis quadros por direção, grade3×2. Contato esquerdo, transferência de peso, passagem direita, contato direito, transferência oposta, passagem esquerda. Ambos os membros alternam função de apoio e balanço. Ciclo660ms (110ms/quadro), velocidade de deslocamento existente46px/s, pequena oscilação de peso e roupa, sem deriva do corpo entre células. Marreta carregada baixa nas duas mãos, sem repetir ataque. Alvo de exportação640², pivô320/500, mesma escala corporal dos ataques. Transformação comum a cada fonte, sem normalizar poses pelo contorno.

Revisar pernas, botas, mãos/arma, identidade e cores nos seis quadros e no fechamento do ciclo. Reproduzir no Godot durante movimentação real na dungeon, incluindo parada, inversão esquerda/direita, início de ataque e congelamento. Fontes e prompts preservados nesta pasta; atlas no recurso do boss e prévias na pasta de imagens do Lorde.

## Exportação revisada

Fontes1536×1024, seis células512². Todas as poses de uma direção recebem a mesma transformação: direita432² em104/116; baixo394² em123/130; cima430² em105/118. Pivô e corpo comparados às guardas canônicas antes da montagem. Alfa fraco da exportação limpo no empacotamento. Medições e ganhos de couro/manto preservados nos registros por direção. Alternância das duas pernas e fechamento dos ciclos revisados nos contatos e na reprodução no Godot; esquerda mantém o mesmo ciclo espelhado.

As caminhadas foram integradas ao controlador do boss real, não apenas ao GIF. Revisão de perseguição, parada, transição para ataque e ciclos de doze passos em quatro direções aprovada. Capturas em `boss_andada_seis_quadros_no_moinho.png` e GIF de quatro direções na pasta de prévias.
