# Estudo da colheita Raven

Prévia lateral criada por IA a partir de um molde dos sprites originais do Raven. O Mana Seed é referência do gesto, não uma transferência literal de poses. Este estudo usa roupa fixa e não substitui o jogador ativo nem suas camadas personalizáveis.

A primeira tentativa de quatro direções e a correção de escala foram rejeitadas: aumentaram o personagem e o detalhamento. O estudo foi reduzido ao perfil, usando `molde_perfil.png` como alvo de edição. `geracao_perfil.png` é o resultado selecionado; instruções em `prompt_perfil.txt`.

A folha final está em `assets/personagens/raven_fantasy/estudo_colheita/colheita_perfil.png`: seis células80×80, pivô40,57. A extração usa a mesma transformação para todos os quadros, sem recorte ou realinhamento por silhueta. O recorte512×512 remove apenas a ampliação8× da grade64×64. Não modificar a geração pelo contorno do cabelo ou das botas.

Quadros: preparar120ms, abaixar140ms, agarrar180ms, puxar120ms, levantar160ms, recuperar180ms. Total900ms, sem repetição; o GIF acrescenta500ms de pausa demonstrativa. No estudo: pés ancorados, cabeça e quadril descem na aproximação, mãos procuram o chão e voltam ao corpo. O cabelo acompanha a inclinação; a recuperação retorna à silhueta de pé.

Revisão executada na fazenda real do Godot com save isolado `AlgoLand testes colheita Raven`. Capturas de todos os quadros e comparação lado a lado com o Raven original em `arte/previas/personagens/raven_colheita/motor/`. Foram conferidos os seis quadros na ordem e a duração real de900ms. A revisão visual cobre identidade, direção, agachamento, apoio, transparência, retorno e tamanho na cena. A reprodução do GIF não foi inspecionada em um visualizador animado; a análise usa os quadros e a sequência renderizada pelo motor.

Para reproduzir, preparar uma cópia com `ferramentas/projeto/preparar_testes.py`, configurar nela o diretório de usuário isolado com nome iniciado em `AlgoLand testes` e rodar:

```sh
flatpak run --filesystem=/tmp org.godotengine.Godot --headless --path /tmp/algoland-colheita-revisao --script res://arte/fontes/personagens/raven_colheita/exportar_perfil.gd
flatpak run --filesystem=/tmp org.godotengine.Godot --path /tmp/algoland-colheita-revisao --script res://arte/fontes/personagens/raven_colheita/revisar_no_godot.gd --fixed-fps 50
ffmpeg -framerate 50 -i arte/previas/personagens/raven_colheita/motor/%03d.png -filter_complex '[0:v]split[a][b];[a]palettegen=max_colors=128:stats_mode=diff[p];[b][p]paletteuse=dither=none' -loop 0 -y arte/previas/personagens/raven_colheita/colheita_perfil.gif
```

Para aplicação no jogador, ainda faltam as outras três direções e o encaixe das camadas de pele, cabelo, roupa e equipamentos. Não publicar uma folha vestida como substituta dessas camadas.
