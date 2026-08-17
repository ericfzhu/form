export const NAV_ITEMS = [
  ["I", "The course", "#course"],
  ["II", "The tally", "#tally"],
  ["III", "The rest", "#rest"],
  ["IV", "The witness", "#witness"],
  ["V", "The making", "#making"],
];

export const COURSES = [
  {
    id: "A",
    sequence: "Squat / Press / Pull",
    title: "Barbell Back Squat",
    image: "/assets/back-squat-black-figure.png",
    alt: "Ancient Greek black-figure style athlete performing a back squat",
    order: "3 × 6–10",
    before: "60 kg × 8",
    appointed: "62.5 kg × 8",
  },
  {
    id: "B",
    sequence: "Hinge / Incline / Unilateral",
    title: "Conventional Deadlift",
    image: "/assets/deadlift-black-figure.png",
    alt: "Ancient Greek black-figure style athlete performing a deadlift",
    order: "3 × 5–6",
    before: "87.5 kg × 6",
    appointed: "90 kg × 6",
  },
  {
    id: "C",
    sequence: "Squat / Shoulders / Carry",
    title: "Dumbbell Shoulder Press",
    image: "/assets/shoulder-press-black-figure.png",
    alt: "Ancient Greek black-figure style athlete performing a dumbbell shoulder press",
    order: "3 × 8–12",
    before: "20 kg / hand",
    appointed: "22 kg / hand",
  },
];

export const MAKING_STEPS = [
  ["I", "The source", "Take up the work at its beginning.", "Install Xcode, draw Form down from GitHub, and open Form.xcodeproj."],
  ["II", "The seal", "Set your name upon the work.", "Choose your signing team and use a bundle identifier belonging to you."],
  ["III", "The joining", "Bind the iPhone to the Mac.", "Grant Trust, choose the device, and enable Developer Mode when asked."],
  ["IV", "The awakening", "Give the command to Run.", "Xcode builds Form and places it upon the iPhone."],
];

export const STRENGTH_POINTS = [38, 42, 40, 53, 51, 63, 67, 77, 74, 86, 90, 96];
export const CONSISTENCY = [2, 1, 3, 2, 3, 1, 2, 3, 2, 2, 3, 2];
export const COURSE_INTERVAL_MS = 5200;

export function formatClock(totalSeconds) {
  const minutes = String(Math.floor(totalSeconds / 60)).padStart(2, "0");
  const seconds = String(totalSeconds % 60).padStart(2, "0");
  return `${minutes}:${seconds}`;
}

export function buildCalendar(referenceDate) {
  const year = referenceDate.getFullYear();
  const month = referenceDate.getMonth();
  const firstDay = new Date(year, month, 1);
  const daysInMonth = new Date(year, month + 1, 0).getDate();
  const leadingBlanks = (firstDay.getDay() + 6) % 7;
  const cellCount = Math.max(35, Math.ceil((leadingBlanks + daysInMonth) / 7) * 7);
  const trainedDays = new Set([1, 4, 8, 11, 15, 18, 22, 25, 29].filter((day) => day <= daysInMonth));

  return {
    title: new Intl.DateTimeFormat("en", { month: "short", year: "numeric" })
      .format(referenceDate)
      .replace(" ", " / ")
      .toUpperCase(),
    cells: Array.from({ length: cellCount }, (_, index) => {
      const day = index - leadingBlanks + 1;
      if (day < 1 || day > daysInMonth) return null;
      return {
        day,
        trained: trainedDays.has(day),
        label: new Intl.DateTimeFormat("en", {
          weekday: "long",
          year: "numeric",
          month: "long",
          day: "numeric",
        }).format(new Date(year, month, day)),
      };
    }),
  };
}
