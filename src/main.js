import "./styles.css";
import "./roman.css";

const routines = {
  A: {
    focus: "Squat / press / pull",
    title: "Workout A",
    exercise: "Barbell Back Squat",
    target: "3 × 6–10",
    image: "/assets/barbell-back-squat.png",
    progress: "Next / 62.5 kg",
  },
  B: {
    focus: "Hinge / incline / unilateral",
    title: "Workout B",
    exercise: "Conventional Deadlift",
    target: "3 × 5–6",
    image: "/assets/conventional-deadlift.png",
    progress: "90 kg / aim for 6",
  },
  C: {
    focus: "Squat / shoulders / carry",
    title: "Workout C",
    exercise: "Dumbbell Shoulder Press",
    target: "3 × 8–12",
    image: "/assets/shoulder-press.png",
    progress: "Last / 22 kg each",
  },
};

const weeks = [2, 1, 3, 2, 3, 1, 2, 3, 2, 2, 3, 2];
const calendarDays = Array.from({ length: 35 }, (_, index) => {
  const day = index - 2;
  const trained = [1, 4, 8, 11, 15, 18, 22, 25, 29].includes(day);
  return `<span class="calendar-day ${trained ? "trained" : ""} ${day < 1 || day > 31 ? "empty" : ""}">${day > 0 && day <= 31 ? day : ""}</span>`;
}).join("");

document.querySelector("#app").innerHTML = `
  <header class="site-masthead">
    <a class="brand" href="#top" aria-label="Form home">
      <img src="/form-icon.png" alt="" />
      <span>FORM</span>
    </a>
    <nav class="masthead-links" aria-label="Primary navigation">
      <a href="#rotation">ROTATION</a>
      <a href="#logging">LOGGING</a>
      <a href="#progress">PROGRESS</a>
    </nav>
    <span class="masthead-meta">IPHONE / IOS 17+</span>
  </header>

  <main id="top">
    <section class="hero" data-hero>
      <div class="hero-index" aria-hidden="true">FORM / IOS</div>
      <div class="hero-copy reveal">
        <p class="kicker">WORKOUT ROTATION / A—B—C</p>
        <h1>Know what<br /><span>comes next.</span></h1>
        <p class="hero-lede">
          Your next workout. Your last weight. A clear target. Form keeps the record so
          you can keep training.
        </p>
        <a class="raw-button" href="#rotation">
          <span>SEE THE WORKOUTS</span>
          <span aria-hidden="true">↓</span>
        </a>
      </div>

      <div class="hero-stage reveal delay-1" aria-label="Form app workout preview">
        <span class="device-note note-left">CURRENT<br />ROTATION</span>
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
        <span class="device-note note-right">LAST SET<br />READY</span>
      </div>
    </section>

    <div class="ticker" aria-label="Product summary">
      <div class="ticker-track">
        <span><b>I</b> ROTATION / A—B—C</span>
        <span><b>II</b> PREVIOUS LOAD / READY</span>
        <span><b>III</b> REST TIMER / LIVE</span>
      </div>
    </div>

    <section class="feature feature-routines" id="rotation">
      <div class="section-label">
        <span>01</span>
        <span>ROTATION</span>
        <span>A → B → C →</span>
      </div>
      <div class="feature-grid">
        <div class="feature-copy">
          <p class="kicker">ONE DECISION REMOVED</p>
          <h2>Finish one.<br />The next is ready.</h2>
          <p>
            Form holds your place across A, B, and C. Open the app and train what is next.
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
                    tabindex="${index === 0 ? "0" : "-1"}"
                    data-routine="${key}"
                  ><span>${key}</span></button>
                `,
              )
              .join("")}
          </div>
        </div>

        <div
          class="routine-viewport"
          role="region"
          aria-roledescription="carousel"
          aria-label="Workout rotation preview"
        >
          <div class="routine-track">
            ${[...Object.keys(routines), ...Object.keys(routines)]
              .map((key, index) => {
                const routine = routines[key];
                return `
                  <article
                    class="routine-canvas"
                    data-routine-slide="${key}"
                    aria-hidden="${index === 0 ? "false" : "true"}"
                  >
                    <div class="routine-header">
                      <span>${routine.focus}</span>
                      <span class="routine-number">${key}</span>
                    </div>
                    <h3>${routine.title}</h3>
                    <div class="routine-exercise">
                      <img src="${routine.image}" alt="" />
                      <div class="exercise-data">
                        <span class="exercise-target">${routine.target}</span>
                        <h4>${routine.exercise}</h4>
                        <p>${routine.progress}</p>
                      </div>
                    </div>
                  </article>
                `;
              })
              .join("")}
          </div>
        </div>
        <p class="sr-only" id="routine-status" aria-live="polite"></p>
      </div>
    </section>

    <section class="feature feature-log" id="logging">
      <div class="section-label light-label">
        <span>02</span>
        <span>LOGGING</span>
        <span>PREVIOUS → CURRENT</span>
      </div>
      <div class="log-grid">
        <div class="log-copy">
          <p class="kicker">NO MEMORY TEST</p>
          <h2>Last time<br />is already<br />there.</h2>
          <p>
            Weight and reps carry into the next session. Warm-up sets stay separate from
            the work that counts.
          </p>
        </div>

        <div class="set-ledger" aria-label="Example workout set log">
          <div class="ledger-title">
            <span>BARBELL BACK SQUAT</span>
            <span>3 × 6–10</span>
          </div>
          <div class="ledger-head">
            <span>SET</span><span>PREVIOUS</span><span>KG</span><span>REPS</span><span>DONE</span>
          </div>
          <div class="ledger-row warmup-row">
            <span class="set-type">W</span><span>40 × 8</span><strong>40</strong><strong>8</strong><i>✓</i>
          </div>
          <div class="ledger-row">
            <span class="set-type working">1</span><span>60 × 8</span><strong>62.5</strong><strong>8</strong><i>✓</i>
          </div>
          <div class="ledger-row">
            <span class="set-type working">2</span><span>60 × 8</span><strong>62.5</strong><strong>8</strong><i></i>
          </div>
          <div class="ledger-row">
            <span class="set-type working">3</span><span>60 × 7</span><strong>62.5</strong><strong>—</strong><i></i>
          </div>
          <div class="ledger-foot">
            <span>W / WARM-UP</span>
            <span>NEXT TARGET / 62.5 KG × 8</span>
          </div>
        </div>
      </div>
    </section>

    <section class="feature feature-timer" id="timer">
      <div class="section-label dark-label">
        <span>03</span>
        <span>REST</span>
        <span>SCREEN LOCKED / TIMER LIVE</span>
      </div>
      <div class="timer-grid">
        <div class="timer-demo" aria-label="Rest timer Live Activity preview">
          <div class="island">
            <span class="island-mark"></span>
            <span>REST</span>
            <strong id="rest-clock">01:30</strong>
          </div>
          <div class="timer-rule">
            <span>FORM / LIVE ACTIVITY</span>
            <span>LOCK SCREEN + DYNAMIC ISLAND</span>
          </div>
          <div class="giant-clock" aria-hidden="true">01<span>:</span>30</div>
        </div>
        <div class="timer-copy">
          <p class="kicker">PUT THE PHONE DOWN</p>
          <h2>Rest time<br />stays visible.</h2>
          <p>
            Keep the session awake while logging. Lock the screen and rest time stays
            visible in Live Activities and the Dynamic Island.
          </p>
        </div>
      </div>
    </section>

    <section class="feature feature-progress" id="progress">
      <div class="section-label">
        <span>04</span>
        <span>PROGRESSION</span>
        <span>SESSION → WEEK → BLOCK</span>
      </div>
      <div class="progress-heading">
        <p class="kicker">THE RECORD HAS A JOB</p>
        <h2>See the work.<br />Set the next number.</h2>
        <p>
          Review every session, scan training consistency, and see whether weight, reps,
          and volume are moving.
        </p>
      </div>

      <div class="progress-board">
        <div class="calendar-panel">
          <div class="panel-head"><span>JUL / 2026</span><span>9 SESSIONS</span></div>
          <div class="calendar-week"><span>M</span><span>T</span><span>W</span><span>T</span><span>F</span><span>S</span><span>S</span></div>
          <div class="calendar-grid">${calendarDays}</div>
        </div>

        <div class="trend-panel">
          <div class="panel-head"><span>BACK SQUAT</span><span>EST. 1RM / KG</span></div>
          <div class="trend-value"><strong>78.4</strong><span>+6.8 KG / 12 WEEKS</span></div>
          <svg class="trend-chart" viewBox="0 0 600 220" role="img" aria-label="Estimated one rep max rising over twelve weeks">
            <g class="chart-grid" aria-hidden="true">
              <path d="M0 20H600 M0 70H600 M0 120H600 M0 170H600 M0 219H600" />
              <path d="M0 0V220 M150 0V220 M300 0V220 M450 0V220 M599 0V220" />
            </g>
            <path class="trend-line" pathLength="1" d="M0 184 L54 176 L109 181 L163 150 L218 155 L272 132 L327 126 L381 96 L436 104 L490 72 L545 63 L600 38" />
            <circle cx="600" cy="38" r="7" />
          </svg>
        </div>

        <div class="rhythm-panel">
          <div class="panel-head"><span>12 WEEK RHYTHM</span><span>27 / 36</span></div>
          <div class="rhythm-bars">
            ${weeks.map((sessions, index) => `<span style="--sessions:${sessions}" aria-label="Week ${index + 1}: ${sessions} sessions"></span>`).join("")}
          </div>
          <div class="rhythm-foot"><span>W01</span><span>W12</span></div>
        </div>
      </div>
    </section>

    <section class="end-mark">
      <p>FORM</p>
      <a class="raw-button inverted" href="#top"><span>BACK TO TOP</span><span aria-hidden="true">↑</span></a>
    </section>
  </main>

  <footer>
    <span>FORM</span>
    <span>WORKOUT TRACKING FOR IPHONE</span>
    <span>© <span id="year"></span></span>
  </footer>
`;

const tabButtons = document.querySelectorAll(".routine-tab");
const routineKeys = Object.keys(routines);
const routineViewport = document.querySelector(".routine-viewport");
const routineTrack = document.querySelector(".routine-track");
const routineSlides = document.querySelectorAll("[data-routine-slide]");
const routineStatus = document.querySelector("#routine-status");
const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)");
let currentRoutine = "A";
let currentSlideIndex = 0;
let transitionTimer;
let carouselTimer;
let carouselPaused = false;
let isSliding = false;
let pendingSelection;
let announceAfterSlide = false;

function stopCountdown() {
  tabButtons.forEach((button) => button.classList.remove("is-counting"));
}

function startCountdown() {
  const activeButton = document.querySelector(".routine-tab.active");
  if (!activeButton || carouselPaused || document.hidden || reducedMotion.matches) return;
  activeButton.getBoundingClientRect();
  activeButton.classList.add("is-counting");
}

function stopCarousel() {
  window.clearTimeout(carouselTimer);
  stopCountdown();
}

function scheduleCarousel() {
  stopCarousel();
  if (carouselPaused || document.hidden || reducedMotion.matches) return;
  startCountdown();
  carouselTimer = window.setTimeout(() => {
    const currentIndex = routineKeys.indexOf(currentRoutine);
    setRoutine(routineKeys[(currentIndex + 1) % routineKeys.length]);
  }, 3000);
}

function updateRoutineSelection(key) {
  tabButtons.forEach((button) => {
    const selected = button.dataset.routine === key;
    button.classList.toggle("active", selected);
    button.setAttribute("aria-selected", String(selected));
    button.tabIndex = selected ? 0 : -1;
  });

  routineSlides.forEach((slide, index) => {
    slide.setAttribute("aria-hidden", String(index !== routineKeys.indexOf(key)));
  });
}

function getTrackTransform(index) {
  return `translate3d(-${index * 100}%, 0, 0)`;
}

function finishSlide() {
  if (!isSliding) return;
  window.clearTimeout(transitionTimer);

  if (currentSlideIndex >= routineKeys.length) {
    routineTrack.classList.add("is-resetting");
    currentSlideIndex -= routineKeys.length;
    routineTrack.style.transform = getTrackTransform(currentSlideIndex);
    routineTrack.getBoundingClientRect();
    routineTrack.classList.remove("is-resetting");
  }

  isSliding = false;
  if (announceAfterSlide) {
    routineStatus.textContent = `Workout ${currentRoutine} selected`;
    announceAfterSlide = false;
  }
  if (pendingSelection) {
    const nextSelection = pendingSelection;
    pendingSelection = undefined;
    setRoutine(nextSelection.key, { manual: nextSelection.manual });
    return;
  }
  scheduleCarousel();
}

function setRoutine(key, { manual = false } = {}) {
  if (!routines[key]) return;
  if (isSliding) {
    pendingSelection = { key, manual };
    stopCarousel();
    return;
  }
  if (key === currentRoutine) {
    if (manual) scheduleCarousel();
    return;
  }

  stopCarousel();
  const currentKeyIndex = routineKeys.indexOf(currentRoutine);
  const targetKeyIndex = routineKeys.indexOf(key);
  const forwardSteps = (targetKeyIndex - currentKeyIndex + routineKeys.length) % routineKeys.length;
  const slideDuration = forwardSteps === 1 ? 520 : 700;

  currentSlideIndex += forwardSteps;
  currentRoutine = key;
  isSliding = true;
  announceAfterSlide = manual;
  updateRoutineSelection(key);
  routineTrack.style.setProperty("--slide-duration", `${slideDuration}ms`);
  routineTrack.style.transform = getTrackTransform(currentSlideIndex);
  transitionTimer = window.setTimeout(finishSlide, reducedMotion.matches ? 0 : slideDuration + 60);
}

routineTrack.addEventListener("transitionend", (event) => {
  if (event.propertyName === "transform") finishSlide();
});

tabButtons.forEach((button) => {
  button.addEventListener("click", () => setRoutine(button.dataset.routine, { manual: true }));
  button.addEventListener("keydown", (event) => {
    if (event.key !== "ArrowLeft" && event.key !== "ArrowRight") return;
    event.preventDefault();
    const currentIndex = routineKeys.indexOf(button.dataset.routine);
    const direction = event.key === "ArrowRight" ? 1 : -1;
    const nextButton = tabButtons[(currentIndex + direction + routineKeys.length) % routineKeys.length];
    nextButton.focus();
    setRoutine(nextButton.dataset.routine, { manual: true });
  });
});

function pauseCarousel() {
  carouselPaused = true;
  stopCarousel();
}

function resumeCarousel() {
  carouselPaused = false;
  scheduleCarousel();
}

routineViewport.addEventListener("mouseenter", pauseCarousel);
routineViewport.addEventListener("mouseleave", resumeCarousel);
routineViewport.addEventListener("focusin", pauseCarousel);
routineViewport.addEventListener("focusout", resumeCarousel);
document.addEventListener("visibilitychange", scheduleCarousel);
reducedMotion.addEventListener("change", () => {
  if (reducedMotion.matches && isSliding) finishSlide();
  scheduleCarousel();
});
scheduleCarousel();

let restSeconds = 90;
const restClock = document.querySelector("#rest-clock");
window.setInterval(() => {
  if (document.hidden || reducedMotion.matches) return;
  restSeconds = restSeconds <= 0 ? 90 : restSeconds - 1;
  const minutes = String(Math.floor(restSeconds / 60)).padStart(2, "0");
  const seconds = String(restSeconds % 60).padStart(2, "0");
  restClock.textContent = `${minutes}:${seconds}`;
}, 1000);

const revealTargets = document.querySelectorAll(".feature-copy, .log-copy, .set-ledger, .timer-demo, .timer-copy, .progress-heading, .progress-board");
if ("IntersectionObserver" in window && !reducedMotion.matches) {
  const observer = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (!entry.isIntersecting) return;
        entry.target.classList.add("in-view");
        observer.unobserve(entry.target);
      });
    },
    { threshold: 0.16 },
  );
  revealTargets.forEach((target) => observer.observe(target));
} else {
  revealTargets.forEach((target) => target.classList.add("in-view"));
}

document.querySelector("#year").textContent = new Date().getFullYear();
