# Goblin — reação de dano

Modelo canônico:modelo_base.png, câmera e roupa preservadas. Fonte gerada com image_gen integrado:ferido_tres_direcoes_v1.png; prompt integral em prompt_ferido.txt. Grade4×3, linhas direita/baixo/cima; esquerda espelha a direita por pedido anterior. Cada linha:impacto45ms, contração/recuo75ms, recuperação90ms, neutra90ms; total300ms, sem repetição. Sem sangue, ataque ou efeitos pintados. Cabeça acompanha ombros; mão livre protege o peito, mão direita mantém adaga abaixada.

Recurso final:células640, raiz(320,560), escala0,071, altura neutra próxima31px. Transformação comum500px por célula e deslocamento(70,94); nenhuma pose ajustada por contorno. Pés têm mesmo plano, transferência de peso e leve flexão no impacto.

Integração:receber_dano inicia imediatamente ferido_DIRECAO, trava orientação visual durante300ms e reinicia em novo impacto. Morte prevalece; guarda firme durante ataques leves mantém a regra existente de não interromper o combo. Quebra de postura cancela e mostra reação; congelamento conserva prioridade. Dano e colisões mantêm comportamento existente. Consumidores:goblin_pomar e goblin_adaga_visual; importador prepara os mesmos atlas para testes e prévias.
