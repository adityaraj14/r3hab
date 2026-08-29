"use client";

import { useState } from "react";
import { DISCLAIMER, type LoadUnit, type RehabPhase } from "@/domain/types";
import { BrandMark, GhostButton, PrimaryButton, Segmented, Wordmark } from "./ui";

const LAST_PAGE = 3;

function ProgressDots({ total, current }: { total: number; current: number }) {
  return (
    <div className="flex items-center gap-1.5" aria-label={`Screen ${current + 1} of ${total}`}>
      {Array.from({ length: total }, (_, i) => (
        <span
          key={i}
          className={`h-1.5 rounded-full ${
            i === current ? "w-5 bg-gold" : "w-1.5 bg-line"
          }`}
        />
      ))}
    </div>
  );
}

export function Onboarding({
  onDone,
}: {
  onDone: (args: { phase: RehabPhase; unit: LoadUnit; skipped: boolean }) => Promise<void>;
}) {
  const [page, setPage] = useState(0);
  const [loading, setLoading] = useState(false);
  const [alreadyLoading, setAlreadyLoading] = useState(true);
  const [unit, setUnit] = useState<LoadUnit>("lb");

  const finish = async (skipped: boolean) => {
    setLoading(true);
    if (skipped) {
      await onDone({ phase: "B", unit: "lb", skipped: true });
      return;
    }
    await onDone({
      phase: alreadyLoading ? "B" : "A",
      unit,
      skipped: false,
    });
  };

  const primaryLabel =
    page === 0 ? "That's my injury" : page === 2 ? "Continue" : page === 3 ? "Let's load" : "Next";

  return (
    <div className="fixed inset-0 z-50 flex flex-col bg-bg px-5 pt-[max(1.25rem,env(safe-area-inset-top))] pb-[max(1rem,env(safe-area-inset-bottom))]">
      <div className="flex items-center justify-between gap-3">
        <div className="flex items-center gap-3">
          <BrandMark size={44} />
          <Wordmark />
        </div>
        <ProgressDots total={4} current={page} />
      </div>

      <div className="mx-auto flex w-full max-w-md flex-1 flex-col justify-center gap-6 py-8">
        {page === 0 ? (
          <>
            <p className="font-display text-4xl leading-none tracking-wide">
              Patellar tendinopathy. That&apos;s the whole app.
            </p>
            <p className="text-base leading-7 text-muted">
              This diary is jumper&apos;s knee only. Primary load is seated knee extension. No other
              injuries, no back, no QL.
            </p>
          </>
        ) : null}

        {page === 1 ? (
          <>
            <p className="font-display text-3xl leading-none">Train today. Judge tomorrow.</p>
            <p className="text-base leading-7 text-muted">
              Seated-extension isometrics and HSR. Mild pain during load is OK if the next morning is
              not worse. Sessions start Pending. Better / Same / Worse. Same → Stay. Better → Stay, or
              Progress after 3 clean sessions. Worse → Soft cut first.
            </p>
          </>
        ) : null}

        {page === 2 ? (
          <>
            <p className="font-display text-3xl leading-none">Where are you?</p>
            <Segmented
              ariaLabel="Starting point"
              value={alreadyLoading ? "yes" : "no"}
              onChange={(v) => setAlreadyLoading(v === "yes")}
              options={[
                { value: "yes", label: "Already loading" },
                { value: "no", label: "Flare / protect" },
              ]}
            />
            <p className="text-sm leading-6 text-muted">
              {alreadyLoading
                ? "Starts in Phase B isometrics. You own every phase change."
                : "Starts in Phase A. Exit after 3 stable mornings and a 6k+ step day."}
            </p>
            <Segmented<LoadUnit>
              ariaLabel="Units"
              value={unit}
              onChange={setUnit}
              options={[
                { value: "lb", label: "lbs" },
                { value: "kg", label: "kg" },
              ]}
            />
          </>
        ) : null}

        {page === 3 ? (
          <>
            <p className="font-display text-3xl leading-none">Not a clinic.</p>
            <p className="text-sm leading-6 text-muted">{DISCLAIMER}</p>
          </>
        ) : null}
      </div>

      <div className="mx-auto flex w-full max-w-md flex-col gap-1">
        {page < LAST_PAGE ? (
          <PrimaryButton onClick={() => setPage((p) => p + 1)}>{primaryLabel}</PrimaryButton>
        ) : (
          <PrimaryButton disabled={loading} onClick={() => void finish(false)}>
            {primaryLabel}
          </PrimaryButton>
        )}
        <GhostButton quiet disabled={loading} onClick={() => void finish(true)}>
          Skip for now
        </GhostButton>
      </div>
    </div>
  );
}
