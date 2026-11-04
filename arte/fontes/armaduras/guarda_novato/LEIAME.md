# Guarda Novato — Noel

Referência do usuário preservada em `referencia_usuario.png`. Modelagem nativa por código no rig canônico, com quatro peças separadas e acabamento pixel art do jogo. A abertura central deixa o rosto original visível; o cabelo fica sob a calota. É o uniforme visual de Noel, sem alterar inventário, atributos ou drops.

Manifesto: `ferramentas/armaduras/em_preparacao/guarda_novato/manifesto.json`.

Gerar e validar pelo pipeline compartilhado em projeto isolado:

```
godot --headless --path <projeto-isolado> --script res://ferramentas/armaduras/gerar_conjunto.gd -- res://ferramentas/armaduras/em_preparacao/guarda_novato/manifesto.json --base-3d
godot --headless --path <projeto-isolado> --script res://ferramentas/armaduras/validar_conjunto.gd -- res://ferramentas/armaduras/em_preparacao/guarda_novato/manifesto.json --base-3d
python3 ferramentas/projeto/harness.py testar --perfil selecionado --teste guarda_novato_3d --teste gerador_npcs_3d --teste moradores_primeira_raiz
python3 ferramentas/armaduras/exportar_guarda_novato_3d.py <capturas-guarda-novato>
```

As capturas saem da renderização real no Godot. A folha de contato e o GIF apenas montam os mesmos quadros, sem retocar os recursos. Caminhada nativa de 1,333 s, oito amostras por direção; máscaras 0–15, idle e poses das ações também são revisadas. Prévia na oficina: selecionar Noel em Morador da cidade; Parado / andando alterna a caminhada; Ver corpo / vestir recolhe ou restaura as peças.
