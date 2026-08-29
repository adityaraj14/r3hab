"use client";

import { useEffect, useState } from "react";
import { localCalendar } from "@/domain/calendar";
import type { DailyCheckIn, RehabPhase } from "@/domain/types";
import { Field, GhostButton, PainControl, PrimaryButton, Sheet } from "./ui";

export function CheckInSheet({
  open,
  onClose,
  existing,
  phase,
  dayKey,
  onSave,
}: {
  open: boolean;
  onClose: () => void;
  existing: DailyCheckIn | null;
  phase: RehabPhase;
  dayKey: string;
  onSave: (row: DailyCheckIn) => Promise<void>;
}) {
  const [am, setAm] = useState<number | null>(null);
  const [stiffness, setStiffness] = useState<number | null>(null);
  const [pm, setPm] = useState<number | null>(null);
  const [steps, setSteps] = useState("");
  const [declineL, setDeclineL] = useState<number | null>(null);
  const [declineR, setDeclineR] = useState<number | null>(null);
  const [notes, setNotes] = useState("");
  const [showDecline, setShowDecline] = useState(false);

  useEffect(() => {
    if (!open) return;
    setAm(existing?.restingPainAM ?? null);
    setStiffness(existing?.morningStiffness ?? null);
    setPm(existing?.dailyPainPM ?? null);
    setSteps(existing?.steps != null ? String(existing.steps) : "");
    setDeclineL(existing?.declineSquatL ?? null);
    setDeclineR(existing?.declineSquatR ?? null);
    setNotes(existing?.notes ?? "");
    setShowDecline(existing?.declineSquatL != null || existing?.declineSquatR != null);
  }, [open, existing]);

  const save = async () => {
    const now = new Date().toISOString();
    const parsedSteps = steps.trim() === "" ? null : Math.max(0, Math.round(Number(steps)));
    await onSave({
      dayKey,
      date: dayKey,
      restingPainAM: am,
      morningStiffness: stiffness,
      dailyPainPM: pm,
      steps: parsedSteps !== null && Number.isFinite(parsedSteps) ? parsedSteps : null,
      declineSquatL: declineL,
      declineSquatR: declineR,
      notes,
      phase,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    });
    onClose();
  };

  const today = localCalendar.dayKey(new Date());
  const title = dayKey === today ? "Daily check-in" : `Check-in · ${dayKey}`;

  return (
    <Sheet
      open={open}
      title={title}
      onClose={onClose}
      footer={
        <div className="flex flex-col gap-2">
          <PrimaryButton onClick={save}>Save</PrimaryButton>
          <p className="text-center text-xs text-muted">Partial save is fine. Under 60 seconds.</p>
        </div>
      }
    >
      <div className="flex flex-col gap-6">
        <PainControl title="AM resting pain" value={am} onChange={setAm} />
        <PainControl title="Morning stiffness" value={stiffness} onChange={setStiffness} />
        <PainControl title="PM pain" value={pm} onChange={setPm} />
        <Field label="Steps">
          <input
            inputMode="numeric"
            value={steps}
            onChange={(e) => setSteps(e.target.value.replace(/[^\d]/g, ""))}
            placeholder="e.g. 7500"
            aria-label="Steps"
            className="h-11 rounded-xl border border-line bg-surface-2 px-3 text-base text-ink outline-none focus:border-gold"
          />
        </Field>
        <button
          type="button"
          className="text-left text-sm text-gold"
          onClick={() => setShowDecline((v) => !v)}
        >
          {showDecline ? "Hide" : "Add"} optional decline-squat pain
        </button>
        {showDecline ? (
          <div className="grid gap-4">
            <PainControl title="Decline squat L" value={declineL} onChange={setDeclineL} />
            <PainControl title="Decline squat R" value={declineR} onChange={setDeclineR} />
          </div>
        ) : null}
        <Field label="Notes">
          <textarea
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
            rows={3}
            className="rounded-xl border border-line bg-surface-2 px-3 py-2 text-sm text-ink outline-none focus:border-gold"
          />
        </Field>
        <GhostButton onClick={onClose}>Cancel</GhostButton>
      </div>
    </Sheet>
  );
}
