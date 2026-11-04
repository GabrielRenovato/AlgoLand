# Estudo anterior cancelado — identidade igual ao goblin de adaga

O usuário rejeitou este reaproveitamento. corrida_direita_v1.png e seu prompt ficam somente como histórico; não usar como modelo canônico nem integrar no jogo. A nova identidade está em contrato_modelo_proprio.md.

# Goblin de machado 2D — primeira direção

Direita: corrida e corte pesado. Modelo e movimento de referência: goblin_adaga/modelo_base.png e correr_direita.png já usados no jogo. Preservar goblin, roupa, paleta e proporções; trocar a adaga por machado de uma mão com cabo de madeira e lâmina simples de aço. Mão direita segura a arma, esquerda equilibra. Mesmo corpo aparente do player (~31px), câmera elevada do projeto.

Recursos separados da versão3D ativa, sem substituir prematuramente os outros rumos. Destino:assets/inimigos/goblin_machado_2d, cena goblin_machado_2d_visual.tscn. Geração image_gen integrado; prompts e fontes nesta pasta.

Células640×640, raiz(320,560), escala0,071. Transformação comum da folha, sem centralização por contorno de cada pose. Corrida:oito quadros4×2, contato/absorção/passagem/voo e alternância dos pés, tempos50/60/40/50/50/60/40/50ms, ciclo400ms, referência100px/s. Cabeça e ombros acompanham apoio e impulsão, sem deformação extra no motor. Preservar as posições da referência editada.

Ataque:seis quadros3×2, guarda, preparação atrás/acima da cabeça, aceleração do arco, impacto à frente/baixo, continuação com flexão de joelhos e recuperação. Tempos100/180/50/70/120/160ms, total680ms, impacto no quadro3 em330ms; sem repetição. Ombros/quadril giram para conduzir o machado; cabeça segue a inclinação, pés transferem peso. Machado mantém cabo, lâmina e conexão à mão; não atacar como se fosse adaga. Guarda e último quadro no mesmo enquadramento.

Conferir todos os quadros, fechamento da corrida, trajetória de mão/cabeça do machado e último ataque→guarda. Gerar contatos e GIFs com os mesmos recursos/tempos, conferir no mapa real com save isolado, ao lado do player, incluindo dois ciclos com deslocamento.
