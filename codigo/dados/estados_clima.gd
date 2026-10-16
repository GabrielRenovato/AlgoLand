extends RefCounted

## Índices persistidos no save da fazenda. Não reordenar nem reutilizar valores.
## Separados da renderização do clima para agendas e dados não dependerem dos autoloads.
enum Estado { LIMPO, NUBLADO, CHUVA_LEVE, CHUVA_FORTE, TEMPESTADE, NEVE_LEVE, NEVE_FORTE }
