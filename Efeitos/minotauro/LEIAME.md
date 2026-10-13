# Efeitos do Minotauro

Arte criada com a ferramenta integrada de geração de imagens. Fonte e prompt completos em `fontes/ataques_v1.png` e `fontes/prompt_ataques_v1.txt`.

O importador `ferramentas/efeitos/importar_efeitos_minotauro.gd` separa a fonte em quatro arquivos independentes, com seis quadros de 128×128, paleta limitada e transparência binária. Filtro nearest, sem suavização.

- `investida.png`: poeira orientada no sentido da corrida, durante o deslocamento.
- `pisao.png`: rachadura e onda de choque no impacto.
- `machado.png`: arco de varrida orientado para o alvo, com a borda dianteira encaixada a 8 unidades da ponta da lâmina em cada pose e frame; ordem de desenho relativa acima do sprite do chefe.
- `furia.png`: impacto maior com fragmentos e faíscas do pisão final do especial.

Os efeitos são visuais. Dano e empurrão continuam nas colisões do chefe, sem dano duplicado. Pisão e varrida começam os efeitos no instante do golpe; congelamento pausa os quadros. Recuperação, interrupção e morte removem os nós.
