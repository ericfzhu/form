import React, { useEffect, useMemo, useState } from "react";
import {
  buildCalendar,
  CONSISTENCY,
  COURSE_INTERVAL_MS,
  COURSES,
  formatClock,
  MAKING_STEPS,
  STRENGTH_POINTS,
} from "./demo-data.js";
import { SectionHeader } from "./demo-layout.jsx";

export function CourseSection({ reducedMotion }) {
  const [activeCourse, setActiveCourse] = useState(0);
  const [paused, setPaused] = useState(false);

  useEffect(() => {
    if (paused || reducedMotion) return undefined;
    const timer = window.setInterval(
      () => setActiveCourse((current) => (current + 1) % COURSES.length),
      COURSE_INTERVAL_MS,
    );
    return () => window.clearInterval(timer);
  }, [paused, reducedMotion]);

  const course = COURSES[activeCourse];
  const nextCourse = COURSES[(activeCourse + 1) % COURSES.length].id;

  return (
    <section className="course-section" id="course">
      <SectionHeader
        number="I"
        eyebrow="THE RETURNING COURSE"
        title="One labour yields, and another rises."
        sequence="A → B → C → A"
      />
      <div className="split-layout">
        <div className="section-copy">
          <p className="inscription">THUS THE COURSE RETURNS</p>
          <p>
            First comes A, and after A comes B, and C follows B in its appointed hour.
            Then the course bends homeward to A; Form forgets not where the athlete ceased.
          </p>
          <div className="course-tabs" aria-label="Choose a workout course">
            {COURSES.map((item, index) => (
              <button
                key={item.id}
                type="button"
                aria-pressed={activeCourse === index}
                onClick={() => setActiveCourse(index)}
              >
                {item.id}
              </button>
            ))}
          </div>
          <p className="next-course">THEREAFTER · {nextCourse}</p>
          <button
            className="motion-control"
            type="button"
            aria-pressed={paused}
            aria-label={paused ? "Resume automatic course rotation" : "Pause automatic course rotation"}
            onClick={() => setPaused((value) => !value)}
          >
            <span className={`motion-control__symbol ${paused ? "motion-control__symbol--play" : ""}`} aria-hidden="true" />
            <span>{paused ? "LET THE COURSE MOVE" : "STAY THE COURSE"}</span>
          </button>
        </div>

        <article className="course-card" aria-live="polite">
          <header className="course-card__header">
            <span>{course.sequence.toUpperCase()}</span><strong>{course.id}</strong>
          </header>
          <div className="course-card__artwork">
            <img src={course.image} alt={course.alt} width="1254" height="1254" />
          </div>
          <div className="course-card__account">
            <span>THE {activeCourse === 0 ? "FIRST" : activeCourse === 1 ? "SECOND" : "THIRD"} COURSE</span>
            <h3>{course.title}</h3>
            <dl>
              <div><dt>ORDER</dt><dd>{course.order}</dd></div>
              <div><dt>BEFORE</dt><dd>{course.before}</dd></div>
              <div><dt>APPOINTED</dt><dd>{course.appointed}</dd></div>
            </dl>
          </div>
        </article>
      </div>
    </section>
  );
}

export function TallySection() {
  const rows = [
    ["W", "40 × 8", "40", "8", true],
    ["1", "60 × 8", "62.5", "8", true],
    ["2", "60 × 8", "62.5", "8", false],
    ["3", "60 × 7", "62.5", "—", false],
  ];

  return (
    <section className="tally-section" id="tally">
      <SectionHeader
        number="II"
        eyebrow="THE TALLY OF DEEDS"
        title="Let no weight once borne fall into darkness."
        sequence="WHAT WAS → WHAT IS"
        tone="dark"
      />
      <div className="split-layout split-layout--dark">
        <div className="section-copy section-copy--dark">
          <p className="inscription inscription--light">THE BRONZE-FAST MEMORY</p>
          <p>
            When the iron-laden bar returns to the hands, the former weight returns beside
            it. The lighter preparation stands apart, but the true work is cut into the tally.
          </p>
          <blockquote>What was done is not lost; it stands beside what must now be done.</blockquote>
        </div>
        <div className="ledger-wrap">
          <div className="ledger">
            <header><span>BARBELL BACK SQUAT</span><span>3 × 6–10</span></header>
            <div className="ledger__row ledger__head">
              <span>SET</span><span>BEFORE</span><span>KG</span><span>REPS</span><span>SEALED</span>
            </div>
            {rows.map(([set, before, weight, reps, sealed]) => (
              <div className={`ledger__row${set === "W" ? " ledger__row--warm" : ""}`} key={set}>
                <span>{set}</span><span>{before}</span><strong>{weight}</strong><strong>{reps}</strong><i>{sealed ? "✓" : ""}</i>
              </div>
            ))}
            <footer><span>W / MAKING READY</span><span>WEIGHT APPOINTED / 62.5 KG × 8</span></footer>
          </div>
        </div>
      </div>
    </section>
  );
}

export function RestSection() {
  const [remaining, setRemaining] = useState(90);

  useEffect(() => {
    const timer = window.setInterval(
      () => setRemaining((seconds) => (seconds <= 0 ? 90 : seconds - 1)),
      1000,
    );
    return () => window.clearInterval(timer);
  }, []);

  const clock = formatClock(remaining);

  return (
    <section className="rest-section" id="rest">
      <SectionHeader
        number="III"
        eyebrow="THE NUMBERED REST"
        title="Rest now; the number keeps watch."
        sequence="SCREEN DARK / COUNT UNBROKEN"
        tone="pale"
      />
      <div className="rest-layout">
        <figure className="rest-artwork">
          <img
            src="/assets/resting-athlete-black-figure.png"
            alt="Ancient Greek black-figure style athlete resting between efforts"
            width="1254"
            height="1254"
            loading="lazy"
          />
        </figure>
        <div className="rest-copy">
          <div className="live-activity"><span>F</span><small>REST</small><strong>{clock}</strong></div>
          <p className="rest-copy__label">FORM / LIVE ACTIVITY</p>
          <p className="rest-copy__clock" aria-hidden="true">{clock}</p>
          <p>
            Bid the bright screen sleep, and still the count goes onward in the Live Activity
            until the hour of strength returns.
          </p>
        </div>
      </div>
    </section>
  );
}

export function WitnessSection() {
  const calendar = useMemo(() => buildCalendar(new Date()), []);

  return (
    <section className="witness-section" id="witness">
      <SectionHeader
        number="IV"
        eyebrow="THE WITNESS OF DAYS"
        title="Let the days bear witness to the strength that grew."
        sequence="SESSION → WEEK → SEASON"
      />
      <div className="witness-intro">
        <p className="inscription">NOTHING DONE IS LOST</p>
        <p>
          Each session stands in its own place, and week answers unto week. The numbers
          declare whether the burden rose and whether the whole labour waxed or stood still.
        </p>
      </div>
      <div className="witness-grid">
        <section className="metric-panel calendar-panel">
          <header><span>{calendar.title}</span><span>NINE SESSIONS</span></header>
          <div className="calendar-week" aria-hidden="true">
            {['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((day, index) => <span key={`${day}-${index}`}>{day}</span>)}
          </div>
          <div className="calendar-grid">
            {calendar.cells.map((cell, index) => cell ? (
              <span
                className={`calendar-day${cell.trained ? " calendar-day--trained" : ""}`}
                key={cell.day}
                aria-label={`${cell.label}${cell.trained ? ", training session" : ""}`}
              >
                {cell.day}
              </span>
            ) : <span className="calendar-day calendar-day--empty" aria-hidden="true" key={`empty-${index}`} />)}
          </div>
        </section>

        <section className="metric-panel strength-panel">
          <header><span>BACK SQUAT</span><span>EST. 1RM / KG</span></header>
          <div className="strength-value"><strong>78.4</strong><span>+6.8 KG / 12 WEEKS</span></div>
          <div className="strength-bars" role="img" aria-label="Estimated one repetition maximum rising over twelve weeks">
            {STRENGTH_POINTS.map((point, index) => (
              <span key={index} style={{ "--point": `${point}%` }} />
            ))}
          </div>
        </section>

        <section className="metric-panel consistency-panel">
          <header><span>12-WEEK CONSISTENCY</span><span>27 / 36</span></header>
          <div className="consistency-bars" aria-label="Weekly training sessions">
            {CONSISTENCY.map((sessions, index) => (
              <span key={index} style={{ "--sessions": sessions }} />
            ))}
          </div>
          <footer><span>W01</span><span>W12</span></footer>
        </section>
      </div>
    </section>
  );
}

export function MakingSection() {
  return (
    <section className="making-section" id="making">
      <SectionHeader
        number="V"
        eyebrow="THE MAKING READY"
        title="Make ready Form, and bear it with you."
        sequence="MAC → XCODE → IPHONE"
        tone="stone"
      />
      <div className="making-layout">
        <div className="section-copy">
          <p className="inscription">THE MAKER'S INSCRIPTION</p>
          <p>
            Provide first a Mac and an Apple Account; provide also an iPhone bearing iOS 17
            or later; and through Xcode shall Form be brought forth upon the device.
          </p>
          <a className="outlined-action outlined-action--filled" href="https://github.com/ericfzhu/form">
            <span>TAKE UP THE SOURCE</span><span aria-hidden="true">↗</span>
          </a>
        </div>
        <ol className="making-steps">
          {MAKING_STEPS.map(([number, eyebrow, title, detail]) => (
            <li key={number}>
              <span>{number}</span>
              <div><small>{eyebrow.toUpperCase()}</small><h3>{title}</h3><p>{detail}</p></div>
            </li>
          ))}
        </ol>
      </div>
    </section>
  );
}

