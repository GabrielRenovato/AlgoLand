#!/usr/bin/env python3
"""PreToolUse (Bash): bloqueia comandos destrutivos mesmo quando as permissões deixariam passar.

Recebe o JSON do Claude Code em stdin. Sai com código 2 e mensagem em stderr para bloquear.
"""
import json
import re
import sys

PROTEGIDOS = r"(arte|assets|arquivo|builds|\.godot|\.git|\.claude|testes|ferramentas|codigo|cenas|recursos|docs)"
REGRAS = [
    (rf"\brm\b[^|;&]*\s(-[a-zA-Z]*r[a-zA-Z]*|-[a-zA-Z]*f[a-zA-Z]*)\b", "rm recursivo ou forçado: remova arquivos específicos, um por vez"),
    (rf"\brm\b[^|;&]*(?<![\w/.-]){PROTEGIDOS}(/|\s|$)", "remoção dentro de pasta protegida do projeto"),
    (r"\brm\b[^|;&]*(app_userdata|user://|\.local/share/godot)", "remoção de saves (user://)"),
    (r"\bgit\b[^|;&]*\breset\b[^|;&]*--hard", "git reset --hard descarta mudanças locais"),
    (r"\bgit\b[^|;&]*\bclean\b", "git clean apaga arquivos não rastreados"),
    (r"\bgit\b[^|;&]*\bpush\b[^|;&]*(--force|\s-f(\s|$)|--force-with-lease)", "push forçado reescreve o remoto"),
    (r"\bgit\b[^|;&]*\bremote\b[^|;&]*\b(set-url|add|remove|rm|rename)\b", "troca de remote precisa de autorização explícita"),
    (r"\bgit\b[^|;&]*\bfilter-repo\b", "filter-repo reescreve o histórico"),
    (r"\b(pkill|pgrep)\b[^|;&]*\s-[a-zA-Z]*f", "pkill/pgrep -f casa pelo texto do próprio comando e pode derrubar o shell: use PID"),
    (r"\bkillall\b", "killall mata por nome: use PID"),
]


def main() -> int:
    try:
        entrada = json.load(sys.stdin)
    except json.JSONDecodeError:
        return 0
    if entrada.get("tool_name") != "Bash":
        return 0
    comando = entrada.get("tool_input", {}).get("command", "")
    for padrao, motivo in REGRAS:
        if re.search(padrao, comando):
            print(f"Bloqueado pelo harness: {motivo}. Comando: {comando}", file=sys.stderr)
            return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
