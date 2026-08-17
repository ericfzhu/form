import React, { useEffect, useMemo, useState } from "react";
import { createRoot } from "react-dom/client";
import "./demo.css";

const NAV = [
  ["I", "THE COURSE", "#course"],
  ["II", "THE TALLY", "#tally"],
  ["III", "THE REST", "#rest"],
  ["IV", "THE WITNESS", "#witness"],
  ["V", "THE MAKING", "#making"],
];

const COURSES = [
  { id: "A", sequence: "SQUAT / PRESS / PULL", title: "Barbell Back Squat", image: "/assets/barbell-back-squat.png", order: "3 × 6–10", before: "60 kg × 8", appointed: "62.5 kg × 8" },
  { id: "B", sequence: "HINGE / INCLINE / UNILATERAL", title: "Conventional Deadlift", image: "/assets/conventional-deadlift.png", order: "3 × 5–6", before: "87.5 kg × 6", appointed: "90 kg × 6" },
  { id: "C", sequence: "SQUAT / SHOULDERS / CARRY", title: "Dumbbell Shoulder Press", image: "/assets/shoulder-press.png", order: "3 × 8–12", before: "20 kg / hand", appointed: "22 kg / hand" },
];

const STRENGTH = [38, 42, 40, 53, 51, 63, 67, 77, 74, 86, 90, 96];
const CONSISTENCY = [2, 1, 3, 2, 3, 1, 2, 3, 2, 2, 3, 2];
const MAKING = [
  ["I", "THE SOURCE", "Take up the work at its beginning.", "Install Xcode, draw Form down from GitHub, and open Form.xcodeproj."],
  ["II", "THE SEAL", "Set your name upon the work.", "Choose your signing team and use a bundle identifier belonging to you."],
  ["III", "THE JOINING", "Bind the iPhone to the Mac.", "Grant Trust, choose the device, and enable Developer Mode when asked."],
  ["IV", "THE AWAKENING", "Give the command to Run.", "Xcode builds Form and places it upon the iPhone."],
];

const display = "font-display";
const eyebrow = `${display} text-[9px] font-bold tracking-[0.18em] text-red`;
const bodyCopy = "text-[17px] leading-relaxed text-ink-soft md:text-xl";

function useReducedMotion() {
  const [reduced, setReduced] = useState(() => window.matchMedia?.("(prefers-reduced-motion: reduce)").matches ?? false);
  useEffect(() => {
    const media = window.matchMedia("(prefers-reduced-motion: reduce)");
    const update = () => setReduced(media.matches);
    media.addEventListener("change", update);
    return () => media.removeEventListener("change", update);
  }, []);
  return reduced;
}

function formatClock(seconds) {
  return `${String(Math.floor(seconds / 60)).padStart(2, "0")}:${String(seconds % 60).padStart(2, "0")}`;
}

function calendarFor(date) {
  const year = date.getFullYear();
  const month = date.getMonth();
  const first = new Date(year, month, 1);
  const days = new Date(year, month + 1, 0).getDate();
  const lead = (first.getDay() + 6) % 7;
  const count = Math.max(35, Math.ceil((lead + days) / 7) * 7);
  const trained = new Set([1, 4, 8, 11, 15, 18, 22, 25, 29].filter((day) => day <= days));
  return {
    title: new Intl.DateTimeFormat("en", { month: "short", year: "numeric" }).format(date).replace(" ", " / ").toUpperCase(),
    cells: Array.from({ length: count }, (_, index) => {
      const day = index - lead + 1;
      return day < 1 || day > days ? null : { day, trained: trained.has(day) };
    }),
  };
}

function SectionHeader({ number, eyebrow: label, title, sequence, dark = false, stone = false }) {
  const tone = dark ? "border-clay bg-ink text-paper" : stone ? "bg-stone" : "bg-paper";
  return (
    <header className={`grid min-h-24 grid-cols-[64px_1fr] border-y border-b-[3px] border-double border-ink md:grid-cols-[86px_1fr_auto] ${tone}`}>
      <span className={`${display} grid place-items-center border-r border-current text-2xl text-red md:text-3xl ${dark ? "text-clay-light" : ""}`}>{number}</span>
      <div className="grid content-center gap-1.5 px-4 py-4 md:px-6">
        <p className={`${display} m-0 text-[8px] font-bold tracking-[0.17em]`}>{label}</p>
        <h2 className={`${display} m-0 text-2xl font-normal leading-none tracking-[-0.035em] md:text-4xl`}>{title}</h2>
      </div>
      <span className={`${display} hidden min-w-52 place-items-center border-l border-current px-5 text-[8px] font-bold tracking-[0.13em] md:grid`}>{sequence}</span>
    </header>
  );
}

function Header() {
  const [open, setOpen] = useState(false);
  useEffect(() => {
    const onKey = (event) => event.key === "Escape" && setOpen(false);
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, []);
  return (
    <header className="sticky top-0 z-50 grid min-h-[72px] grid-cols-[1fr_auto] border-b border-ink bg-paper md:grid-cols-[minmax(230px,1fr)_auto_minmax(160px,1fr)]">
      <a href="/demo/" className="flex min-h-[71px] w-max items-center gap-3 px-4 md:px-10" aria-label="Form Attic vessel study home">
        <span className={`${display} grid size-9 place-items-center border-2 border-ink font-bold`}>F</span>
        <span className="grid gap-0.5"><strong className={`${display} text-[17px] font-semibold tracking-[0.2em]`}>FORM</strong><small className="hidden text-[7px] font-bold tracking-[0.15em] text-ink-soft sm:block">ATTIC VESSEL STUDY</small></span>
      </a>
      <button className={`${display} flex min-h-[71px] items-center gap-3 border-l border-ink px-4 text-[8px] font-bold tracking-[0.14em] md:hidden`} onClick={() => setOpen((value) => !value)} aria-expanded={open} aria-controls="demo-nav">THE STELE <span aria-hidden="true">{open ? "×" : "☰"}</span></button>
      <nav id="demo-nav" className={`${open ? "grid" : "hidden"} absolute inset-x-0 top-[71px] bg-ink text-paper md:static md:flex md:bg-transparent md:text-ink`} aria-label="Demo navigation">
        {NAV.map(([number, label, href]) => <a key={href} href={href} onClick={() => setOpen(false)} className={`${display} flex min-h-14 items-center gap-2 border-b border-clay/40 px-5 text-[8px] font-bold tracking-[0.13em] hover:bg-ink hover:text-paper md:min-h-[71px] md:border-b-0 md:border-l md:border-ink/40 md:px-3`}><span className="text-red">{number}</span>{label}</a>)}
      </nav>
      <a href="/" className={`${display} hidden min-h-[71px] items-center justify-self-end px-10 text-[8px] font-bold tracking-[0.14em] md:flex`}>CURRENT SITE <span className="ml-2 text-red">↗</span></a>
    </header>
  );
}

function Hero() {
  return (
    <section id="proem" className="grid border-b border-ink lg:min-h-[calc(100svh-87px)] lg:grid-cols-[0.94fr_1.06fr]">
      <div className="border-b border-ink px-6 py-20 lg:border-b-0 lg:border-r lg:px-[clamp(26px,6vw,92px)] lg:py-[clamp(82px,9vw,142px)]">
        <p className={eyebrow}>THE PROEM / OF STRENGTH KEPT IN ORDER</p>
        <h1 className={`${display} mb-8 max-w-4xl text-[clamp(58px,10vw,118px)] font-normal leading-[0.84] tracking-[-0.065em]`}><span className="block text-[0.44em] tracking-[0.01em]">TELL, MUSE,</span>of strength remembered.</h1>
        <p className={`${bodyCopy} mb-8 max-w-2xl`}>Tell how one task followed another, and how no former deed was lost; for Form keeps the returning course, and sets beside each labour the weight borne before.</p>
        <a href="#course" className={`${display} flex min-h-12 w-full max-w-[270px] items-center justify-between border-2 border-ink px-4 text-[9px] font-bold tracking-[0.15em] hover:bg-ink hover:text-paper`}>ENTER THE ACCOUNT <span>↓</span></a>
        <dl className="mt-14 grid max-w-2xl border-y border-t-[3px] border-double border-ink sm:grid-cols-3 lg:mt-24">
          {[["I", "THE COURSE RETURNS"], ["II", "THE TALLY REMEMBERS"], ["III", "THE REST KEEPS WATCH"]].map(([number, text]) => <div key={number} className="grid min-h-16 grid-cols-[38px_1fr] items-center border-b border-ink last:border-b-0 sm:border-b-0 sm:border-r sm:last:border-r-0"><dt className={`${display} grid h-full place-items-center border-r border-ink text-red`}>{number}</dt><dd className={`${display} m-0 px-3 text-[7px] font-bold tracking-[0.11em]`}>{text}</dd></div>)}
        </dl>
      </div>
      <div className="grid bg-ink px-5 py-12 text-cream lg:grid-rows-[auto_1fr_auto] lg:px-[clamp(22px,3.5vw,54px)] lg:py-[clamp(48px,6vw,82px)]">
        <div className={`${display} flex justify-between gap-4 border-y border-t-[3px] border-double border-clay py-3 text-[8px] font-bold tracking-[0.14em] text-clay-light`}><span>THE DEED APPOINTED</span><span>A → B → C → A</span></div>
        <div className="grid min-h-[520px] place-items-center py-8"><div className="w-full max-w-[360px] rounded-[46px] border-2 border-clay-light bg-ink p-[7px]" aria-label="Form app train screen"><img src="/app-train.webp" alt="Form Train screen showing the next workout and workout rotation" width="520" height="1126" fetchPriority="high" className="w-full rounded-[39px]" /></div></div>
        <div className={`${display} flex justify-between gap-4 border-y border-b-[3px] border-double border-clay py-3 text-[8px] font-bold tracking-[0.14em] text-clay-light`}><span>FORM / IPHONE</span><span>THE DEED REMEMBERED</span></div>
      </div>
    </section>
  );
}

function CourseSection({ reducedMotion }) {
  const [active, setActive] = useState(0);
  const [paused, setPaused] = useState(false);
  useEffect(() => {
    if (paused || reducedMotion) return undefined;
    const id = window.setInterval(() => setActive((value) => (value + 1) % COURSES.length), 5200);
    return () => window.clearInterval(id);
  }, [paused, reducedMotion]);
  const course = COURSES[active];
  return (
    <section id="course">
      <SectionHeader number="I" eyebrow="THE RETURNING COURSE" title="One labour yields, and another rises." sequence="A → B → C → A" />
      <div className="grid lg:grid-cols-[0.72fr_1.28fr]">
        <div className="border-b border-ink px-6 py-16 lg:border-b-0 lg:border-r lg:px-[clamp(26px,5vw,78px)] lg:py-[clamp(68px,8vw,118px)]">
          <p className={eyebrow}>THUS THE COURSE RETURNS</p>
          <p className={`${bodyCopy} max-w-xl`}>First comes A, and after A comes B, and C follows B in its appointed hour. Then the course bends homeward to A; Form forgets not where the athlete ceased.</p>
          <div className="mt-8 flex w-max border-2 border-ink">{COURSES.map((item, index) => <button key={item.id} onClick={() => setActive(index)} aria-pressed={active === index} className={`${display} size-12 border-r border-ink text-lg last:border-r-0 aria-pressed:bg-ink aria-pressed:text-paper`}>{item.id}</button>)}</div>
          <p className={`${display} mb-2 mt-3 text-[8px] font-bold tracking-[0.13em] text-ink-soft`}>THEREAFTER · {COURSES[(active + 1) % COURSES.length].id}</p>
          <button onClick={() => setPaused((value) => !value)} aria-pressed={paused} aria-label={paused ? "Resume automatic course rotation" : "Pause automatic course rotation"} className={`${display} flex min-h-11 w-full max-w-[340px] items-center gap-3 border border-bronze px-3 text-left text-[8px] font-bold tracking-[0.13em] hover:border-red hover:text-red`}>
            <span aria-hidden="true" className="relative block size-[18px] shrink-0">{paused ? <span className="absolute left-1 top-0 h-0 w-0 border-y-[9px] border-l-[14px] border-y-transparent border-l-red" /> : <><span className="absolute left-1 top-px h-4 w-1 bg-red" /><span className="absolute right-1 top-px h-4 w-1 bg-red" /></>}</span>
            {paused ? "LET THE COURSE MOVE" : "STAY THE COURSE"}
          </button>
        </div>
        <article className="grid min-h-[660px] grid-rows-[auto_1fr_auto] bg-ink p-7 text-cream md:p-12" aria-live="polite">
          <header className={`${display} flex items-center justify-between gap-4 border-b-[3px] border-double border-current pb-3 text-[8px] font-bold tracking-[0.14em]`}><span>{course.sequence}</span><strong className="grid size-14 place-items-center border border-current text-3xl font-normal text-clay-light">{course.id}</strong></header>
          <div className="my-5 grid min-h-[340px] place-items-center bg-paper p-5"><img src={course.image} alt="" width="512" height="512" className="max-h-[360px] object-contain" /></div>
          <div className="border-t-[3px] border-double border-current pt-4"><span className={`${display} text-[8px] font-bold tracking-[0.14em]`}>THE {["FIRST", "SECOND", "THIRD"][active]} COURSE</span><h3 className={`${display} my-2 text-4xl font-normal leading-none tracking-[-0.04em] md:text-5xl`}>{course.title}</h3><dl className="grid border-y border-current sm:grid-cols-3">{[["ORDER", course.order], ["BEFORE", course.before], ["APPOINTED", course.appointed]].map(([key, value]) => <div key={key} className="grid min-h-16 content-center gap-1 border-b border-current px-3 last:border-b-0 sm:border-b-0 sm:border-r sm:last:border-r-0"><dt className={`${display} text-[7px] font-bold tracking-[0.12em]`}>{key}</dt><dd className="m-0 text-sm font-bold">{value}</dd></div>)}</dl></div>
        </article>
      </div>
    </section>
  );
}

function TallySection() {
  const rows = [["W", "40 × 8", "40", "8", true], ["1", "60 × 8", "62.5", "8", true], ["2", "60 × 8", "62.5", "8", false], ["3", "60 × 7", "62.5", "—", false]];
  return <section id="tally"><SectionHeader number="II" eyebrow="THE TALLY OF DEEDS" title="Let no weight once borne fall into darkness." sequence="WHAT WAS → WHAT IS" dark /><div className="grid bg-ink text-paper lg:grid-cols-[0.72fr_1.28fr]"><div className="border-b border-clay px-6 py-16 lg:border-b-0 lg:border-r lg:px-[clamp(26px,5vw,78px)] lg:py-24"><p className={`${eyebrow} text-clay-light`}>THE BRONZE-FAST MEMORY</p><p className="max-w-xl text-[17px] leading-relaxed text-paper/80 md:text-xl">When the iron-laden bar returns to the hands, the former weight returns beside it. The lighter preparation stands apart, but the true work is cut into the tally.</p><blockquote className={`${display} mt-10 border-t-[3px] border-double border-clay pt-5 text-2xl leading-tight md:text-4xl`}>What was done is not lost; it stands beside what must now be done.</blockquote></div><div className="grid place-items-center p-6 md:p-12"><div className="w-full max-w-3xl border-2 border-ink bg-clay text-ink outline outline-1 outline-offset-8 outline-clay"><header className={`${display} flex min-h-16 items-center justify-between border-b-[3px] border-double border-ink px-4 text-xl`}><span>BARBELL BACK SQUAT</span><span className="text-sm font-bold text-red">3 × 6–10</span></header><div className="grid grid-cols-[44px_1.2fr_.8fr_.8fr_54px] border-b border-ink text-center font-display text-[7px] font-bold tracking-widest">{["SET", "BEFORE", "KG", "REPS", "SEALED"].map((label) => <span key={label} className="grid min-h-10 place-items-center border-r border-ink last:border-r-0">{label}</span>)}</div>{rows.map(([set, before, weight, reps, sealed]) => <div key={set} className={`grid min-h-16 grid-cols-[44px_1.2fr_.8fr_.8fr_54px] border-b border-ink ${set === "W" ? "bg-paper/20" : ""}`}>{[set, before, weight, reps, sealed ? "✓" : ""].map((value, index) => <span key={index} className={`grid place-items-center border-r border-ink last:border-r-0 ${index === 0 ? "font-display text-lg text-red" : ""} ${index === 2 || index === 3 ? "font-display text-xl" : ""}`}>{value}</span>)}</div>)}<footer className={`${display} flex min-h-12 items-center justify-between gap-3 px-4 text-[7px] font-bold tracking-wider`}><span>W / MAKING READY</span><span>WEIGHT APPOINTED / 62.5 KG × 8</span></footer></div></div></div></section>;
}

function RestSection() {
  const [remaining, setRemaining] = useState(90);
  useEffect(() => {
    const id = window.setInterval(() => setRemaining((value) => (value <= 0 ? 90 : value - 1)), 1000);
    return () => window.clearInterval(id);
  }, []);
  const clock = formatClock(remaining);
  return <section id="rest"><SectionHeader number="III" eyebrow="THE NUMBERED REST" title="Rest now; the number keeps watch." sequence="SCREEN DARK / COUNT UNBROKEN" /><div className="grid bg-paper-raised lg:grid-cols-[0.9fr_1.1fr]"><div className="grid min-h-[520px] content-center border-b border-ink px-6 py-16 lg:border-b-0 lg:border-r lg:px-16"><p className={eyebrow}>THE NUMBERED REST</p><p className={`${display} max-w-xl text-[clamp(54px,7vw,104px)] font-normal leading-[0.88] tracking-[-0.055em]`}>The screen may sleep. The count does not.</p></div><div className="flex flex-col justify-center px-6 py-16 lg:px-12"><p className={`${display} mb-3 text-[8px] font-bold tracking-[0.14em] text-ink-soft`}>FORM / LIVE ACTIVITY</p><div className="grid max-w-md grid-cols-[34px_1fr_auto] items-center gap-3 rounded-full bg-ink p-2 pr-4 text-cream"><span className={`${display} grid size-9 place-items-center rounded-full bg-clay text-ink`}>F</span><small className="font-bold tracking-widest">REST</small><strong className="text-xl tabular-nums text-clay-light">{clock}</strong></div><p className={`${bodyCopy} mt-8 max-w-2xl`}>Bid the bright screen sleep, and still the count goes onward in the Live Activity until the hour of strength returns.</p></div></div></section>;
}

function WitnessSection() {
  const calendar = useMemo(() => calendarFor(new Date()), []);
  return <section id="witness"><SectionHeader number="IV" eyebrow="THE WITNESS OF DAYS" title="Let the days bear witness to the strength that grew." sequence="SESSION → WEEK → SEASON" /><div className="grid gap-4 px-6 py-16 lg:grid-cols-[.8fr_1.2fr] lg:px-16"><div><p className={eyebrow}>NOTHING DONE IS LOST</p><p className={`${bodyCopy} max-w-2xl`}>Each session stands in its own place, and week answers unto week. The numbers declare whether the burden rose and whether the whole labour waxed or stood still.</p></div><div className="grid gap-4 xl:grid-cols-2"><section className="border border-ink xl:row-span-2"><header className={`${display} flex min-h-12 items-center justify-between border-b border-ink px-4 text-[8px] font-bold tracking-[0.13em]`}><span>{calendar.title}</span><span>NINE SESSIONS</span></header><div className="grid grid-cols-7 border-b border-ink">{["M", "T", "W", "T", "F", "S", "S"].map((day, index) => <span key={`${day}${index}`} className={`${display} grid min-h-9 place-items-center border-r border-ink/40 text-[8px] font-bold last:border-r-0`}>{day}</span>)}</div><div className="grid grid-cols-7">{calendar.cells.map((cell, index) => cell ? <span key={cell.day} className={`${display} grid min-h-12 place-items-center border-b border-r border-ink/30 text-[10px] ${cell.trained ? "bg-ink text-paper" : ""}`}>{cell.day}</span> : <span key={index} className="min-h-12 border-b border-r border-ink/20 bg-ink/5" />)}</div></section><section className="border border-ink"><header className={`${display} flex min-h-12 items-center justify-between border-b border-ink px-4 text-[8px] font-bold tracking-[0.13em]`}><span>BACK SQUAT</span><span>EST. 1RM / KG</span></header><div className="p-5"><div className="flex items-end justify-between gap-3"><strong className={`${display} text-6xl font-normal tracking-tight`}>78.4</strong><span className={`${display} text-[8px] font-bold tracking-wider text-red`}>+6.8 KG / 12 WEEKS</span></div><div className="mt-6 grid h-40 grid-cols-12 items-end gap-1 border-b border-l border-ink/50 p-2">{STRENGTH.map((point, index) => <span key={index} style={{ height: `${point}%` }} className="bg-red" />)}</div></div></section><section className="border border-ink"><header className={`${display} flex min-h-12 items-center justify-between border-b border-ink px-4 text-[8px] font-bold tracking-[0.13em]`}><span>12-WEEK CONSISTENCY</span><span>27 / 36</span></header><div className="grid h-40 grid-cols-12 items-end gap-1 p-4">{CONSISTENCY.map((sessions, index) => <span key={index} style={{ height: `${sessions * 32}px` }} className="min-h-4 bg-ink" />)}</div></section></div></div></section>;
}

function MakingSection() {
  return <section id="making"><SectionHeader number="V" eyebrow="THE MAKING READY" title="Make ready Form, and bear it with you." sequence="MAC → XCODE → IPHONE" stone /><div className="grid bg-stone lg:grid-cols-[.72fr_1.28fr]"><div className="border-b border-ink px-6 py-16 lg:border-b-0 lg:border-r lg:px-16 lg:py-24"><p className={eyebrow}>THE MAKER'S INSCRIPTION</p><p className={`${bodyCopy} max-w-xl`}>Provide first a Mac and an Apple Account; provide also an iPhone bearing iOS 17 or later; and through Xcode shall Form be brought forth upon the device.</p><a href="https://github.com/ericfzhu/form" className={`${display} mt-7 flex min-h-12 max-w-[270px] items-center justify-between border-2 border-ink bg-ink px-4 text-[9px] font-bold tracking-[0.15em] text-paper hover:bg-transparent hover:text-ink`}>TAKE UP THE SOURCE <span>↗</span></a></div><ol className="m-0 list-none p-0">{MAKING.map(([number, label, title, detail]) => <li key={number} className="grid min-h-36 grid-cols-[58px_1fr] border-b border-ink last:border-b-0 md:grid-cols-[84px_1fr]"><span className={`${display} grid place-items-start border-r border-ink pt-7 text-xl text-red`}>{number}</span><div className="px-5 py-7 md:px-8"><small className={`${display} text-[8px] font-bold tracking-[0.14em] text-red`}>{label}</small><h3 className={`${display} my-2 text-2xl font-normal tracking-tight md:text-3xl`}>{title}</h3><p className="m-0 max-w-3xl leading-relaxed text-ink-soft">{detail}</p></div></li>)}</ol></div></section>;
}

function Footer() {
  return <footer className="flex min-h-72 flex-col justify-between gap-10 border-t-[15px] border-ink bg-ink px-6 py-14 text-paper md:flex-row md:items-center md:px-16"><div><p className={`${display} mb-3 text-[clamp(52px,7vw,104px)] leading-[.84] tracking-[-.05em]`}>So the course returns.</p><span className={`${display} text-[8px] font-bold tracking-[0.15em] text-clay-light`}>ATTIC VESSEL STUDY / © {new Date().getFullYear()}</span></div><nav className="grid gap-3"><a href="#proem" className={`${display} grid min-h-12 min-w-56 place-items-center border border-clay text-[8px] font-bold tracking-[0.14em] hover:bg-clay hover:text-ink`}>RETURN TO THE PROEM ↑</a><a href="/" className={`${display} grid min-h-12 min-w-56 place-items-center border border-clay text-[8px] font-bold tracking-[0.14em] hover:bg-clay hover:text-ink`}>SEE THE CURRENT SITE ↗</a></nav></footer>;
}

function App() {
  const reduced = useReducedMotion();
  return <><a href="#course" className="fixed left-2 top-2 z-[100] -translate-y-40 bg-ink px-4 py-3 text-paper focus:translate-y-0">Skip to the course</a><Header /><div aria-hidden="true" className="sticky top-[72px] z-40 h-[15px] border-b border-ink" style={{ background: "repeating-linear-gradient(90deg,#201b17 0 18px,#8a7447 18px 22px,#201b17 22px 34px)" }} /><main><Hero /><div className={`${display} grid min-h-14 place-items-center border-b border-ink bg-ink px-4 text-center text-[9px] font-bold tracking-[0.22em] text-paper`}>COURSE · TALLY · REST · WITNESS · RETURN</div><CourseSection reducedMotion={reduced} /><TallySection /><RestSection /><WitnessSection /><MakingSection /></main><Footer /></>;
}

createRoot(document.getElementById("root")).render(<React.StrictMode><App /></React.StrictMode>);
