import "./styles.css";

const routines = {
  A: {
    focus: "Squat · press · pull",
    title: "Workout A",
    exercise: "Barbell Back Squat",
    target: "3 × 6-10",
    image: "/assets/barbell-back-squat.png",
    progress: "Next: 62.5 kg",
  },
  B: {
    focus: "Hinge · incline · unilateral",
    title: "Workout B",
    exercise: "Conventional Deadlift",
    target: "3 × 5-6",
    image: "/assets/conventional-deadlift.png",
    progress: "Repeat 90 kg, aim for 6 reps",
  },
  C: {
    focus: "Squat · shoulders · carry",
    title: "Workout C",
    exercise: "Dumbbell Shoulder Press",
    target: "3 × 8-12",
    image: "/assets/shoulder-press.png",
    progress: "Last used: 22 kg each",
  },
};

document.querySelector("#app").innerHTML = `
  <header class="site-masthead fixed inset-x-0 top-0 z-30">
    <nav
      class="masthead-nav mx-auto flex items-center justify-between"
      aria-label="Primary navigation"
    >
      <a
        class="group flex min-h-11 items-center gap-3 text-[#1d1d1f]"
        href="#top"
        aria-label="Form home"
      >
        <img
          class="brand-icon size-9 rounded-[10px] shadow-[0_1px_2px_rgba(0,0,0,0.08),0_5px_14px_rgba(0,0,0,0.08)] outline outline-1 -outline-offset-1 outline-black/10 transition-transform duration-200 ease-out group-hover:-rotate-2 group-active:scale-[0.96]"
          src="/form-icon.png"
          alt=""
        />
        <span class="text-[19px] font-semibold tracking-[-0.035em]">Form</span>
        <span class="brand-divider hidden h-4 w-px bg-black/10 sm:block" aria-hidden="true"></span>
        <span class="brand-context hidden text-xs font-normal tracking-normal text-[#6e6e73] sm:block">
          Workout log
        </span>
      </a>
      <a
        class="group flex min-h-11 items-center gap-2 text-[13px] font-medium text-[#1d1d1f] transition-colors duration-150 hover:text-[#a4261d] active:scale-[0.96]"
        href="#workouts"
      >
        <span>How it works</span>
      </a>
    </nav>
  </header>

  <main id="top">
    <section class="hero" data-hero>
      <div class="hero-copy shell">
        <p class="eyebrow reveal">Workout tracking for iPhone</p>
        <h1 class="reveal delay-1">Pick up where you left off.</h1>
        <p class="hero-lede reveal delay-2">
          Form opens to your next workout, with your previous weights and reps ready when
          you need them.
        </p>
        <div class="hero-actions reveal delay-3">
          <a class="button button-primary form-cta" href="#workouts">
            <span>See how it works</span>
            <span class="form-cta-mark" aria-hidden="true">↓</span>
          </a>
        </div>
      </div>

      <div class="hero-stage reveal delay-3" aria-label="Form app workout preview">
        <div class="halo"></div>
        <div class="device-wrap">
          <div class="phone phone-hero">
            <div class="phone-screen">
              <img
                class="app-screenshot"
                src="/app-train.webp"
                alt="Form Train screen showing the next workout and workout rotation"
                loading="eager"
                decoding="async"
              />
            </div>
          </div>
        </div>
      </div>
    </section>

    <section class="feature feature-routines" id="workouts">
      <div class="shell feature-grid">
        <div class="feature-copy">
          <p class="eyebrow">A simple A/B/C rotation</p>
          <h2>Finish one workout.<br />Form queues the next.</h2>
          <p>
            Form keeps your place in the rotation. Open an exercise to see the weight and
            reps you logged last time, along with the target for this session.
          </p>
          <div class="routine-tabs" role="tablist" aria-label="Choose a workout">
            ${Object.keys(routines)
              .map(
                (key, index) => `
                  <button
                    class="routine-tab ${index === 0 ? "active" : ""}"
                    type="button"
                    role="tab"
                    aria-selected="${index === 0}"
                    data-routine="${key}"
                  >${key}</button>
                `,
              )
              .join("")}
          </div>
        </div>

        <div class="routine-canvas" aria-live="polite">
          <div class="routine-header">
            <div class="routine-part routine-meta">
              <span id="routine-focus">${routines.A.focus}</span>
              <h3 id="routine-title">${routines.A.title}</h3>
            </div>
            <span class="routine-number routine-part" id="routine-number">A</span>
          </div>
          <div class="routine-exercise">
            <img class="routine-part routine-art" id="routine-image" src="${routines.A.image}" alt="" />
            <div class="routine-part routine-details">
              <span id="routine-target">${routines.A.target}</span>
              <h4 id="routine-exercise">${routines.A.exercise}</h4>
              <p id="routine-progress">${routines.A.progress}</p>
            </div>
          </div>
        </div>
      </div>
    </section>

  </main>

  <footer>
    <div class="shell footer-inner">
      <span>Form</span>
      <span>© <span id="year"></span> Form. All rights reserved.</span>
    </div>
  </footer>
`;

const tabButtons = document.querySelectorAll(".routine-tab");
const routineCanvas = document.querySelector(".routine-canvas");
let currentRoutine = "A";
let routineTimer;

function setRoutine(key) {
  if (key === currentRoutine) return;

  const routine = routines[key];
  window.clearTimeout(routineTimer);
  routineCanvas.classList.add("changing");

  routineTimer = window.setTimeout(() => {
    document.querySelector("#routine-focus").textContent = routine.focus;
    document.querySelector("#routine-title").textContent = routine.title;
    document.querySelector("#routine-number").textContent = key;
    document.querySelector("#routine-image").src = routine.image;
    document.querySelector("#routine-target").textContent = routine.target;
    document.querySelector("#routine-exercise").textContent = routine.exercise;
    document.querySelector("#routine-progress").textContent = routine.progress;
    currentRoutine = key;
    routineCanvas.classList.remove("changing");
  }, 180);

  tabButtons.forEach((button) => {
    const selected = button.dataset.routine === key;
    button.classList.toggle("active", selected);
    button.setAttribute("aria-selected", String(selected));
  });
}

tabButtons.forEach((button) => {
  button.addEventListener("click", () => setRoutine(button.dataset.routine));
});

const hero = document.querySelector("[data-hero]");
const masthead = document.querySelector(".site-masthead");
const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)");
let scrollFrameRequested = false;

function updateScrollStory() {
  scrollFrameRequested = false;
  const heroBounds = hero.getBoundingClientRect();
  const travel = Math.max(hero.offsetHeight - window.innerHeight, 1);
  const progress = Math.min(Math.max(-heroBounds.top / travel, 0), 1);

  hero.style.setProperty("--hero-progress", reducedMotion.matches ? "0" : progress.toFixed(3));
  masthead.classList.toggle("compact", window.scrollY > 48);
}

function requestScrollUpdate() {
  if (scrollFrameRequested) return;
  scrollFrameRequested = true;
  window.requestAnimationFrame(updateScrollStory);
}

window.addEventListener("scroll", requestScrollUpdate, { passive: true });
window.addEventListener("resize", requestScrollUpdate);
reducedMotion.addEventListener("change", requestScrollUpdate);
updateScrollStory();

document.querySelector("#year").textContent = new Date().getFullYear();
