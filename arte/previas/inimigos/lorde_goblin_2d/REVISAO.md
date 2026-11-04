# Revisão — martelada com pegada fechada

Recurso 2D próprio derivado do conceito; oito poses desenhadas por IA, empacotadas sem deformação ou interpolação artificial do corpo. Versão consumida: `martelada_direita_v3_pegada_fechada.png`. A pegada ampla dos estudos anteriores foi rejeitada pelo usuário e corrigida com referência fotográfica de uma pessoa golpeando com marreta, registrada junto às fontes.

## Inspeção dos quadros

- Oito quadros conferidos em `martelada_direita_contato.png`: rosto, cicatriz, orelhas, cabelo, armadura, manto e martelo preservados; mãos distintas e adjacentes junto à ponta do cabo na elevação, descida e contato.
- O golpe tem preparação, elevação, aceleração, contato baixo, absorção e recuperação. Ombros e tronco acompanham a arma; o golpe termina à frente dos pés. Fonte artística, guia e poses finais são registrados separadamente; o guia não é prova de transferência exata de articulações.
- Translação de registro medida pelos apoios das botas, sem escala por contorno. Células 512², raiz 256/450, escala comum 0,2. Limiar de alfa 64 remove a franja praticamente transparente da exportação; não houve repintura das poses no empacotador.
- Tempos reais: 100/150/180/50/80/110/160/170 ms. Total 1000 ms; contato no quadro 4 aos 480 ms. O GIF de estudo acrescenta 500 ms ao final para leitura, e o recurso do motor não repete automaticamente.

## Reprodução no Godot

`no_mapa.png` e `motor_contato.png` mostram o AnimatedSprite2D real no mapa da Bacia do Moinho, ao lado do jogador e do goblin comum. `reproducao_motor.json` registra todas as amostras e os tempos de dois ataques; `martelada_no_motor.gif` usa essas mesmas capturas. Todos os oito quadros apareceram no motor. A inspeção foi feita pelas capturas e pela sequência de poses; não atribuir ao visualizador estático uma reprodução de GIF que ele não oferece.

Save exclusivo: `/tmp/algoland-lorde2d-revisao/dados/AlgoLand testes lorde2d`. Log gráfico: `/tmp/algoland-lorde2d-revisao/godot.log`. Execução com retorno 0 e sem erro de script; o encerramento do mapa ainda registra mensagens de liberação de recursos do renderer, que não comprovam nem invalidam a análise artística. Nenhum save de partida foi usado.

## Escopo

Estudo de uma martelada à direita/três quartos e guarda estática em recurso independente. Caminhada, outras direções, dano, morte e substituição do chefe de combate não fazem parte deste recurso. Teste estrutural: `harness.py testar --perfil selecionado --teste lorde_goblin_2d`; seu resultado não representa aprovação estética do usuário.
