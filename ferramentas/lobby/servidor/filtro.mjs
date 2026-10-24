// Mesmo filtro de apelidos e mensagens do banco (ferramentas/ranking/supabase.sql::apelido_proibido).
const TERMOS = ['caralho','pora','buceta','foder','fodase','fodido','puta','merda','viado','arombado','cuzao',
  'cuzinho','punheta','xereca','piroca','cacete','estupr','pedofil','nazi','hitler','fuck','shit',
  'bitch','cunt','nigga','fagot','ashole','whore','slut','porn','sexo','pussy','dick'];
const CURTOS = new Set(['cu','pau','rola','pica','xota','cock','niga','niger','mongol','retardado','fdp','pqp','vsf','vtnc','tnc','bosta']);
const TROCAS = { '0': 'o', '1': 'i', '3': 'e', '4': 'a', '5': 's', '7': 't', '8': 'b' };

export function normalizar(texto) {
  let t = String(texto).toLowerCase().replace(/[0134578]/g, (c) => TROCAS[c] ?? c);
  t = t.replace(/[^a-z]/g, '').replace(/(.)\1+/g, '$1');
  return t;
}

export function proibido(texto) {
  const t = normalizar(texto);
  return TERMOS.some((termo) => t.includes(termo)) || CURTOS.has(t);
}

export function limparApelido(bruto) {
  const limpo = String(bruto ?? '').replace(/[\u0000-\u001f\u007f-\u009f]/g, '').trim().slice(0, 16);
  return limpo === '' || proibido(limpo) ? 'sem apelido' : limpo;
}

export function limparTexto(bruto) {
  return String(bruto ?? '').replace(/[\u0000-\u001f\u007f-\u009f]/g, ' ').trim().slice(0, 160);
}
