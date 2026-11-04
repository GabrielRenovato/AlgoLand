# Boss 2D da dungeon do moinho

A cena real `cenas/inimigos/lorde_goblin.tscn`, já instanciada em `codigo/campanha/dungeon_comporta.gd`, usa agora o Lorde pintado2D. A apresentação antiga em3D foi substituída no consumidor ativo; fontes3D históricas preservadas. Quatro direções de guarda, caminhada e martelada; esquerda espelha direita e compartilha atlas. Fontes escolhidas pelo usuário, cores e eventos de contato mantidos.

## Movimento e combate

- Caminhada: seis quadros/direção,110ms por quadro, ciclo660ms. Inicia com deslocamento, para na guarda, interrompe ao iniciar ataque e congela junto com o chefe. Atlas e ajustes de cor em `boss_direcoes.json`.
- Martelada: baixo/cima nove poses, contato540ms; direita/esquerda oito, contato480ms. Direção travada durante o ataque. O relógio único garante um evento mesmo com passos grandes, sem timer pendurado depois do cancelamento/morte.
- Dano em área: elipse de raio56 e profundidade28, mesma região para IA, aviso e acerto. Cada jogador vivo no mesmo mundo recebe dano uma vez por contato; paredes bloqueiam acerto. Multiplicador1,25 do dano configurado. Escombros animados são visuais e não repetem dano.
- Escombros: ponto de ruptura vinculado à cabeça da marreta em cada direção; reprodução e descarte automáticos. A chegada usa processamento durante pausa para não deixar o efeito congelado até o fim do diálogo.
- Preservados600HP, navegação, apresentação/diálogo, proteção antes do combate, HUD, alvo da missão e vínculo com a alavanca. Derrota libera a progressão existente. Marcador acompanha a posição da cabeça sem procurar esqueleto3D.
- No carregamento dos goblins acompanhantes, recurso de armadura inexistente não substitui mais os quadros válidos por null. Mantém o recurso básico existente enquanto a variante opcional estiver ausente.

## Construção e validação

`preparar_andadas.py` registra as fontes de caminhada com uma transformação comum por direção. `integrar_boss.py` copia os atlas aprovados e gera o manifesto consumido no jogo. Não há nova geração ao executar esses empacotadores.

Perfil executado: `bacia-moinho`, incluindo `bacia_moinho`, `entrada_dungeon_visual` e `lorde_goblin_combate`. Última execução completa:242 verificações, zero erros funcionais; importação aprovada. O resultado do harness não substitui a revisão visual: capturas da câmara, quatro ataques, seis poses de cada caminhada e diálogo nas escalas576×324,288×512 e320×324 foram inspecionadas. Todos os testes usaram cópia/save isolados. Não houve publicação nem alteração do save do usuário.

Evidência: `arte/previas/inimigos/lorde_goblin_2d/validacao_boss_integrado_moinho.json`, fotos `boss_moinho_martelada_*.png` e `boss_andando_quatro_direcoes_no_moinho.gif`. O GIF é composto a partir das capturas reais da dungeon. Exportador `exportar_andada_no_mapa.py PASTA --escala-coordenadas 2` para a resolução do teste gráfico existente.
