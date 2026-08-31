import React, { useEffect } from "react";
import { createRoot } from "react-dom/client";
import { mountFieldWall } from "./field-sketch.js";
import "./field.css";

const PASSAGES = [
  ["Arrival", "Before I know the weight, I know that you came back."],
  ["Preparation", "You choose the plates. I hold the plan."],
  ["Attempt", "The first set is a question. The next set is the answer your body gives."],
  ["Attention", "I keep the load, the repetitions, and the rest, so you do not have to carry them in your head."],
  ["Recovery", "Between efforts, nothing is wasted. Breath returns. Grip returns. Judgment can wait."],
  ["History", "I set today beside the last time—not to crown a winner, but to make change visible."],
  ["Uncertainty", "Some days the bar moves cleanly. Some days it does not move. Both belong here."],
  ["Choice", "More is not always next. Next may be another clean repetition, less weight, a longer rest, or home."],
  ["Return", "I remember what happened. You decide what it means. When you return, I return it to you."],
];

function FieldPage() {
  useEffect(() => {
    const wall = document.querySelector("[data-field-wall]");
    if (!wall) return undefined;
    return mountFieldWall(wall);
  }, []);

  return (
    <div className="field-page">
      <div className="field-wall" data-field-wall aria-hidden="true" />

      <main className="field-transcript" aria-label="Field: an illustrated portrait of Form">
        <h1>Field</h1>
        {PASSAGES.map(([heading, copy]) => (
          <section key={heading}>
            <h2>{heading}</h2>
            <p>{copy}</p>
          </section>
        ))}
      </main>

    </div>
  );
}

createRoot(document.getElementById("field-root")).render(<FieldPage />);
