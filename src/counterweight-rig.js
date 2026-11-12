// Code-native Counterweight: separate silhouette, head, arms, hands and weight.
// All coordinates are local to the same 400 × 400 artwork frame used before.
const ink = '#051230';
const blue = '#97acc8';
const bases = {
  push: {head:[240,104], shoulders:[[143,143],[263,150]], weight:[190,307], radius:57},
  rhythm: {head:[246,81], shoulders:[[132,128],[268,128]], weight:[200,205], radius:59},
  return: {head:[246,81], shoulders:[[132,128],[268,128]], weight:[200,205], radius:59},
  rest: {head:[201,163], shoulders:[[164,206],[246,207]], weight:[310,273], radius:73},
};
const number = n => Number(n.toFixed(3));
const point = p => p.map(number).join(' ');
export function armGeometry(shoulder, hand, side) {
  const dx=hand[0]-shoulder[0], dy=hand[1]-shoulder[1];
  const distance=Math.hypot(dx,dy);
  const length=91;
  const height=Math.sqrt(Math.max(0,length*length-distance*distance/4));
  const direction=side==='left'?1:-1;
  const elbow=[(shoulder[0]+hand[0])/2-direction*dy/Math.max(distance,.001)*height,
    (shoulder[1]+hand[1])/2+direction*dx/Math.max(distance,.001)*height];
  // Round the elbow while keeping the wrist exactly on its grip point.
  const control=elbow.map((v,i)=>2*v-(shoulder[i]+hand[i])/2);
  return {shoulder,hand,elbow,path:`M${point(shoulder)} Q${point(control)} ${point(hand)}`};
}
const smooth = t => t*t*t*(t*(t*6-15)+10);
function track(time, keys) {
  if(time<=keys[0][0])return keys[0][1];
  for(let i=1;i<keys.length;i++)if(time<=keys[i][0]){
    const [start,a]=keys[i-1], [end,b]=keys[i];
    return a+(b-a)*smooth((time-start)/(end-start));
  }
  return keys.at(-1)[1];
}
export const gestureDuration={push:3600,rhythm:4200,rest:4800,return:3000};
export function rigPose(kind, seconds=0, action=null) {
  const base=bases[kind];
  const phase=action===null?null:Math.min(1,action/gestureDuration[kind]);
  const inhale=kind==='rest'&&phase!==null?track(phase,[[0,0],[.38,1],[.5,1],[.94,0],[1,0]])*.65:0;
  const breath=(1-Math.cos(seconds*Math.PI*2/(kind==='rest'?8.6:10.7)))/2+inhale;
  // The rhythm scene has a complete lift followed by a long, quiet recovery.
  const t=phase??(kind==='rhythm'?((seconds+10)%17)/5.4:2);
  const lift=track(t,[[0,0],[.16,0],[.39,1],[.58,1],[.86,0],[1,0]]);
  const brace=(kind==='rest'||kind==='return')?0:track(t,[[0,0],[.13,1],[.29,0],[.74,0],[.87,.3],[1,0]]);
  const follow=(kind==='rest'||kind==='return')?0:track(t,[[0,0],[.21,0],[.44,1],[.63,1],[.94,0],[1,0]]);
  const correction=(kind==='rest'||kind==='return')?0:track(t,[[0,0],[.39,1],[.46,-.55],[.54,.2],[.63,0],[1,0]]);
  const nod=phase===null?0:track(phase,[[0,0],[.22,-1],[.4,-1],[.58,1],[.76,-.15],[1,0]]);
  const isRest=kind==='rest';
  const isGreeting=kind==='return';
  const amount=isRest||isGreeting?0:lift*(kind==='push'?66:60);
  const bodyY=brace*4-breath*(isRest?1.1:.55);
  const headX=base.head[0]+follow*3;
  const headY=base.head[1]+bodyY-follow*5-(isRest?breath*1.7:0);
  const headAngle=isRest?breath*-2+nod*2:isGreeting?nod*7-follow*3:-follow*7+brace*2+correction*1.4;
  const weight=[base.weight[0]+(isRest?0:correction*1.1),base.weight[1]-amount+(isGreeting?nod*2:0)];
  const weightAngle=isRest?nod*.65:correction*2.3;
  let hands;
  if(isRest)hands=[[139,335-bodyY],[268,281+nod*2]];
  else {
    const radians=weightAngle*Math.PI/180;
    hands=[-1,1].map(sign=>[weight[0]+sign*(base.radius-5)*Math.cos(radians),weight[1]+sign*(base.radius-5)*Math.sin(radians)]);
  }
  const shoulders=base.shoulders.map(([x,y])=>[x,y+bodyY]);
  return {head:[headX,headY,headAngle],bodyY,weight,weightAngle,
    arms:hands.map((hand,i)=>armGeometry(shoulders[i],hand,i?'right':'left')),
    blink:phase!==null ? (phase>.12&&phase<.16?1:0) : ((seconds%7.9)>7.55&&(seconds%7.9)<7.7?1:0)};
}
function torso(kind){
  if(kind==='push')return 'M226 94Q189 97 137 121Q106 146 119 204L144 268Q188 293 250 260L272 191Q286 141 255 111Z';
  if(kind==='rest')return 'M185 157Q145 180 138 224L152 298Q188 333 252 321L277 274Q276 222 244 183Z';
  return 'M231 74Q195 81 145 104Q115 130 126 177L147 236Q193 264 256 233L278 170Q290 126 265 99Z';
}
function legs(kind){
  if(kind==='push')return '<path d="M146 243Q101 226 77 258Q65 276 86 316L76 340Q47 344 47 360L124 360L141 318L173 286ZM251 244Q292 228 314 259Q328 282 303 320L317 341Q347 345 348 360L271 360L252 318L221 286Z"/>';
  if(kind==='rest')return '<path d="M163 275Q111 250 100 295L101 337L82 345Q77 360 96 361L128 347L142 311L176 319ZM235 281Q278 271 276 311L262 346Q257 361 241 361L201 360Q199 344 221 337L223 317L196 309Z"/>';
  return '<path d="M154 219Q111 238 99 278L87 333Q69 340 69 360L146 360L150 331L172 292Q183 280 200 279L219 292L242 333L244 360L320 360Q320 342 299 333L288 280Q276 240 249 222Z"/>';
}
export function characterMarkup(kind){
  const base=bases[kind], pose=rigPose(kind,0);
  return `<g class="character-rig" data-rig="${kind}" fill="${ink}" stroke="none">
    <g data-part="legs">${legs(kind)}</g>
    <g data-part="torso"><path d="${torso(kind)}"/></g>
    <g data-part="head" transform="translate(${point(pose.head.slice(0,2))})"><path d="M-33 10C-38-8-23-30-8-31C11-34 28-12 33 11Q8 27-33 10Z"/><path fill="#fcfcff" d="M-28 8Q-25-10-10-16Q12-25 27 7Q6 22-28 8Z"/><g data-part="eyes"><ellipse cx="-6" cy="0" rx="2.7" ry="4.5"/><ellipse cx="10" cy="0" rx="2.7" ry="4.5"/></g><path data-part="closed-eyes" d="M-9 1q3 2 6 0M7 1q3 2 6 0" fill="none" stroke="${ink}" stroke-width="1.5" opacity="0"/></g>
    <g data-part="weight" transform="translate(${point(pose.weight)})"><path fill="${blue}" d="M-${base.radius} 0C-${base.radius+2} -${base.radius*.56} -${base.radius*.5} -${base.radius+2} 0 -${base.radius}C${base.radius*.64} -${base.radius} ${base.radius+1} -${base.radius*.48} ${base.radius} 0C${base.radius} ${base.radius*.64} ${base.radius*.45} ${base.radius+1} 0 ${base.radius}C-${base.radius*.65} ${base.radius} -${base.radius} ${base.radius*.45} -${base.radius} 0Z"/></g>
    ${pose.arms.map((arm,i)=>`<g data-part="arm-${i?'right':'left'}"><path data-arm-path d="${arm.path}" fill="none" stroke="${ink}" stroke-width="31" stroke-linecap="round" stroke-linejoin="round"/><ellipse data-hand cx="${arm.hand[0]}" cy="${arm.hand[1]}" rx="16" ry="13"/></g>`).join('')}
  </g>`;
}
export function bindRig(scene,kind){
  const rig=scene.querySelector('[data-rig]');
  const part=name=>rig.querySelector(`[data-part="${name}"]`);
  const head=part('head'), torsoElement=part('torso'), weight=part('weight'), eyes=part('eyes'), closed=part('closed-eyes');
  const arms=['left','right'].map(side=>({path:part('arm-'+side).querySelector('[data-arm-path]'),hand:part('arm-'+side).querySelector('[data-hand]')}));
  return pose=>{
    head.setAttribute('transform',`translate(${point(pose.head.slice(0,2))}) rotate(${number(pose.head[2])})`);
    torsoElement.setAttribute('transform',`translate(0 ${number(pose.bodyY)})`);
    weight.setAttribute('transform',`translate(${point(pose.weight)}) rotate(${number(pose.weightAngle)})`);
    eyes.setAttribute('opacity',1-pose.blink);closed.setAttribute('opacity',pose.blink);
    arms.forEach((arm,i)=>{arm.path.setAttribute('d',pose.arms[i].path);arm.hand.setAttribute('cx',pose.arms[i].hand[0]);arm.hand.setAttribute('cy',pose.arms[i].hand[1]);});
  };
}
