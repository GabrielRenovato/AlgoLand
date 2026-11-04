# Cerne Partido — estudo de poses

Pedido: desenho isolado do boss nas poses de movimento, golpes, especiais, reação e morte. Entrega de estudo visual; esta etapa não altera o personagem ativo nem integra animações no motor.

Referência canônica: `referencia_aprovada.png`, conceito aprovado na conversa. Toco rachado, coroa serrilhada com anéis, núcleo âmbar, dois braços articulados e quatro pernas de raízes. Sem copa, seiva escorrendo ou corpo preso ao cenário. Câmera elevada de três quartos do jogo, grupos de pixels definidos, madeira quente e musgo restrito. Monstro sem variantes sazonais obrigatórias.

Cada folha: grade pretendida de 4 colunas × 2 linhas, células iguais, fundo alfa, boss inteiro e margens em cada célula. Escala e chão comuns; corpo não deve ser redimensionado para encaixar braços abertos. Ordem de leitura da esquerda para a direita, linha superior antes da inferior. Sem textos sobre os desenhos.

- `01_combo.png`: varrida A — antecipação, aceleração, impacto, continuação; varrida B de retorno — antecipação oposta, aceleração, impacto, recuperação.
- `02_vistas_movimento.png`: repouso frontal, lateral direita, costas e lateral esquerda; quatro chaves de caminhada frontal com apoios diagonais alternados.
- `03_especiais.png`: investida — compressão, propulsão, avanço, frenagem; conjuração — abrir os braços, fincar raízes, descarga, retirada dos apoios.
- `04_pancada_fase2.png`: pancada dupla — erguer braços, comprimir corpo, impacto com duas mãos, recuperar; transição — fissura inicial, placas se abrindo, núcleo exposto, postura enfurecida.
- `05_reacao_queda_morte.png`: reação ao dano, recuperação da reação, queda por perda de apoios, núcleo vulnerável; morte — núcleo apagando, pernas cedendo, tronco tombando, restos inertes.

São quadros-chave de estudo, sem FPS final ou declaração de ciclo pronto. Na produção para o jogo: completar intervalos e direções, registrar pivôs medidos, separar efeitos de ataques, fixar durações/janelas de dano e revisar movimento real no Godot com save isolado. Não gerar GIF com quadros-chave desconexos e apresentá-lo como animação validada.

Ferramenta: image_gen nativa. Prompts exatos e origens ficam junto das folhas.
