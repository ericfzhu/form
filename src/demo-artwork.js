const artwork = {
  squat: {
    src: "/assets/back-squat-black-figure.png",
    alt: "Ancient Greek black-figure style athlete performing a back squat",
  },
  deadlift: {
    src: "/assets/deadlift-black-figure.png",
    alt: "Ancient Greek black-figure style athlete performing a deadlift",
  },
  press: {
    src: "/assets/shoulder-press-black-figure.png",
    alt: "Ancient Greek black-figure style athlete performing a dumbbell shoulder press",
  },
  rest: {
    src: "/assets/resting-athlete-black-figure.png",
    alt: "Ancient Greek black-figure style athlete resting between efforts",
  },
};

function createArtworkImage({ src, alt }, className = "") {
  const image = document.createElement("img");
  image.src = src;
  image.alt = alt;
  image.width = 1254;
  image.height = 1254;
  image.decoding = "async";
  if (className) image.className = className;
  return image;
}

function replaceHeroFigures() {
  const left = document.querySelector(".hero-figures-left");
  const right = document.querySelector(".hero-figures-right");

  if (left) {
    const panel = document.createElement("div");
    panel.className = "hero-panel hero-panel-left";
    const image = createArtworkImage(artwork.squat, "hero-athlete");
    image.fetchPriority = "high";
    panel.append(image);
    left.replaceWith(panel);
  }

  if (right) {
    const panel = document.createElement("div");
    panel.className = "hero-panel hero-panel-right";
    panel.append(createArtworkImage(artwork.press, "hero-athlete"));
    right.replaceWith(panel);
  }
}

function replaceCourseArtwork() {
  const sources = [artwork.squat, artwork.deadlift, artwork.press];

  document.querySelectorAll("[data-course-panel]").forEach((panel, index) => {
    const scene = panel.querySelector(".black-figure-scene");
    const source = sources[index];
    if (!scene || !source) return;

    const image = createArtworkImage(source);
    if (index > 0) image.loading = "lazy";
    scene.replaceChildren(image);
  });
}

function replaceRestFigure() {
  const rest = document.querySelector(".rest-figure");
  if (!rest) return;

  const image = createArtworkImage(artwork.rest);
  image.loading = "lazy";
  rest.removeAttribute("aria-hidden");
  rest.replaceChildren(image);
}

replaceHeroFigures();
replaceCourseArtwork();
replaceRestFigure();
