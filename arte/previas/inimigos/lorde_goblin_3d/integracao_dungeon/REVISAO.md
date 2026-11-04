# Lorde Goblin — integração na dungeon

Revisão em 03/11/2026, Godot 4.7.2.

- Boss original integrado à câmara da comporta do estágio 4.
- Chegada com câmera, queda e martelada; combate bloqueado durante três falas.
- Caminhada e três ataques reaproveitam KayKit Character Animations 1.1 (Kay Lousberg, CC0). Giro mantém tornado pixelado e subida/descida.
- Derrota real libera a alavanca; guia acompanha boss, alavanca e saída conforme a missão.
- Inspecionadas as 3 falas nas resoluções lógicas 576×324, 288×512 e 320×324: texto, molduras, título e botões sem cortes ou sobreposição.
- Inspecionadas chegada, aproximação e os três ataques na dungeon. Marcador alinhado acima da cabeça, inclusive no giro.
- Harness: bacia_moinho 147 verificações; entrada_dungeon_visual 24; lorde_goblin_3d 16; lorde_goblin_combate 16. Todos aprovados, saves preservados.
- Relatórios originais anexos; revisão visual registrada aqui após inspeção das capturas. Avisos de recursos no encerramento classificados pelo harness como conhecidos.
- Validação local com tamanhos de tela simulados; aparelho móvel físico e multiplayer não avaliados nesta revisão. Morte usa desaparecimento gradual.
