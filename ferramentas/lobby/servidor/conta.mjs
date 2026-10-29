// Confere o token de acesso da conta (Supabase Auth) perguntando ao próprio Auth quem é o dono: o servidor não guarda segredo nenhum.
// O resultado fica em cache por alguns minutos (por hash do token) para não consultar a cada conexão.
import { createHash } from 'node:crypto';

export function criarVerificadorConta({ url = '', chave = '', ttlMs = 300000, limite = 2000, buscar = globalThis.fetch } = {}) {
  const cache = new Map();
  const ativo = Boolean(url && chave);
  async function verificar(token) {
    if (!ativo || typeof token !== 'string' || token.length < 20 || token.length > 4096) return null;
    const hash = createHash('sha256').update(token, 'utf8').digest('hex');
    const guardado = cache.get(hash);
    if (guardado && guardado.ate > Date.now()) return guardado.id;
    try {
      const resposta = await buscar(`${url.replace(/\/+$/, '')}/auth/v1/user`, {
        headers: { apikey: chave, Authorization: `Bearer ${token}` },
        signal: AbortSignal.timeout(4000),
      });
      if (!resposta.ok) return null;
      const usuario = await resposta.json();
      if (typeof usuario?.id !== 'string' || usuario.id.length < 8) return null;
      if (cache.size >= limite) cache.delete(cache.keys().next().value);
      cache.set(hash, { id: usuario.id, ate: Date.now() + ttlMs });
      return usuario.id;
    } catch {
      return null;
    }
  }
  return { verificar, ativo, tamanhoCache: () => cache.size };
}
