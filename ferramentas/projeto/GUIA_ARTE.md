# Guia de arte do AlgoLand — versão 1

Este guia diz **como o jogo deve parecer**. As [regras visuais](REGRAS_VISUAIS.md) dizem **como produzir** (encaixes, água, mapas modulares, armaduras), e o [estilo 3D](ESTILO_3D_ALGOLAND.md) cobre modelos 3D. Toda arte nova, feita à mão ou gerada, é conferida contra este guia antes de entrar em `assets/`.

O guia foi tirado do que já funciona no jogo (medido em 09/11/2026), não de um ideal novo.

## 1. Assinatura

**Pintura com cara de pixel art, feita em alta resolução e reduzida no jogo.** Não é pixel art de grade: as peças das clareiras têm de 570 a 680 px, com dezenas de milhares de cores, e entram no mundo reduzidas com filtro linear e mipmaps. O herói 3D segue a mesma ideia: ele é renderizado com `NITIDEZ = 16` e reduzido.

O que define a assinatura:
- Pinceladas em blocos pequenos e visíveis, com bordas nítidas, sem degradê liso.
- Contorno escuro e quente (verde ou marrom muito escuro), nunca preto puro.
- Luz de cima e da esquerda, sombra curta, sem brilho especular.
- Câmera elevada e frontal, a mesma do mundo (ver `ESTILO_3D_ALGOLAND.md`).
- Detalhe proporcional ao tamanho final: o que some ao reduzir não deve ser pintado.

**Referências canônicas** (comparar lado a lado antes de aprovar):
- `assets/cenario/campanha/clareiras_modulares/primavera/` → `carvalho.png`, `arbustos.png`, `bau_resgate.png`, `jovem.png`
- `assets/campanha/carregamento/vila.jpg` → ilustração de tela cheia
- `docs/avaliacao-2026-11/capturas/dialogo-576.png` → mundo e interface juntos

**Fora do estilo:** render cartoon liso e brilhante (como `mapa_primeira_raiz_cartoon.png`), vetor chapado (SVG), foto, cel-shading, contorno preto grosso e uniforme, saturação de desenho animado.

## 2. Paleta do mundo (primavera)

Cores dominantes medidas nas referências. São âncoras, não uma lista fechada: cores novas devem ficar perto delas em tom e saturação.

| Papel | Cores |
| --- | --- |
| Sombra e contorno | `0d1a14` `142819` `112515` |
| Folhagem escura | `21361e` `2b3e1a` `263311` `214126` |
| Folhagem média | `415516` `4f6716` `39602b` `2e4e22` |
| Grama iluminada | `5f8439` `658a3b` `6a8e3b` |
| Madeira e terra escura | `3e2712` `452c15` `4d331a` |
| Terra e pedra clara | `b89e7d` `b7a081` `ccaf87` |

Regras:
- Saturação moderada. Os verdes puxam para o oliva e as sombras puxam para o verde ou o marrom.
- O ponto mais escuro de uma peça fica perto de `0d1a14`, e o mais claro raramente passa de `ccaf87` (exceto brilho de magia, fogo e água).
- As outras estações variam a partir desta tabela pelas pastas `verao/`, `outono/` e `inverno/`, sem trocar contorno nem luz.
- A água segue o contrato de água das regras visuais. O ciano saturado do mapa atual (`017693`) não pertence ao jogo.

## 3. Paleta da interface

Hoje está espalhada em `codigo/ui/estilo_campanha.gd` e `codigo/campanha/tela_resultado.gd`:

| Nome sugerido | Cor | Uso |
| --- | --- | --- |
| PAPEL | `30271c` | fundo dos painéis |
| TINTA_ESCURA | `352b20` | texto sobre fundo claro (pergaminho) |
| CREME | `f4e6c4` | texto principal sobre painel escuro |
| SUAVE | `c1b18b` | texto secundário e legendas |
| OURO | `d1ad62` | títulos, destaques e item selecionado |
| BRONZE | `a58650` | moldura e bordas |
| VERDE_ACAO | `273d32` | botão principal ("Explorar", "Rejogar") |

**Atenção:** o nome `VERDE` hoje vale ouro (`d1ad62`) em `estilo_campanha.gd` e verde-escuro (`273d32`) em `tela_resultado.gd`. Unificar numa só fonte de cores antes de criar telas novas.

## 4. Texto

- Títulos em Noto Serif SemiBold. Corpo de texto em Noto Sans. As duas estão em `assets/ui/fontes/`.
- Tamanhos na resolução base (576×324): 10–11 px no corpo, 8 px só em legenda curta, 15 px ou mais em título de tela.
- **Português sempre com acento** (POÇÃO, NÍVEL, ÀS). As fontes têm todos os glifos.
- Caixa alta só em títulos curtos e botões. Frases e descrições em caixa normal.

## 5. Escala e filtro

- A resolução base é 576×324, com `stretch canvas_items` e `aspect expand`. Toda medida de interface é pensada nela.
- **Arte do mundo e ilustrações:** produzir pelo menos 4× maior que o tamanho final e exibir com `TEXTURE_FILTER_LINEAR_WITH_MIPMAPS`, como em `clareiras_chegada.gd`.
- **Pixel art de grade de verdade** (o corpo base em `personagens/Body`, que tem 5 cores, e pacotes de interface em pixel): usar filtro *nearest*, que é o padrão do projeto, e escala inteira (2×, 3×…). Nunca reduzir com filtro linear.
- Não misturar as duas coisas no mesmo elemento. Um ícone ou é pintura reduzida ou é pixel de grade.

## 6. Ícones

Hoje há quatro origens que não combinam: "Cute RPG Icons", três pacotes da craftpix e SVGs próprios (`assets/ui/acessorios_iniciais/*.svg`). O padrão a seguir:

- **Mesmo estilo do mundo:** pintura com cara de pixel, contorno escuro quente e luz de cima e da esquerda.
- **Fonte de 128×128 px**, fundo transparente, objeto ocupando cerca de 80% do quadro. Exibir entre 24 e 48 px na resolução base.
- **Cada ícone diferente do outro.** Não repetir o mesmo desenho em nós diferentes (como acontece hoje na árvore de maestria).
- **Item trancado:** o próprio ícone dessaturado e escurecido a cerca de 40%, com um cadeado pequeno. Nunca uma silhueta preta.
- Os SVGs de acessórios devem ser substituídos por pinturas no padrão acima.

## 7. Ilustrações (mapa, carregamento, retratos, cenas)

- Mesma assinatura e paleta do mundo. A referência é `carregamento/vila.jpg`.
- Vista elevada e frontal para mapas e lugares. Nada de perspectiva isométrica nova ou câmera de cinema.
- PNG por padrão. JPG só em ilustração de tela cheia, com qualidade de 90 ou mais.
- Texto nunca vai pintado dentro da imagem. Nomes e rótulos ficam na interface.

## 8. Arte gerada por IA

Pode ser usada como fonte, desde que passe pela mesma régua de qualquer arte:
- Guardar o prompt e as referências em `arte/fontes/`, como manda o pipeline.
- Gerar com as referências canônicas da seção 1 anexadas, pedindo explicitamente: *"pixel art painting, high resolution, warm dark outlines, top-left soft light, muted olive greens, elevated frontal view, no glossy highlights, no text"*.
- **Antes de aprovar, remover os sinais típicos de IA:** brilho plástico, detalhe miúdo demais para o tamanho final, simetria estranha, objetos que se fundem, texto ou letras falsas, contorno que muda de espessura sem motivo, saturação de "pôster".
- Reduzir para o tamanho real do jogo e comparar lado a lado com as referências. Se destoar, refazer em vez de "consertar no shader".

## 9. Checklist de aprovação

1. Está na assinatura da seção 1 e não está na lista do que fica fora do estilo?
2. As cores ficam perto da paleta (mundo ou interface)?
3. Contorno, luz e câmera batem com as referências?
4. No tamanho real do jogo continua legível, sem borrar e sem chuviscar?
5. Ícones: 128 px de origem, sem repetição, trancado = dessaturado?
6. Texto com acento e nas fontes certas?
7. Conferido no Godot em 576×324 e 288×512 (regra das regras visuais)?

## 10. Dívidas conhecidas (09/11/2026)

- `assets/ui/campanha/mapa_primeira_raiz_cartoon.png`: fora do estilo. Refazer na assinatura do mundo.
- `assets/ui/acessorios_iniciais/*.svg`: vetor; aparece borrado na tela de resultado.
- Forja: itens trancados aparecem como silhueta preta.
- Maestria: ícones de 24 px repetidos entre nós.
- Interface: nome `VERDE` com dois significados (seção 3).
- Pacotes de ícones de origens diferentes misturados na interface.
