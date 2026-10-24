# Poses da Medusa — PixelLab

O modelo adulto anterior é a referência. As garras foram desenhadas pelo
PixMiniMax a partir de recortes desse modelo nas quatro direções. O manifesto
de `garras/` registra os jobs, a seleção de quadros, as seis fases lógicas e o
registro espacial. Os diretórios de estudos preservam tentativas rejeitadas;
somente as direções diretamente em `garras/` alimentam o empacotamento.

As primeiras tentativas por esqueleto alongaram o braço. O animador clássico
produziu pouco movimento. Algumas saídas MiniMax viraram o corpo ou pintaram
rastros: esses quadros foram excluídos, sem usar efeitos para esconder defeitos.
A limpeza frontal no PixelLab Workbench removeu 21 pixels isolados; a decisão
exata está em `garras/limpeza_baixo.json`. Não houve compra de recursos.

As células de 160 recebem margem uniforme de 48 pixels. A célula final é 256,
com raiz `(128,184)` e sprite em `(0,-54)`: o apoio continua em `(0,2)` no mundo.
Não há escala ou normalização individual pela caixa delimitadora. A guarda
inicial preserva o recorte canônico. O preparador fixa o alfa binário.

O consumidor usa `SpriteFrames` e `AtlasTexture`, sem deformação óptica das
poses novas. O impacto corresponde aos 30% da etapa ativa, conservando aviso,
duração, dano, alcance, combos e vulnerabilidade. A preparação visual ocupa
os primeiros 315 ms do aviso e o retorno à guarda termina em cerca de 399 ms;
a recuperação vulnerável continua durando 950 ms. As outras páginas continuam
com os recursos anteriores; estes estudos não representam um redesenho delas.

Reprodução com projeto de testes isolado:

1. Executar `preparar_poses_medusa.gd -- --somente-atlas`.
2. Importar o projeto pelo editor Godot e executar o preparador sem argumentos.
3. Executar `testes/teste_poses_medusa.gd` e `testes/teste_medusa.gd`.
4. Executar graficamente `revisar_medusa_arte.gd -- --poses-pixellab`.
5. Executar `python3 ferramentas/inimigos/exportar_previas_medusa.py --poses-pixellab`.

Capturas, tempos e GIFs ficam em `arte/previas/inimigos/medusa/pixellab/`.
O teste estrutural não substitui a inspeção de anatomia, direção e contato.
