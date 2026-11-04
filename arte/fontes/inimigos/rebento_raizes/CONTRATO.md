# Rebento das raízes

Modelo: casca marrom retorcida, crista de três pontas, núcleo âmbar frontal, folhas discretas, dois braços de raiz e três raízes de apoio. Referência inicial: `assets/cenario/campanha/clareiras_modulares/primavera/broto.png`, derivada do conceito aprovado da clareira. Fontes geradas por IA; originais e origens ficam nesta pasta. O estudo inicial de caminhada precedeu as demais ações.

Câmera: elevada de três quartos. Três vistas desenhadas: baixo, perfil à direita, costas sem núcleo frontal. Esquerda usa espelhamento lateral. Mobs não recebem as quatro estações exigidas para peças estáticas de cenário.

## Grade e apoios

Fontes em folhas 2×2. O preparador separa as quatro silhuetas para recuperar braços que ultrapassam a linha da célula, mantendo o referencial original de cada pose. Não recentraliza pela caixa nem aumenta a arte. Todas as poses usam a mesma célula final de 1024×1024 e pivô [512,800], escala 0,1 no Godot. O atlas compartilhado tem 8×6 células. Colisão de navegação é um círculo de raio 8 no apoio; área atingível é separada, com cápsula de 35px de altura no tronco.

## Movimento e tempos

- Caminhada: quatro chaves, 0,17s cada, apoios alternados e braço oposto. O centro da crista permanece sobre o núcleo; braços oscilam e as raízes dianteiras alternam apoio/passagem. Costas têm oclusões próprias. Último→primeiro integra o ciclo.
- Espera frontal: quatro chaves de 0,3s; flexão discreta e brilho do núcleo. Perfil e costas conservam a pose apoiada da direção correspondente.
- Combo: varrida de raízes seguida de pancada com os dois braços. Cada golpe tem preparação de 0,5s, janela de impacto única e recuperação; impactos em 0,5s e 1,42s. A pancada reutiliza os desenhos de braços erguidos/plantados da conjuração com tempos próprios. A segunda varrida gerada foi descartada por leitura muito semelhante à primeira.
- Conjuração: agachar/preparar 0,45s, erguer braços 0,35s, plantar raízes 0,48s e recuperar 0,42s. Três zonas ficam travadas no início e irrompem em 0,8s, 0,98s e 1,16s. Erupção é um sprite independente de quatro fases, com 0,14s por quadro.
- Reação: pose própria em cada vista, 0,24s; interrompe o ataque. Morte: quatro chaves de 0,2s, apoio cede, corpo cai, núcleo apaga; conclusão emitida uma vez.

Não há dano de contato constante. Dano só ocorre nas janelas, dentro das mesmas áreas anunciadas; paredes bloqueiam conjurações e dano. Congelamento pausa a ação; reação, atordoamento, morte e remoção cancelam os avisos pendentes. Equipamentos, bloqueio e esquiva usam o combate existente.

## Entrega e revisão

Preparador: `ferramentas/campanha/preparar_rebento_raizes.py`. Manifesto de quadros/tempos e PNGs consumidos em `assets/inimigos/rebento_raizes/`; contatos e GIFs com os mesmos tempos em `arte/previas/inimigos/rebento_raizes/`. Não interpretar a exportação do GIF como evidência de que foi assistido.

Perfil `monstro-raizes`: janelas, esquiva, interrupção, parede, morte, capturas por pose e reprodução com os tempos reais no Godot. Conferir identidade, direção, apoios, trajetória das garras e fechamento dos ciclos. A revisão funcional não substitui a inspeção visual no cenário com o jogador.
