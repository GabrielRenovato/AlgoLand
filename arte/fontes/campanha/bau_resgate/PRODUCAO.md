# Baú de resgate — abertura

Referência: o baú de madeira/ferro já aceito em `clareiras_modulares/primavera/bau_resgate.png`. Perspectiva elevada de três quartos, corpo fixo e tampa articulada na dobradiça traseira.

Folha transparente 2×2, leitura por linhas: fechado, tampa a aproximadamente 30°, 60° e aberta. Mesmo corpo, câmera, textura, escala e base em todos os quadros. Sem equipamento pintado, efeitos luminosos, cenário, molduras ou textos. O loot é concedido pelo inventário real, uma vez por objetivo pessoal.

As quatro estações derivam da mesma folha: madeira mais seca no verão, poucas folhas âmbar no outono e neve descontínua nas superfícies superiores no inverno, preservando interior, corpo, ordem e ângulos da tampa.

Preparação: `ferramentas/campanha/preparar_bau_resgate.py`. Apenas recorte e registro por translação da base; sem ampliar a arte. Atlas final com quadros de 768×768, pivô [440,710], duração de 0,16s por quadro, abertura de 0,64s sem repetição. Corpo com largura lógica de 50px, colisão de 37×13px independente da tampa.

Interação: abrir, aguardar a animação, recolher espada e escudo separadamente. Save registra baú aberto e objetivos coletados; equipamentos antigos preservam compatibilidade. Testes e capturas usam saves isolados.
