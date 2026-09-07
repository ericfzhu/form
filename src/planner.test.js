import test from 'node:test';
import assert from 'node:assert/strict';
import { available, equipment, makePlan, normaliseProfile, sampleProfile } from './planner.js';

test('provided gym excludes unlisted dumbbells and includes barbell pressing', () => {
  assert.equal(sampleProfile.equipment.includes('dumbbells'), false);
  const plan = makePlan(sampleProfile);
  assert.equal(plan.length, 2);
  assert.ok(plan[0].movements.some(m => m.id === 'barbell-bench-press'));
  assert.ok(plan.every(s => !s.missing.length));
});
test('equipment prerequisites and bench capabilities are enforced', () => {
  const flat = { ...sampleProfile, equipment: ['dumbbells','bench'] };
  assert.ok(available(flat).some(e => e.id === 'chest-press'));
  assert.ok(!available(flat).some(e => e.id === 'incline-press'));
  assert.ok(available({ ...flat, equipment: ['dumbbells','adjustableBench'] }).some(e => e.id === 'incline-press'));
  assert.ok(!available({ ...flat, equipment: ['rack','bench'] }).some(e => e.id === 'barbell-bench-press'));
});
test('no equipment produces honest missing patterns and only bodyweight exercises', () => {
  for (const session of makePlan({ ...sampleProfile, equipment: [] })) {
    assert.ok(session.missing.includes('pull'));
    assert.ok(session.movements.every(m => m.equipment.length === 0));
  }
});
test('invalid, unavailable and wrong-pattern swaps cannot enter the plan', () => {
  const profile = { ...sampleProfile, overrides: { 'plan-1-push': 'incline-press', 'plan-1-squat': 'barbell-row' } };
  const plan = makePlan(profile);
  assert.ok(!plan[0].movements.some(m => m.id === 'incline-press'));
  assert.equal(plan[0].movements[0].pattern, 'squat');
  profile.overrides['plan-1-push'] = 'pushup';
  assert.ok(makePlan(profile)[0].movements.some(m => m.id === 'pushup'));
});
test('corrupt saved values are normalised', () => {
  const profile = normaliseProfile({ equipment: ['unknown','barbell','barbell'], sessionsPerWeek: -9, minutes: 800, focus: 'invalid', overrides: [] });
  assert.deepEqual(profile.equipment, ['barbell']);
  assert.equal(profile.sessionsPerWeek, 2);
  assert.equal(profile.minutes, 50);
  assert.deepEqual(profile.overrides, {});
});
test('all supported budgets and goals respect time estimates and unique exercises', () => {
  for (const minutes of [40,50,60]) for (const focus of ['fatLoss','strength','muscle','consistency']) {
    for (const session of makePlan({ ...sampleProfile, minutes, focus, equipment: equipment.map(([id]) => id) })) {
      assert.ok(session.estimatedMinutes <= minutes);
      assert.equal(new Set(session.movements.map(m => m.id)).size, session.movements.length);
    }
  }
});

test('A/B sessions match the agreed equipment and include cardio in the visit budget', () => {
  const [a, b] = makePlan(sampleProfile);
  assert.deepEqual(a.movements.map(m => m.id), ['barbell-back-squat', 'barbell-bench-press', 'seated-row', 'leg-curl']);
  assert.deepEqual(b.movements.map(m => m.id), ['barbell-romanian-deadlift', 'barbell-incline-press', 'lat-pulldown', 'reverse-lunge']);
  for (const session of [a,b]) {
    assert.equal(session.movements.length, 4);
    assert.equal(session.cardioMinutes, 15);
    assert.equal(session.estimatedMinutes, session.warmupMinutes + session.strengthMinutes + session.cardioMinutes);
    assert.equal(session.cardioOptions.length, 4);
  }
});
test('missing leg-curl equipment gets a feasible hinge, and cardio machines are never invented', () => {
  const [a] = makePlan({...sampleProfile, equipment:['barbell','rack','bench']});
  assert.equal(a.movements[3].pattern, 'hinge');
  assert.deepEqual(a.cardioOptions, []);
  assert.ok(a.movements.every(m => m.equipment.every(e => ['barbell','rack','bench'].includes(e))));
});
