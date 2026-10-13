# Gelo do Mordomo

Arte gerada com a ferramenta integrada image_gen: conceito_v1.png e prompt_v1.txt. importar_gelo.gd converte os seis estados em três folhas nativas, com paleta fria, pixels sem suavização e janela frontal semitransparente para mostrar o inimigo.

Estados: formação nos pés, fechamento, duas poses de brilho, rachaduras e fragmentos. Variantes: pequeno 24×24, normal 32×40 e grande 64×64, seis colunas cada. Sem mipmaps; nearest no sprite. congelamento.gd escolhe o tamanho pelo quadro visível do inimigo e acompanha o tamanho de seu sprite.

Com quatro peças reais lendárias do Mordomo, cada acerto de espada, lança ou flecha tem 10% de chance de congelar o alvo por 2 segundos. A recarga compartilhada do jogador é 2 segundos. Três peças, conjuntos misturados e prévia cosmética não ativam o bônus. Movimento, animação, ataques e contato ficam bloqueados, inclusive habilidades de chefe; dano continua permitido. No fim, o gelo racha e some; na morte é removido imediatamente.

O id histórico do conjunto continua cavalheiro para preservar inventários e sprites. As peças antigas comuns migram para lendárias mantendo id e melhorias. Os pesos de drop natural permanecem zero até definir o balanceamento de obtenção.

Prévia sem saves: ferramentas/efeitos/previa_gelo.gd. Teste de combate somente no projeto isolado: testes/teste_mordomo_gelo.gd.
