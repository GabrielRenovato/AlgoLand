# Plantio e colheita integrados ao Raven

As duas bases geradas nos estudos de plantio e colheita agora são usadas pelo jogador com suas camadas personalizáveis. `contrato.json` registra fontes, métodos, tempos e verificações. As primeiras tentativas vestidas permanecem como estudos, sem uso no jogador.

`encaixes.json` fixa as articulações por pose/direção na grade80: centro da cabeça, pescoço, quadril, ombros, cotovelos, punhos, joelhos e pés. O compositor mantém o desenho nativo de cada cabelo e elmo, transladando-o pela cabeça; mapeia os pixels de tecido e equipamento dos membros para a silhueta das novas poses; a capa acompanha o pescoço e fica atrás dos braços. Não há geração separada de identidade para cada cabelo ou roupa. O short neutro da base de colheita fica sob a vestimenta; cada item real conserva sua peça independente, ids, níveis e bônus.

As folhas de consumo são320×320, células80×80, pivô40,47 e direções baixo/direita/cima/esquerda. O carregamento usa os mesmos arquivos compactos no desktop, Android e Web, evitando dependência dos atlas grandes. Somente plantar/colher usam esse caminho. As onze páginas de compatibilidade e demais ações continuam preservadas.

Comandos, sempre numa cópia com save isolado iniciado em `AlgoLand testes`:

```sh
flatpak run --filesystem=/tmp org.godotengine.Godot --headless --path /tmp/algoland-colheita-base-revisao --script res://ferramentas/personagem/preparar_acoes_fazenda_raven.gd
flatpak run --filesystem=/tmp org.godotengine.Godot --headless --path /tmp/algoland-colheita-base-revisao --script res://ferramentas/armaduras/gerar_conjunto.gd -- res://ferramentas/armaduras/modelos/carrasco.json --somente-acoes-fazenda
flatpak run --filesystem=/tmp org.godotengine.Godot --headless --path /tmp/algoland-colheita-base-revisao --script res://ferramentas/armaduras/validar_conjunto.gd -- res://ferramentas/armaduras/modelos/carrasco.json --acoes-fazenda
flatpak run --filesystem=/tmp org.godotengine.Godot --headless --editor --path /tmp/algoland-colheita-base-revisao --import --quit
flatpak run --filesystem=/tmp org.godotengine.Godot --path /tmp/algoland-colheita-base-revisao --script res://testes/teste_acoes_fazenda_raven.gd
flatpak run --filesystem=/tmp org.godotengine.Godot --path /tmp/algoland-colheita-base-revisao --script res://ferramentas/personagem/revisar_acoes_fazenda_raven.gd --fixed-fps 50
```

Repetir a geração/validação dos conjuntos com os manifestos `em_preparacao/cavaleiro_rubro/manifesto.json` e `em_preparacao/cavalheiro/manifesto.json`. O compilador completo e a atualização Web também recompõem essas ações a partir das quatro peças existentes do manifesto.

O teste novo passou1005 verificações, incluindo todos os cabelos, dimensões e margens, peças sem sobreposição, efeito no quadro certo, término da ação e retorno ao repouso. Foram capturadas as combinações comum, verde, capa, três conjuntos completos, mistura e peitoral isolado nas duas ações. A revisão encontrou capa à frente dos braços; a ordem foi corrigida e a verificação adicionada ao teste. O teste geral de Raven passou sem falhas. O antigo `teste_plantio.gd` tem nove falhas e um acesso a nó antigo de UI: as mesmas falhas foram reproduzidas com os dois scripts de runtime anteriores à alteração; não foram ocultadas nem tratadas como aprovação do teste.

O GIF em `arte/previas/personagens/acoes_fazenda_raven/plantio_colheita.gif` contém344 quadros de20ms: quatro direções, roupa comum, capa e mistura real, com semeadura em cima e colheita embaixo. É o controlador real do jogador, capturado nos mesmos tempos usados no jogo. A sequência termina no repouso, sem repetição da ação; o GIF repete apenas para demonstração. Foram inspecionadas as poses renderizadas, transições e recuperação, não uma reprodução assistida em visualizador GIF. As animações estão ativas no código local; nenhum patch foi publicado.
