# Golpes, queda física e toco 3D

`codigo/cenario/fisica_arvore_3d.gd` cria uma simulação isolada somente na árvore atingida. Copia as malhas da maquete da espécie/estação, preservando as outras árvores. RigidBody3D com massa18, junta HingeJoint3D na altura do corte0,68 e mola angular amortecida representa as fibras restantes. O impulso do golpe entra em `_integrate_forces`, depois da atualização da inércia. O último golpe remove raízes/trecho inferior da cópia e deixa a gravidade tombar o tronco. Colisão com o solo solta a junta, faz o corpo assentar, movimenta a copa e dispara lascas/folhas (neve no inverno). Detritos têm colisão e amortecimento. A apresentação é liberada após o assentamento; o estado persistido continua sendo árvore cortada/toco existente.

Plantio informa a posição do jogador que golpeou à Extração; a reação usa essa origem, inclusive com P2. Itens, resistência, drops, colisões2D, toco removível e crescimento continuam no fluxo comum. O modo Tiny e o excesso do orçamento mantêm a apresentação legada.

Celular: viewport512² por árvore ativa, no máximo2 simulações por mapa,3 lascas por golpe e6 detritos no impacto. Desktop:768², no máximo4 simulações,7/18 detritos. A escala exibida compensa a resolução, preservando tamanho/pivô. Árvores paradas compartilham as duas maquetes renderizadas somente ao mudar estação; não simulam física continuamente.

O toco é uma maquete3D128² compartilhada, com raízes e casca iguais ao tronco, superfície de corte e anéis em `madeira_cortada_3d.gdshader`; só renderiza ao mudar estação. Neve no inverno. `vestir_toco` também atende saves já cortados e restaura escala/material depois da comparação Tiny. A colisão desaparece somente ao arrancar o toco.

## Validação

`ferramentas/fazenda/revisar_fisica_arvore_3d.gd`, em save isolado e renderização gráfica: golpe isolado/retorno ao repouso, quatro golpes, direção, RigidBody/junta, gravidade, contato real, colisão do toco, limpeza e isolamento; verifica também as quatro estações do toco, pivô, Tiny, recarga do mapa e retirada. Argumentos `--estacao=0..3`, `--lado=-1|1` e `--fisica-mobile` permitem repetir variantes. As quedas sazonais e os dois sentidos passaram. Revisão final da primavera com toco:32 verificações, zero falhas. Fontes temporárias em `/dev/shm/algoland-fisica-arvore/`; prévias em `arte/previas/fazenda/fisica_arvore_3d/`.

`ferramentas/fazenda/medir_corte_3d.gd -- --fisica-mobile` mede no PC o caminho de orçamento reduzido, não emula o hardware de um celular. Amostra120 quadros por fase: CPU média7,11ms parada,11,49ms com uma árvore ativa,12,98ms com duas; física média0,44/1,43/2,45ms. Testou limite de duas e limpeza com sucesso. Não é medição de GPU nem comprovação de FPS em Android. Logs detalhados em `/dev/shm/perfil-corte-mobile.log`.
