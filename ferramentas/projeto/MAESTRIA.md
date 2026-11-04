# Maestria de armas

A progressão pertence ao personagem e à família de arma, independentemente do item e da aparência. Espada, duas mãos, lança, machado, maça, arco e escudo têm níveis de 0 a 100. Não existe nível geral do personagem nem magia de jogador neste sistema.

## Combate e escolhas

- Acertos com dano efetivo e defesas reais concedem experiência. Cada inimigo tem orçamento limitado; repetir o mesmo contato ou curar o alvo não renova esse orçamento. Réplicas aguardam crédito do anfitrião.
- Cada família oferece três caminhos de seis nós. São até 12 pontos; não é possível completar todos os caminhos. Pré requisitos e patamares são conferidos ao aprender.
- Duas técnicas equipadas usam Q/E, RB/R3 no controle e botões de toque. Defender + técnica seleciona as técnicas do escudo. Sem técnica da arma no espaço, o escudo também pode preencher esse espaço.
- O finalizador equipado substitui o último golpe. Arco usa sequência de três disparos; escudo substitui a escudada após aparar. Técnicas e finalizadores têm preparação, contato único, gasto de fôlego e recuperação; usam os movimentos existentes do personagem.
- O terceiro golpe básico libera na maestria 5. Personagens anteriores preservam seus fundamentos.
- Redistribuição na cidade devolve os pontos e conserva experiência; exige confirmar na própria tela.

## Interface

Inventário → aba com espada → Maestria. Nós quadrados pequenos, ícones e conexões mostram a árvore. Clicar abre descrição, requisitos e ações. Arrastar/rolar explora a árvore; botões alteram zoom e recentralizam. O tooltip permanece dentro da área visível. Cores distinguem bloqueio, disponibilidade e aprendizado; 1/2/F identificam técnicas e finalizador equipados.

## Persistência e compatibilidade

`maestria.json` e `maestria_p2.json` ficam ao lado do inventário correspondente. Campanha mantém seu diretório próprio. Gravação usa arquivo temporário e troca atômica. Importação valida XP, pré requisitos, orçamento e equipamentos; recibos persistentes evitam reaplicar créditos de rede.

Tratamentos físicos conservam os identificadores antigos dos encantamentos para compatibilidade dos itens: afiação, balanceamento, contrapeso e ponta reforçada. Os conjuntos antigos passam a reforçar empurrão ou eficiência da guarda. Não alterar a versão global do save para instalar este sistema.

## Validação

`python3 ferramentas/projeto/harness.py testar --perfil maestria` executa modelo, contrato da rede e combate/renderização real com saves isolados. Revisar capturas de paisagem, retrato e tela dividida. `--perfil coop-online` verifica anfitrião/convidado reais por WebRTC e rejeição dos antigos efeitos elementais; `--perfil campanha-percurso` cobre o percurso existente.
