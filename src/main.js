import "./styles.css";

const routines = {
  A: {
    focus: "Squat · press · pull",
    title: "Workout A",
    exercise: "Barbell Back Squat",
    target: "3 × 6–10",
    image: "/assets/barbell-back-squat.png",
    progress: "Increase to 62.5 kg",
  },
  B: {
    focus: "Hinge · incline · unilateral",
    title: "Workout B",
    exercise: "Conventional Deadlift",
    target: "3 × 5–6",
    image: "/assets/conventional-deadlift.png",
    progress: "Hold 90 kg · aim for 6",
  },
  C: {
    focus: "Squat · shoulders · carry",
    title: "Workout C",
    exercise: "Dumbbell Shoulder Press",
    target: "3 × 8–12",
    image: "/assets/shoulder-press.png",
    progress: "22 kg / hand",
  },
};

document.querySelector("#app").innerHTML = `
  <header class="absolute inset-x-0 top-0 z-20">
    <nav
      class="mx-auto flex h-20 w-[min(1180px,calc(100%-48px))] items-center justify-between md:h-24"
      aria-label="Primary navigation"
    >
      <a
        class="group flex min-h-11 items-center gap-3 text-[#1d1d1f]"
        href="#top"
        aria-label="Form home"
      >
        <img
          class="size-9 rounded-[10px] shadow-[0_1px_2px_rgba(0,0,0,0.08),0_5px_14px_rgba(0,0,0,0.08)] outline outline-1 -outline-offset-1 outline-black/10 transition-transform duration-200 ease-out group-hover:-rotate-2 group-active:scale-[0.96]"
          src="/form-icon.png"
          alt=""
        />
        <span class="text-[19px] font-semibold tracking-[-0.035em]">Form</span>
        <span class="hidden h-4 w-px bg-black/10 sm:block" aria-hidden="true"></span>
        <span class="hidden text-xs font-normal tracking-normal text-[#6e6e73] sm:block">
          Workout journal
        </span>
      </a>
      <a
        class="group flex min-h-11 items-center gap-2 text-[13px] font-medium text-[#1d1d1f] transition-colors duration-150 hover:text-[#a4261d] active:scale-[0.96]"
        href="#workouts"
      >
        <span>Workouts</span>
        <span
          class="grid size-6 place-items-center rounded-full bg-black/[0.05] text-[14px] transition-[background-color,transform] duration-200 ease-out group-hover:translate-y-0.5 group-hover:bg-[#a4261d]/10"
          aria-hidden="true"
        >↓</span>
      </a>
    </nav>
  </header>

  <main id="top">
    <section class="hero">
      <div class="hero-copy shell">
        <p class="eyebrow reveal">A workout log for iPhone</p>
        <h1 class="reveal delay-1">Train with clarity.</h1>
        <p class="hero-lede reveal delay-2">
          Your routine, your numbers, and the next sensible step — without the noise.
        </p>
        <div class="hero-actions reveal delay-3">
          <a class="button button-primary" href="#workouts">Explore workouts</a>
        </div>
      </div>

      <div class="hero-stage reveal delay-3" aria-label="Form app workout preview">
        <div class="halo"></div>
        <div class="phone phone-hero">
          <div class="phone-screen">
            <div class="status-bar">
              <span>9:41</span>
              <span class="status-icons">● ᯤ ▰</span>
            </div>
            <div class="app-view">
              <div class="app-topline">
                <span class="red-mark"></span>
                <span>Workout A</span>
                <button type="button" aria-label="Close workout">Close</button>
              </div>
              <div class="exercise-heading">
                <span>01 / 06</span>
                <h2>Barbell<br />Back Squat</h2>
                <p>3 × 6–10</p>
              </div>
              <img class="exercise-art" src="/assets/barbell-back-squat.png" alt="" />
              <div class="set-grid">
                <span>SET</span><span>KG</span><span>REPS</span>
                <strong>1</strong><strong>60</strong><strong>8</strong>
                <strong>2</strong><strong>60</strong><strong>8</strong>
                <strong>3</strong><strong>60</strong><strong>7</strong>
              </div>
              <button class="finish-button" type="button">Finish workout</button>
            </div>
          </div>
        </div>
      </div>
    </section>

    <section class="feature feature-routines" id="workouts">
      <div class="shell feature-grid">
        <div class="feature-copy">
          <p class="eyebrow">Your training, organised</p>
          <h2>One rotation.<br />Three deliberate sessions.</h2>
          <p>
            Move naturally through A, B, and C. Form remembers where you left off and keeps
            the next workout ready.
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
            <div>
              <span id="routine-focus">${routines.A.focus}</span>
              <h3 id="routine-title">${routines.A.title}</h3>
            </div>
            <span class="routine-number" id="routine-number">A</span>
          </div>
          <div class="routine-exercise">
            <img id="routine-image" src="${routines.A.image}" alt="" />
            <div>
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

function setRoutine(key) {
  const routine = routines[key];
  routineCanvas.classList.add("changing");

  window.setTimeout(() => {
    document.querySelector("#routine-focus").textContent = routine.focus;
    document.querySelector("#routine-title").textContent = routine.title;
    document.querySelector("#routine-number").textContent = key;
    document.querySelector("#routine-image").src = routine.image;
    document.querySelector("#routine-target").textContent = routine.target;
    document.querySelector("#routine-exercise").textContent = routine.exercise;
    document.querySelector("#routine-progress").textContent = routine.progress;
    routineCanvas.classList.remove("changing");
  }, 140);

  tabButtons.forEach((button) => {
    const selected = button.dataset.routine === key;
    button.classList.toggle("active", selected);
    button.setAttribute("aria-selected", String(selected));
  });
}

tabButtons.forEach((button) => {
  button.addEventListener("click", () => setRoutine(button.dataset.routine));
});

document.querySelector("#year").textContent = new Date().getFullYear();
