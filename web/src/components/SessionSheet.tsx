"use client";

import { useEffect, useMemo, useState } from "react";
import { displayToKg, formatLoad, kgToDisplay, loadUnitLabel } from "@/domain/nextLoadSuggester";
import { shouldWarnUnder48h } from "@/domain/sessionSpacing";
import { defaultSetsFromPrescription, type TodayPrescription } from "@/domain/prescription";
import {
  sessionToSnapshot,
  type ExerciseId,
  type ExtensionSet,
  type LoadUnit,
  type SessionSide,
  type SessionType,
  type TrainingSession,
} from "@/domain/types";
import { EXERCISE_TITLES } from "@/domain/types";
import { Field, GhostButton, NumberField, PainControl, PrimaryButton, Segmented, Sheet } from "./ui";

type DraftSet = ExtensionSet;

function newSet(side: "L" | "R", loadKg: number, hold: number | null, reps: number | null): DraftSet {
  return {
    id: crypto.randomUUID(),
    side,
    loadKg,
    holdSeconds: hold,
    reps,
    painDuring: null,
    isWarmup: false,
  };
}

export function SessionSheet({
  open,
  onClose,
  onSave,
  onDelete,
  existing,
  prescription,
  unit,
  allSessions,
  phase,
  todayKey,
}: {
  open: boolean;
  onClose: () => void;
  onSave: (row: TrainingSession) => Promise<void>;
  onDelete?: (id: string) => Promise<void>;
  existing: TrainingSession | null;
  prescription: TodayPrescription;
  unit: LoadUnit;
  allSessions: TrainingSession[];
  phase: TrainingSession["phase"];
  todayKey: string;
}) {
  const isHsr = (existing?.sessionType ?? prescription.sessionType) === "hsrStrength";
  const [exerciseId, setExerciseId] = useState<ExerciseId>(prescription.exerciseId);
  const [sessionType, setSessionType] = useState<SessionType>(prescription.sessionType);
  const [side, setSide] = useState<SessionSide>("both");
  const [kneeAngle, setKneeAngle] = useState(60);
  const [tempo, setTempo] = useState("3-1-3");
  const [sets, setSets] = useState<DraftSet[]>([]);
  const [painAfter, setPainAfter] = useState<number | null>(2);
  const [notes, setNotes] = useState("");
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    if (!open) return;
    if (existing) {
      setExerciseId(existing.exerciseId);
      setSessionType(existing.sessionType);
      setSide(existing.side);
      setKneeAngle(existing.kneeAngle);
      setTempo(existing.tempo ?? "3-1-3");
      setSets(existing.sets);
      setPainAfter(existing.painAfter);
      setNotes(existing.notes);
      return;
    }
    setExerciseId(prescription.exerciseId);
    setSessionType(prescription.sessionType);
    setSide("both");
    setKneeAngle(prescription.kneeAngle);
    setTempo(prescription.tempo ?? "3-1-3");
    setSets(defaultSetsFromPrescription(prescription));
    setPainAfter(2);
    setNotes("");
  }, [open, existing, prescription]);

  const structured = exerciseId === "seatedExtensionIso" || exerciseId === "seatedExtensionHsr";
  const iso = exerciseId === "seatedExtensionIso" || sessionType === "isometrics";

  const warn48 = useMemo(
    () =>
      shouldWarnUnder48h(
        allSessions.map(sessionToSnapshot),
        sessionType,
        new Date(),
        existing?.id ?? null,
      ),
    [allSessions, sessionType, existing?.id],
  );

  const duringScores = sets
    .filter((s) => visible(s, side))
    .map((s) => s.painDuring)
    .filter((n): n is number => n !== null);
  const duringWarn = duringScores.some((n) => n > 5);

  const save = async () => {
    if (painAfter === null) return;
    setBusy(true);
    const now = new Date().toISOString();
    const work = structured ? sets.filter((s) => visible(s, side)) : [];
    const row: TrainingSession = {
      id: existing?.id ?? crypto.randomUUID(),
      date: existing?.date ?? todayKey,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      phase,
      sessionType,
      exerciseId,
      side,
      kneeAngle,
      tempo: isHsr || exerciseId === "seatedExtensionHsr" ? tempo : null,
      sets: work,
      painAfter,
      notes,
      whatIDid: describe(exerciseId, side, work, unit, tempo, iso),
      response24h: existing?.response24h ?? "pending",
      decision: existing?.decision ?? null,
      resolvedAt: existing?.resolvedAt ?? null,
      snoozedUntil: existing?.snoozedUntil ?? null,
      snoozeUsed: existing?.snoozeUsed ?? false,
    };
    await onSave(row);
    setBusy(false);
    onClose();
  };

  return (
    <Sheet
      open={open}
      title={existing ? "Edit session" : "Log session"}
      onClose={onClose}
      footer={
        <div className="flex flex-col gap-2">
          <PrimaryButton disabled={busy || painAfter === null} onClick={save}>
            {existing ? "Save changes" : "Save session"}
          </PrimaryButton>
          {existing && onDelete ? (
            <GhostButton
              danger
              onClick={async () => {
                await onDelete(existing.id);
                onClose();
              }}
            >
              Delete
            </GhostButton>
          ) : null}
        </div>
      }
    >
      <div className="flex flex-col gap-5">
        {warn48 ? (
          <p className="rounded-2xl border border-amber/40 bg-amber/10 px-3 py-2 text-sm text-amber">
            Hard sessions are supposed to sit ≥48h apart. This is a warning, not a block.
          </p>
        ) : null}
        {duringWarn ? (
          <p className="rounded-2xl border border-danger/40 bg-danger/10 px-3 py-2 text-sm text-danger">
            Pain during is above 5/10. Next morning is still the source of truth — consider a softer session.
          </p>
        ) : null}

        <Segmented<ExerciseId>
          ariaLabel="Exercise"
          value={exerciseId}
          onChange={(id) => {
            setExerciseId(id);
            setSessionType(typeFor(id));
          }}
          options={exerciseOptions(prescription)}
        />

        {structured ? (
          <>
            <Segmented<SessionSide>
              ariaLabel="Side"
              value={side}
              onChange={setSide}
              options={[
                { value: "both", label: "Both" },
                { value: "L", label: "Left" },
                { value: "R", label: "Right" },
              ]}
            />
            <p className="text-xs leading-5 text-muted">
              {side === "both"
                ? "Both sides in this one session — left and right set rows, one 24h resolve tomorrow."
                : "One side only. Prefer Both if you trained L and R — that stays one 24h unit, not two sessions."}
            </p>
            <div className="grid grid-cols-2 gap-3">
              <NumberField label="Knee angle °" value={kneeAngle} onChange={setKneeAngle} min={0} max={90} />
              {exerciseId === "seatedExtensionHsr" ? (
                <Field label="Tempo">
                  <input
                    value={tempo}
                    onChange={(e) => setTempo(e.target.value)}
                    className="h-11 rounded-xl border border-line bg-surface-2 px-3 text-base text-ink"
                    aria-label="Tempo"
                  />
                </Field>
              ) : (
                <p className="self-end text-xs text-muted">Holds @ ~70% · 2 min rest</p>
              )}
            </div>

            {(side === "both" ? (["L", "R"] as const) : ([side] as const)).map((s) => (
              <SetBlock
                key={s}
                side={s}
                unit={unit}
                iso={iso}
                rows={sets.filter((row) => row.side === s)}
                onChange={(next) =>
                  setSets((prev) => [...prev.filter((row) => row.side !== s), ...next])
                }
                onAdd={() =>
                  setSets((prev) => [
                    ...prev,
                    newSet(
                      s,
                      prescription.side === "both"
                        ? (s === "L" ? prescription.loadKgL : prescription.loadKgR) ?? 20
                        : 20,
                      prescription.holdSeconds,
                      prescription.reps,
                    ),
                  ])
                }
              />
            ))}
          </>
        ) : (
          <p className="text-sm text-muted">
            Log pain after this {EXERCISE_TITLES[exerciseId].toLowerCase()} session. 24h still applies.
          </p>
        )}

        <PainControl title="Pain after" value={painAfter} onChange={setPainAfter} optional={false} />
        <Field label="Notes">
          <textarea
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
            rows={2}
            className="rounded-xl border border-line bg-surface-2 px-3 py-2 text-sm text-ink"
          />
        </Field>
      </div>
    </Sheet>
  );
}

function visible(set: DraftSet, side: SessionSide): boolean {
  if (side === "both") return true;
  return set.side === side;
}

function typeFor(id: ExerciseId): SessionType {
  switch (id) {
    case "seatedExtensionIso":
    case "wallSit":
    case "spanishSquat":
      return "isometrics";
    case "seatedExtensionHsr":
      return "hsrStrength";
    case "landings":
      return "energyStorage";
    case "hitting":
    case "match":
      return "tennisSport";
    default:
      return "other";
  }
}

function exerciseOptions(p: TodayPrescription): Array<{ value: ExerciseId; label: string }> {
  const primary: ExerciseId[] =
    p.kind === "hsrExtension"
      ? ["seatedExtensionHsr", "seatedExtensionIso"]
      : p.kind === "energyStorage"
        ? ["landings", "seatedExtensionHsr"]
        : p.kind === "tennisHitting" || p.kind === "tennisMatch"
          ? ["hitting", "match", "seatedExtensionHsr"]
          : p.kind === "walk" || p.kind === "rest" || p.kind === "easyBike"
            ? ["walk", "bike"]
            : ["seatedExtensionIso", "wallSit", "spanishSquat"];
  return primary.map((value) => ({
    value,
    label:
      value === "seatedExtensionIso"
        ? "Ext iso"
        : value === "seatedExtensionHsr"
          ? "Ext HSR"
          : value === "spanishSquat"
            ? "Spanish"
            : value === "wallSit"
              ? "Wall sit"
              : EXERCISE_TITLES[value],
  }));
}

function describe(
  exerciseId: ExerciseId,
  side: SessionSide,
  sets: ExtensionSet[],
  unit: LoadUnit,
  tempo: string,
  iso: boolean,
): string {
  const work = sets.filter((s) => !s.isWarmup);
  if (work.length === 0) return EXERCISE_TITLES[exerciseId];
  const summary = work
    .map((s) => {
      const load = formatLoad(s.loadKg, unit);
      if (iso && s.holdSeconds) return `${s.side} ${s.holdSeconds}s @ ${load}`;
      return `${s.side} ${s.reps ?? 0}r @ ${load}`;
    })
    .slice(0, 4)
    .join(" · ");
  const sideLabel = side === "both" ? "L+R" : side;
  return `${EXERCISE_TITLES[exerciseId]} · ${sideLabel} · ${summary}${iso ? "" : ` · ${tempo}`}`;
}

function SetBlock({
  side,
  unit,
  iso,
  rows,
  onChange,
  onAdd,
}: {
  side: "L" | "R";
  unit: LoadUnit;
  iso: boolean;
  rows: DraftSet[];
  onChange: (rows: DraftSet[]) => void;
  onAdd: () => void;
}) {
  return (
    <section className="rounded-2xl border border-line bg-surface p-3">
      <div className="mb-2 flex items-center justify-between">
        <h3 className="text-sm font-semibold text-gold">{side === "L" ? "Left" : "Right"}</h3>
        <button type="button" className="text-xs text-muted" onClick={onAdd}>
          Add set
        </button>
      </div>
      <div className="flex flex-col gap-2">
        {rows.map((row, idx) => (
          <div key={row.id} className="grid grid-cols-12 items-end gap-2">
            <div className="col-span-3">
              <NumberField
                label={idx === 0 ? `Load ${loadUnitLabel(unit)}` : ""}
                value={kgToDisplay(row.loadKg, unit)}
                step={unit === "kg" ? 2.5 : 5}
                min={0}
                onChange={(n) =>
                  onChange(rows.map((r) => (r.id === row.id ? { ...r, loadKg: displayToKg(n, unit) } : r)))
                }
              />
            </div>
            <div className="col-span-3">
              <NumberField
                label={idx === 0 ? (iso ? "Hold s" : "Reps") : ""}
                value={iso ? (row.holdSeconds ?? 0) : (row.reps ?? 0)}
                min={0}
                onChange={(n) =>
                  onChange(
                    rows.map((r) =>
                      r.id === row.id
                        ? iso
                          ? { ...r, holdSeconds: n, reps: null }
                          : { ...r, reps: n, holdSeconds: null }
                        : r,
                    ),
                  )
                }
              />
            </div>
            <div className="col-span-5">
              <OptionalPainField
                label={idx === 0 ? "Pain" : ""}
                value={row.painDuring}
                onChange={(n) =>
                  onChange(rows.map((r) => (r.id === row.id ? { ...r, painDuring: n } : r)))
                }
              />
            </div>
            <button
              type="button"
              aria-label={`Remove ${side} set ${idx + 1}`}
              className="col-span-1 mb-1 h-11 text-muted"
              onClick={() => onChange(rows.filter((r) => r.id !== row.id))}
            >
              ×
            </button>
          </div>
        ))}
      </div>
    </section>
  );
}

function OptionalPainField({
  label,
  value,
  onChange,
}: {
  label: string;
  value: number | null;
  onChange: (n: number | null) => void;
}) {
  return (
    <Field label={label}>
      <input
        type="number"
        inputMode="numeric"
        min={0}
        max={10}
        value={value === null ? "" : value}
        aria-label={label || "Pain during set"}
        placeholder="—"
        onChange={(e) => {
          const raw = e.target.value;
          if (raw === "") {
            onChange(null);
            return;
          }
          const n = Number(raw);
          if (!Number.isFinite(n)) return;
          onChange(Math.min(10, Math.max(0, Math.round(n))));
        }}
        className="h-11 rounded-xl border border-line bg-surface-2 px-3 text-base text-ink outline-none focus:border-gold"
      />
    </Field>
  );
}
