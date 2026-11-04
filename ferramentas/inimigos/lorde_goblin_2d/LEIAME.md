# Lorde Goblin — estudo animado 2D

Martelada para direita/três quartos, oito quadros, 1 s, contato no quadro 4 aos 480 ms. Pegada corrigida com as duas mãos adjacentes na ponta do cabo, conforme a referência humana real. O recurso contém esta ação e uma guarda estática; não contém caminhada nem as outras direções e não substitui o chefe ativo.

Fontes, prompts, guia de articulações e referências em `arte/fontes/inimigos/lorde_goblin_2d/`. Canônico em `arte/previas/inimigos/lorde_goblin_2d/conceito_v1.png`.

Empacotar e produzir contato/GIF com os tempos do motor:

```bash
python3 ferramentas/inimigos/lorde_goblin_2d/preparar_animacao.py
```

O empacotador só recorta a grade, aplica limiar de alfa e registra os apoios das botas. Não deforma partes, não reescala poses individualmente e não inventa quadros intermediários. Células 512², raiz (256,450), escala de demonstração 0,2. `registro_animacoes.json` documenta as raízes medidas, durações e evento de contato. GIF acrescenta 500 ms no fim apenas para demonstrar.

Reproduzir no mapa real com save isolado e montar as mesmas capturas:

```bash
python3 ferramentas/inimigos/lorde_goblin_2d/revisar_no_motor.py
python3 ferramentas/inimigos/lorde_goblin_2d/preparar_animacao.py --motor
```

Conferir estrutura, margem e encerramento da animação:

```bash
python3 ferramentas/projeto/harness.py testar --perfil selecionado --teste lorde_goblin_2d
```

O teste não aprova anatomia ou movimento. Conferir os oito quadros, pega da marreta, trajeto da cabeça da arma, apoio, recuperação e retorno à guarda no contato e nas capturas do motor. A revisão gráfica escreve apenas em `/tmp/algoland-lorde2d-revisao` e no save exclusivo `AlgoLand testes lorde2d` sob esse diretório.

## Prévias direcionais atuais

Baixo (nove poses), cima (nove) e direita (oito, folha escolhida pelo usuário) têm GIFs com escombros iniciados no contato e revisão de cor. São estudos independentes do chefe ativo. Consulte `arte/fontes/inimigos/lorde_goblin_2d/CONTRATO_PREVIAS_IMPACTO_DIRECOES.md` para fontes, encaixes e reprodução; use `--forcar` ao mudar a direção por ambiente para evitar reutilização de cache de outra direção. Exportador: `exportar_previa_impacto.py baixo|cima|direita`. Nenhuma integração de dano de combate nesta etapa.
