import React, {useEffect, useRef, useState} from 'react';
import {createRoot} from 'react-dom/client';
import {makePlan, sampleProfile, target} from './planner.js';
import {StoryDefinitions, StoryScene} from './StoryScenes.jsx';
import './field.css';

// This routine is prescribed from the supplied gym inventory. Previous planner
// preferences and swaps deliberately do not participate in the homepage.
const workouts = makePlan({...sampleProfile, minutes:50, overrides:{}}).map(session=>({...session,cardio:'Treadmill walking'}));
function Workout({close}){
 const dialog=useRef(null);
 const [selected,setSelected]=useState(0);
 const session=workouts[selected];
 useEffect(()=>{const el=dialog.current;el.showModal();return()=>el.close();},[]);
 return <dialog className="workout" ref={dialog} aria-labelledby="workout-title" onCancel={close} onClick={e=>{if(e.target===dialog.current)close();}}><div className="workout-nav"><h2 id="workout-title">the routine</h2><button onClick={close} aria-label="Close workout">close ×</button></div><p className="workout-intro">Twice a week. A rest day between.</p><div className="workout-tabs" role="tablist" aria-label="View the routine sessions">{workouts.map((s,i)=><button key={s.id} id={`tab-${s.id}`} role="tab" aria-selected={selected===i} aria-controls="workout-session" tabIndex={selected===i?0:-1} onClick={()=>setSelected(i)} onKeyDown={e=>{if(['ArrowLeft','ArrowRight','Home','End'].includes(e.key)){e.preventDefault();const next=e.key==='Home'?0:e.key==='End'?1:1-i;setSelected(next);document.getElementById(`tab-${workouts[next].id}`)?.focus();}}}>{s.name}</button>)}</div><section id="workout-session" role="tabpanel" aria-labelledby={`tab-${session.id}`}><p className="session-time">~{session.estimatedMinutes} min · warm up first</p><ol>{session.movements.map(m=><li key={m.id}><strong>{m.name}</strong><span>{target(m)} · {m.restSeconds}s rest</span></li>)}</ol><div className="cardio"><strong>Treadmill · {session.cardioMinutes} min</strong><p>Speed 5 · incline 7.5</p><small>Check console units. Keep the effort conversational.</small></div></section><p className="workout-footnote">Lift with 2 reps in reserve.</p></dialog>;
}
function App(){
 const [showWorkout,setShowWorkout]=useState(false);
 const [paused,setPaused]=useState(()=>matchMedia('(prefers-reduced-motion: reduce)').matches);
 useEffect(()=>{const q=matchMedia('(prefers-reduced-motion: reduce)');const sync=()=>setPaused(q.matches);q.addEventListener('change',sync);return()=>q.removeEventListener('change',sync);},[]);
 useEffect(()=>{if(paused)document.querySelectorAll('.scene-button svg').forEach(svg=>svg.getAnimations({subtree:true}).forEach(a=>{if(a.constructor.name!=='CSSAnimation')a.cancel();}));},[paused]);
 return <div className={paused?'story paused':'story'}><StoryDefinitions/><nav className="quiet-nav" aria-label="Main navigation"><a href="#beginning" className="signature">form.</a><button onClick={()=>setShowWorkout(true)}>the routine ↗</button></nav><main>
 <section className="page encounter" id="beginning" aria-labelledby="opening-title"><header><h1 id="opening-title">a little<br/>movement.</h1><p>sometimes,<br/>a nudge is enough.</p></header><StoryScene kind="push" paused={paused}/><span className="pencil-note">oh.</span><a className="scroll-note" href="#rhythm">wander a little ↓</a></section>
 <section className="page rhythm" id="rhythm" aria-labelledby="rhythm-title"><header><h2 id="rhythm-title">finding<br/>a rhythm.</h2><p>getting the hang of it.</p></header><StoryScene kind="rhythm" paused={paused}/></section>
 <section className="page rest" id="rest" aria-labelledby="rest-title"><header><h2 id="rest-title">room<br/>to rest.</h2><p>the world can wait<br/>a little.</p></header><StoryScene kind="rest" paused={paused}/><span className="pencil-note">in ... and out.</span></section>
 <section className="page returning" aria-labelledby="return-title"><header><h2 id="return-title">and<br/>again.</h2><p>hello, you.</p></header><StoryScene kind="return" paused={paused}/><a className="return-link" href="#beginning">back to the beginning ↶</a></section>
 </main>{showWorkout&&<Workout close={()=>setShowWorkout(false)}/>}</div>;
}
createRoot(document.getElementById('field-root')).render(<App/>);
