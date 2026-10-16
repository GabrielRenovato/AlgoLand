# Set cavaleiro

Para próximos conjuntos, seguir ferramentas/armaduras/PADRAO.md. O manifesto do Carrasco fica em ferramentas/armaduras/modelos/carrasco.json; gerar_conjunto.gd produz as folhas e definicao.gd, usada pelo cadastro do jogo.

Quatro peças visuais independentes: elmo, peitoral, luvas e botas. Cada pasta contém as 11 páginas do personagem, em folhas 512 × 512 com células 64 × 64. As folhas na raiz recompõem o conjunto completo.

No jogo, F3 → EQUIPAMENTOS → CARRASCO (VISUAL) alterna a prévia do conjunto. Os botões VISUAL: ELMO/PEITORAL/LUVAS/BOTAS alternam uma peça por vez. Esses controles testam a aparência; não concedem o bônus do conjunto.

O cabelo fica oculto apenas enquanto o elmo está ativo. No equipamento real, as peças sobrepõem a roupa escolhida pelo jogador em todas as páginas. Na prévia do F3, a base é a roupa de camponês.

## Equipamento real: Carrasco

Elmo, peitoral, luvas e botas são itens lendários independentes, equipados nos slots respectivos e guardados pelo inventário. Cada peça possui nível e três afixos. O conjunto não aparece como traje gratuito na criação de personagem.

A partir da onda 14, após o sorteio de haver um equipamento, a chance de ele ser uma peça do Carrasco é 5% para inimigos normais, 10% para mutantes e 20% para chefes. Com as chances gerais de equipamento, isso corresponde a 0,075%, 0,6% e 20% por morte, respectivamente. As quatro peças têm a mesma chance entre si.

Com as quatro peças equipadas: 10% por acerto de espada, lança ou flecha para invocar um raio em área no alvo, com 200% do dano do golpe e recarga de 2 segundos. Não causa dano ao jogador nem ativa efeitos em cadeia. Retirar qualquer peça desativa novos raios. Bônus e chances ficam em codigo/dados/conjunto_carrasco.gd.

F3 → DROP CARRASCO (4 PECAS) solta os quatro itens reais para recolher e equipar pelo inventário.

Para regenerar: execute o Godot com --headless --path . --script ferramentas/personagem/gerar_set_cavaleiro.gd e depois importe o projeto. A fonte visual e o prompt original estão em arte/fontes/armaduras/carrasco/set_cavaleiro_v1.png e set_cavaleiro_prompt_original.txt.

Verificação visual: --headless --path . --script testes/teste_set_cavaleiro.gd. Confere as 44 folhas independentes, recomposição sem sobreposição, cobertura de todas as poses, alternância pelo F3 e atualização das camadas do jogador.

Integração: testes/teste_carrasco.gd exige uma cópia do projeto com config/name="AlgoLand testes Carrasco", para usar saves separados. Confere drops, raridade, afixos, ícones, coleta, slots, bônus sem acumulação, saves, acertos reais de arma e flecha, recarga e dano aliado em área.
