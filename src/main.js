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
                    tabindex="${index === 0 ? "0" : "-1"}"
                    data-routine="${key}"
                  >${key}</button>
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
                      <div>
                        <span>${routine.focus}</span>
                        <h3>${routine.title}</h3>
                      </div>
                      <span class="routine-number">${key}</span>
                    </div>
                    <div class="routine-exercise">
                      <img src="${routine.image}" alt="" />
                      <div>
                        <span>${routine.target}</span>
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

  </main>

  <footer>
    <div class="shell footer-inner">
      <span>Form</span>
      <span>© <span id="year"></span> Form. All rights reserved.</span>
    </div>
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

function stopCarousel() {
  window.clearTimeout(carouselTimer);
}

function scheduleCarousel() {
  stopCarousel();

  if (carouselPaused || document.hidden || reducedMotion.matches) return;

  carouselTimer = window.setTimeout(() => {
    const currentIndex = routineKeys.indexOf(currentRoutine);
    const nextKey = routineKeys[(currentIndex + 1) % routineKeys.length];
    setRoutine(nextKey);
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
    const isPrimarySelected = index === routineKeys.indexOf(key);
    slide.setAttribute("aria-hidden", String(!isPrimarySelected));
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
  const slideDuration = forwardSteps === 1 ? 620 : 820;

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
    const nextIndex = (currentIndex + direction + routineKeys.length) % routineKeys.length;
    const nextButton = tabButtons[nextIndex];
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

document.addEventListener("visibilitychange", scheduleCarousel);
reducedMotion.addEventListener("change", () => {
  if (reducedMotion.matches && isSliding) finishSlide();
  scheduleCarousel();
});
scheduleCarousel();

const hero = document.querySelector("[data-hero]");
const masthead = document.querySelector(".site-masthead");
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
