# Terreno da vila (tilesets de transição do PixelLab, recoloridos no padrão Mana Seed)

Quatro estações, uma pasta cada: `primavera/`, `verao/`, `outono/`, `inverno/` (a ordem é a do calendário). Em cada uma:

| arquivo | conteúdo |
| --- | --- |
| `grama_terra.png` | grama com caminho de terra (borda por cantos) |
| `grama_pedra.png` | grama com a calçada da praça |
| `terra_pedra.png` | caminho de terra encontrando a praça |
| `grama_agua_0..7.png` | grama com água (rio e lago); os 8 quadros fazem a água correr |

Cada folha tem 4 colunas x 6 linhas de tiles 16x16: linhas 0 a 3 são as 16 combinações de cantos (índice = NO*8 + NE*4 + SO*2 + SE, 1 = terreno de cima do par), linha 4 as variações do terreno de baixo puro e linha 5 as do de cima puro.

Prévia de todas as estações lado a lado: `arte/previas/cenario/tilesets_estacoes.png` (rode `ferramentas/cidade/previa_terreno.gd`). Como foram feitos e como refazer: `recursos/cidade/COMO_USAR.md`.
