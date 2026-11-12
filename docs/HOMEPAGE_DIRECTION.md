# Homepage: a little movement

The homepage is an atmospheric illustrated story, not a product presentation. Four scenes: an encounter with a blue paper circle; a loose rhythm of shapes; a rest beneath a folded leaf; and the circle returning. Sparse handwriting, pure white background, fine indigo contours, white cut edges and shallow paper shadows follow the supplied references. There are no feature sections, inventory lists, setup forms, duration controls or workout sheets in the story.

The small persistent “the routine” link opens a separate modal reading view introduced to all visitors as a two-day strength-and-cardio routine. The routine uses the supplied equipment and agreed two-session structure. Both finish with fifteen minutes of treadmill walking. The recorded console settings are speed 5 and incline 7.5; units are explicitly unconfirmed in the reading view. Effort guidance allows reducing speed or incline as needed. Session tabs navigate the prescription; they do not edit it. Old localStorage configuration and swaps are ignored but not deleted. The website is a read-only introduction to the routine, with no download or session-start action. Workout logging belongs in the iOS app. Exact weights remain based on familiar loads and the displayed effort guidance; no strength performance data was supplied.

Original code-native SVG in StoryScenes.jsx supplies the cut pieces and motion. Taps/keyboard activation trigger scene responses. The footer pauses motion; system reduced-motion preference is respected. Gaegu and its OFL license are bundled locally. No runtime font/image CDN dependency, publishing, or iOS changes.

Validation: Vite production build; existing planner tests; browser checks of story, interactions, fixed-workout view and responsive layout.

## Counterweight character update — 10 November 2026

Keep the original four-scene layout, asymmetric text placement, empty space, copy and read-only routine popup. This is an artwork update, not a marketing-page redesign. The exact iOS Counterweight session artwork is reused in `public/counterweight/session.png`, framed into each existing SVG scene. The paper plates, plant, ledge and ground lines remain. Nudge, lift, breeze and return interactions retain their timing, with rotations adapted to the new character. Handwritten story typography stays; only the small Form signature takes the app's sans-serif wordmark treatment. No feature grid, product hero or new navigation is introduced. Local preview only; no deployment.

### Character motion refinement

The subsequent motion pass keeps every scene, heading and illustration frame at its existing size and position. It replaces the old plate-like rolling and floating with a brief brace, small weight shifts, a lift/balance/settle sequence, slower breathing and a restrained return greeting. Small eyelid overlays add intermittent blinks without changing the source artwork. Long idle holds give each effort space. Tap/keyboard responses start and finish at the current idle pose; repeated taps do not restart or stack them. Off-screen scenes and hidden tabs pause; interrupted responses clean up, and system reduced motion disables both idle and triggered motion.

Validation: Vite build passed. Browser checks at 1440px and 390px covered all four keyboard responses, repeated taps, completion, reduced motion and off-screen interruption. Scene, header, navigation and button bounds remained identical through sampled animation phases. No layout, story copy or routine changes were made in this motion pass.

### Articulated character

The sprite-based motion is superseded by `counterweight-rig.js`: a code-native SVG adaptation of the same navy character and blue weight, split into fixed legs, torso, head/eyes, two curved arms, hands and weight. The original iOS artwork remains the visual reference. Every existing scene frame retains its coordinates and size. Each arm uses a two-segment joint calculation; its wrist stays on the weight's rotated grip point while the weight rises, holds and lowers. The head follows with separate timing, and resting/greeting poses use their own movement. `story-motion.js` drives these parts rather than transforming the character image. Idle motion freezes during interaction and blends back to its captured pose; off-screen, hidden-tab and reduced-motion handling remain in place.

Nine kinematic tests cover arm reach and grip attachment throughout each response, return to the starting pose, and independent movement of the weight versus the head/torso. The existing eight planner tests also pass.

Browser validation at 1440px and 390px checked each scene's separate arm/head transforms, weight movement in the lifting scenes, fixed leg geometry and page bounds, keyboard triggering, repeated taps, completion, reduced motion and off-screen interruption. The production build passes. Static enlarged pose checks were used to refine the elbow curves and shoulder anchors; the site itself keeps the original small character scale.

### Counterweight props and controls — 11 November 2026

The surrounding artwork now uses the articulated character's flat navy and blue palette: blue plates with open centers, solid leaves, a navy bench and simplified ground marks. Paper patterns, folds, cut edges and drop shadows have been removed. Prop positions, illustration frames, scene dimensions and handwritten story copy/type remain unchanged. The existing leaf response targets the new blue leaf.

The read-only routine retains its content and A/B tabs, with a rounded white panel, a flat navy backdrop tint, navy selected tabs and rounded icon controls. Existing navigation wording stays handwritten; blue circular arrow marks replace the thin text arrows. The popup enters with a small, brief rise and respects reduced motion. Background scrolling is locked while it is open, closing restores focus to its opener, and only clicks outside its bounds dismiss it.

The fixed navigation has a white surface to prevent passing artwork from overlapping its controls. On phones, the rhythm heading is inset from the right edge; its font, rotation and vertical placement remain unchanged.

Validation: production build and all 17 existing planner/rig tests pass. Browser checks at 1440×1000, 390×844 and 320×568 covered scene bounds, horizontal overflow, rhythm clearance, A/B keyboard navigation, popup scrolling to the final note, close/Escape/backdrop dismissal, focus restoration, background scroll restoration, and leaf/reduced-motion behavior. Before/after measurements confirm unchanged scene and illustration bounds at desktop and phone sizes. Visual captures are in `output/playwright/counterweight-style/`. Local preview only; no deployment.
