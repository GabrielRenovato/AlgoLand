// Navegador descartável: não usa sessões ou saves pessoais.
import { parseArgs } from 'node:util';
import { resolve, join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { mkdir, writeFile } from 'node:fs/promises';
const { values: args } = parseArgs({ options: {
  wiki: { type: 'string' }, url: { type: 'string' }, saida: { type: 'string' },
} });
if (!args.wiki || !args.url || !args.saida) throw new Error('Use --wiki PASTA --url URL --saida PASTA');
const { chromium } = await import(pathToFileURL(resolve(args.wiki, 'node_modules/playwright/index.mjs')));
const saida = resolve(args.saida);
await mkdir(saida, { recursive: true });
const browser = await chromium.launch({ headless: true, args: ['--enable-webgl', '--use-angle=gl', '--ignore-gpu-blocklist'] });
const erros = [], capturas = [];
try {
  const contexto = await browser.newContext({ viewport: { width: 1280, height: 576 },
    deviceScaleFactor: 1, isMobile: true, hasTouch: true,
    userAgent: 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Mobile Safari/537.36' });
  const page = await contexto.newPage();
  page.on('pageerror', e => erros.push(e.message));
  page.on('console', m => { if (m.type() === 'error') erros.push(m.text()); });
  await page.goto(args.url, { waitUntil: 'load', timeout: 30000 });
  await page.locator('#jogar').waitFor({ state: 'visible', timeout: 120000 });
  await page.locator('#jogar').click();
  await page.waitForTimeout(10000);
  // A tela de conta de uma sessão nova abre sem foco no celular.
  await page.touchscreen.tap(500, 170);
  await page.waitForTimeout(500);
  await page.keyboard.type('teste@exemplo.com');
  const teclado = await page.locator('input').evaluateAll(es => es.map(e => ({ tipo: e.type, valor: e.value })));
  if (!teclado.some(t => t.tipo === 'text' && t.valor === 'teste@exemplo.com')) erros.push('Campo de e-mail não recebeu a digitação');
  const foto = async nome => { const p = join(saida, nome + '.png'); await page.screenshot({ path: p }); capturas.push(p); };
  await foto('web-paisagem');
  await page.evaluate(async () => { if (document.fullscreenElement) await document.exitFullscreen(); });
  await page.waitForTimeout(500);
  for (const [nome, width, height] of [['web-retrato', 576, 1024], ['web-retorno', 1280, 576]]) {
    await page.setViewportSize({ width, height });
    await page.waitForTimeout(2000);
    await foto(nome);
  }
  await writeFile(join(saida, 'browser.json'), JSON.stringify({ erros, teclado, capturas, revisao_visual: 'pendente' }, null, 2));
  for (const e of erros) console.error('FALHA ' + e);
  if (erros.length) process.exitCode = 1;
  else console.log('OK navegador: digitação e rotação; revisão visual pendente');
} catch (erro) {
  erros.push(erro instanceof Error ? erro.message : String(erro));
  await writeFile(join(saida, 'browser.json'), JSON.stringify({ erros, capturas, revisao_visual: 'pendente' }, null, 2));
  console.error('FALHA navegador: ' + erros.at(-1).split('\n')[0]);
  process.exitCode = 1;
} finally {
  await browser.close();
}
