# Efeitos dos ataques do Dragão Vermelho

Quatro efeitos de seis quadros: fogo (sopro em cone saindo da boca), impacto (poeira e pedras da cauda e patada no chão), vento (rajada circular da batida de asas), meteoro (queda e explosão da chuva de fogo).

Arte criada com image_gen integrado, fundo transparente. Fontes e prompts ficam em fontes/*_v1.png e fontes/prompt_*_v1.txt. O importador ferramentas/efeitos/importar_efeitos_dragao.gd compila a grade de três colunas e duas linhas para seis colunas nativas, preservando os pontos de origem e a escala entre os estados. Paletas limitadas, alpha binário, interpolação nearest e sem mipmaps.

O controlador Codigos/Efeitos/efeito_ataque_dragao.gd acompanha o relógio do golpe, sem dano próprio. As preparações mantêm os avisos no chão; os sprites aparecem somente no impacto. Congelamento pausa os quadros junto com o ataque. Morte, cancelamento e troca de onda removem o efeito com a área do golpe.

Geometria compartilhada em Codigos/Efeitos/geometria_ataque_dragao.gd: o fogo parte da boca da pose escolhida e mira a posição capturada do alvo, com cone de 60 graus e alcance de 150 px a partir da boca. Aviso e efeito usam essa mesma origem. A colisão considera a cápsula real de AreaDano, acompanha a escala do chefe e o crescimento do fogo. Ignição e brasas finais não causam dano. Obstáculos da camada 64 bloqueiam o dano e limitam o comprimento central do sopro. Cauda e asas colidem com o círculo dos pés e aplicam um único impacto no instante de expansão, sem dano ao entrar na dissipação. O impacto é preservado se o relógio saltar o quadro correspondente. Testes/teste_colisoes_dragao.gd cobre as quatro direções, bordas, escala, obstáculos e janelas de dano.

Teste no F3 → DRAGAO, selecionando os três ataques. Testes/teste_dragao.gd valida preparação, impacto, quadros, congelamento e limpeza em projeto isolado. A prévia dos efeitos reais é produzida por ferramentas/inimigos/previa_dragao.gd e exportada como previas/ataques.gif.

O especial usa chuva_fogo_dragao.gd: uma vez abaixo de 50% e outra ao atingir 10% de vida, o dragão decola e fica invulnerável. Ao desaparecer, captura a posição atual dos pés do jogador. Uma área circular centrada nessa posição é recortada pelo contorno da arena e seu raio é calculado para cobrir exatamente 50% da área do mapa. A marcação fica fixa: três segundos para fugir, três segundos de chuva, depois pouso. O hit kill ignora defesa, guarda, invulnerabilidade e o reviver da curandeira. Morte ou troca de onda cancelam a chuva. O aviso usa o tile compartilhado Efeitos/avisos/perigo.png, assim como os avisos das habilidades comuns.

Prévia do especial: inimigos/dragao_vermelho/previas/especial/especial.gif, renderizada por ferramentas/inimigos/previa_especial_dragao.gd. Testes/teste_especial_dragao.gd valida limiares, cobertura, marcação fixa, aviso, hit kill real e pouso em saves isolados.
