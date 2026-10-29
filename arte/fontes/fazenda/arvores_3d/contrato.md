# Árvores adultas da fazenda em 3D

Referências: carvalho e pinheiro originais em `assets/cenario/substitutos/natureza/arvore_spring.png` e `arvore_var_spring.png`; acabamento pixel do personagem e casa 3D da fazenda. Modelos próprios procedurais, sem geração de imagens. Não usar esferas como folhagem: folhas com pontas e nervura elevada (quatro triângulos) e ramos de agulhas em malhas próprias, tronco afunilado, raízes, bifurcações e galhos finos. Casca pintada por shader. Ver `codigo/cenario/arvores_fazenda_3d.gd` e `arvore_pintada_3d.gdshader`.

Duas maquetes reais em SubViewport384×384, compartilhadas pelos sprites adultos do próprio mapa; grade3× com nearest e contorno pixel. Os sprites mantêm posição, ordenação, visibilidade e colisões. A âncora é a projeção da raiz na câmera ortográfica frontal elevada. NaturezaFazenda integra a troca de estações. Carvalho verde na primavera/verão, alaranjado no outono e sem folhas no inverno; pinheiro mantém agulhas e acumula neve. A neve do carvalho acompanha os galhos. Crescimentos jovens e tocos conservam os recursos existentes.

O modo Tiny restaura escala/pivô de suas próprias texturas. A queda desconta a escala de renderização para preservar a altura física do corte. Revisão gráfica em save isolado: `ferramentas/fazenda/revisar_arvores_3d.gd`, 1290 verificações (estações, folhas sem esferas, margens, pivôs, Tiny e queda). Capturas `/dev/shm/algoland-arvores-3d/`; prévias em `arte/previas/fazenda/arvores_3d/`.

Golpes e queda agora usam corpo rígido3D temporário e junta amortecida; o toco também é modelado em3D e compartilhado. Contrato, orçamento mobile e validação em [fisica.md](fisica.md).
