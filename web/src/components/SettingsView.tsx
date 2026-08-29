"use client";

import { useRef, useState } from "react";
import { DISCLAIMER, PHASE_TITLES, type IsoProtocol, type LoadUnit, type RehabPhase } from "@/domain/types";
import { REHAB_PHASES } from "@/domain/types";
import { PHASE_RULES, RED_FLAGS } from "@/domain/phaseCopy";
import { useStore } from "@/data/store";
import { Field, GhostButton, PrimaryButton, Segmented, Sheet } from "./ui";

export function SettingsView() {
  const { settings, checkIns, sessions, updateSettings, exportJson, importJson, clearLogs, loadDemo } =
    useStore();
  const [confirmPhase, setConfirmPhase] = useState<RehabPhase | null>(null);
  const [confirmClear, setConfirmClear] = useState(false);
  const [message, setMessage] = useState<string | null>(null);
  const fileRef = useRef<HTMLInputElement>(null);

  const skipWarn = (next: RehabPhase) =>
    next === "E" && (settings.currentPhase === "A" || settings.currentPhase === "B");

  return (
    <div className="mx-auto flex w-full max-w-2xl flex-col gap-6 pb-8">
      <h1 className="font-display text-2xl tracking-wide">Settings</h1>

      <section className="rounded-3xl border border-line bg-surface p-4">
        <p className="text-xs font-semibold uppercase tracking-[0.16em] text-muted">Phase</p>
        <p className="mt-2 text-sm text-ink">{PHASE_TITLES[settings.currentPhase]}</p>
        <p className="mt-1 text-sm text-muted">{PHASE_RULES[settings.currentPhase].do}</p>
        <div className="mt-3 grid grid-cols-5 gap-1">
          {REHAB_PHASES.map((p) => (
            <button
              key={p}
              type="button"
              onClick={() => setConfirmPhase(p)}
              className={`h-10 rounded-xl text-sm font-semibold ${
                settings.currentPhase === p ? "bg-gold text-black" : "bg-surface-2 text-muted"
              }`}
            >
              {p}
            </button>
          ))}
        </div>
        <p className="mt-3 text-xs text-muted">You own the phase. The app never auto-advances.</p>
      </section>

      <section className="rounded-3xl border border-line bg-surface p-4">
        <p className="text-xs font-semibold uppercase tracking-[0.16em] text-muted">Units & protocol</p>
        <div className="mt-3">
          <Segmented<LoadUnit>
            ariaLabel="Load units"
            value={settings.loadUnit}
            onChange={(loadUnit) => updateSettings({ loadUnit })}
            options={[
              { value: "kg", label: "kg" },
              { value: "lb", label: "lbs" },
            ]}
          />
        </div>
        <div className="mt-3">
          <Segmented<IsoProtocol>
            ariaLabel="Isometric protocol"
            value={settings.isoProtocol}
            onChange={(isoProtocol) => updateSettings({ isoProtocol })}
            options={[
              { value: "holds45", label: "5×45s" },
              { value: "rioPulses", label: "Rio pulses" },
            ]}
          />
        </div>
      </section>

      <section className="rounded-3xl border border-line bg-surface p-4">
        <p className="text-xs font-semibold uppercase tracking-[0.16em] text-muted">Phase A thresholds</p>
        <div className="mt-3 grid grid-cols-3 gap-2">
          <Field label="Stable days">
            <input
              type="number"
              min={2}
              max={7}
              value={settings.phaseAStableDaysRequired}
              onChange={(e) => updateSettings({ phaseAStableDaysRequired: Number(e.target.value) })}
              className="h-11 rounded-xl border border-line bg-surface-2 px-3 text-ink"
            />
          </Field>
          <Field label="AM max">
            <input
              type="number"
              min={0}
              max={5}
              value={settings.phaseAPainThreshold}
              onChange={(e) => updateSettings({ phaseAPainThreshold: Number(e.target.value) })}
              className="h-11 rounded-xl border border-line bg-surface-2 px-3 text-ink"
            />
          </Field>
          <Field label="Steps min">
            <input
              type="number"
              min={3000}
              step={500}
              value={settings.stepNearNormalMin}
              onChange={(e) => updateSettings({ stepNearNormalMin: Number(e.target.value) })}
              className="h-11 rounded-xl border border-line bg-surface-2 px-3 text-ink"
            />
          </Field>
        </div>
      </section>

      <section className="rounded-3xl border border-line bg-surface p-4">
        <p className="text-xs font-semibold uppercase tracking-[0.16em] text-muted">Backup</p>
        <p className="mt-2 text-sm text-muted">
          {checkIns.length} check-ins · {sessions.length} sessions · schemaVersion 2
        </p>
        <div className="mt-3 flex flex-col gap-2">
          <PrimaryButton
            onClick={async () => {
              const json = await exportJson();
              const blob = new Blob([json], { type: "application/json" });
              const url = URL.createObjectURL(blob);
              const a = document.createElement("a");
              a.href = url;
              a.download = `r3hab-backup-${new Date().toISOString().slice(0, 10)}.json`;
              a.click();
              URL.revokeObjectURL(url);
            }}
          >
            Export JSON
          </PrimaryButton>
          <GhostButton onClick={() => fileRef.current?.click()}>Import JSON</GhostButton>
          <input
            ref={fileRef}
            type="file"
            accept="application/json"
            className="hidden"
            onChange={async (e) => {
              const file = e.target.files?.[0];
              if (!file) return;
              try {
                await importJson(await file.text(), "replace");
                setMessage("Imported (replace).");
              } catch (err) {
                setMessage(err instanceof Error ? err.message : "Import failed");
              }
            }}
          />
          <GhostButton
            onClick={async () => {
              await loadDemo();
              setMessage("Demo week loaded. Today has a prescription, a pending 24h, and charts.");
            }}
          >
            Load demo week
          </GhostButton>
          <GhostButton danger onClick={() => setConfirmClear(true)}>
            Clear logs
          </GhostButton>
        </div>
      </section>

      <section className="rounded-3xl border border-line bg-surface p-4">
        <p className="text-xs font-semibold uppercase tracking-[0.16em] text-muted">Disclaimer</p>
        <p className="mt-2 text-sm leading-6 text-muted">{DISCLAIMER}</p>
        <p className="mt-3 text-sm leading-6 text-muted">{RED_FLAGS}</p>
        <p className="mt-3 text-xs text-muted">
          This app is knee-only — patellar tendinopathy. No low-back / QL protocol.
        </p>
        <p className="mt-2 text-xs text-muted">Protocol {settings.protocolRevision}</p>
      </section>

      {message ? <p className="text-sm text-gold">{message}</p> : null}

      <Sheet
        open={confirmPhase !== null}
        title="Change phase"
        onClose={() => setConfirmPhase(null)}
        footer={
          <PrimaryButton
            onClick={async () => {
              if (confirmPhase) await updateSettings({ currentPhase: confirmPhase });
              setConfirmPhase(null);
            }}
          >
            Confirm {confirmPhase}
          </PrimaryButton>
        }
      >
        {confirmPhase ? (
          <div className="flex flex-col gap-3 text-sm text-muted">
            {skipWarn(confirmPhase) ? (
              <p className="text-amber">Never skip to tennis from A/B. Energy storage exists for a reason.</p>
            ) : null}
            <p>{PHASE_RULES[confirmPhase].do}</p>
            <p>Advance: {PHASE_RULES[confirmPhase].advance}</p>
          </div>
        ) : null}
      </Sheet>

      <Sheet
        open={confirmClear}
        title="Clear all logs"
        onClose={() => setConfirmClear(false)}
        footer={
          <GhostButton
            danger
            onClick={async () => {
              await clearLogs();
              setConfirmClear(false);
              setMessage("Logs cleared. Phase and settings kept.");
            }}
          >
            Wipe check-ins and sessions
          </GhostButton>
        }
      >
        <p className="text-sm text-muted">This cannot be undone unless you have a JSON backup.</p>
      </Sheet>
    </div>
  );
}
