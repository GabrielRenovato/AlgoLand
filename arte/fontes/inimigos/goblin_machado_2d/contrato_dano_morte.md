# Goblin de machado: dano e morte

Modelo canônico parrudo aceito: modelo_direita.png e vistas derivadas dos ataques cima/baixo. Direita, baixo/frente e cima/costas desenhadas; esquerda espelha direita. Escala.071, corpo31px, célula640, raiz320/560; chão comum, sem ajustar escala por pose. Ombreira anatômica esquerda; duas mãos na arma na reação; na queda soltar arma uma vez e ela permanece ao lado do corpo. Sem sangue/efeito de corte na reação.

Fonte por direção4x3: primeira linha dano4quadros, duas linhas seguintes morte8quadros. Dano45/75/90/90ms (300ms), sem loop, retorna à guarda. Impacto/flexão, recuo máximo, recomposição e guarda. Morte80/100/110/100/100/120/160/500ms (1270ms), sem loop, corpo final permanece no chão. Fases: golpe fatal, perda de força, joelhos cedem, apoio/queda lateral, contato, acomodação, repouso, imóvel. Não animar morte girando rigidamente o sprite de pé. Corpo e axe nunca somem entre poses; arma cai em trajetória contínua.

Guia direita na célula: dano cabeça350/200→315/220→330/210→350/200; quadril310/430→295/440→305/435→310/430; ombros seguem recuo; cotovelos e mãos mantêm o cabo baixo, pés260/560 e390/560 absorvem apoio. Morte cabeça350/210→320/250→290/330→260/390→220/450→205/485→205/490→205/490; quadril310/435→305/450→310/480→325/500→340/515→345/525→345/530→345/530. Joelhos flexionam antes do quadril tocar chão, mãos afrouxam cabo durante queda; machado repousa ao lado. Frente/back adaptam mesma perda de apoio no plano do chão, mantendo rosto/nuca e roupa respectivos.

Saída: fontes e prompts preservados em arte/fontes; atlas e SpriteFrames em assets/inimigos/goblin_machado_2d; prévias em arte/previas. Cena visual própria com sinais e término de morte; não afirmar troca do mob ativo sem integração completa dele. Revisão no mapa com save isolado.

## Registro efetivo
Fontes1448x1086, grade4x3. Direita lado564/deslocamento(38,43); baixo lado582/(29,0); cima lado580/(30,36). Limpeza de alfa<=128/255 remove somente resíduos semitransparentes, mesma regra em todas as poses. Uma transformação por direção para dano e morte, sem recorte individual. Esquerda espelha atlas direito pronto. Contatos inspecionados: arma pousa ao lado, corpo se acomoda sem desaparecer, vistas frontal/costas mantidas.

`ferido_*` retorna à guarda, `morte_*` não repete e segura último quadro. Sinal morte_finalizada ao terminar, bloqueio de ataques/reação depois de iniciar morte; reiniciar permite reutilização explícita do visual. Esta etapa disponibiliza animações na cena visual do novo goblin; o inimigo ativo antigo não é substituído parcialmente.
