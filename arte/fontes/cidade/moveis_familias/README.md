# Móveis exclusivos das famílias

Criados com a ferramenta nativa `image_gen`, usando os próprios móveis detalhados do AlgoLand como referência de câmera, acabamento e paleta. Sem uso de Mana Seed ou Tiny. São sprites ambientais transparentes independentes, montados por peça; não uma imagem estática da casa inteira.

## Peças e função

As plantas organizam a área comercial na entrada e os quartos nos fundos. Pia e bancada ficam agrupadas na produção ou cozinha, sem ocupar a área de clientes.

- **Mara — balcão de hospedaria:** livro de hóspedes, chaves e mapas do Téo, tecido verde e vaso sazonal. Largura aparente104 px; colisão96×20 px; salão da pousada.
- **Cora — bancada de padeiro:** massas, rolo, farinha, pães e ingredientes sazonais, com armazenamento inferior. Largura80 px; colisão72×20 px; cozinha da padaria.
- **Rosa — bancada de ervas:** suporte preso ao tampo para secagem, pilão, frascos e caderno botânico compartilhado com Nina. Largura72 px; colisão64×20 px; balcão de atendimento da botica.

- **Cora — vitrine de pães:** mostruário envidraçado, pães em bandejas e área de caixa. Largura144 px; colisão136×22 px; frente comercial. Fonte e pedido em `cora_vitrine/`, com atlas de quatro linhas recortado pelo preparador.

Os pedidos base e alterações sazonais estão nos JSONs desta pasta. Os originais RGBA de1448×1086 permanecem intactos. A publicação copia os arquivos, sem repintar ou alterar os pixels; a escala e o pivô base-centro são metadados, calculados pela silhueta opaca. Não se usa o retângulo de transparências residuais para medir o móvel. Cada versão mantém a largura física e a linha dos pés. Pequenas variações do desenho gerado entre estações são normalizadas pela escala de apresentação, sem modificar a colisão.

## Estações

Primavera: margaridas, morangos e camomila. Verão: calêndulas, mirtilos e lavanda. Outono: flores secas, maçãs/canela e ervas douradas. Inverno: ramos verdes e bagas, nozes/frutas conservadas e ervas medicinais armazenadas. Madeira e ferragens continuam internas, sem neve ou filtro branco.

## Reprodução

1. `python3 ferramentas/casas/preparar_moveis_familias.py` publica16 sprites e os metadados em `codigo/cidade/familias/moveis_exclusivos.json`.
2. `python3 ferramentas/casas/plantas_familias.py` gera as três distribuições comerciais próprias.
3. `python3 ferramentas/projeto/harness.py testar --perfil selecionado --teste casas_familias` verifica acesso aos cômodos, recursos permitidos, troca sazonal, pivô e largura. Renderiza os interiores, fachadas e closes nas quatro estações no Godot, usando save isolado.
4. `python3 ferramentas/casas/abrir_casas_familias.py` abre a bancada local:1–3 casas, F dentro/fora, E estação, roda zoom, arrastar desloca a câmera.

A mudança integra os móveis nas cenas de casas já existentes na bancada; não adiciona novas transições de portas nem sincronização de interiores pela rede.
