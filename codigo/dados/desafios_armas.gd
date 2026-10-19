extends RefCounted

## Desafios liberam receitas. Após fabricar no Ivo, cada partida recebe uma cópia comum no nível 1.
const DESAFIOS := {
	"arco_curto": {"titulo": "PRIMEIROS DISPAROS", "texto": "Venca o andar 3 da arena.", "campo": "maior_onda_vencida", "meta": 3},
	"espada_gemea": {"titulo": "DOIS GUMES", "texto": "Venca o andar 5 da arena.", "campo": "maior_onda_vencida", "meta": 5},
	"maca": {"titulo": "ABRINDO CAMINHO", "texto": "Venca o andar 8 da arena.", "campo": "maior_onda_vencida", "meta": 8},
	"machado": {"titulo": "QUEBRA-GUARDA", "texto": "Derrote o guardiao do andar 10.", "campo": "checkpoint_max", "meta": 10},
	"arco_curvo": {"titulo": "MIRA PACIENTE", "texto": "Venca o andar 15 da arena.", "campo": "maior_onda_vencida", "meta": 15},
	"arco_longo": {"titulo": "TRES FLECHAS", "texto": "Derrote o guardiao do andar 20.", "campo": "checkpoint_max", "meta": 20},
}
