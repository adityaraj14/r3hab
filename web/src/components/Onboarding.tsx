"use client";

import { useState } from "react";
import { DISCLAIMER, type LoadUnit, type RehabPhase } from "@/domain/types";
import { BrandMark, GhostButton, PrimaryButton, Segmented, Wordmark } from "./ui";

export function Onboarding({
  onDone,
}: {
  onDone: (args: { phase: RehabPhase; unit: LoadUnit; skipped: boolean }) => Promise<void>;
}) {
  const [page, setPage] = useState(0);
  const [loading, setLoading] = useState(false);
  const [alreadyLoading, setAlreadyLoading] = useState(true);
  const [unit, setUnit] = useState<LoadUnit>("kg");

  const finish = async (skipped: boolean) => {
    setLoading(true);
    await onDone({ phase: alreadyLoading ? "B" : "A", unit, skipped });
  };

  return (
    <div className="fixed inset-0 z-50 flex flex-col bg-bg px-5 py-8">
      <div className="flex items-center gap-3">
        <BrandMark size={44} />
        <Wordmark />
      </div>
      <div className="mx-auto flex w-full max-w-md flex-1 flex-col justify-center gap-6">
        {page === 0 ? (
          <>
            <p className="font-display text-4xl leading-none tracking-wide">Unstoppable, not uninjured.</p>
            <p className="text-base leading-7 text-muted">
              R3hab is the protocol for patellar tendinopathy — seated knee extension as the primary load,
              plus a 24h pain loop. Rest is not the treatment. Not a clinic. Not a spreadsheet.
            </p>
          </>
        ) : null}
        {page === 1 ? (
          <>
            <p className="font-display text-3xl leading-none">The 24h rule</p>
            <p className="text-base leading-7 text-muted">
              Mild pain during load is OK if the next morning is not worse. Sessions start Pending. You
              pick Better / Same / Worse. Same → Stay. Better → Stay, or Progress after 3 clean sessions.
              Worse → Soft cut first; Hard drop only if the previous load day was also Worse.
            </p>
          </>
        ) : null}
        {page === 2 ? (
          <>
            <p className="font-display text-3xl leading-none">Where are you?</p>
            <Segmented
              ariaLabel="Already loading"
              value={alreadyLoading ? "yes" : "no"}
              onChange={(v) => setAlreadyLoading(v === "yes")}
              options={[
                { value: "yes", label: "Already loading" },
                { value: "no", label: "Flare / protect" },
              ]}
            />
            <p className="text-sm text-muted">
              {alreadyLoading
                ? "Starts in Phase B isometrics. You own every phase change."
                : "Starts in Phase A. Exit after 3 stable mornings and a 6k+ step day."}
            </p>
            <Segmented<LoadUnit>
              ariaLabel="Units"
              value={unit}
              onChange={setUnit}
              options={[
                { value: "kg", label: "Kilograms" },
                { value: "lb", label: "lbs" },
              ]}
            />
          </>
        ) : null}
        {page === 3 ? (
          <>
            <p className="font-display text-3xl leading-none">Not a medical device</p>
            <p className="text-sm leading-6 text-muted">{DISCLAIMER}</p>
          </>
        ) : null}
      </div>
      <div className="mx-auto flex w-full max-w-md flex-col gap-2">
        {page < 3 ? (
          <PrimaryButton onClick={() => setPage((p) => p + 1)}>
            {page === 2 ? "Continue" : "Next"}
          </PrimaryButton>
        ) : (
          <PrimaryButton disabled={loading} onClick={() => finish(false)}>
            Let’s load
          </PrimaryButton>
        )}
        <GhostButton onClick={() => finish(true)}>Skip for now</GhostButton>
      </div>
    </div>
  );
}
