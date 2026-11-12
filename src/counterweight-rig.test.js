import test from 'node:test';
import assert from 'node:assert/strict';
import {rigPose, gestureDuration} from './counterweight-rig.js';
const distance=(a,b)=>Math.hypot(a[0]-b[0],a[1]-b[1]);
for(const kind of Object.keys(gestureDuration)){
  test(`${kind}: arms stay connected and in reach throughout the response`,()=>{
    for(let time=0;time<=gestureDuration[kind];time+=8){
      const pose=rigPose(kind,0,time);
      for(const [i,arm] of pose.arms.entries()){
        assert.ok(Math.abs(distance(arm.shoulder,arm.elbow)-91)<1e-8);
        assert.ok(Math.abs(distance(arm.elbow,arm.hand)-91)<1e-8);
        assert.ok(arm.elbow.every(Number.isFinite));
        if(kind!=='rest'){
          const radius=kind==='push'?52:54;
          const angle=pose.weightAngle*Math.PI/180;
          const sign=i?1:-1;
          assert.ok(Math.abs(arm.hand[0]-(pose.weight[0]+sign*radius*Math.cos(angle)))<1e-8);
          assert.ok(Math.abs(arm.hand[1]-(pose.weight[1]+sign*radius*Math.sin(angle)))<1e-8);
        }
      }
    }
  });
  test(`${kind}: response returns to its starting pose`,()=>{
    assert.deepEqual(rigPose(kind,0,0),rigPose(kind,0,gestureDuration[kind]));
  });
}
test('lifting moves the weight independently of head and torso',()=>{
  const start=rigPose('rhythm',0,0),lift=rigPose('rhythm',0,4200*.48);
  assert.ok(start.weight[1]-lift.weight[1]>59);
  assert.ok(Math.abs(start.head[1]-lift.head[1])<6);
  assert.ok(Math.abs(start.bodyY-lift.bodyY)<1);
  assert.notEqual(start.arms[0].path,lift.arms[0].path);
  assert.notEqual(start.arms[1].path,lift.arms[1].path);
  assert.ok(Math.abs(lift.head[2])>5);
});
