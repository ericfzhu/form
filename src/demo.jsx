import React, { useState } from "react";
import { createRoot } from "react-dom/client";
import "./demo.css";
import "./demo-sections.css";
import "./demo-responsive.css";
import { Footer, Header, Hero } from "./demo-layout.jsx";
import { CourseSection, MakingSection, RestSection, TallySection, WitnessSection } from "./demo-sections.jsx";
import useReducedMotion from "./use-reduced-motion.js";

function App() {
  const [menuOpen, setMenuOpen] = useState(false);
  const reducedMotion = useReducedMotion();

  return (
    <>
      <a className="skip-link" href="#course">Skip to the course</a>
      <Header menuOpen={menuOpen} setMenuOpen={setMenuOpen} />
      <div className="ornament-band" aria-hidden="true" />
      <main>
        <Hero />
        <div className="register-band" aria-hidden="true">COURSE · TALLY · REST · WITNESS · RETURN</div>
        <CourseSection reducedMotion={reducedMotion} />
        <TallySection />
        <RestSection />
        <WitnessSection />
        <MakingSection />
      </main>
      <Footer />
    </>
  );
}

createRoot(document.getElementById("root")).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
);
