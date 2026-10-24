# Posto funcional de ferreiro

Direção: objetos pintados da vila, câmera elevada de três quartos, Ivo canônico pixelado31px/célula64px. A lareira doméstica anterior foi rejeitada como modelo funcional.

Produção imagegen: forja a carvão aberta, mesa de alvenaria baixa, carvão incandescente com chamas pequenas, coifa metálica rebitada e chaminé central. Sem grade dianteira, arco de lareira ou segunda câmara inferior. Entrada de ar lateral diretamente sob o leito. Edição dirigida reduziu o pedestal para uma fiada de pedra e rodapé, mantendo carvão e coifa. Bigorna independente sobre cepo curto de carvalho, aço escuro, ponta à esquerda, tampo acessível à direita.

Fontes: fornalha.png e bigorna.png. Prompt técnico: authentic traditional blacksmith coal forge, open waist-high coke hearth, low masonry pedestal, broad riveted hood and centered chimney, visible left tuyere under coal bed, no fireplace arch, no grate, no anvil, isolated transparent background. Bigorna: isolated forged dark steel anvil, horn left, hardy hole right, short oak stump, elevated front view, transparent background.

Integração: preparar_posto_ferreiro.py, resolução4×, fornalha288×256 (72×64), bigorna120×96 (30×24). Base-centro fornalha440,64, bigorna474,108. Mesma geometria e pivôs nas quatro estações, com alterações discretas de luz de interior. Fumaça no topo da chaminé, carvão animado em máscara local sem mover pedra ou coifa. Fole usa fonte própria e bico direto na entrada lateral, sem cano desenhado.

Contatos de animação em trabalho_ferreiro.gd: fole360,50; aquecer480,49; martelar490,97; impacto476,90. A cápsula do Ivo mantém5px de raio e suporte9px abaixo da raiz. Contorno frontal passa por404,114 e498,114 sem cruzar fornalha ou cepo. Colisões representam bases, não coifa/sombra. Braços e corpo sempre vêm de quadros inteiros, sem máscaras no NPC.

Transporte: PixelLab animate_image job068aca08-4785-4f9f-bd1b-05fe0f2a3810, asset313b6389-b003-5927-8996-1cca1eca42f9. Entrada: primeiro quadro canônico ivo_aquecer. Pedido: caminhada lateral carregando tarugo quente na tenaz, braços firmes, pernas alternadas, corpo completo e raiz fixa. Folha ivo_transportar.png, nove células64px, quadros1–8 a8fps durante deslocamento; espelhamento apenas ao contornar pela esquerda.

Fole: imagem lógica50×29 (fonte192×116), raiz360,36, bico penetra no bocal; recorte AtlasTexture da metade frontal do bocal encobre sua ponta. Ida ao fogo contorna por360,92 e404,92, subindo pela DIREITA do fole. Ida à bigorna usa404,114,498,114 e498,97. Cápsula continua colidindo durante todo percurso.

Combustão: fornalha_fraca.png é edição imagegen com carvão escuro, poucas brasas vermelhas e sem labaredas; mesma tela/geometria da fonte quente. Recorte comum derivado da fonte quente, quatro variantes de cada estado. Shader mistura carvão fraco com fogo quente por altura e vigor. Receber ar aumenta vigor acumulado, impulsos acionam fumaça do braseiro e chaminé, luz cresce e o fogo decai lentamente.

Martelo corrigido no PixelLab pixelart_workbench, desenho168a650a-aad7-4c7e-91c8-cd152a8d63d6. Cabeça reduzida para5×5px em aço escuro, em vez da grande placa azul. Receita, folha fonte3×2 e perfil atualizados para regeneração consistente. Tarugo incandescente fica separado da ferramenta.

Aquecimento definitivamente pelo lado DIREITO da fornalha: posição480,49, sprite completo espelhado, tenaz aponta à esquerda para o carvão. Ida desde o fole:360,114 →498,114 →498,49 →480,49; passa abaixo do fole e do cepo antes de subir pela lateral direita. Depois retorna pela lateral498,49 →498,97 →490,97 para martelar.
