"""Compara as nove poses no mesmo instante, sem alterar a arte dos membros."""

from pathlib import Path
import subprocess
import tempfile


RAIZ = Path(__file__).resolve().parents[2]
FONTES = RAIZ / "arte/fontes/personagens/exemplo_alta_qualidade/ataque_espada"
SAIDA = RAIZ / "arte/previas/personagens/exemplo_alta_qualidade/ataque_direita"


def executar(*argumentos):
    subprocess.run(["magick", *map(str, argumentos)], check=True)


def main():
    fonte = subprocess.check_output(["fc-match", "-f", "%{file}", "sans-serif"], text=True).strip()
    with tempfile.TemporaryDirectory(prefix="algoland-comparacao-jab-") as pasta:
        temporarios = Path(pasta)
        executar(FONTES / "referencia_link_jab.gif", "-coalesce", temporarios / "referencia_%02d.png")
        pares = []
        for indice in range(9):
            referencia = temporarios / f"referencia_{indice:02d}.png"
            exemplo = temporarios / f"exemplo_{indice:02d}.png"
            nosso = temporarios / f"nosso_{indice:02d}.png"
            par = SAIDA / f"comparacao_{indice:02d}.png"
            executar(
                "-size", "640x640", "xc:white", "(", referencia,
                "-filter", "point", "-resize", "110%", ")", "-geometry", "+10+174",
                "-compose", "Over", "-composite", "-font", fonte,
                "-fill", "#20252a", "-pointsize", "24", "-gravity", "North",
                "-annotate", "+0+32", f"EXEMPLO — {indice + 1}/9", exemplo,
            )
            executar(
                "-size", "640x640", "xc:white", SAIDA / f"pose_{indice}.png",
                "-compose", "Over", "-composite", "-font", fonte,
                "-fill", "#20252a", "-pointsize", "24", "-gravity", "North",
                "-annotate", "+0+32", f"NOSSO — {indice + 1}/9", nosso,
            )
            executar(exemplo, nosso, "+append", par)
            pares.append(par)
        executar("-delay", "8", "-loop", "0", *pares, SAIDA / "comparacao_lado_a_lado.gif")
        executar("montage", *pares, "-resize", "50%", "-tile", "3x3", "-geometry", "+2+2", SAIDA / "comparacao_nove_quadros.png")
    print("Comparação: nove pares, mesma escala aparente, apoio alinhado e 80 ms por quadro.")


if __name__ == "__main__":
    main()
