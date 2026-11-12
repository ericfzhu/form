import React, {useEffect, useRef} from 'react';
import {createCharacterMotion} from './story-motion.js';
import {characterMarkup} from './counterweight-rig.js';
const art = {
 push: `<svg class="drawing" viewBox="0 0 1000 430" role="img" aria-label="Counterweight gathers a blue weight, on the same sparse hand-drawn ground line.">
<path class="scene-arrow" d="M269 144q20 13 27 32m-5-6 5 6 1-9"/>
<path class="ground" d="M243 270l29-2m10 1 46 1m12-2q54 4 83 1m6 1 58-2m11 2q67-2 90 1m9 0 47 1m10-2 61 2m14 0 27-1"/>
<g id="push-world"><g id="pusher" style="transform-origin:450px 275px"><svg x="375" y="135" width="150" height="150" viewBox="0 0 400 400" overflow="hidden" aria-hidden="true">__CHARACTER__</svg></g></g>
<g id="effort" opacity="0"><path d="m377 186-7-7m12-1-2-9m-10 26-10-1"/></g>
</svg>`,
 rhythm: `<svg class="drawing" viewBox="0 0 1000 470" role="img" aria-label="Among a loose collection of blue weight plates, Counterweight lifts a blue weight, wobbles, and settles again."><g transform="translate(290 112) rotate(-9) scale(0.9)"><g class="quiet-plate"><path class="prop-blue" fill-rule="evenodd" d="M-33-2C-35-22-17-37 2-36 23-36 37-18 35 3 35 24 17 37-3 35-23 36-35 18-33-2ZM-7 0C-8-9 8-9 8 0 9 9-8 10-7 0Z"/></g></g><g transform="translate(415 100) rotate(8) scale(1.05)"><g class="quiet-plate"><path class="prop-blue" fill-rule="evenodd" d="M-33-2C-35-22-17-37 2-36 23-36 37-18 35 3 35 24 17 37-3 35-23 36-35 18-33-2ZM-7 0C-8-9 8-9 8 0 9 9-8 10-7 0Z"/></g></g><g transform="translate(550 117) rotate(-6) scale(0.88)"><g class="quiet-plate"><path class="prop-blue" fill-rule="evenodd" d="M-33-2C-35-22-17-37 2-36 23-36 37-18 35 3 35 24 17 37-3 35-23 36-35 18-33-2ZM-7 0C-8-9 8-9 8 0 9 9-8 10-7 0Z"/></g></g><g transform="translate(681 106) rotate(12) scale(1)"><g class="quiet-plate"><path class="prop-blue" fill-rule="evenodd" d="M-33-2C-35-22-17-37 2-36 23-36 37-18 35 3 35 24 17 37-3 35-23 36-35 18-33-2ZM-7 0C-8-9 8-9 8 0 9 9-8 10-7 0Z"/></g></g><g transform="translate(315 229) rotate(8) scale(1)"><g class="quiet-plate"><path class="prop-blue" fill-rule="evenodd" d="M-33-2C-35-22-17-37 2-36 23-36 37-18 35 3 35 24 17 37-3 35-23 36-35 18-33-2ZM-7 0C-8-9 8-9 8 0 9 9-8 10-7 0Z"/></g></g><g transform="translate(444 224) rotate(-12) scale(0.82)"><g class="quiet-plate"><path class="prop-blue" fill-rule="evenodd" d="M-33-2C-35-22-17-37 2-36 23-36 37-18 35 3 35 24 17 37-3 35-23 36-35 18-33-2ZM-7 0C-8-9 8-9 8 0 9 9-8 10-7 0Z"/></g></g><g transform="translate(683 237) rotate(-9) scale(0.95)"><g class="neighbor-plate"><path class="prop-blue" fill-rule="evenodd" d="M-33-2C-35-22-17-37 2-36 23-36 37-18 35 3 35 24 17 37-3 35-23 36-35 18-33-2ZM-7 0C-8-9 8-9 8 0 9 9-8 10-7 0Z"/></g></g><g transform="translate(280 351) rotate(-14) scale(0.9)"><g class="quiet-plate"><path class="prop-blue" fill-rule="evenodd" d="M-33-2C-35-22-17-37 2-36 23-36 37-18 35 3 35 24 17 37-3 35-23 36-35 18-33-2ZM-7 0C-8-9 8-9 8 0 9 9-8 10-7 0Z"/></g></g><g transform="translate(417 358) rotate(7) scale(1.06)"><g class="quiet-plate"><path class="prop-blue" fill-rule="evenodd" d="M-33-2C-35-22-17-37 2-36 23-36 37-18 35 3 35 24 17 37-3 35-23 36-35 18-33-2ZM-7 0C-8-9 8-9 8 0 9 9-8 10-7 0Z"/></g></g><g transform="translate(699 366) rotate(9) scale(0.82)"><g class="quiet-plate"><path class="prop-blue" fill-rule="evenodd" d="M-33-2C-35-22-17-37 2-36 23-36 37-18 35 3 35 24 17 37-3 35-23 36-35 18-33-2ZM-7 0C-8-9 8-9 8 0 9 9-8 10-7 0Z"/></g></g>
<path class="ground" d="M510 404q29-2 47 0m8 0 40-1m10 1 15-1"/>
<g transform="translate(570 417)"><g class="lifter-balance"><g class="lifter-rise"><svg x="-76" y="-150" width="152" height="152" viewBox="0 0 400 400" overflow="hidden" aria-hidden="true">__CHARACTER__</svg></g></g></g></svg>`,
 rest: `<svg class="drawing" viewBox="0 0 1000 475" role="img" aria-label="Counterweight rests against a blue weight on the navy bench beneath a leafy plant.">
<g id="plant" style="transform-origin:334px 359px">
<path class="plant-stem" d="M333 359q9-61-1-115t7-76m-5 121q-23-30-48-34m49 4q18-32 44-46m-43 21q-16-29-41-34"/>
<path class="prop-ink" d="M286 255q-16-30-44-19 16 25 44 19Zm9-55q-4-31-28-35-2 27 28 35Zm44-32q-13-31 6-52 18 31-6 52Z"/>
<g id="blue-leaf" style="transform-origin:379px 213px"><path class="prop-blue" d="M379 213q3-34 31-40 2 29-31 40Z"/></g></g>
<g class="prop-ink"><path d="M395 303q120-4 241 0q5 0 5 5v4q0 4-5 4-124 4-241-1-5 0-5-4v-3q0-5 5-5Z"/>
<path d="m410 315-6 42q-1 5 4 5h2q4 0 5-4l7-43Zm204 0 9 43q1 4 5 4h2q5 0 4-5l-8-42Z"/></g>
<path class="ground" d="M307 366q52-5 101 0m13-1 98 1m12-1 115 1m11-1 29 1"/>
<g class="breath"><svg x="450" y="170.5" width="145" height="145" viewBox="0 0 400 400" overflow="hidden" aria-hidden="true">__CHARACTER__</svg></g>
<g id="breeze" class="gray" opacity="0"><path d="M653 235q26-10 50-3m-42 15q37-11 59-3m-79-21 17-4"/></g><g class="float-mark"></g>
</svg>`,
 return: `<svg class="drawing" viewBox="0 0 1000 330" role="img" aria-label="Counterweight waits with the blue weight, ready to begin again."><g id="return-circle" style="transform-origin:510px 243px"><svg x="457" y="142" width="108" height="108" viewBox="0 0 400 400" overflow="hidden" aria-hidden="true">__CHARACTER__</svg></g><path class="ground" d="M432 241q55-3 143 0m8 0 16-1"/></svg>`
};
// Keep React from replacing SVG nodes that the motion controller animates in place.
const sceneMarkup = Object.fromEntries(
 Object.entries(art).map(([kind, svg]) => [
  kind, {__html: svg.replace('__CHARACTER__', characterMarkup(kind))}
 ])
);

export function StoryScene({kind, paused, covered}) {
 const ref = useRef(null);
 const motion = useRef(null);
 useEffect(() => {
  const element = ref.current;
  const character = createCharacterMotion(element, kind);
  motion.current = character;
  const media = matchMedia('(prefers-reduced-motion: reduce)');
  let visible = false;
  const sync = () => {
   const resting = paused || media.matches || !visible || document.hidden;
   character.setRunning(!resting, paused || media.matches);
  };
  const observer = new IntersectionObserver(([entry]) => {
   visible = entry.isIntersecting;
   sync();
  }, {threshold: 0.15});
  observer.observe(element);
  document.addEventListener('visibilitychange', sync);
  media.addEventListener('change', sync);
  sync();
  return () => {
   observer.disconnect();
   document.removeEventListener('visibilitychange', sync);
   media.removeEventListener('change', sync);
   character.dispose();
   motion.current = null;
  };
 }, [kind, paused]);
 useEffect(() => {
  motion.current?.setCovered(covered);
 }, [covered, kind, paused]);
 function play() {
  if (ref.current.dataset.motion !== 'running' || paused || matchMedia('(prefers-reduced-motion: reduce)').matches) return;
  motion.current?.play();
 }
 const labels = {push: 'Give Counterweight a nudge', rhythm: 'Watch Counterweight try another lift', rest: 'Send a breeze through the leaves', return: 'Nudge Counterweight to begin again'};
 return <button className={'scene-button scene-' + kind} ref={ref} data-motion="paused" aria-label={labels[kind]} onClick={play} dangerouslySetInnerHTML={sceneMarkup[kind]}/>;
}
