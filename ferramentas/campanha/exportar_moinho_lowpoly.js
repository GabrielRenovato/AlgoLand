// Fonte reproduzível: converte a geometria da primeira prévia em peças exportáveis.
const fs=require('fs'),vm=require('vm'),path=require('path');
const root=path.resolve(__dirname,'../..');
const html=fs.readFileSync(path.join(root,'arte/previas/campanha/moinho_3d_interativo/previa-geometria-v1.html'),'utf8');
let code=html.split('<script>')[1].split('function project')[0];
// Aro com 20 segmentos; materiais planos e geometria sem texturas grandes.
code=code.replaceAll('i<32','i<20').replaceAll('i/32','i/20').replaceAll('(i+1)/32','(i+1)/20');
const scene=vm.runInNewContext(code+'\nwheel(0);JSON.stringify({fixed,moving});',{document:{getElementById:()=>({getContext:()=>({})})}});
fs.writeFileSync(path.join(root,'arte/fontes/campanha/moinho_lowpoly/geometria.json'),scene);
console.log('Geometria de origem exportada.');
