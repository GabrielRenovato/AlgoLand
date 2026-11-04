#!/usr/bin/env python3
"""Descobre e executa todos os testes do jogo com saves e capturas isolados."""
import argparse
import json
from pathlib import Path
import re
import shutil
import sys
import tempfile
import uuid

from preparar_testes import preparar
from testar_coop import ARGUMENTOS_TESTES, ERROS_ESPERADOS, executar

RAIZ = Path(__file__).resolve().parents[2]
GRAFICOS = {"lote_mixamo_3d", "corrida_mixamo_3d", "ferramentas_kaykit_3d", "natureza_fazenda", "acabamento_cidade", "chao_detalhado", "ponte_cidade", "urbanismo_cidade", "enfeites_detalhados", "nitidez_exteriores", "botoes_carta", "cama_raven", "entrada_portal", "f3_equipar_conjuntos", "previa_inventario_raven", "catalogo_armas_raven", "rotina_aves", "painel_debug", "obra_carpinteiro","atendimento_cidade", "dialogo_cidade", "familia_carpinteiro", "casa_carpinteiro", "galinheiro", "relevo_gentle", "enseada_visual", "mapa_mundi", "fazenda_tiny", "sobreposicao_cais", "pegadas_praia", "rotas_visuais", "barra_energia", "continuidade_caverna"}
GRAFICOS.update({"interface_campanha", "maestria_combate", "maestria_coop", "drops_iniciais_visual", "instancias_campanha"})
GRAFICOS.add("goblins_pomar")
# Os dois abrem a vila da campanha com janela; sem tela encerram logo no início.
GRAFICOS.update({"vila_defesa", "vila_missoes"})
GRAFICOS.add("colisao_mobs_player")
GRAFICOS.add("moinho_mobile")
GRAFICOS.add("fluidez_medusa")
GRAFICOS.add("camadas_magias_medusa")
GRAFICOS.add("fontes_web")
GRAFICOS.add("moradores_primeira_raiz")
GRAFICOS.add("historia_goblins")
GRAFICOS.add("guarda_novato_3d")
GRAFICOS.add("movimentos_npcs")
GRAFICOS.add("manequim_infantil_3d")
GRAFICOS.add("vestuario_infantil_3d")
GRAFICOS.add("casas_familias")
GRAFICOS.add("mapas_modulares")
GRAFICOS.add("campanha_pesca_social")
GRAFICOS.add("bacia_moinho")
GRAFICOS.add("entrada_dungeon_visual")
GRAFICOS.add("estrada_carreteiros")
GRAFICOS.add("monstro_raizes")
GRAFICOS.add("cerne_partido")
GRAFICOS.add("salas_campanha")
GRAFICOS.update({"percurso_campanha", "mapas_campanha"})
GRAFICOS.update({"marcadores_missao", "alinhamento_chat_marcador", "gerador_npcs_3d", "roupas_base_3d", "tintura_cabelo_3d", "pelos_faciais_npcs"})


def liberar(saida, tmp_antes, texto_teste=""):
    """Apaga o que o teste que acabou de terminar gravou (saves, cache do Godot, capturas), mantendo só o log."""
    shutil.rmtree(saida / "dados", ignore_errors=True)
    previas = saida / "projeto" / "arte" / "previas"
    if previas.is_dir():
        for item in previas.iterdir():
            shutil.rmtree(item, ignore_errors=True) if item.is_dir() else item.unlink(missing_ok=True)
    # Só o que este teste escreve em /tmp: outra sessão pode estar usando outras pastas algoland-*.
    for novo in set(Path("/tmp").glob("algoland-*")) - tmp_antes:
        if novo.name.split("-")[0] + "-" + novo.name.split("-")[1] not in texto_teste: continue
        shutil.rmtree(novo, ignore_errors=True) if novo.is_dir() and not novo.is_symlink() else novo.unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--listar", action="store_true")
    parser.add_argument("--teste", action="append", help="Nome sem teste_ e sem extensão; repita para selecionar.")
    parser.add_argument("--aproveitar", action="append", type=Path, default=[], help="Relatório desta mesma revisão; evita repetir testes já executados.")
    parser.add_argument("--saida", type=Path)
    parser.add_argument("--limite", type=int, default=180)
    args = parser.parse_args()
    testes = {p.stem.removeprefix("teste_"): p for p in sorted((RAIZ / "testes").glob("teste*")) if p.suffix in {".gd", ".py"}}
    if args.teste:
        if set(args.teste) - testes.keys():
            parser.error("Testes desconhecidos: " + ", ".join(sorted(set(args.teste) - testes.keys())))
        testes = {n: p for n, p in testes.items() if n in args.teste}
    if args.listar:
        for nome, caminho in testes.items():
            print(nome + (" (gráfico)" if nome in GRAFICOS else "") + " " + caminho.suffix)
        return 0
    if args.limite <= 0:
        parser.error("--limite deve ser positivo")
    anteriores = {}
    for caminho in args.aproveitar:
        for resultado in json.loads(caminho.read_text())["testes"]:
            anteriores[resultado["nome"]] = dict(resultado, reaproveitado_de=str(caminho.resolve()))
    # /tmp é tmpfs (RAM) nesta máquina: a saída padrão fica no disco.
    cache = Path.home() / ".cache"
    cache.mkdir(parents=True, exist_ok=True)
    saida = args.saida.resolve() if args.saida else Path(tempfile.mkdtemp(prefix="algoland-tudo-", dir=cache))
    saida.mkdir(parents=True, exist_ok=True)
    if list(saida.iterdir()):
        parser.error("--saida precisa ser uma pasta vazia")
    projeto = preparar(saida / "projeto")
    # As capturas não podem atravessar os links e sobrescrever prévias do usuário.
    arte = projeto / "arte"
    arte.unlink()
    arte.mkdir()
    for origem in (RAIZ / "arte").iterdir():
        if origem.name != "previas":
            (arte / origem.name).symlink_to(origem, target_is_directory=origem.is_dir())
    (arte / "previas").mkdir()
    base = re.sub(r'^config/(?:use_custom_user_dir|custom_user_dir_name)=.*\n', '', (projeto / "project.godot").read_text(), flags=re.M)
    identificador = uuid.uuid4().hex

    def isolar(nome):
        prefixo = "AlgoLand testes "
        if nome in {"comercio", "comercio_coop", "animacao_carroca"}:
            prefixo += "carroca "
        elif nome == "fazenda_tiny":
            prefixo += "fazenda tiny "
        diretorio = prefixo + identificador + " " + nome
        caminho_teste = testes.get(nome)
        if caminho_teste and 'ends_with("AlgoLand testes Carrasco")' in caminho_teste.read_text():
            diretorio += "/AlgoLand testes Carrasco"
        if nome == "rotina_praia":
            diretorio = "AlgoLand testes praia 20261016"
        config = base.replace("[application]", '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="' + diretorio + '"', 1)
        (projeto / "project.godot").write_text(config)

    godot = shutil.which("godot") or shutil.which("godot4")
    # Isola também o teste legado que exige um nome de save exato.
    dados = str(saida / "dados")
    motor = ["env", "XDG_DATA_HOME=" + dados, godot] if godot else ["flatpak", "run", "--filesystem=" + str(saida), "--command=env", "org.godotengine.Godot", "XDG_DATA_HOME=" + dados, "godot"]
    isolar("importacao")
    print("Logs e relatório: " + str(saida), flush=True)
    importacao = executar(motor + ["--headless", "--editor", "--path", str(projeto), "--import", "--quit"], saida / "importacao.log", max(180, args.limite))
    relatorio = {"escopo": "Todos os scripts teste*.gd e teste*.py disponíveis; não certifica funcionalidades sem testes nem substitui revisão visual/manual.", "importacao": importacao, "selecionados": list(testes), "testes": []}
    (saida / "relatorio.json").write_text(json.dumps(relatorio, ensure_ascii=False, indent=2) + "\n")
    if importacao["aprovado"]:
        for nome, caminho in testes.items():
            if nome in anteriores:
                resultado = anteriores[nome]
            else:
                isolar(nome)
                if caminho.suffix == ".py":
                    comando = [sys.executable, str(caminho)]
                else:
                    comando = motor + ([] if nome in GRAFICOS else ["--headless"]) + ["--path", str(projeto), "--script", "res://testes/" + caminho.name]
                    if nome in ARGUMENTOS_TESTES:
                        comando += ["--"] + ARGUMENTOS_TESTES[nome]
                tmp_antes = set(Path("/tmp").glob("algoland-*"))
                resultado = executar(comando, saida / (nome + ".log"), args.limite, ERROS_ESPERADOS.get(nome, ()))
                liberar(saida, tmp_antes, caminho.read_text(errors="replace"))
                resultado.update(nome=nome, modo="python" if caminho.suffix == ".py" else "grafico" if nome in GRAFICOS else "headless")
            relatorio["testes"].append(resultado)
            relatorio["falhas"] = sum(not r["aprovado"] for r in relatorio["testes"])
            (saida / "relatorio.json").write_text(json.dumps(relatorio, ensure_ascii=False, indent=2) + "\n")
            print(("OK " if resultado["aprovado"] else "FALHA ") + nome + (" (reaproveitado)" if nome in anteriores else " (%.1fs)" % resultado["segundos"]), flush=True)
            for erro in resultado["erros"][:3]:
                print("  " + erro, flush=True)
    relatorio["falhas"] = sum(not r["aprovado"] for r in relatorio["testes"]) + int(not importacao["aprovado"])
    # Ao fim só ficam os logs e o relatório: a cópia do projeto e os dados vão embora.
    shutil.rmtree(saida / "dados", ignore_errors=True)
    shutil.rmtree(projeto, ignore_errors=True)
    relatorio["aprovado"] = relatorio["falhas"] == 0 and len(relatorio["testes"]) == len(testes)
    (saida / "relatorio.json").write_text(json.dumps(relatorio, ensure_ascii=False, indent=2) + "\n")
    print("%d testes; %d falhas. Relatório: %s" % (len(relatorio["testes"]), relatorio["falhas"], saida / "relatorio.json"))
    return 0 if relatorio["aprovado"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
