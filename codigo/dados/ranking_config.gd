extends RefCounted
## Ranking global. Com URL ou chave vazias o ranking fica desligado e o jogo segue normal.
## A chave é a "anon public" do Supabase: pode ir no jogo, pois a tabela só aceita as funções de pontuação e aparência autenticadas pelo código.
const URL := "https://mqaurdqxvpxoqccypqnh.supabase.co"
const CHAVE := "sb_publishable_9OBi-D1a5To2obqFqMW5QA_JzS8jzN0"

## Temporada nova exige save zerado; clientes antigos não podem enviar recordes legados.
const TEMPORADA := 1
