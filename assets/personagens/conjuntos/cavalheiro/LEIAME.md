# Mordomo — conjunto lendário

Prévia original inspirada na referência de cartola e traje formal, adaptada para as proporções compactas e a câmera do personagem do jogo.

`conceito_v1.png` apresenta frente, costas, direita e esquerda. `referencia.png` contém a inspiração enviada pelo usuário. `prompt_conceito_v1.txt` registra o prompt usado com a ferramenta integrada image_gen.

O conceito foi adaptado para as 11 páginas nativas, em folhas de 512×512 e células de 64×64. Cartola, casaco/colete, mangas/luvas e calças/botas são separados nas pastas elmo, peitoral, luvas e botas. A prévia cosmética interna é separada das ações EQUIPAR, que colocam as peças reais nos slots.

No jogo: F3 → CONJUNTOS → MORDOMO (EQUIPAR) → EXECUTAR. As quatro peças são equipadas nos slots reais. Peças anteriores voltam à mochila; repetir reutiliza as mesmas peças e preserva melhorias. Cabeça, estilo e cor do cabelo são preservados. O traje acompanha caminhada, ataques, arco, reações, fazenda, forja e sentado.

O manifesto é ferramentas/armaduras/em_preparacao/cavalheiro/manifesto.json. Usa modo_visual=tecido no gerador e validador compartilhados. As peças são lendárias e estão disponíveis pelo F3. Com 4/4, acertos têm 10% de chance de congelar por 2 segundos, com recarga de 2 segundos. Status base e chances de drop permanecem zerados até definir o balanceamento; os ids antigos cavalheiro são preservados. A prévia cosmética interna permanece separada dos itens reais.

O molde de mangas curtas foi adaptado para mangas escuras compridas e luvas claras. Não pintar os braços de couro marrom: esse material aparece no colete e nos sapatos.

A cartola e o cabelo são compostos em uma única camada acima da roupa. O cabelo recebe a cor escolhida antes de compor a cartola, que mantém sua própria paleta. O sprite de cabelo original fica com self_modulate.a=0 enquanto o chapéu está ativo e é restaurado ao retirar o traje. cartola_sobre_cabelo.gd acompanha quadro, espelhamento, visibilidade e ordem da roupa antes de desenhar.

A arte atual da cartola é cartolas_completas_v2.png, gerada com image_gen; o prompt está em prompt_cartola_v2.txt. O manifesto usa altura 14 e encaixe 7 para manter a copa inteira sem encobrir os olhos. A máscara segue a borda da aba por coluna, evitando a faixa de pele exposta. O centro da copa acompanha o topo do crânio, sem usar nariz ou queixo como âncora nos perfis. A cabeça composta acompanha a roupa, corrigindo o quadro divergente de idle_up.

previa_cartola_real.gd renderiza as camadas e o AnimationPlayer da cena original sem executar o jogador nem acessar saves. cartola_completa_no_jogo.png mostra três estilos de cabelo com a cartola nas poses nativas. O validador verifica a altura completa do chapéu em todas as células ocupadas.

Prévias em previas/ usam as folhas nativas compostas. O cabelo marrom é demonstrativo; no jogo vale a escolha do jogador. Teste sem saves: testes/teste_traje_cavalheiro.gd.
