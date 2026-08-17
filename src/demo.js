import "./demo.css";

const COURSE_INTERVAL = 4600;
const tabs = [...document.querySelectorAll("[data-course-tab]")];
const panels = [...document.querySelectorAll("[data-course-panel]")];
const track = document.querySelector("[data-course-track]");
const windowElement = document.querySelector("[data-course-window]");
const motionControl = document.querySelector("[data-course-motion]");
const motionLabel = document.querySelector("[data-motion-label]");
const nextCourse = document.querySelector("[data-next-course]");
const courseStatus = document.querySelector("[data-course-status]");
const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)");

let activeCourse = 0;
let manuallyPaused = false;
let temporarilyPaused = false;
let courseTimer;
let progressFrame;
let progressStartedAt = 0;

function updateCourse(index, { announce = false } = {}) {
  activeCourse = (index + panels.length) % panels.length;
  track.style.transform = `translate3d(-${activeCourse * (100 / panels.length)}%, 0, 0)`;

  tabs.forEach((tab, tabIndex) => {
    const selected = tabIndex === activeCourse;
    tab.setAttribute("aria-selected", String(selected));
    tab.tabIndex = selected ? 0 : -1;
  });

  panels.forEach((panel, panelIndex) => {
    panel.setAttribute("aria-hidden", String(panelIndex !== activeCourse));
  });

  const courseLetter = String.fromCharCode(65 + activeCourse);
  const nextLetter = String.fromCharCode(65 + ((activeCourse + 1) % panels.length));
  nextCourse.textContent = `THEREAFTER · ${nextLetter}`;
  if (announce) courseStatus.textContent = `Course ${courseLetter} shown`;
}

function stopProgress() {
  cancelAnimationFrame(progressFrame);
  document.documentElement.style.setProperty("--course-progress", "0%");
}

function animateProgress(timestamp) {
  if (!progressStartedAt) progressStartedAt = timestamp;
  const elapsed = timestamp - progressStartedAt;
  const percent = Math.min(100, (elapsed / COURSE_INTERVAL) * 100);
  document.documentElement.style.setProperty("--course-progress", `${percent}%`);
  if (percent < 100) progressFrame = requestAnimationFrame(animateProgress);
}

function shouldAutoplay() {
  return !manuallyPaused && !temporarilyPaused && !document.hidden && !reducedMotion.matches;
}

function stopCourseTimer() {
  clearTimeout(courseTimer);
  stopProgress();
  progressStartedAt = 0;
}

function scheduleCourse() {
  stopCourseTimer();
  renderMotionControl();
  if (!shouldAutoplay()) return;

  progressFrame = requestAnimationFrame(animateProgress);
  courseTimer = window.setTimeout(() => {
    updateCourse(activeCourse + 1);
    scheduleCourse();
  }, COURSE_INTERVAL);
}

function renderMotionControl() {
  const moving = !manuallyPaused;
  motionControl.dataset.state = moving ? "moving" : "paused";
  motionControl.setAttribute("aria-pressed", String(manuallyPaused));
  motionControl.setAttribute(
    "aria-label",
    moving ? "Pause automatic course rotation" : "Resume automatic course rotation",
  );
  motionLabel.textContent = moving ? "STAY THE COURSE" : "LET THE COURSE MOVE";
}

tabs.forEach((tab, index) => {
  tab.addEventListener("click", () => {
    updateCourse(index, { announce: true });
    scheduleCourse();
  });

  tab.addEventListener("keydown", (event) => {
    if (!["ArrowLeft", "ArrowRight", "Home", "End"].includes(event.key)) return;
    event.preventDefault();

    let nextIndex = activeCourse;
    if (event.key === "ArrowLeft") nextIndex -= 1;
    if (event.key === "ArrowRight") nextIndex += 1;
    if (event.key === "Home") nextIndex = 0;
    if (event.key === "End") nextIndex = tabs.length - 1;

    nextIndex = (nextIndex + tabs.length) % tabs.length;
    tabs[nextIndex].focus();
    updateCourse(nextIndex, { announce: true });
    scheduleCourse();
  });
});

motionControl.addEventListener("click", () => {
  manuallyPaused = !manuallyPaused;
  scheduleCourse();
});

windowElement.addEventListener("mouseenter", () => {
  temporarilyPaused = true;
  scheduleCourse();
});

windowElement.addEventListener("mouseleave", () => {
  temporarilyPaused = false;
  scheduleCourse();
});

windowElement.addEventListener("focusin", () => {
  temporarilyPaused = true;
  scheduleCourse();
});

windowElement.addEventListener("focusout", (event) => {
  if (windowElement.contains(event.relatedTarget)) return;
  temporarilyPaused = false;
  scheduleCourse();
});

document.addEventListener("visibilitychange", scheduleCourse);
reducedMotion.addEventListener("change", scheduleCourse);

function installSteleNavigation() {
  const toggle = document.querySelector(".stele-toggle");
  const navigation = document.querySelector(".demo-navigation");
  const masthead = document.querySelector("[data-masthead]");
  if (!toggle || !navigation || !masthead) return;

  const close = () => {
    toggle.setAttribute("aria-expanded", "false");
    navigation.classList.remove("is-open");
  };

  toggle.addEventListener("click", () => {
    const isOpen = toggle.getAttribute("aria-expanded") === "true";
    toggle.setAttribute("aria-expanded", String(!isOpen));
    navigation.classList.toggle("is-open", !isOpen);
  });

  navigation.addEventListener("click", (event) => {
    if (event.target.closest("a")) close();
  });

  document.addEventListener("click", (event) => {
    if (!masthead.contains(event.target)) close();
  });

  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape") close();
  });

  window.matchMedia("(min-width: 801px)").addEventListener("change", (event) => {
    if (event.matches) close();
  });
}

function renderCurrentMonth() {
  const title = document.querySelector("[data-calendar-title]");
  const grid = document.querySelector("[data-calendar-grid]");
  if (!title || !grid) return;

  const now = new Date();
  const year = now.getFullYear();
  const month = now.getMonth();
  const firstDay = new Date(year, month, 1);
  const daysInMonth = new Date(year, month + 1, 0).getDate();
  const leadingBlanks = (firstDay.getDay() + 6) % 7;
  const cellCount = Math.ceil((leadingBlanks + daysInMonth) / 7) * 7;
  const trainedDays = new Set([1, 4, 8, 11, 15, 18, 22, 25, 29].filter((day) => day <= daysInMonth));
  const monthName = new Intl.DateTimeFormat("en", { month: "short" })
    .format(now)
    .toUpperCase();

  title.textContent = `${monthName} / ${year}`;

  grid.innerHTML = Array.from({ length: Math.max(35, cellCount) }, (_, index) => {
    const day = index - leadingBlanks + 1;
    if (day < 1 || day > daysInMonth) {
      return '<span class="calendar-day empty" aria-hidden="true"></span>';
    }

    const date = new Date(year, month, day);
    const dateLabel = new Intl.DateTimeFormat("en", {
      weekday: "long",
      year: "numeric",
      month: "long",
      day: "numeric",
    }).format(date);
    const trained = trainedDays.has(day);

    return `<span class="calendar-day ${trained ? "trained" : ""}" aria-label="${dateLabel}${trained ? ", training session" : ""}">${day}</span>`;
  }).join("");
}

function startRestClock() {
  const islandClock = document.querySelector("[data-rest-clock]");
  const minuteClock = document.querySelector("[data-rest-minutes]");
  const secondClock = document.querySelector("[data-rest-seconds]");
  if (!islandClock || !minuteClock || !secondClock) return;

  let remaining = 90;

  window.setInterval(() => {
    if (document.hidden || reducedMotion.matches) return;
    remaining = remaining <= 0 ? 90 : remaining - 1;
    const minutes = String(Math.floor(remaining / 60)).padStart(2, "0");
    const seconds = String(remaining % 60).padStart(2, "0");
    islandClock.textContent = `${minutes}:${seconds}`;
    minuteClock.textContent = minutes;
    secondClock.textContent = seconds;
  }, 1000);
}

function installReveals() {
  const targets = [...document.querySelectorAll("[data-reveal]")];
  if (!("IntersectionObserver" in window) || reducedMotion.matches) {
    targets.forEach((target) => target.classList.add("is-visible"));
    return;
  }

  const observer = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (!entry.isIntersecting) return;
        entry.target.classList.add("is-visible");
        observer.unobserve(entry.target);
      });
    },
    { threshold: 0.12 },
  );

  targets.forEach((target) => observer.observe(target));
}

function setCurrentYear() {
  document.querySelectorAll("[data-year]").forEach((target) => {
    target.textContent = String(new Date().getFullYear());
  });
}

installSteleNavigation();
renderCurrentMonth();
startRestClock();
installReveals();
setCurrentYear();
updateCourse(0);
scheduleCourse();
