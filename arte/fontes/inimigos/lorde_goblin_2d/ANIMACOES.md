# Lorde Goblin — animação 2D

Modelo canônico: `arte/previas/inimigos/lorde_goblin_2d/conceito_v1.png`.
Preservar rosto, cicatriz, cabelo, manto azul-petróleo, armadura, cinto e martelo de pedra.

Primeira direção: três quartos para direita, mesma câmera da ilustração. Estudo de martelada com oito quadros em grade 4×2. Células lógicas 512×512, raiz (256,450), corpo com aproximadamente 320 px de altura para reservar espaço à elevação da arma. Escala de revisão no mapa: 0,20, corpo próximo de 64 px; confirmar visualmente ao lado do jogador e goblin comum. Fundo transparente. A transformação de escala é comum à folha inteira; não ajustar escala ou centralizar poses pelo contorno.

Correção solicitada pelo usuário: as duas mãos ficam adjacentes na extremidade do cabo, uma imediatamente acima da outra, inclusive na elevação e no impacto. A pegada anterior muito aberta foi rejeitada. Ombros, cotovelos, mãos e martelo precisam formar uma cadeia contínua; ajustar os braços ao novo encaixe. Pés plantados na martelada, joelhos absorvem o impacto, manto reage ao torso. Referência principal de pegada: sequência real https://www.muscleandfitness.com/exercise/workouts/sledgehammer-slam/ . Fotografia arquivada em `referencias_internet/muscle_fitness_sequencia_marreta.jpg`, apenas para análise de movimento. Foto complementar de Ross Enamait: https://www.rosstraining.com/articles/sledge.html .

| Quadro | Fase | Duração | Apoio e trajetória |
| --- | --- | --- | --- |
| 0 | Guarda | 100 ms | Dois pés apoiados; martelo baixo à frente. |
| 1 | Carregar | 150 ms | Peso para trás, joelhos flexionam, arma recua. |
| 2 | Preparar | 180 ms | Arma sobre a cabeça, quadril firme, braços elevados. |
| 3 | Acelerar | 50 ms | Tronco conduz arco descendente à frente. |
| 4 | Impacto | 80 ms | Cabeça do martelo no chão à frente; joelhos absorvem. |
| 5 | Continuação | 110 ms | Corpo acompanha a força sem inverter o arco. |
| 6 | Recuperar | 160 ms | Torso sobe e traz o martelo de volta. |
| 7 | Guarda | 170 ms | Encaixe com quadro 0, sem mudança de escala. |

Ataque não repete no recurso do motor; a prévia pode acrescentar pausa identificada. Animações posteriores devem partir da aparência e do encaixe conferidos desta primeira ação.

O estudo inicial usou o 0 A.D., mas o usuário pediu artes específicas de marreta e depois corrigiu a pegada. A versão consumida é `martelada_direita_v3_pegada_fechada.png`, baseada nas referências humanas reais e nas referências 2D registradas em `referencias_internet/REFERENCIAS.md`. Fontes anteriores permanecem como histórico rejeitado; não voltar à pegada ampla. O registro de apoios efetivamente aplicado e a ficha de reprodução estão em `assets/inimigos/lorde_goblin_2d/registro_animacoes.json`.
