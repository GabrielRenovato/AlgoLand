extends RefCounted
## Ranking global. Com URL ou chave vazias o ranking fica desligado e o jogo segue normal.
## A chave é a "anon public" do Supabase: pode ir no jogo, pois a tabela só aceita as funções de pontuação e aparência autenticadas pelo código.
const URL := "https://mqaurdqxvpxoqccypqnh.supabase.co"
const CHAVE := "sb_publishable_9OBi-D1a5To2obqFqMW5QA_JzS8jzN0"

## Temporada nova exige save zerado; clientes antigos não podem enviar recordes legados.
const TEMPORADA := 1

## Servidor próprio de presença e chat (WebSocket). Vazio: usa o banco como antes. Pode ser trocado sem lançar versão
## por opcoes.cfg ([lobby] servidor="wss://...") ou, nos testes, por --lobby-ws=ws://127.0.0.1:PORTA.
const LOBBY_WS := ""

