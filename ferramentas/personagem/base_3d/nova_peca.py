#!/usr/bin/env python3
"""Cadastra uma peça nova de roupa a partir de uma existente (mesma forma e estilo, outra cor e nome).

  python3 ferramentas/personagem/base_3d/nova_peca.py camisa camisa_bosque_vermelha "Camisa do bosque vermelha" \\
      --base camisa_bosque --cor a33b3b [--simular] [--gerar]

Acrescenta a entrada ao final da categoria em codigo/dados/roupas_base_3d.gd (IDs antigos nunca mudam). Com --gerar,
roda gerar_roupas_pixel.gd numa cópia de testes para criar a textura pixel da peça. Sem --gerar, o comando é só impresso.
Para novas cores SEM nova peça, basta acrescentar o hex à paleta do perfil em codigo/dados/variacao_npcs.gd.
Formas novas (modelagem diferente) continuam exigindo código em roupas_base_3d.gd."""
import argparse
import re
import subprocess
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[3]
CATALOGO = RAIZ / "codigo/dados/roupas_base_3d.gd"
CATEGORIAS = ["camisa", "calca", "calcado", "cabelo"]


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("categoria", choices=CATEGORIAS)
    p.add_argument("id", help="novo id permanente, minúsculas e sublinhado")
    p.add_argument("nome", help="nome mostrado ao jogador")
    p.add_argument("--base", required=True, help="id da peça existente que fornece forma e estilo")
    p.add_argument("--cor", required=True, help="cor do catálogo em hex, sem #")
    p.add_argument("--simular", action="store_true", help="só mostra a linha que seria inserida")
    p.add_argument("--gerar", action="store_true", help="gera a textura pixel depois de cadastrar")
    a = p.parse_args()
    if not re.fullmatch(r"[a-z][a-z0-9_]*", a.id):
        sys.exit("id inválido: use minúsculas, números e sublinhado")
    if not re.fullmatch(r"[0-9a-fA-F]{6}", a.cor):
        sys.exit("cor inválida: use 6 dígitos hex, sem #")
    texto = CATALOGO.read_text()
    if f'"id":"{a.id}"' in texto:
        sys.exit(f"o id {a.id} já existe no catálogo")
    inicio = texto.index(f'"{a.categoria}":[')
    fim = texto.index("]", inicio)
    bloco = texto[inicio:fim]
    base = re.search(r'\{"id":"%s"[^}]*\}' % re.escape(a.base), bloco)
    if not base:
        sys.exit(f"base {a.base} não encontrada em {a.categoria}")
    nova = re.sub(r'"id":"[^"]*"', f'"id":"{a.id}"', base.group(0), count=1)
    nova = re.sub(r'"nome":"[^"]*"', f'"nome":"{a.nome}"', nova, count=1)
    nova = re.sub(r'"cor":"[^"]*"', f'"cor":"{a.cor.lower()}"', nova, count=1)
    ultima = list(re.finditer(r'\{"id":"[^"]*"[^}]*\}', bloco))[-1]
    posicao = inicio + ultima.end()
    print("Nova entrada:", nova)
    if a.simular:
        return
    CATALOGO.write_text(texto[:posicao] + ",\n        " + nova + texto[posicao:])
    print("Catálogo atualizado:", CATALOGO.relative_to(RAIZ))
    comando = ["flatpak", "run", "org.godotengine.Godot", "--path", "/tmp/algoland-testes", "--script",
               "res://ferramentas/personagem/base_3d/gerar_roupas_pixel.gd"]
    if a.gerar:
        subprocess.run([sys.executable, str(RAIZ / "ferramentas/projeto/preparar_testes.py"), "/tmp/algoland-testes"], check=True)
        subprocess.run(comando, check=True)
    else:
        print("Para gerar a textura pixel:\n  python3 ferramentas/projeto/preparar_testes.py /tmp/algoland-testes\n  " + " ".join(comando))


if __name__ == "__main__":
    main()
