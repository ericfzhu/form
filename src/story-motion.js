import {bindRig, rigPose, gestureDuration, armGeometry} from './counterweight-rig.js';
const lerp=(a,b,t)=>a+(b-a)*t;
const mixPoint=(a,b,t)=>a.map((v,i)=>lerp(v,b[i],t));
const ease=t=>t*t*(3-2*t);
function blend(kind,a,b,t){
  const weight=mixPoint(a.weight,b.weight,t), angle=lerp(a.weightAngle,b.weightAngle,t);
  const radius=kind==='push'?52:54;
  return {
    head:mixPoint(a.head,b.head,t),bodyY:lerp(a.bodyY,b.bodyY,t),weight,weightAngle:angle,blink:t<.5?a.blink:b.blink,
    arms:a.arms.map((arm,i)=>{
      const shoulder=mixPoint(arm.shoulder,b.arms[i].shoulder,t);
      const radians=angle*Math.PI/180,sign=i?1:-1;
      const hand=kind==='rest'?mixPoint(arm.hand,b.arms[i].hand,t):[weight[0]+sign*radius*Math.cos(radians),weight[1]+sign*radius*Math.sin(radians)];
      return armGeometry(shoulder,hand,i?'right':'left');
    }),
  };
}
export function createCharacterMotion(scene,kind){
  const draw=bindRig(scene,kind);
  let running=false,frame=null,last=null,idle=0,action=null,elapsed=0;
  let breeze=[];
  let covered=false;
  draw(rigPose(kind));
  const clearBreeze=()=>{breeze.forEach(a=>a.cancel());breeze=[];};
  const clearAction=()=>{action=null;elapsed=0;delete scene.dataset.acting;clearBreeze();};
  function tick(now){
    if(!running)return;
    const dt=last===null?0:Math.min(80,now-last);last=now;
    if(action){
      elapsed+=dt;
      const progress=Math.min(1,elapsed/gestureDuration[kind]);
      const pose=rigPose(kind,idle,elapsed);
      if(progress<.12)draw(blend(kind,action,pose,ease(progress/.12)));
      else if(progress>.84)draw(blend(kind,pose,action,ease((progress-.84)/.16)));
      else draw(pose);
      if(progress===1){clearAction();draw(rigPose(kind,idle));}
    }else{idle+=dt/1000;draw(rigPose(kind,idle));}
    frame=requestAnimationFrame(tick);
  }
  function syncPlayback(){
    const playing = running && !covered;
    scene.dataset.motion = playing ? 'running' : 'paused';
    if(frame !== null) cancelAnimationFrame(frame);
    last = null;
    frame = playing ? requestAnimationFrame(tick) : null;
    for(const animation of breeze){
      if(animation.playState === 'finished') continue;
      if(playing) animation.play();
      else animation.pause();
    }
  }
  return {
    setRunning(value,reduce=false){
      running=value;
      if(!value){clearAction();if(reduce)idle=0;draw(rigPose(kind,idle));}
      syncPlayback();
    },
    setCovered(value){
      covered=value;
      syncPlayback();
    },
    play(){
      if(!running||covered||action)return;
      action=rigPose(kind,idle);elapsed=0;scene.dataset.acting='true';
      if(kind==='rest'){
        const animate=(selector,frames,duration)=>{const el=scene.querySelector(selector);if(el)breeze.push(el.animate(frames,{duration,easing:'ease-in-out'}));};
        animate('#plant',[{transform:'rotate(0)'},{transform:'rotate(2.4deg)',offset:.3},{transform:'rotate(-.8deg)',offset:.65},{transform:'rotate(0)'}],3900);
        animate('#blue-leaf',[{transform:'skewY(0)'},{transform:'skewY(-8deg)'},{transform:'skewY(0)'}],4100);
        animate('#breeze',[{opacity:0},{opacity:.35,offset:.25},{opacity:0}],2600);
      }
    },
    dispose(){running=false;if(frame!==null)cancelAnimationFrame(frame);clearAction();},
  };
}
