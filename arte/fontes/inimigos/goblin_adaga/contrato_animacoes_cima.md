# Goblin com adaga — corrida para cima

- Pedido: direção cima da corrida aprovada para baixo. Somente `correr_cima`; ataques/guarda cima ainda não produzidos.
- Identidade e movimento: `corrida_baixo_referencia_v1.png`, aprovada pelo usuário; vista traseira `modelo_costas_referencia.png`, extraída do modelo original. Mesmo goblin, roupa, cabelo, escala e ritmo.
- Referência externa anterior: Oul Studio, https://oul-studio.itch.io/top-down-player-template, prévia frontal inspecionada e registrada em `referencias_internet/REFERENCIAS.md`. Não se afirma que a prévia inclui corrida traseira nem transferência literal de articulações. Vista de costas criada a partir do canônico e guia anatômico próprio.
- Arte pelo image_gen integrado: `corrida_cima_v1.png`; prompt exato `prompt_corrida_cima.txt`; guia e fases `movimento_cima.json` / `guia_corrida_cima.png`.
- Costas mostram nuca, dorso e costura central, sem olhos ou peito frontal. Mão anatômica direita = lado direito da tela; corrige a inversão da arma na vista traseira estática original. Pano da faixa no quadril esquerdo = lado esquerdo da tela.
- 8 quadros, folha 4×2, final 640×640 por célula, pivô (320,560), escala 0,071, altura próxima a31 px. Registro global: folha reescalada para 4×608 por2×608, deslocamento(16,9) em cada célula640; nenhuma pose ajustada pelo próprio contorno.
- Tempos 50/60/40/50/50/60/40/50 ms, ciclo400 ms, referência de velocidade100 px/s. Contatos e absorções alternados, calcanhar recuado levantando, braços em oposição, oscilação pequena e solidária de cabeça/tronco.
- Recursos: `assets/inimigos/goblin_adaga/correr_cima.png`, `animacoes.tres`, registroJSON; consumidor `cenas/inimigos/goblin_adaga_visual.tscn`. Direções de combo registradas separadamente para não inventar ataques ausentes.
- Prévia planejada: contatos de todos os quadros, GIF dos mesmos quadros/tempos; captura no Godot em projeto/save isolados, comparando com corrida frontal e player, mais deslocamento para cima.

## Revisão executada

Inspecionados os oito quadros, continuidade7→0, apoios/solas alternados e cabeça/pescoço solidários ao tronco. Renderização real no Godot4.7.2 com player e corrida frontal ao lado, seguida de dois ciclos avançando para cima. Altura de contato31,666 px. Evidências em `arte/previas/inimigos/goblin_adaga/revisao_animacoes_cima.json`. Perfil selecionado:33 verificações OK, zero falhas; relatório `/tmp/algoland-harness/execucao-ebh1go3f/relatorio.json`. Auditoria geral mantém8 falhas anteriores fora desta tarefa. A inspeção foi dos quadros/trajetórias capturados, não reprodução do GIF no visualizador estático.
