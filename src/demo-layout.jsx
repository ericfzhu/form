import React, { useEffect } from "react";
import { NAV_ITEMS } from "./demo-data.js";

export function SectionHeader({ number, eyebrow, title, sequence, tone = "paper" }) {
  return (
    <header className={`section-header section-header--${tone}`}>
      <span className="section-header__number">{number}</span>
      <div className="section-header__copy">
        <p>{eyebrow}</p>
        <h2>{title}</h2>
      </div>
      <span className="section-header__sequence">{sequence}</span>
    </header>
  );
}

export function Header({ menuOpen, setMenuOpen }) {
  useEffect(() => {
    const closeOnEscape = (event) => {
      if (event.key === "Escape") setMenuOpen(false);
    };
    window.addEventListener("keydown", closeOnEscape);
    return () => window.removeEventListener("keydown", closeOnEscape);
  }, [setMenuOpen]);

  return (
    <header className="masthead">
      <a className="brand" href="/demo/" aria-label="Form Attic vessel study home">
        <span className="brand__seal" aria-hidden="true">F</span>
        <span>
          <strong>FORM</strong>
          <small>ATTIC VESSEL STUDY</small>
        </span>
      </a>

      <button
        className="menu-button"
        type="button"
        aria-expanded={menuOpen}
        aria-controls="demo-navigation"
        onClick={() => setMenuOpen((open) => !open)}
      >
        <span>THE STELE</span>
        <span className="menu-button__mark" aria-hidden="true" />
      </button>

      <nav
        id="demo-navigation"
        className={`primary-nav${menuOpen ? " primary-nav--open" : ""}`}
        aria-label="Demo navigation"
      >
        {NAV_ITEMS.map(([number, label, href]) => (
          <a key={href} href={href} onClick={() => setMenuOpen(false)}>
            <span>{number}</span>
            {label}
          </a>
        ))}
      </nav>

      <a className="current-site" href="/">CURRENT SITE <span aria-hidden="true">↗</span></a>
    </header>
  );
}

export function Hero() {
  return (
    <section className="hero" id="proem">
      <div className="hero__copy">
        <p className="inscription">THE PROEM / OF STRENGTH KEPT IN ORDER</p>
        <h1><span>Tell, Muse,</span>of strength remembered.</h1>
        <p className="hero__lede">
          Tell how one task followed another, and how no former deed was lost; for Form
          keeps the returning course, and sets beside each labour the weight borne before.
        </p>
        <a className="outlined-action" href="#course">
          <span>ENTER THE ACCOUNT</span><span aria-hidden="true">↓</span>
        </a>
        <dl className="hero__facts" aria-label="Form essentials">
          <div><dt>I</dt><dd>THE COURSE RETURNS</dd></div>
          <div><dt>II</dt><dd>THE TALLY REMEMBERS</dd></div>
          <div><dt>III</dt><dd>THE REST KEEPS WATCH</dd></div>
        </dl>
      </div>

      <div className="hero__stage">
        <div className="stage-caption"><span>THE DEED APPOINTED</span><span>A → B → C → A</span></div>
        <div className="stage-grid">
          <figure className="figure-panel">
            <img
              src="/assets/back-squat-black-figure.png"
              alt="Ancient Greek black-figure style athlete performing a back squat"
              width="1254"
              height="1254"
              fetchPriority="high"
            />
          </figure>
          <div className="phone-frame" aria-label="Form app train screen">
            <span className="phone-frame__notch" aria-hidden="true" />
            <img
              src="/app-train.webp"
              alt="Form Train screen showing the next workout and workout rotation"
              width="520"
              height="1126"
              fetchPriority="high"
            />
          </div>
          <figure className="figure-panel">
            <img
              src="/assets/shoulder-press-black-figure.png"
              alt="Ancient Greek black-figure style athlete performing a dumbbell shoulder press"
              width="1254"
              height="1254"
            />
          </figure>
        </div>
        <div className="stage-caption"><span>FORM / IPHONE</span><span>THE DEED REMEMBERED</span></div>
      </div>
    </section>
  );
}

export function Footer() {
  return (
    <footer className="footer">
      <div><p>So the course returns.</p><span>ATTIC VESSEL STUDY / © {new Date().getFullYear()}</span></div>
      <nav aria-label="Demo footer">
        <a href="#proem">RETURN TO THE PROEM ↑</a>
        <a href="/">SEE THE CURRENT SITE ↗</a>
      </nav>
    </footer>
  );
}

