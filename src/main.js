import "./styles.css";
import "./roman.css";

const routines = {
  A: {
    focus: "Squat / press / pull",
    title: "The First Labour",
    exercise: "Barbell Back Squat",
    target: "3 × 6–10",
    image: "/assets/barbell-back-squat.png",
    progress: "Appointed load · 62.5 kg",
  },
  B: {
    focus: "Hinge / incline / unilateral",
    title: "The Second Labour",
    exercise: "Conventional Deadlift",
    target: "3 × 5–6",
    image: "/assets/conventional-deadlift.png",
    progress: "Appointed load · 90 kg × 6",
  },
  C: {
    focus: "Squat / shoulders / carry",
    title: "The Third Labour",
    exercise: "Dumbbell Shoulder Press",
    target: "3 × 8–12",
    image: "/assets/shoulder-press.png",
    progress: "Former load · 22 kg / hand",
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
      <a href="#rotation">ORDER</a>
      <a href="#logging">LEDGER</a>
      <a href="#progress">RECORD</a>
      <a href="#setup">INSTALL</a>
    </nav>
    <span class="masthead-meta">IPHONE / IOS 17+</span>
  </header>

  <main id="top">
    <section class="hero" data-hero>
      <div class="hero-index" aria-hidden="true">FORM / IOS</div>
      <div class="hero-copy reveal">
        <p class="kicker">THE ORDER / A · B · C</p>
        <h1>Take up the work<br /><span>where you left it.</span></h1>
        <p class="hero-lede">
          Each session follows the one before it. Form keeps your place and brings
          the measure of your former effort into the work ahead.
        </p>
        <a class="raw-button" href="#rotation">
          <span>SEE THE ORDER</span>
          <span aria-hidden="true">↓</span>
        </a>
      </div>

      <div class="hero-stage reveal delay-1" aria-label="Form app workout preview">
        <span class="device-note note-left">YOUR PLACE<br />IN THE ORDER</span>
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
        <span class="device-note note-right">FORMER<br />LOAD</span>
      </div>
    </section>

    <div class="ticker" aria-label="Product summary">
      <div class="ticker-track">
        <span><b>I</b> THE ORDER / A · B · C</span>
        <span><b>II</b> FORMER LOAD / HELD IN MEMORY</span>
        <span><b>III</b> REST / THE COUNT ENDURES</span>
      </div>
    </div>

    <section class="feature feature-routines" id="rotation">
      <div class="section-label">
        <span>01</span>
        <span>THE ORDER</span>
        <span>A → B → C →</span>
      </div>
      <div class="feature-grid">
        <div class="feature-copy">
          <p class="kicker">THE THREE LABOURS</p>
          <h2>Finish the work before you.<br />Then take up the next.</h2>
          <p>
            A gives way to B, and B to C. Form remembers your place, even when many
            days lie between one session and the next.
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
          <div class="rotation-timing" aria-hidden="true">
            <span class="rotation-next">NEXT LABOUR · B</span>
            <span class="rotation-meter"><i></i></span>
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
        <span>THE LEDGER</span>
        <span>FORMER → PRESENT</span>
      </div>
      <div class="log-grid">
        <div class="log-copy">
          <p class="kicker">WHAT CAME BEFORE</p>
          <h2>Let the former effort<br />stand beside the present.</h2>
          <p>
            The last weight and repetitions return when the exercise comes again.
            Preparatory sets remain apart from the work itself.
          </p>
        </div>

        <div class="set-ledger" aria-label="Example workout set log">
          <div class="ledger-title">
            <span>BARBELL BACK SQUAT</span>
            <span>3 × 6–10</span>
          </div>
          <div class="ledger-head">
            <span>SET</span><span>FORMER</span><span>KG</span><span>REPS</span><span>DONE</span>
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
            <span>APPOINTED NEXT / 62.5 KG × 8</span>
          </div>
        </div>
      </div>
    </section>

    <section class="feature feature-timer" id="timer">
      <div class="section-label dark-label">
        <span>03</span>
        <span>REST</span>
        <span>SCREEN LOCKED / COUNT UNBROKEN</span>
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
          <p class="kicker">THE MEASURE OF REST</p>
          <h2>Rest without<br />losing the count.</h2>
          <p>
            While you record the work, the screen remains wakeful. Lock it, and the
            count continues in the Live Activity and Dynamic Island.
          </p>
        </div>
      </div>
    </section>

    <section class="feature feature-progress" id="progress">
      <div class="section-label">
        <span>04</span>
        <span>THE RECORD</span>
        <span>SESSION → WEEK → BLOCK</span>
      </div>
      <div class="progress-heading">
        <p class="kicker">DEEDS KEPT IN ORDER</p>
        <h2>Read what has been done.<br />Judge what comes next.</h2>
        <p>
          Every session takes its place in the record. Across the weeks, the figures
          reveal whether load, repetitions and volume are rising or standing still.
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
          <div class="panel-head"><span>12-WEEK CONSISTENCY</span><span>27 / 36</span></div>
          <div class="rhythm-bars">
            ${weeks.map((sessions, index) => `<span style="--sessions:${sessions}" aria-label="Week ${index + 1}: ${sessions} sessions"></span>`).join("")}
          </div>
          <div class="rhythm-foot"><span>W01</span><span>W12</span></div>
        </div>
      </div>
    </section>

    <section class="feature feature-setup" id="setup">
      <div class="section-label">
        <span>05</span>
        <span>INSTALLATION</span>
        <span>MAC → XCODE → IPHONE</span>
      </div>

      <div class="setup-grid">
        <div class="setup-intro">
          <p class="kicker">BRING IT TO YOUR DEVICE</p>
          <h2>Install Form on<br />your iPhone.</h2>
          <p>
            Form comes to the iPhone through Xcode. You will need a Mac, an Apple
            Account and an iPhone running iOS 17 or later.
          </p>
          <a
            class="raw-button setup-source"
            href="https://github.com/ericfzhu/form"
            target="_blank"
            rel="noreferrer"
          >
            <span>OPEN THE SOURCE</span>
            <span aria-hidden="true">↗</span>
          </a>
        </div>

        <div class="setup-ledger">
          <ol class="setup-steps">
            <li>
              <span class="setup-numeral">I</span>
              <div>
                <p class="setup-step-label">SOURCE</p>
                <h3>Download the project.</h3>
                <p>
                  Install Xcode 16 or later from the Mac App Store. Download Form from
                  GitHub, then open <code>Form.xcodeproj</code>.
                </p>
              </div>
            </li>
            <li>
              <span class="setup-numeral">II</span>
              <div>
                <p class="setup-step-label">SIGNING</p>
                <h3>Choose your Personal Team.</h3>
                <p>
                  In the Form target, open Signing &amp; Capabilities and select your
                  Apple Account. If Xcode asks, give the app a unique bundle identifier.
                </p>
              </div>
            </li>
            <li>
              <span class="setup-numeral">III</span>
              <div>
                <p class="setup-step-label">DEVICE</p>
                <h3>Connect your iPhone.</h3>
                <p>
                  Connect it to the Mac, approve Trust, and select it as the run
                  destination. Enable Developer Mode under Privacy &amp; Security if prompted.
                </p>
              </div>
            </li>
            <li>
              <span class="setup-numeral">IV</span>
              <div>
                <p class="setup-step-label">INSTALL</p>
                <h3>Press Run in Xcode.</h3>
                <p>
                  Xcode builds and installs Form. If iOS reports an untrusted developer,
                  approve your Apple Account under VPN &amp; Device Management.
                </p>
              </div>
            </li>
            <li>
              <span class="setup-numeral">V</span>
              <div>
                <p class="setup-step-label">HEALTH</p>
                <h3>Connect Apple Health.</h3>
                <p>
                  In Form, open Train and press Connect under Apple Health. Allow workout
                  writing and body-weight reading.
                </p>
              </div>
            </li>
          </ol>

          <div class="signing-note">
            <span>FREE SIGNING</span>
            <p>
              A Personal Team installation expires after seven days. Reconnect your
              iPhone and press Run in Xcode to renew it; your on-device data remains in place.
            </p>
          </div>
        </div>
      </div>
    </section>

    <section class="end-mark">
      <div class="end-signature">
        <p>FORM</p>
        <span class="end-year">© <span id="year"></span></span>
      </div>
      <a class="raw-button inverted" href="#top"><span>RETURN TO THE BEGINNING</span><span aria-hidden="true">↑</span></a>
    </section>
  </main>
`;

const tabButtons = document.querySelectorAll(".routine-tab");
const routineKeys = Object.keys(routines);
const rotationTiming = document.querySelector(".rotation-timing");
const rotationNext = document.querySelector(".rotation-next");
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
  rotationTiming.classList.remove("is-counting");
}

function startCountdown() {
  const activeButton = document.querySelector(".routine-tab.active");
  if (!activeButton || carouselPaused || document.hidden || reducedMotion.matches) return;
  rotationTiming.getBoundingClientRect();
  activeButton.classList.add("is-counting");
  rotationTiming.classList.add("is-counting");
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
  const nextIndex = (routineKeys.indexOf(key) + 1) % routineKeys.length;
  rotationNext.textContent = `NEXT LABOUR · ${routineKeys[nextIndex]}`;
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
    routineStatus.textContent = `Labour ${currentRoutine} selected`;
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

const revealTargets = document.querySelectorAll(".feature-copy, .log-copy, .set-ledger, .timer-demo, .timer-copy, .progress-heading, .progress-board, .setup-intro, .setup-ledger");
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
