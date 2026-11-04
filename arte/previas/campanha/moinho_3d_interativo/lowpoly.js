/* Prévia WebGL do mesmo modelo exportado como GLB. Three.js r160, licença MIT. */
const scene = new THREE.Scene();
scene.background = new THREE.Color('#b7c6bd');
scene.fog = new THREE.Fog('#b7c6bd', 24, 55);
const renderer = new THREE.WebGLRenderer({antialias:true, preserveDrawingBuffer:true});
renderer.setPixelRatio(Math.min(devicePixelRatio,2));
renderer.shadowMap.enabled=true;renderer.shadowMap.type=THREE.PCFSoftShadowMap;
renderer.outputColorSpace=THREE.SRGBColorSpace;renderer.toneMapping=THREE.ACESFilmicToneMapping;renderer.toneMappingExposure=1.15;
document.body.prepend(renderer.domElement);
const camera = new THREE.PerspectiveCamera(36,1,.1,70);
let yaw=-.83,pitch=.46,distance=13.3,paused=false,time=0,angle=0,flow=1,season=0,pixelArt=true;
const target=new THREE.Vector3(-.25,1.85,.1);
scene.add(new THREE.HemisphereLight('#b5d3eb','#60503a',1.15));
const sun=new THREE.DirectionalLight('#ffe2ac',3.4);sun.position.set(-6,10,6);sun.castShadow=true;
sun.shadow.mapSize.set(2048,2048);Object.assign(sun.shadow.camera,{left:-7,right:7,top:8,bottom:-6,near:1,far:25});sun.shadow.bias=-.0004;sun.shadow.normalBias=.035;scene.add(sun);
const floor=new THREE.Mesh(new THREE.PlaneGeometry(200,200),new THREE.MeshStandardMaterial({color:'#9cae99',roughness:1}));floor.rotation.x=-Math.PI/2;floor.position.y=-.47;floor.receiveShadow=true;scene.add(floor);
const materials=new Map(),baseColors=new Map();
function geometry(faces,pivot){const positions=[],colors=[];for(const f of faces)for(let i=1;i<f.points.length-1;i++)for(const p of [f.points[0],f.points[i],f.points[i+1]]){positions.push(p[0]-pivot[0],p[1]-pivot[1],p[2]-pivot[2]);let ao=1-.20*Math.exp(-Math.max(p[1],0)*1.6);if(pivot[0]!==0)ao*=.82+.18*Math.min(Math.hypot(p[1]-pivot[1],p[2]-pivot[2])/1.1,1);ao*=.97+.03*Math.sin(p[0]*5.1+p[2]*7.3);colors.push(ao*.97,ao*.985,ao);}const g=new THREE.BufferGeometry();g.setAttribute('position',new THREE.Float32BufferAttribute(positions,3));g.setAttribute('color',new THREE.Float32BufferAttribute(colors,3));g.computeVertexNormals();return g;}
function groupFaces(faces,pivot){const root=new THREE.Group(),groups=new Map();for(const f of faces){if(!groups.has(f.color))groups.set(f.color,[]);groups.get(f.color).push(f);}for(const [color,items]of groups){let material=materials.get(color);if(!material){material=new THREE.MeshStandardMaterial({color,roughness:.84,vertexColors:true,flatShading:true,side:THREE.DoubleSide});materials.set(color,material);baseColors.set(color,new THREE.Color(color));}const mesh=new THREE.Mesh(geometry(items,pivot),material);mesh.castShadow=true;mesh.receiveShadow=true;root.add(mesh);}return root;}
const structure=groupFaces(MODEL.fixed,[0,0,0]);scene.add(structure);
const wheel=groupFaces(MODEL.moving,[-2.86,1.55,.2]);wheel.position.set(-2.86,1.55,.2);scene.add(wheel);
const targetRT=new THREE.WebGLRenderTarget(1,1,{minFilter:THREE.LinearFilter,magFilter:THREE.LinearFilter});targetRT.depthTexture=new THREE.DepthTexture(1,1,THREE.UnsignedIntType);
const uniforms={tempo:{value:0},fluxo:{value:1},fundo:{value:targetRT.texture},profundidade:{value:targetRT.depthTexture},resolucao:{value:new THREE.Vector2()},perto:{value:.1},longe:{value:70},frio:{value:0}};
const vertex=`uniform float tempo; uniform float fluxo; varying vec3 mundo; varying vec2 textura;
void main(){vec3 p=position; textura=uv; float a=sin(p.x*13.+tempo*1.7)*cos(p.y*9.-tempo*2.5)*.009; p.z+=a;vec4 w=modelMatrix*vec4(p,1.);mundo=w.xyz;gl_Position=projectionMatrix*viewMatrix*w;}`;
const common=`uniform float tempo;uniform float fluxo;uniform float frio; varying vec3 mundo;varying vec2 textura;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
float waves(vec2 p){return sin(p.x*10.+p.y*6.-tempo*2.1)*.4+sin(p.y*17.-p.x*5.-tempo*3.3)*.22+noise(p*13.+vec2(0.,-tempo*1.4))*.2;}
`;
const surface=new THREE.ShaderMaterial({uniforms,vertexShader:vertex,fragmentShader:common+`
uniform sampler2D fundo;uniform sampler2D profundidade;uniform vec2 resolucao;uniform float perto;uniform float longe;
float linearDepth(float d){return (perto*longe)/(longe-d*(longe-perto));}
void main(){vec2 uv=gl_FragCoord.xy/resolucao;vec2 p=mundo.xz;float e=.013;
vec3 n=normalize(vec3((waves(p-vec2(e,0))-waves(p+vec2(e,0)))*.55,1.,(waves(p-vec2(0,e))-waves(p+vec2(0,e)))*.55));
float dist=length(p-vec2(-2.78,-.3));float ripple=sin(dist*33.-tempo*8.)*exp(-dist*2.)*fluxo;n.xz+=normalize(p-vec2(-2.78,-.3)+.001)*ripple*.14;n=normalize(n);
float depth=max(0.,linearDepth(texture2D(profundidade,uv).x)-linearDepth(gl_FragCoord.z));
vec3 behind=texture2D(fundo,uv+n.xz*.009*min(depth,1.)).rgb;
float absorb=1.-exp(-depth*2.4);vec3 tint=mix(vec3(.055,.28,.29),vec3(.12,.34,.40),frio);vec3 c=mix(behind,tint,absorb*.67);
vec3 viewDir=normalize(cameraPosition-mundo);float fresnel=.035+.72*pow(1.-max(dot(viewDir,n),0.),5.);vec3 sky=mix(vec3(.29,.49,.52),vec3(.77,.87,.88),n.y);c=mix(c,sky,fresnel);
vec3 lightDir=normalize(vec3(-6.,10.,6.));float spec=pow(max(dot(reflect(-lightDir,n),viewDir),0.),100.);c+=vec3(1.,.94,.75)*spec*.85;
float streak=pow(max(0.,sin(p.x*29.+sin(p.y*15.-tempo*3.)*2.)),17.);float bank=1.-smoothstep(.015,.095,min(textura.x,1.-textura.x));
float impact=exp(-dist*dist*6.)*(.4+.6*noise(p*35.-tempo*1.8))*min(fluxo,1.5);
float foam=clamp(bank*.28+impact*.65+streak*impact*.4,0.,.9);c=mix(c,vec3(.86,.94,.90),foam);gl_FragColor=vec4(c,1.);}`,side:THREE.DoubleSide});
const river=new THREE.Mesh(new THREE.PlaneGeometry(1.37,6.6,18,90),surface);river.rotation.x=-Math.PI/2;river.position.set(-2.7,.145,.2);river.renderOrder=2;scene.add(river);
const sheetMat=new THREE.ShaderMaterial({uniforms,vertexShader:`varying vec3 mundo;varying vec2 textura;uniform float tempo;void main(){textura=uv;vec3 p=position;p.x+=sin(uv.y*40.-tempo*8.+uv.x*8.)*.008;vec4 w=modelMatrix*vec4(p,1.);mundo=w.xyz;gl_Position=projectionMatrix*viewMatrix*w;}`,fragmentShader:common+`
uniform sampler2D fundo;uniform vec2 resolucao;
void main(){float stripes=noise(vec2(textura.x*38.,textura.y*17.-tempo*4.));float lines=pow(max(0.,sin(textura.x*72.+sin(textura.y*15.-tempo*7.)*.8)),12.);
float edge=smoothstep(0.,.1,textura.x)*smoothstep(0.,.1,1.-textura.x);vec2 screen=gl_FragCoord.xy/resolucao;vec3 behind=texture2D(fundo,screen+vec2((stripes-.5)*.006,0)).rgb;
vec3 c=mix(behind,vec3(.24,.63,.66),.28);c+=vec3(.52,.66,.66)*(lines*.48+pow(stripes,7.)*.45);float alpha=edge*(.40+lines*.30+stripes*.13);gl_FragColor=vec4(c,alpha*min(fluxo*2.,1.));}`,transparent:true,depthWrite:false,side:THREE.DoubleSide});
function ribbon(curve){const pos=[],uv=[],indices=[],cols=12,rows=64;for(let j=0;j<=rows;j++)for(let i=0;i<=cols;i++){const [y,z]=curve(j/rows);pos.push(-3.12+i/cols*.56,y,z);uv.push(i/cols,j/rows);}for(let j=0;j<rows;j++)for(let i=0;i<cols;i++){const a=j*(cols+1)+i,b=a+cols+1;indices.push(a,b,a+1,b,b+1,a+1);}const g=new THREE.BufferGeometry();g.setAttribute('position',new THREE.Float32BufferAttribute(pos,3));g.setAttribute('uv',new THREE.Float32BufferAttribute(uv,2));g.setIndex(indices);g.computeVertexNormals();const mesh=new THREE.Mesh(g,sheetMat);mesh.renderOrder=3;scene.add(mesh);return mesh;}
const fall=ribbon(t=>{const p=t*.43;return[3.24-3.05*p*p,-.8+p*.85];});
const wheelWater=ribbon(t=>{const a=-.51-t*2.48;return[1.55+1.32*Math.cos(a),.2+1.32*Math.sin(a)];});
const trough=new THREE.Mesh(new THREE.PlaneGeometry(.62,2.02,8,32),surface);trough.rotation.x=-Math.PI/2;trough.position.set(-2.65,3.24,-1.85);trough.renderOrder=2;scene.add(trough);
const count=280,positions=new Float32Array(count*3),sizes=new Float32Array(count),particleGeo=new THREE.BufferGeometry();particleGeo.setAttribute('position',new THREE.BufferAttribute(positions,3));particleGeo.setAttribute('taille',new THREE.BufferAttribute(sizes,1));
const particleMat=new THREE.ShaderMaterial({uniforms:{pixel:{value:renderer.getPixelRatio()}},vertexShader:`attribute float taille;uniform float pixel;varying float a;void main(){vec4 p=modelViewMatrix*vec4(position,1.);a=taille;gl_PointSize=clamp(taille*pixel*170./-p.z,1.,8.);gl_Position=projectionMatrix*p;}`,fragmentShader:`varying float a;void main(){float r=length(gl_PointCoord-.5)*2.;if(r>1.)discard;gl_FragColor=vec4(.81,.94,.93,(1.-r*r)*.7);}`,transparent:true,depthWrite:false});
const particles=new THREE.Points(particleGeo,particleMat);particles.renderOrder=4;scene.add(particles);
function droplets(t){for(let i=0;i<count;i++){const q=(t*(.6+flow*.45)+i*.6180339)%1,a=i*2.399963,r=.13+q*.6,j=i*3;positions[j]=-2.8+Math.cos(a)*r;positions[j+1]=.17+q*(1-q)*(.8+(i%5)*.28);positions[j+2]=-.12+Math.sin(a)*r+q*.28;sizes[i]=(.11+(i%3)*.04)*(1-q)*Math.min(flow,1.5);}particleGeo.attributes.position.needsUpdate=true;particleGeo.attributes.taille.needsUpdate=true;}
// Variantes de materiais com a mesma geometria e os mesmos pivôs.
const seasons=[{grass:'#71845b',roof:'#b95732',wood:'#83502c',stone:'#a5a38a'}, {grass:'#6e814c',roof:'#c16137',wood:'#936338',stone:'#aaa58b'}, {grass:'#9a794a',roof:'#a94f30',wood:'#785031',stone:'#a2977e'}, {grass:'#d7dfdc',roof:'#c9c9be',wood:'#69594a',stone:'#b0bcb9'}];
function setSeason(index){season=index;const s=seasons[index];for(const [key,mat]of materials){mat.color.copy(baseColors.get(key));if(key==='#72835b'||key==='#496747')mat.color.set(s.grass);if(['#b95832','#c46438','#cb7141','#ae4d2c','#dd824c'].includes(key))mat.color.set(s.roof);if(key==='#83502c')mat.color.set(s.wood);if(key==='#a5a38a')mat.color.set(s.stone);}uniforms.frio.value=index===3?1:0;floor.material.color.set(index===3?'#bfcfce':'#9cae99');}
function resize(){
const factor=pixelArt?3:1;
renderer.setPixelRatio(pixelArt?1:Math.min(devicePixelRatio,2));
renderer.setSize(Math.ceil(innerWidth/factor),Math.ceil(innerHeight/factor),false);
renderer.domElement.style.width='100vw';renderer.domElement.style.height='100vh';
renderer.domElement.style.imageRendering=pixelArt?'pixelated':'auto';
camera.aspect=innerWidth/innerHeight;camera.updateProjectionMatrix();
const size=renderer.getDrawingBufferSize(new THREE.Vector2());targetRT.setSize(size.x,size.y);uniforms.resolucao.value.copy(size);
particleMat.uniforms.pixel.value=renderer.getPixelRatio()/factor;
}addEventListener('resize',resize);resize();
let drag=null;renderer.domElement.onpointerdown=e=>{drag=[e.clientX,e.clientY];renderer.domElement.setPointerCapture(e.pointerId);};renderer.domElement.onpointermove=e=>{if(!drag)return;yaw-=(e.clientX-drag[0])*.007;pitch=Math.max(.13,Math.min(1.15,pitch+(e.clientY-drag[1])*.005));drag=[e.clientX,e.clientY];};renderer.domElement.onpointerup=renderer.domElement.onpointercancel=()=>drag=null;renderer.domElement.addEventListener('wheel',e=>{e.preventDefault();distance=Math.max(7,Math.min(23,distance*Math.exp(e.deltaY*.001)));},{passive:false});
document.getElementById('pause').onclick=e=>{paused=!paused;e.target.textContent=paused?'Continuar':'Pausar';};document.getElementById('reset').onclick=()=>{yaw=-.83;pitch=.46;distance=13.3;};document.getElementById('flow').oninput=e=>flow=Number(e.target.value);document.getElementById('season').onchange=e=>setSeason(Number(e.target.value));
document.getElementById('pixel').onclick=e=>{pixelArt=!pixelArt;e.target.textContent=pixelArt?'Pixel art: ligado':'Pixel art: desligado';e.target.setAttribute('aria-pressed',String(pixelArt));resize();};
let last=performance.now();function animate(now){const dt=Math.min((now-last)/1000,.05);last=now;if(!paused){time+=dt;angle-=dt*Math.PI/6*flow;}wheel.rotation.x=angle;uniforms.tempo.value=time;uniforms.fluxo.value=flow;droplets(time);camera.position.set(target.x+Math.sin(yaw)*Math.cos(pitch)*distance,target.y+Math.sin(pitch)*distance,target.z+Math.cos(yaw)*Math.cos(pitch)*distance);camera.lookAt(target);
const water=[river,fall,wheelWater,trough,particles];water.forEach(m=>m.visible=false);renderer.setRenderTarget(targetRT);renderer.render(scene,camera);renderer.setRenderTarget(null);water.forEach(m=>m.visible=true);fall.visible=wheelWater.visible=particles.visible=flow>.01;renderer.render(scene,camera);requestAnimationFrame(animate);}requestAnimationFrame(animate);
window.moinho={scene,renderer,camera,setSeason};
