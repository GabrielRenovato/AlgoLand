# Cerne Partido — integração

Modelo: `estudo_v1/referencia_aprovada.png`; desenhos isolados e prompts preservados em `estudo_v1`. O preparo reutiliza os quarenta desenhos, identifica as oito silhuetas de cada fonte e conserva coordenadas relativas à grade fracionária original. Não amplia desenhos nem ajusta individualmente pelo contorno. Célula final640×640, pivô320,520, atlas8×5 e escala0,26; recursos em `assets/inimigos/cerne_partido/`.

Tempos, ordem e repetição são a fonte única em `animacoes.json`; `ferramentas/campanha/preparar_cerne_partido.py` gera o atlas e as prévias com os mesmos índices. Combo com varridas nos instantes0,58 e1,63s; pancada em0,90s; investida ativa0,98–1,63s; conjuração cria apoios em1,30s e atinge áreas anunciadas a partir de4,50s. Cortar os três apoios interrompe a conjuração e abre4s de vulnerabilidade com dano dobrado.

Queda: aviso visível por2,20s; corpo aparece no alto em1,50s e cai durante0,70s. Impacto único de8 de dano e empurrão280, raio78. Após a fala, IA entra em combate em6,50s. Metade da vida inicia transição de2s; morte dura3s e só depois emite a vitória.

O encontro da chegada mantém as três ondas de rebentos e cria o boss ao concluir a última. O objetivo existente `vigilia` passa a ser confirmado pela morte do chefe, preservando saves já concluídos. Vida480 solo, mais240 por companheiro; sem moedas, Brasas ou progresso de arena. Apoios e chefe são entidades replicadas; a queda inclui posição local do sprite e as falas são mensagens apenas do anfitrião.

Validar com `harness.py testar --perfil cerne-partido`, `campanha-percurso` e `campanha-online`. Capturas e reprodução no Godot em saves isolados; GIFs não certificam sozinhos apoio ou movimento. Caminhada e ataques usam os desenhos frontais do estudo; as vistas estáticas lateral/traseira ficam disponíveis no atlas, sem inventar ataques laterais por rotação do corpo.
