#!/usr/bin/env python3
"""Cria a configuração e o roteiro de trabalho de um novo conjunto."""
import argparse
import json
from pathlib import Path
import re


def criar_modelo(identificador: str, nome: str, arte: str, pasta: Path, raridade: str) -> Path:
    if not re.fullmatch(r"[a-z][a-z0-9_]*", identificador):
        raise ValueError("O id deve começar por letra e conter apenas letras minúsculas, números e sublinhado.")
    if not nome.strip():
        raise ValueError("Informe o nome do conjunto.")
    if not arte.startswith("res://") or ".." in arte:
        raise ValueError("A referência deve apontar para um arquivo dentro do projeto.")
    if raridade not in ("comum", "incomum", "raro", "epico", "lendario"):
        raise ValueError("Raridade desconhecida.")
    origem = Path(__file__).parent / "modelos" / "carrasco.json"
    dados = json.loads(origem.read_text(encoding="utf-8"))
    dados.update(
        id=identificador,
        nome=nome,
        arte=arte,
        raridade=raridade,
        destino=f"res://CharacterSprites/Conjuntos/{identificador}/",
    )
    # O efeito do próximo set é uma decisão de design; o raio do Carrasco não é herdado por acidente.
    dados["bonus"] = {
        "tipo": "nenhum", "pecas": 4, "chance": 0.0,
        "recarga": 0.0, "multiplicador_dano": 0.0, "aviso": 0.0,
    }
    pasta.mkdir(parents=True, exist_ok=False)
    manifesto = pasta / "manifesto.json"
    manifesto.write_text(json.dumps(dados, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    prompt = (Path(__file__).parent / "modelos" / "prompt_conceito.txt").read_text(encoding="utf-8")
    (pasta / "prompt_conceito.txt").write_text(prompt.replace("{NOME}", nome), encoding="utf-8")
    (pasta / "LEIAME.md").write_text(
        f"# Conjunto {nome}\n\n"
        "Este modelo está em preparação. Ajuste a paleta, os recortes, os status, "
        "as chances e o bônus em manifesto.json. Aponte arte para o conceito aprovado.\n\n"
        "Gere as folhas com ferramentas/armaduras/gerar_conjunto.gd e valide com "
        "ferramentas/armaduras/validar_conjunto.gd, passando o caminho do manifesto após --.\n\n"
        "A geração também produz definicao.gd. O cadastro no jogo e qualquer efeito novo "
        "seguem ferramentas/armaduras/PADRAO.md; criar este modelo não adiciona itens aos drops.\n",
        encoding="utf-8",
    )
    return manifesto


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--id", required=True)
    parser.add_argument("--nome", required=True)
    parser.add_argument("--arte", required=True, help="Caminho res:// do conceito de quatro vistas.")
    parser.add_argument("--raridade", default="lendario", choices=["comum", "incomum", "raro", "epico", "lendario"])
    parser.add_argument("--pasta", type=Path, help="Pasta nova para o manifesto e o prompt.")
    argumentos = parser.parse_args()
    pasta = argumentos.pasta or Path(__file__).parent / "em_preparacao" / argumentos.id
    try:
        manifesto = criar_modelo(argumentos.id, argumentos.nome, argumentos.arte, pasta, argumentos.raridade)
    except (ValueError, FileExistsError) as erro:
        parser.error(str(erro))
    print(f"Modelo criado: {manifesto}")


if __name__ == "__main__":
    main()
