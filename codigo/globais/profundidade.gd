extends RefCounted

## Ordem de desenho pela altura dos pés na tela (y-sort manual por z_index): quem está mais abaixo fica na frente.
## As partes do jogador usam z relativo de 0 a 6 (ver reacao_jogador.gd / arco_jogador.gd), então cada faixa
## de PASSO_PX reserva NIVEIS valores de z para elas não se misturarem com árvores e objetos da mesma faixa.
## O intervalo útil fica dentro de ±1024 para continuar dentro do range_z padrão das luzes 2D.
const PASSO_PX := 8.0
const NIVEIS := 8
const Z_CHAO := -1000   ## camadas de chão (neve, terra, gelo, pedrinhas)
const Z_TOPO := 1000    ## efeitos que ficam acima de tudo (dano flutuante, neve caindo, raios)
## Distância da origem do jogador até os pés (quadro de 64 centralizado)
const PES_JOGADOR := 11.0

static func z_de(pes_y: float) -> int:
	return clampi(int(floor(pes_y / PASSO_PX)) * NIVEIS, Z_CHAO + NIVEIS, Z_TOPO - NIVEIS)
