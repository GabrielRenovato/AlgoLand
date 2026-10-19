# Base visual dos moradores

O Ivo usa a primeira base reutilizável, `adulto_avental`, extraída dos pixels
nativos do Tomas. Quatro camadas sem sobreposição separam corpo, cabelo/barba,
camisa e avental. Cada perfil escolhe as paletas e acessórios. O gerador compõe
os materiais, preserva as poses e exporta o manifesto usado pelo jogo.

```bash
python3 ferramentas/npcs/gerar_npc.py ivo
python3 ferramentas/npcs/gerar_npc.py ivo --verificar
```

Os contratos e fontes ficam em `arte/fontes/npcs/base_vila/`. `perfis/ivo.json`
registra cores, mecha, capa e retrato. `adulto_avental.json` define quadros
64×64, grade 7×4, seis passos por direção, pés em y=44 e corpo de 31 pixels.
Não há redimensionamento do corpo. As duas transições sentado são articuladas
sobre a mesma folha, com o método já usado pelo Caio e pelas poses de costas.
O retrato mantém a identidade do Ivo e muda somente a região da boca.

As animações de trabalho usam os mesmos pixels do corpo: quatro quadros de
aquecimento com tenaz e seis de martelo, sem ampliar o personagem. As receitas
exatas `ivo_aquecer_receita.json` e `ivo_martelar_receita.json` foram desenhadas
com `PixelLab pixelart_workbench` (IDs `5b1f2489-fc82-477d-bda6-5d4f1bc4e596`
e `00d3e9ad-110a-4ea5-a886-33860eed2065`). O gerador apenas organiza essas
células em folhas horizontais consumidas pelo motor.

`codigo/cidade/trabalho_ferreiro.gd`, filho da bigorna, coordena um pedido por
vez inclusive entre as interfaces cooperativas: caminhada até a fornalha,
aquecimento, percurso pela frente da bancada e quatro ciclos de martelo com
impactos, faíscas e som. A tela fecha para mostrar o trabalho; reabrir permite
consultar o andamento. Os materiais são entregues ao encomendar, usando o diário transacional do
progresso. A encomenda fica em `Progresso.encomenda_forja`, com tipo, dono,
dia inicial e dia de conclusão absolutos; sobrevive a viagens, novas partidas
e recargas. O modelo só é liberado na retirada, depois do prazo. Sem espaço
na mochila, a cópia permanece disponível para retirada gratuita posterior.

Prazos em dias corridos do jogo (`forja_armas.gd: DIAS_FABRICACAO`): arco curto
1; espada gêmea, maça e arco curvo 2; machado e arco longo 3. Dormir avança o
calendário; ondas não contam. A data pode cair na quarta, mas a retirada segue
o expediente. Sem a cena carregada, o prazo continua pelo calendário, sem
simular quadros de animação. Carregar a forja durante o prazo retoma os ciclos
visuais de trabalho durante o expediente; eles não cobram nem liberam armas.

O Ivo atende das 8h às 18h, folga quarta, janta das 19h às 21h e volta à forja
antes de dormir às 22h. Festa, temporal e trajetos seguem a lógica comum da
vila. O trabalho visual para no fechamento e na folga, e retoma no próximo expediente. Sem o
ferreiro presente ou fora do horário, a bigorna permite consultar receitas,
mas desabilita fabricação e retirada.

Validação do fluxo e capturas reais, sempre com saves isolados:

```bash
python3 ferramentas/projeto/testar_tudo.py --teste base_npcs \
  --teste encomendas_forja --teste trabalho_ferreiro --teste forja --teste layout_flex
flatpak run --filesystem=/tmp org.godotengine.Godot \
  --path /tmp/algoland-progressao --rendering-method gl_compatibility \
  --script res://testes/teste_trabalho_ferreiro.gd -- --capturar
```

Para outro morador, criar um perfil e escolher uma base adequada à sua
silhueta. Esta primeira base é de adulto com avental; não atende sozinha a
crianças, vestidos, chapéus ou outros corpos. Novas peças precisam das mesmas
28 poses e do mesmo pivô, além de capa e retrato compatíveis. Não copiar a
mesma cara para todos nem corrigir diferenças de estilo apenas com escala.
O cadastro de casa, profissão, diálogo e rotina permanece em
`codigo/cidade/dados_cidade.gd`.

As edições exatas foram feitas com `PixelLab pixelart_workbench`, sem geração
de IA: caminhada `43ed1d3b-89c7-4a4e-87f4-878926e899ea`, capa
`39813831-628a-45a5-9940-5625942c2f8d`, retrato
`035a20a0-8c7b-4f15-a2ca-fe8f33d0eb14`. A tentativa de geração PixelLab foi
recusada por falta de créditos; nenhum personagem dessa tentativa foi criado.
A camada de mecha vem da edição exata preservada em `ivo_edicoes.json`.
Contornos novos usam marrons e tons locais, sem uma borda preta contínua.

Antes de integrar: verificar grade, transparência binária, pés e reprodução
das folhas; depois conferir no Godot ao lado dos moradores, andando nas
quatro direções, com chuva, sentado e conversando. Testes não aprovam a arte.
Capturas exigem saves isolados:

```bash
flatpak run --filesystem=/tmp org.godotengine.Godot \
  --path /tmp/algoland-progressao --rendering-method gl_compatibility \
  --script res://ferramentas/npcs/revisar_base_vila.gd
```
