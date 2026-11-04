# Fachadas 3D — Vila das Flores

## Referências usadas

- `assets/cenario/campanha/cidade_fiel/sede_pousada.png`: sede (coluna esquerda) e pousada (direita).
- `assets/cenario/campanha/cidade_fiel/oficinas.png`: forja (esquerda) e carpintaria (direita).
- `assets/cenario/campanha/cidade_fiel/enfermaria_mistica.png`: enfermaria (esquerda) e casa mística (direita).
- `assets/cenario/campanha/cidade_fiel/venda_casa.png`: venda (esquerda) e casas comuns (direita).
- Para pousada, enfermaria e a casa da família Cora, preservar as fachadas e pivôs sazonais já usados pelo jogo, descritos em `codigo/cidade/familias/arquitetura.json`.

As referências são as fachadas atuais da própria campanha. Cada atlas tem duas colunas e quatro faixas de estação (primavera, verão, outono e inverno). As fachadas foram conferidas em grade e na cena Vila das Flores.

`referencia_fachadas_3d.png` e `referencia_inverno.png` são rascunhos rejeitados: a prancha cortava as casas entre células. Não são carregados pelo jogo nem usados como referência aprovada.

## Modelo e integração

- Recurso: construção estática de cenário na cidade da campanha.
- Escala lógica: largura original de `ARTE` em `codigo/campanha/cidade_primeira_raiz.gd`; resolução do render 3D: 384×384.
- Câmera ortográfica frontal elevada, orientação e âncora mantidas no plano do mapa. As casas mantêm posição, profundidade e colisões existentes.
- Malha: contorno da fachada extrudado em 0,22 unidade; a placa frontal usa a pintura sazonal original. A imagem 3D é renderizada uma vez por estação em `SubViewport` e reutilizada como `Sprite2D` no mapa 2D.
- Estações: o contorno permanece; a textura troca pelos quatro quadros existentes, sem redimensionar o pivô.
- Mobile: sem animação por quadro, iluminação em tempo real ou atualizações contínuas do `SubViewport`. A adequação foi avaliada pela resolução e pela composição; não foi medida em aparelho físico.

## Revisão visual

- Grade das nove identidades: `arte/previas/campanha/vila_das_flores_casas_3d.png`.
- Cena inteira da campanha: `arte/previas/campanha/vila_das_flores_visao_geral.png`.
- As capturas sazonais usadas na conferência ficaram em `/tmp/vila_casas_3d_estacao_0.png` até `..._3.png`.
