# Cidade da campanha — medição com ajustes mobile

**Resultado:** há sinais de peso para celulares, sobretudo memória e carregamento. A cidade ainda não está validada em telefone físico.

PC: AMD Ryzen 5 5600X 6-Core Processor / NVIDIA GeForce RTX 4060 Ti. Godot 4.7.2-stable (flathub), Compatibility com OpenGL ES3.2. Toque e seleção de ajustes de celular ligados apenas na cópia descartável; branches nativos Android não são simulados. Save do usuário preservado.

## Medidas

- Até o primeiro quadro da cidade: **7.8–8.6s**. Não inclui a inicialização anterior dos autoloads.
- Memória residente ao carregar: **1383–1434MiB**.
- Memória de vídeo estimada pelo motor: **1542–1544MiB**. Não somar com RSS como se fossem memória física independente num celular.

| Cenário | FPS observados no PC | P95 do quadro |
|---|---:|---:|
| 1280x720-praca-movimento | 53.2–129.5 | 9.0–21.5ms |
| 1280x720-oficinas-fogo | 57.4–106.6 | 17.2–21.5ms |
| 1280x720-moradias-grama | 57.7–84.1 | 16.3–20.3ms |
| 1920x1080-praca-movimento | 55.6–101.9 | 15.1–21.5ms |
| 1920x1080-oficinas-fogo | 91.1–137.8 | 8.3–16.1ms |
| 1920x1080-moradias-grama | 114.8–133.2 | 8.6–11.0ms |
| 1280x720-inverno-moradias | 57.4–75.0 | 19.4–19.7ms |

Os intervalos são as médias de duas passagens de3s, não FPS mínimo instantâneo. FPS apresentaram variação grande, inclusive reversões entre resoluções e diagnóstico; não usar para extrapolar desempenho de telefone nem para calcular custo causal de um componente. P95 acima de16,67ms ocorreu em alguns cenários mesmo neste PC.

## Recursos e prioridade

- Grama: 108 visores registrados; resolução base864², fator3 e vento a cada2 quadros. O `_ready()` da grama da cidade substitui a inicialização que aplicaria os ajustes mobile do sistema base.
- Remover a grama liberou aproximadamente157MiB de vídeo; remover em seguida as casas liberou aproximadamente26MiB, além de cerca de22MiB de memória estática do motor. Caches e materiais compartilhados permaneceram residentes, e o RSS não diminuiu durante essa janela. Estes valores não representam todo o custo dos sistemas.
- Cerca de **1361 MiB de vídeo** continuaram contabilizados após essas remoções. É necessária auditoria dos demais recursos e caches. A lista parcial de texturas maiores está em execucao_2/resultado.json; dimensões não equivalem a bytes GPU.
- Prioridade técnica: aplicar os ajustes mobile à grama e reduzir recursos/texturas residentes e custo de montagem. Não foi alterada a qualidade do jogo neste teste.

## Evidências

- Duas execuções completas, 11 cenários cada, sem falhas de cenário ou erros de script na execução final. Avisos GLES conhecidos ao fechar estão nos logs.
- Capturas reais, resultados brutos e logs em execucao_1/ e execucao_2/. Piloto com menu aberto e repetição interrompida na coleta de metadados foram excluídos.
- Configuração, comando, escopo e medidas completas: resumo.json.
- Renderizações revisadas em720p,1080p, oficinas e inverno, com movimento e controles visíveis.
