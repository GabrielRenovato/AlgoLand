#!/usr/bin/env python3
"""Personagem base em ASCII: corpo de 9x6 caracteres montado em camadas (cabeça, tronco, pernas, arma), com 4 direções,
animações (parado, andar, atacar) e cores por peça. Só biblioteca padrão.

  python3 ferramentas/ascii/personagem_ascii.py --folha            # imprime a folha de sprites em texto
  python3 ferramentas/ascii/personagem_ascii.py --html SAIDA.html  # prévia interativa colorida (direção, animação, classe)
  python3 ferramentas/ascii/personagem_ascii.py --jogar            # anda numa arena (terminal): setas, espaço ataca, c troca classe

Papéis de cor de cada caractere: h cabelo/elmo  s pele  e olhos  a armadura  t detalhes  p calça  b botas  w arma  c capa  x efeito
Para criar outro visual, acrescente uma entrada em CLASSES (cores e arma) ou novas peças em CABECA/TRONCO/PERNAS."""
import argparse
import json
import sys

LARG, ALT = 9, 6          # tela do sprite; o corpo ocupa as colunas 1..7
DIRECOES = ["frente", "costas", "direita", "esquerda"]
ANIMACOES = {"parado": 2, "andar": 4, "atacar": 3}

CLASSES = {
    "guerreiro": {"arma": "espada", "cores": {"h": "9aa4b2", "s": "e0a87c", "e": "fff3d6", "a": "6b7482", "t": "e0b84a", "p": "3d4250", "b": "6b4428", "w": "dfe8f2", "c": "a02828", "x": "ffffff"}},
    "ladino": {"arma": "espada", "cores": {"h": "6b4a34", "s": "e0a87c", "e": "fff3d6", "a": "4f8a46", "t": "a98448", "p": "5a4630", "b": "34281a", "w": "c8c8c8", "c": "35602f", "x": "e8ffd0"}},
    "mago": {"arma": "cajado", "cores": {"h": "8a4fc0", "s": "e0a87c", "e": "fff3d6", "a": "9a62d6", "t": "ffd84a", "p": "48347a", "b": "2c1f4a", "w": "7fe0ff", "c": "5a3a96", "x": "bff0ff"}},
}

# ---------- peças (7 caracteres de largura) ----------
CABECA = {
    "frente": ["  ▄▄▄  ", " ▐•‿•▌ "],
    "costas": ["  ▄▄▄  ", " ▐███▌ "],
    "direita": ["  ▄▄▄  ", " ▐█▌•  "],
}
TRONCO = {   # variantes: 0 normal, 1 braços balançando / respiração
    "frente": [[" ╔▓▓▓╗ ", "╱║▓▓▓║╲"], [" ╔▓▓▓╗ ", "║║▓▓▓║║"]],
    "costas": [[" ╔▒▒▒╗ ", "╱║▒▒▒║╲"], [" ╔▒▒▒╗ ", "║║▒▒▒║║"]],
    "direita": [["  ╔▓▓╗ ", "  ║▓▓║╲"], ["  ╔▓▓╗ ", "  ║▓▓║│"]],
}
PERNAS = {   # fases: 0 parado, 1 passo aberto, 2 parado, 3 passo fechado
    "frente": [["  ▐ ▌  ", " ▄█ █▄ "], [" ▐   ▌ ", "▄█   █▄"], ["  ▐ ▌  ", " ▄█ █▄ "], ["   █   ", "  ▄█▄  "]],
    "costas": [["  ▐ ▌  ", " ▄█ █▄ "], [" ▐   ▌ ", "▄█   █▄"], ["  ▐ ▌  ", " ▄█ █▄ "], ["   █   ", "  ▄█▄  "]],
    "direita": [["   █   ", "  ▄█▄▄ "], ["  ▐ ▌  ", " ▄█ ▙▄ "], ["   █   ", "  ▄█▄▄ "], ["   ▐▌  ", "  ▄▙▄  "]],
}
ESPELHO = str.maketrans("▐▌╱╲╔╗╟╢▙▟▶◀◢◣", "▌▐╲╱╗╔╢╟▟▙◀▶◣◢")

# ---------- armas: (linha, coluna, glifo, papel) sobre a tela 9x6 ----------
ESPADA = {
    "parado": [(1, 8, "▲"), (2, 8, "║"), (3, 8, "╫")],
    "atacar": [
        [(0, 8, "▲"), (1, 8, "║"), (2, 8, "╫")],
        [(2, 5, "░"), (2, 6, "▒"), (3, 4, "═"), (3, 5, "═"), (3, 6, "═"), (3, 7, "═"), (3, 8, "▶")],
        [(3, 8, "╫"), (4, 8, "║"), (5, 8, "▼"), (3, 6, "▒"), (3, 7, "░")]]}
CAJADO = {
    "parado": [(0, 8, "◉"), (1, 8, "│"), (2, 8, "│"), (3, 8, "│"), (4, 8, "│")],
    "atacar": [
        [(0, 8, "◉"), (1, 8, "│"), (2, 8, "│"), (3, 8, "│"), (4, 8, "│")],
        [(0, 8, "✺"), (1, 8, "│"), (2, 8, "│"), (3, 8, "│"), (4, 8, "│"), (1, 7, "░"), (0, 7, "▒")],
        [(0, 8, "◉"), (1, 8, "│"), (2, 8, "│"), (3, 8, "│"), (4, 8, "│"), (1, 7, "░")]]}


def papel(parte, linha, glifo, direcao):
    if glifo in "░▒▓" and parte == "arma":
        return "x"
    if parte == "cabeca":
        return "e" if glifo == "•" else ("s" if glifo == "‿" else "h")
    if parte == "tronco":
        if glifo == "▒":
            return "c"
        return "a" if glifo == "▓" else "t"
    if parte == "pernas":
        return "p" if linha == 0 else "b"
    return "w"


def quadro(direcao, anim, i, classe="guerreiro"):
    """Devolve (linhas de glifos, linhas de papéis) da tela 9x6 para a direção/animação/quadro."""
    espelhar = direcao == "esquerda"
    base = "direita" if espelhar else direcao
    glifos = [[" "] * LARG for _ in range(ALT)]
    papeis = [[" "] * LARG for _ in range(ALT)]

    def pôr(parte, linhas, topo):
        for dy, texto in enumerate(linhas):
            for dx, ch in enumerate(texto):
                if ch != " ":
                    glifos[topo + dy][1 + dx] = ch
                    papeis[topo + dy][1 + dx] = papel(parte, dy, ch, base)

    fase = {"parado": 0, "andar": [0, 1, 0, 3][i % 4], "atacar": 0}[anim]
    variante = {"parado": i % 2, "andar": (i // 2) % 2 if False else i % 2, "atacar": 1 if i == 1 else 0}[anim]
    pôr("cabeca", CABECA[base], 0)
    pôr("tronco", TRONCO[base][variante], 2)
    pôr("pernas", PERNAS[base][fase], 4)
    arma = ESPADA if CLASSES[classe]["arma"] == "espada" else CAJADO
    celulas = arma["atacar"][i % 3] if anim == "atacar" else arma["parado"]
    for y, x, ch in celulas:
        xx = (LARG - 1 - x) if base == "costas" else x   # nas costas a arma aparece do outro lado
        glifos[y][xx] = ch
        papeis[y][xx] = "x" if ch in "░▒▓·✺" else "w"
    linhas, rolos = ["".join(r) for r in glifos], ["".join(r) for r in papeis]
    if espelhar:
        linhas = ["".join(reversed(l)).translate(ESPELHO) for l in linhas]
        rolos = ["".join(reversed(l)) for l in rolos]
    return linhas, rolos


def folha():
    saida = []
    saida.append("PARADO (frente | costas | direita | esquerda)")
    quadros = [quadro(d, "parado", 0)[0] for d in DIRECOES]
    for y in range(ALT):
        saida.append("   ".join(q[y] for q in quadros))
    saida.append("")
    saida.append("ANDAR de frente (4 quadros)  |  ANDAR para a direita (4 quadros)")
    a = [quadro("frente", "andar", i)[0] for i in range(4)]
    b = [quadro("direita", "andar", i)[0] for i in range(4)]
    for y in range(ALT):
        saida.append("  ".join(q[y] for q in a) + "   |   " + "  ".join(q[y] for q in b))
    saida.append("")
    saida.append("ATACAR: guerreiro (frente, direita) e mago (frente, direita)")
    c = [quadro("frente", "atacar", i)[0] for i in range(3)] + [quadro("direita", "atacar", i)[0] for i in range(3)]
    m = [quadro("frente", "atacar", i, "mago")[0] for i in range(3)] + [quadro("direita", "atacar", i, "mago")[0] for i in range(3)]
    for y in range(ALT):
        saida.append(" ".join(q[y] for q in c))
    saida.append("")
    for y in range(ALT):
        saida.append(" ".join(q[y] for q in m))
    return "\n".join(saida)


def html(caminho):
    dados = {c: {d: {a: [[list(zip(l, r)) for l, r in zip(*quadro(d, a, i, c))] for i in range(n)] for a, n in ANIMACOES.items()} for d in DIRECOES} for c in CLASSES}
    cores = {c: v["cores"] for c, v in CLASSES.items()}
    pagina = """<!doctype html><html lang="pt-br"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Personagem ASCII</title><style>
body{margin:0;background:#0d0b10;color:#d9d2c3;font-family:system-ui,sans-serif;display:flex;flex-direction:column;align-items:center;padding:18px 12px;gap:14px}
h1{font-size:18px;margin:0;font-weight:600;letter-spacing:.04em}
#tela{background:#15121a;border:1px solid #3a3144;border-radius:10px;padding:22px 34px}
pre{margin:0;font-family:'DejaVu Sans Mono',Menlo,Consolas,monospace;font-size:34px;line-height:1.08;letter-spacing:0}
.linha{display:flex;gap:8px;flex-wrap:wrap;justify-content:center}
button{background:#241f2c;color:#d9d2c3;border:1px solid #4a4056;border-radius:8px;padding:7px 12px;font-size:14px;cursor:pointer}
button.on{background:#6b3f2a;border-color:#e0a060;color:#fff}
small{color:#8a8196}
#legenda{display:flex;gap:10px;flex-wrap:wrap;justify-content:center;font-size:12px}
#legenda span{display:inline-flex;align-items:center;gap:5px}
#legenda i{width:11px;height:11px;border-radius:3px;display:inline-block}
</style></head><body><h1>Personagem base · ASCII 9×6</h1><div id="tela"><pre id="sprite"></pre></div>
<div class="linha" id="classes"></div><div class="linha" id="direcoes"></div><div class="linha" id="animacoes"></div>
<div id="legenda"></div><small>Dica: no teclado, setas mudam a direção e a barra de espaço ataca.</small>
<script>
const DADOS=__DADOS__, CORES=__CORES__, NOMES={h:"cabelo/elmo",s:"pele",a:"armadura",t:"detalhes",p:"calça",b:"botas",w:"arma",c:"capa",x:"efeito"};
let classe="guerreiro", dir="frente", anim="andar", i=0, atrasoAtaque=0;
const vel={parado:520,andar:170,atacar:150};
function botoes(id,itens,atual,aoClicar){const el=document.getElementById(id);el.innerHTML="";itens.forEach(x=>{const b=document.createElement("button");b.textContent=x;if(x===atual)b.className="on";b.onclick=()=>{aoClicar(x);desenhar()};el.appendChild(b)})}
function desenhar(){
 botoes("classes",Object.keys(DADOS),classe,x=>classe=x);botoes("direcoes",["frente","costas","direita","esquerda"],dir,x=>dir=x);botoes("animacoes",["parado","andar","atacar"],anim,x=>{anim=x;i=0});
 document.getElementById("legenda").innerHTML=Object.keys(NOMES).map(k=>`<span><i style="background:#${CORES[classe][k]}"></i>${NOMES[k]}</span>`).join("");
}
function quadro(){
 const q=DADOS[classe][dir][anim];const f=q[i%q.length];
 document.getElementById("sprite").innerHTML=f.map(l=>l.map(([g,r])=>r===" "||g===" "?" ":`<span style="color:#${CORES[classe][r]}">${g}</span>`).join("")).join("\\n");
}
function laco(){quadro();i++;if(anim==="atacar"&&i>=3){i=0;anim="parado";desenhar()}setTimeout(laco,vel[anim])}
document.addEventListener("keydown",e=>{const m={ArrowUp:"costas",ArrowDown:"frente",ArrowLeft:"esquerda",ArrowRight:"direita"};
 if(m[e.key]){dir=m[e.key];anim="andar";desenhar();e.preventDefault()}else if(e.key===" "){anim="atacar";i=0;desenhar();e.preventDefault()}});
desenhar();laco();
</script></body></html>"""
    pagina = pagina.replace("__DADOS__", json.dumps(dados, ensure_ascii=False)).replace("__CORES__", json.dumps(cores))
    open(caminho, "w", encoding="utf-8").write(pagina)
    print("gravado:", caminho)


def jogar():
    import curses
    import locale
    import time
    locale.setlocale(locale.LC_ALL, "")

    def principal(tela):
        curses.curs_set(0)
        curses.start_color()
        curses.use_default_colors()
        tela.nodelay(True)
        ok256 = curses.COLORS >= 256

        def indice(hexa):
            r, g, b = (int(hexa[k:k + 2], 16) for k in (0, 2, 4))
            return 16 + 36 * round(r / 255 * 5) + 6 * round(g / 255 * 5) + round(b / 255 * 5)

        pares = {}

        def par(classe, papel_):
            chave = (classe, papel_)
            if chave not in pares:
                n = len(pares) + 1
                curses.init_pair(n, indice(CLASSES[classe]["cores"][papel_]) if ok256 else curses.COLOR_WHITE, -1)
                pares[chave] = curses.color_pair(n) | curses.A_BOLD
            return pares[chave]

        classe, direcao, x, y = "guerreiro", "frente", 30, 8
        anim, i, ultimo, ataque = "parado", 0, 0.0, -1
        while True:
            tecla = tela.getch()
            passo = {curses.KEY_UP: (0, -1, "costas"), curses.KEY_DOWN: (0, 1, "frente"), curses.KEY_RIGHT: (2, 0, "direita"), curses.KEY_LEFT: (-2, 0, "esquerda")}
            if tecla in (ord("q"), 27):
                break
            if tecla in passo and ataque < 0:
                dx, dy, direcao = passo[tecla]
                x, y, anim = x + dx, y + dy, "andar"
                i += 1
            elif tecla == ord(" ") and ataque < 0:
                ataque, anim = 0, "atacar"
                ultimo = time.time()
            elif tecla == ord("c"):
                nomes = list(CLASSES)
                classe = nomes[(nomes.index(classe) + 1) % len(nomes)]
            elif tecla == -1 and ataque < 0 and time.time() - ultimo > 0.25:
                anim, i = "parado", int(time.time() * 2) % 2
            if ataque >= 0 and time.time() - ultimo > 0.12:
                ataque += 1
                ultimo = time.time()
                if ataque >= 3:
                    ataque, anim = -1, "parado"
            altura, largura = tela.getmaxyx()
            x, y = max(0, min(largura - 12, x)), max(0, min(altura - 8, y))
            tela.erase()
            for yy in range(0, altura - 1):
                for xx in range(0, largura - 1, 4):
                    try:
                        tela.addstr(yy, xx, "·" if (xx // 4 + yy) % 3 else " ", curses.A_DIM)
                    except curses.error:
                        pass
            linhas, papeis = quadro(direcao, anim, ataque if ataque >= 0 else i, classe)
            for dy, (l, r) in enumerate(zip(linhas, papeis)):
                for dx, (g, p) in enumerate(zip(l, r)):
                    if g != " ":
                        try:
                            tela.addstr(y + dy, x + dx, g, par(classe, p))
                        except curses.error:
                            pass
            tela.addstr(altura - 1, 1, f" {classe}  | setas andam | espaço ataca | c troca classe | q sai "[:largura - 3])
            tela.refresh()
            time.sleep(0.03)

    curses.wrapper(principal)


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--folha", action="store_true", help="imprime a folha de sprites em texto")
    p.add_argument("--html", metavar="SAIDA", help="grava a prévia interativa em HTML")
    p.add_argument("--jogar", action="store_true", help="anda numa arena no terminal")
    a = p.parse_args()
    if a.folha:
        print(folha())
    if a.html:
        html(a.html)
    if a.jogar:
        jogar()
    if not (a.folha or a.html or a.jogar):
        p.print_help()


if __name__ == "__main__":
    main()
