import inventory from '../Form/Planning/exercises.json' with { type: 'json' };
export const equipment = [
  ['dumbbells', 'Dumbbells'], ['bench', 'Flat bench'], ['adjustableBench', 'Adjustable bench'],
  ['barbell', 'Barbell & plates'], ['rack', 'Squat rack'], ['cable', 'Cable row station'],
  ['pulldown', 'Lat pulldown'], ['legPress', 'Leg press'], ['legCurl', 'Seated leg curl'], ['highLow', 'High–low pulley'],
  ['bike', 'Upright bike'], ['elliptical', 'Elliptical'], ['rower', 'Rowing machine'], ['treadmill', 'Treadmill'],
];
export const focuses = [['fatLoss', 'Lose fat, keep strength'], ['consistency', 'Find a rhythm'], ['strength', 'Build strength'], ['muscle', 'Build muscle']];
export const patternNames = { squat: 'Squat', hinge: 'Hinge', push: 'Push', pull: 'Pull', singleLeg: 'Single leg', core: 'Core', carry: 'Carry', accessory: 'Leg accessory' };
export const sampleProfile = { name: 'My gym', equipment: ['barbell', 'rack', 'adjustableBench', 'legCurl', 'highLow', 'pulldown', 'cable', 'bike', 'elliptical', 'rower', 'treadmill'], sessionsPerWeek: 2, minutes: 50, focus: 'fatLoss', configured: true, overrides: {} };
export function normaliseProfile(value) {
  if (!value || typeof value !== 'object') return { ...sampleProfile, equipment: [...sampleProfile.equipment], overrides: {} };
  return {
    name: typeof value.name === 'string' ? value.name.slice(0, 80) : 'My gym',
    equipment: [...new Set(Array.isArray(value.equipment) ? value.equipment.filter(id => equipment.some(([key]) => key === id)) : [])],
    sessionsPerWeek: 2,
    minutes: [40,50,60].includes(value.minutes) ? value.minutes : 50,
    focus: focuses.some(([id]) => id === value.focus) ? value.focus : 'fatLoss',
    configured: value.configured === true,
    overrides: value.overrides && typeof value.overrides === 'object' && !Array.isArray(value.overrides) ? value.overrides : {},
  };
}
export function available(profile, pattern) {
  const effective = new Set(profile.equipment);
  if (effective.has('adjustableBench')) effective.add('bench');
  return inventory.filter(item => (!pattern || item.pattern === pattern) && item.equipment.every(id => effective.has(id))).sort((a, b) => Number(a.equipment.length === 0) - Number(b.equipment.length === 0));
}
export function makePlan(input) {
  const profile = normaliseProfile(input);
  const templates = [
    [['squat','barbell-back-squat'], ['push','barbell-bench-press'], ['pull','seated-row'], ['accessory','leg-curl']],
    [['hinge','barbell-romanian-deadlift'], ['push','barbell-incline-press'], ['pull','lat-pulldown'], ['singleLeg','reverse-lunge']],
  ];
  return templates.map((slots, index) => {
    const id = `plan-${index + 1}`;
    const missing = [];
    const movements = slots.flatMap(([pattern, preferred]) => {
      // A gym without a leg-curl station can use an available hinge instead.
      const effectivePattern = pattern === 'accessory' && !available(profile, pattern).length ? 'hinge' : pattern;
      const options = available(profile, effectivePattern);
      if (!options.length) { missing.push(effectivePattern); return []; }
      const exercise = options.find(item => item.id === profile.overrides[`${id}-${effectivePattern}`])
        || options.find(item => item.id === preferred) || options[0];
      const timed = ['timed', 'weightedTimed'].includes(exercise.measurement);
      const heavy = ['squat', 'hinge', 'push'].includes(effectivePattern) && exercise.measurement === 'weighted';
      return [{...exercise, sets: 2, minimum: timed ? 30 : exercise.id === 'leg-curl' ? 10 : ['barbell-romanian-deadlift','barbell-incline-press'].includes(exercise.id) ? 8 : heavy ? 6 : 8,
        maximum: timed ? 45 : exercise.id === 'leg-curl' ? 15 : exercise.id === 'barbell-incline-press' ? 12 : heavy ? 10 : 12, restSeconds: heavy ? 120 : 90}];
    });
    const warmupMinutes = 5;
    // Allow for both legs and equipment changes; reserve time for cardio after lifting.
    const strengthMinutes = Math.ceil(movements.reduce((sum, m) => sum + m.sets * ((m.pattern === 'singleLeg' ? 75 : 45) + m.restSeconds), 0) / 60) + Math.max(0, movements.length - 1);
    const cardioMinutes = profile.minutes === 40 ? 10 : profile.minutes === 50 ? 15 : 20;
    const cardioOptions = equipment.filter(([key]) => ['bike','elliptical','rower','treadmill'].includes(key) && profile.equipment.includes(key));
    return { id, name: `Session ${index === 0 ? 'A' : 'B'}`, subtitle: index === 0 ? 'Squat, press & row' : 'Hinge, press & pull', movements, missing,
      warmupMinutes, strengthMinutes, cardioMinutes, cardioOptions,
      estimatedMinutes: warmupMinutes + strengthMinutes + cardioMinutes };
  });
}
export function target(item) { return `${item.sets} × ${item.minimum}–${item.maximum} ${['timed','weightedTimed'].includes(item.measurement) ? 'sec' : 'reps'}${item.pattern === 'singleLeg' ? ' / side' : ''}`; }
export function equipmentLabel(item) { return item.equipment.map(id => equipment.find(([key]) => key === id)?.[1]).join(' + ') || 'Bodyweight'; }
