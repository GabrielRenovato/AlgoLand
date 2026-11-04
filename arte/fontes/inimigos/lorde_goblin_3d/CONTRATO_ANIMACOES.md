# Lorde Goblin — ataques gratuitos

O usuário pediu animações prontas da internet e escolheu as gratuitas.
A versão autoral anterior foi rejeitada como abordagem e não é exportada.
O comando `animar_modelo.py` agora encaminha para `retarget_kaykit.py`.
`lorde_goblin_animado.blend` é a fonte antiga, sem uso; a fonte atual é
`lorde_goblin_kaykit.blend`. O modelo base, escala, pintura e anatomia
continuam próprios do AlgoLand.

## Fonte verificada

- Autor: Kay Lousberg. Biblioteca KayKit Character Animations 1.1.
- Página: https://kaylousberg.itch.io/kaykit-character-animations
- Licença: CC0, uso pessoal e comercial sem custo; cópia em LICENSE_KAYKIT.txt.
- Originais: arte/fontes/personagens/base_3d/kaykit/original_free_1_1.zip.
- GLB fonte: Rig_Medium_CombatMelee.glb. Clipes e hashes em animacoes_kaykit.json.
- Pesquisa inicial também avaliou Mixamo. As variantes descendente/giro
  disponíveis nessa seleção tinham gesto de uma mão; o KayKit oferece os
  três gestos de duas mãos e um giro realmente contínuo.

| Clipe no Lorde | Clipe pronto | Tempo final |
| --- | --- | --- |
| golpe_duas_maos | Melee_2H_Attack_Slice | 2,05 s |
| impacto_area | Melee_2H_Attack_Chop | 2,85 s |
| giro_area | Melee_2H_Attack_Spinning, repetido 3 vezes | 3,80 s |

A trajetória e o eixo Y do slot da arma vêm dos quadros da biblioteca.
Tronco, cabeça, quadril e pés seguem as transformações da fonte. Comprimentos
são os do Lorde; IK acomoda braços/pernas e preserva as duas mãos no cabo.
Entrada e saída ligam ao repouso existente; não substituem o ataque pronto
por poses autorais. Raiz do giro e passos derivam do clipe fonte. Reprodução
a 60 FPS, sem ciclo automático do ataque completo.

O martelo conserva geometria, proporção e material. A direita desliza até
perto do final do cabo durante a entrada. A esquerda usa a anatomia de
pegada espelhada da direita, com quatro dedos e polegar. Ambas ficam
referenciadas no cabo durante a fase ativa; direita abaixo e esquerda acima,
com folga entre as mãos e o tórax robusto. A correção de alcance não estica
braços. A pedra é mantida acima do chão e encosta no ataque descendente.

## Eventos e revisão

animacoes.json registra tempos e centros locais Godot em metros. A martelada
usa o ponto de menor altura da pedra; o aviso antecede o impacto em 0,42 s.
Anel e onda compartilham centro/raio. O giratório possui sete pulsos nas três
voltas. O ator consumidor aplica dano aos alvos; o visual emite sinais.

Capturas reais no Godot: câmera frontal elevada ortográfica fixa, 720²,
campo de 9,8 m; detalhes laterais e das pegadas, escala de jogo 224² com
nearest. GIFs usam os mesmos quadros e tempos das capturas a 20 FPS.
Prévia: arte/previas/inimigos/lorde_goblin_3d/animacoes/.

O ator jogável agora usa o GLB em viewport224² com nearest. Os sinais 3D
aplicam dano, com teste de parede e área projetada. Caminhada gratuita
Walking_A incluída; morte por desaparecimento (sem clipe esquelético).
A entrada na câmara da comporta usa chegada_lorde_goblin.tscn: câmera,
martelada sem dano, três falas e início da batalha após a conversa.

## Tornado solicitado durante o giro

Efeito de geometria própria, independente da animação pronta do personagem:
três fitas espirais semitransparentes, funil de 0,8 a 3,35 m de raio e 3,32 m
de altura, cor de vento cinza esverdeada. Rotação e intensidade usam o tempo
do clipe. Aparece só na janela ativa do giro, com entrada/saída suaves, e
some imediatamente ao cancelar. Não altera os raios nem os eventos de dano.
Prévia e consumidor usam a mesma função determinística de amostragem.

## Subida e descida no giratório

A pedido do usuário, o giro pronto recebe um deslocamento vertical de todo o
rig, incluindo pés, mãos e arma. Sobe até 0,50 m no meio da janela ativa e
desce ao mesmo chão antes de terminar. Curva seno ao quadrado com velocidade
vertical zero nas emendas. O funil de vento cresce em altura acompanhando a
subida; a base do efeito, área de dano e sombra permanecem no chão.
