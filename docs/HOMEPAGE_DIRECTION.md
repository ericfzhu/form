# Homepage: a little movement

The homepage is an atmospheric illustrated story, not a product presentation. Four scenes: an encounter with a blue paper circle; a loose rhythm of shapes; a rest beneath a folded leaf; and the circle returning. Sparse handwriting, pure white background, fine indigo contours, white cut edges and shallow paper shadows follow the supplied references. There are no feature sections, inventory lists, setup forms, duration controls or workout sheets in the story.

The small persistent “the routine” link opens a separate modal reading view introduced to all visitors as a two-day strength-and-cardio routine. The routine uses the supplied equipment and agreed two-session structure. Both finish with fifteen minutes of treadmill walking. The recorded console settings are speed 5 and incline 7.5; units are explicitly unconfirmed in the reading view. Effort guidance allows reducing speed or incline as needed. Session tabs navigate the prescription; they do not edit it. Old localStorage configuration and swaps are ignored but not deleted. The website is a read-only introduction to the routine, with no download or session-start action. Workout logging belongs in the iOS app. Exact weights remain based on familiar loads and the displayed effort guidance; no strength performance data was supplied.

Original code-native SVG in StoryScenes.jsx supplies the cut pieces and motion. Taps/keyboard activation trigger scene responses. The footer pauses motion; system reduced-motion preference is respected. Gaegu and its OFL license are bundled locally. No runtime font/image CDN dependency, publishing, or iOS changes.

Validation: Vite production build; existing planner tests; browser checks of story, interactions, fixed-workout view and responsive layout.
