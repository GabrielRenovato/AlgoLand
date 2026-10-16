# Cavaleiro Rubro — prévia visual

Conjunto baseado na referência enviada pelo usuário: aço escuro, bordas envelhecidas e tecido vermelho.

As quatro peças são itens reais de raridade Incomum, disponíveis nos drops a partir da onda 4. Seus níveis seguem a progressão normal de equipamentos (1 a 5).

Vestir elmo, peitoral, luvas e botas do Rubro dá +10% de defesa e vitalidade totais. Não concede raio nem outro efeito de ataque. Três peças ou uma mistura com outro conjunto não ativam esse bônus. As peças separadas ainda têm seus próprios status de armadura.

Chances condicionais ao drop de equipamento: normal 35%, mutante 45%, chefe 45%. Isso corresponde a 0,525%, 2,7% e 45% por morte, respectivamente. O Carrasco mantém seus intervalos próprios no mesmo sorteio; um inimigo não gera drops extras independentes para cada conjunto.

F3 → CONJUNTOS → CAVALEIRO RUBRO (VISUAL) → EXECUTAR veste/restaura apenas a prévia, sem dar bônus. RESTAURAR ROUPA retorna à roupa anterior. Para testar os itens reais: F3 → DROPS → CAVALEIRO RUBRO (4 PECAS) → EXECUTAR, recolher e equipar os quatro itens. As 11 páginas seguem as poses nativas do personagem, com pixels opacos e filtro nearest.

Manifesto: ferramentas/armaduras/em_preparacao/cavaleiro_rubro/manifesto.json.
Gerador e validador: ferramentas/armaduras/.
Conceito e correção do elmo: image_gen, ferramenta integrada. Prompts exatos nesta pasta.

Elmo atual: elmos_face_completa_v6.png. Calota, visor e queixo ocupam a cabeça inteira; espigões finos permanecem acima. O recorte tem 16×20 pixels e uma borda escura nas chapas, sem esticar o visor a cada quadro.

A cabeça ORIGINAL permanece em todas as animações: substituir_cabeca=false. As folhas anteriores em corpo_sem_cabeca estão desativadas e não são usadas. A definição gerada controla essa opção explicitamente, em vez de depender da existência desses arquivos.

Teste teste_elmo_rubro.gd: preservação do corpo, cobertura completa da cabeça nos seis quadros de corrida em quatro direções e estabilidade da arte após descontar o deslocamento da cabeça.
