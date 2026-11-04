# Revisão do modelo e das mãos

Renderização real do GLB no Godot 4.7.2, em projeto mínimo sem autoloads ou saves.

- `oito_vistas.png`: inspeção de frente, costas, perfis e quatro diagonais. Silhueta inteira e martelo dentro do enquadramento.
- `maos.png`: pegada e punho fechado vistos de frente e em ângulo. As mãos foram refeitas após a crítica aos dedos: palma contínua, quatro dedos e polegar oposto; as pontas do punho esquerdo ficam recolhidas. A mão direita possui concavidade para o cabo.
- `mao_direita_lateral.png` e `pes.png`: conferência complementar da volta dos dedos, apoio dos pés, proporções dos dedos dos pés e unhas curtas.
- `comparacao_porte.png`: chefe com 3,075 m de corpo ao lado do goblin comum de 1,35 m, no mesmo plano e com a mesma câmera. O aumento de 50% foi aplicado à geometria, aos ossos e à arma.
- `na_caverna.png`: prévia do GLB sobre captura real do cenário, com iluminação reduzida para a caverna. É uma composição de revisão, sem execução da IA de combate.
- `respiracao_contato.png`: 17 capturas de 6,5 s de reprodução no motor. Inspeção de dois ciclos, identidade, apoio e vínculo da arma. `respiracao.gif` reúne os mesmos quadros, com intervalos de 400 ms.
- `validacao_harness.json`: importação e oito verificações aprovadas, sem erros; conteúdo preservado. Inclui pesos do rig, vínculo do martelo, ciclo, escala, origem e folga entre mão e cabo.

O recurso possui rig de 18 ossos e respiração. Caminhada, golpes e morte para este novo rig continuam fora desta etapa de modelagem. A cena jogável mantém seu atlas de combate anterior. Inspeção técnica e visual não representa aprovação estética do usuário.
