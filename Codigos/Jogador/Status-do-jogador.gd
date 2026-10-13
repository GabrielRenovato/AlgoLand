# EstatisticasJogador.gd
# ====================
# Esta classe calcula os atributos derivados (HP, dano, crítico, etc.) a partir dos atributos básicos.
# A defesa não é derivada: vem de Jogador.bonus_defesa (armaduras, escudo e itens da loja).

class_name EstatisticasJogador

# Atributos básicos
var forca: int = 5
var agilidade: int = 5
var bonus_vitalidade_conjunto := 0.0
var _vitalidade_sem_conjunto := 5
var vitalidade: int:
	get:
		return roundi(_vitalidade_sem_conjunto * (1.0 + bonus_vitalidade_conjunto))
	set(valor):
		_vitalidade_sem_conjunto = valor
var inteligencia: int = 5
var sorte: int = 5
var roubo_vida: int = 0

# Atributos de movimento
var velocidade_base_movimento: float = 114.0  # Velocidade base sem bônus
var bonus_velocidade_item: float = 0.0   # Bônus de velocidade adquirido via itens
## Afixos da raridade dos equipamentos (Raridades.AFIXOS): somam ao crítico base, que vem da sorte
var bonus_critico: float = 0.0
var bonus_dano_critico: float = 0.0
var velocidade_movimento: float = velocidade_base_movimento

# Atributos derivados
var hp_maximo: int
var dano_ataque: int
var chance_critico: float
var dano_critico: float
var bonus_defesa_conjunto := 0.0
var _defesa_sem_conjunto := 0
var defesa: int:
	get:
		return roundi(_defesa_sem_conjunto * (1.0 + bonus_defesa_conjunto))
	set(valor):
		_defesa_sem_conjunto = valor
var dano_arma: int = 0

const K_DEFESA: float = 50.0
const REDUCAO_MAXIMA: float = 0.75
const ROUBO_VIDA_MAXIMO: int = 30
const VELOCIDADE_MAXIMA: float = 180.0

func calcular_estatisticas_derivadas(_arma_equipada: bool = false):
	# Melhorias permanentes (Progresso): vigor aumenta a vida máxima e força o dano
	hp_maximo = roundi((40 + vitalidade * 6) * (1.0 + Progresso.bonus("vigor")))
	dano_ataque = roundi((dano_arma + forca) * (1.0 + Progresso.bonus("forca")))
	chance_critico = clamp(0.05 + sorte * 0.01 + bonus_critico, 0.0, 0.6)
	dano_critico = 1.5 + sorte * 0.02 + bonus_dano_critico
	velocidade_movimento = min(velocidade_base_movimento + bonus_velocidade_item + agilidade * 1.5, VELOCIDADE_MAXIMA)
	# defesa não é recalculada aqui: vem de Jogador.bonus_defesa (armaduras/escudo/loja)

func reducao_dano() -> float:
	# A couraça (Progresso) soma por fora da fórmula de defesa
	return min(float(defesa) / (float(defesa) + K_DEFESA) + Progresso.bonus("couraca"), REDUCAO_MAXIMA)

func calcular_dano_golpe() -> Dictionary:
	var critico: bool = randf() < chance_critico
	var valor: float = float(dano_ataque) * randf_range(0.9, 1.1)
	if critico:
		valor *= dano_critico
	return {"dano": max(1, int(round(valor))), "critico": critico}

# Função para adicionar bônus de velocidade sem zerar valores anteriores
func adicionar_bonus_velocidade(quantidade: float, arma_equipada: bool = false) -> void:
	bonus_velocidade_item += quantidade
	calcular_estatisticas_derivadas(arma_equipada)
