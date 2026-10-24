# Fluidez da Medusa

O modelo anterior continua sendo `revisao_cidade`; esta alteração não redesenha
personagem, equipamento, paleta ou silhuetas-chave. Os cinco PNGs consumidos
continuam intactos, com células160×160, grade6×4, raiz(80,136), sprite em(0,-54),
direções baixo/cima/direita/esquerda e base física y2. Não há variante sazonal
para o chefe.

`gerar_fluxos_medusa.py` analisa os deslocamentos entre poses vizinhas e5→0,
nas quatro direções. Os campos são dados numéricos, não novos desenhos.
O shader usa a cor do pixel original mais próximo, sem mesclar transparências.
Cada pose-chave permanece idêntica; as amostras entre elas são renderizadas
pelo motor. Isso não equivale a quadros intermediários desenhados à mão.

O campo usa80×80 amostras por célula, deslocamento bidirecional em pixels,
armazenado em RG8. Os `.bin` são intermediários locais; os `.res` comprimidos
em `recursos/personagens/medusa/fluxos/` são os recursos exportáveis.
O manifesto guarda hashes das imagens e a versão do OpenCV.

Os tempos de aviso, impacto, recuperação, dano, alcance e regras de combo
continuam os anteriores à revisão. Apenas a progressão visual percorre as
poses continuamente, incluindo repouso e retorno da recuperação.

Para reproduzir após alterar os sprites:

1. Executar `preparar_medusa.gd` numa cópia com save isolado.
2. Com `opencv-python-headless`, executar `gerar_fluxos_medusa.py`.
3. Executar `preparar_fluxos_medusa.gd` para empacotar os dados no Godot.
4. Rodar `teste_medusa.gd` e, com renderização gráfica,
   `teste_fluidez_medusa.gd`, `previa_medusa.gd` e `revisar_medusa_arte.gd`.
5. Conferir movimento, identidade, raízes, braços, cauda e fechamento dos ciclos
   nas capturas reais; aprovação funcional não aprova qualidade de movimento.

O teste gráfico compara todas as poses-chave e os20 fechamentos com a
renderização sem shader, valida alfa e exige intermediários distintos.
