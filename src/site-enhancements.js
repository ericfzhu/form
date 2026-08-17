import "./site-enhancements.css";

const COURSE_LINKS = [
  ["I", "THE COURSE", "#rotation"],
  ["II", "THE TALLY", "#logging"],
  ["III", "THE WITNESS", "#progress"],
  ["IV", "THE MAKING", "#setup"],
];

function installMobileNavigation() {
  const masthead = document.querySelector(".site-masthead");
  if (!masthead || masthead.querySelector(".mobile-menu-toggle")) return;

  const toggle = document.createElement("button");
  toggle.className = "mobile-menu-toggle";
  toggle.type = "button";
  toggle.setAttribute("aria-expanded", "false");
  toggle.setAttribute("aria-controls", "mobile-primary-navigation");
  toggle.innerHTML = `
    <span>THE TABLET</span>
    <span class="mobile-menu-glyph" aria-hidden="true">≡</span>
  `;

  const panel = document.createElement("nav");
  panel.id = "mobile-primary-navigation";
  panel.className = "mobile-menu-panel";
  panel.setAttribute("aria-label", "Primary navigation");
  panel.hidden = true;
  panel.innerHTML = COURSE_LINKS.map(
    ([index, label, href]) => `
      <a href="${href}">
        <span aria-hidden="true">${index}</span>
        <strong>${label}</strong>
      </a>
    `,
  ).join("");

  const close = () => {
    panel.hidden = true;
    toggle.setAttribute("aria-expanded", "false");
    masthead.classList.remove("mobile-menu-open");
  };

  const open = () => {
    panel.hidden = false;
    toggle.setAttribute("aria-expanded", "true");
    masthead.classList.add("mobile-menu-open");
  };

  toggle.addEventListener("click", () => {
    if (toggle.getAttribute("aria-expanded") === "true") {
      close();
    } else {
      open();
    }
  });

  panel.addEventListener("click", (event) => {
    if (event.target.closest("a")) close();
  });

  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape") close();
  });

  document.addEventListener("click", (event) => {
    if (!masthead.contains(event.target)) close();
  });

  window.matchMedia("(min-width: 701px)").addEventListener("change", (event) => {
    if (event.matches) close();
  });

  masthead.append(toggle, panel);
}

function installCourseMotionControl() {
  const timing = document.querySelector(".rotation-timing");
  const viewport = document.querySelector(".routine-viewport");
  if (!timing || !viewport || document.querySelector(".course-motion-control")) return;

  let manuallyPaused = false;
  const control = document.createElement("button");
  control.className = "course-motion-control";
  control.type = "button";
  control.setAttribute("aria-pressed", "false");
  control.setAttribute("aria-label", "Pause automatic course rotation");
  control.innerHTML = `
    <span class="course-motion-mark" aria-hidden="true">Ⅱ</span>
    <span data-course-motion-label>STAY THE COURSE</span>
  `;

  const pause = () => {
    viewport.dispatchEvent(new Event("mouseenter"));
  };

  const resume = () => {
    viewport.dispatchEvent(new Event("mouseleave"));
  };

  const render = () => {
    control.setAttribute("aria-pressed", String(manuallyPaused));
    control.setAttribute(
      "aria-label",
      manuallyPaused ? "Resume automatic course rotation" : "Pause automatic course rotation",
    );
    control.querySelector("[data-course-motion-label]").textContent = manuallyPaused
      ? "LET THE COURSE MOVE"
      : "STAY THE COURSE";
    control.classList.toggle("is-paused", manuallyPaused);
  };

  control.addEventListener("click", () => {
    manuallyPaused = !manuallyPaused;
    if (manuallyPaused) pause();
    else resume();
    render();
  });

  const preserveManualPause = () => {
    if (manuallyPaused) queueMicrotask(pause);
  };

  viewport.addEventListener("mouseleave", preserveManualPause);
  viewport.addEventListener("focusout", preserveManualPause);
  document.addEventListener("visibilitychange", () => {
    if (!document.hidden) preserveManualPause();
  });

  timing.insertAdjacentElement("afterend", control);
  render();
}

function renderCurrentMonth() {
  const header = document.querySelector(".calendar-panel .panel-head span:first-child");
  const grid = document.querySelector(".calendar-grid");
  if (!header || !grid) return;

  const now = new Date();
  const year = now.getFullYear();
  const month = now.getMonth();
  const firstDay = new Date(year, month, 1);
  const daysInMonth = new Date(year, month + 1, 0).getDate();
  const leadingBlanks = (firstDay.getDay() + 6) % 7;
  const cellCount = Math.max(35, Math.ceil((leadingBlanks + daysInMonth) / 7) * 7);
  const trainedDays = new Set([1, 4, 8, 11, 15, 18, 22, 25, 29].filter((day) => day <= daysInMonth));
  const monthName = new Intl.DateTimeFormat("en", { month: "short" })
    .format(now)
    .toUpperCase();

  header.textContent = `${monthName} / ${year}`;
  grid.dataset.currentMonth = `${year}-${String(month + 1).padStart(2, "0")}`;
  grid.innerHTML = Array.from({ length: cellCount }, (_, index) => {
    const day = index - leadingBlanks + 1;
    if (day < 1 || day > daysInMonth) {
      return '<span class="calendar-day empty" aria-hidden="true"></span>';
    }

    const date = new Date(year, month, day);
    const label = new Intl.DateTimeFormat("en", {
      weekday: "long",
      year: "numeric",
      month: "long",
      day: "numeric",
    }).format(date);
    const trained = trainedDays.has(day);
    return `<span class="calendar-day ${trained ? "trained" : ""}" aria-label="${label}${trained ? ", training session" : ""}">${day}</span>`;
  }).join("");
}

function tuneProductImages() {
  document.querySelectorAll(".routine-exercise img").forEach((image) => {
    image.loading = "lazy";
    image.decoding = "async";
    image.fetchPriority = "low";
    image.width = 512;
    image.height = 512;
    image.sizes = "(max-width: 700px) 82vw, (max-width: 980px) 52vw, 38vw";
  });

  const screenshot = document.querySelector(".app-screenshot");
  if (screenshot) {
    screenshot.decoding = "async";
    screenshot.fetchPriority = "high";
  }
}

installMobileNavigation();
installCourseMotionControl();
renderCurrentMonth();
tuneProductImages();
