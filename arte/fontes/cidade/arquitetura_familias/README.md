# Arquitetura das famílias

Artes próprias geradas com image_gen nativa, sem Mana Seed ou Tiny.
Referência de perspectiva, luz e densidade: captura real da vila em
`arte/previas/campanha/cidade_primeira_raiz/primavera.png`.

- Mara e Téo: pousada com pedra, madeira escura e telhado azul.
- Cora e Bia: padaria com tijolos, reboco quente e telhado de terracota.
- Rosa e Nina: casa herbalista com reboco verde, calcário e telhado musgo.

Cada atlas contém quatro fachadas e quatro amostras de parede, na ordem
primavera, verão, outono e inverno. Materiais interiores são abrigados;
neve e variações da vegetação ficam no exterior.

`contrato.json` registra recortes medidos, tela e pivô da porta/base.
`ferramentas/casas/preparar_arquitetura_familias.py` recorta os originais,
normaliza a parede para 256×128 (64×32 lógicos) e publica somente as peças
consumidas em assets. Uma única escala e um único pivô por família são
compartilhados pelas quatro estações; não ajustar pelo recorte de cada estação.

As fachadas são cenas reutilizáveis e aparecem na bancada com F (dentro/fora).
Na vila experimental, Mara usa a pousada, Rosa o prédio de cuidados e Cora
a moradia sudoeste. IDs do mapa, posições e bases de colisão são preservados.
As plantas interiores continuam em cenas próprias, sem migrar a partida do usuário.

Validação: `python3 ferramentas/projeto/harness.py testar --perfil selecionado --teste casas_familias`.
O teste captura interiores, fachadas, vila nas quatro estações e telas compactas;
a aprovação funcional exige ainda inspeção das capturas.
