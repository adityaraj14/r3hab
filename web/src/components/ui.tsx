"use client";

import Image from "next/image";
import type { ReactNode } from "react";
import type { RehabPhase } from "@/domain/types";
import { PHASE_SHORT } from "@/domain/types";

export function BrandMark({ size = 36 }: { size?: number }) {
  return (
    <Image
      src="/r3hab-mark.png"
      alt="R3hab"
      width={size}
      height={size}
      className="rounded-[22%] shadow-[0_0_24px_rgba(255,106,26,0.25)]"
      priority
    />
  );
}

export function Wordmark() {
  return (
    <span className="font-display text-[22px] leading-none tracking-[0.12em] text-ink">
      R<span className="ember-text">3</span>hab
    </span>
  );
}

export function PhaseChip({ phase }: { phase: RehabPhase }) {
  return (
    <span className="inline-flex items-center gap-1 rounded-full border border-gold/30 bg-gold/10 px-2.5 py-1 text-[11px] font-semibold uppercase tracking-[0.14em] text-gold">
      Phase {phase}
      <span className="font-medium tracking-normal text-muted">· {PHASE_SHORT[phase]}</span>
    </span>
  );
}

export function PainControl({
  title,
  value,
  onChange,
  optional = true,
}: {
  title: string;
  value: number | null;
  onChange: (n: number | null) => void;
  optional?: boolean;
}) {
  const tone =
    value === null ? "text-muted" : value >= 5 ? "text-danger" : value >= 3 ? "text-amber" : "text-gold";
  return (
    <div className="flex flex-col gap-2">
      <div className="flex items-baseline justify-between gap-3">
        <span className="text-sm font-semibold text-ink">{title}</span>
        <span className={`font-display text-2xl tabular-nums ${tone}`} aria-live="polite">
          {value === null ? "—" : value}
        </span>
      </div>
      <div role="radiogroup" aria-label={title} className="grid grid-cols-11 gap-1">
        {Array.from({ length: 11 }, (_, n) => {
          const selected = value === n;
          const hot = n >= 5;
          const mid = n >= 3 && n < 5;
          return (
            <button
              key={n}
              type="button"
              role="radio"
              aria-checked={selected}
              aria-label={`${title} ${n}`}
              onClick={() => onChange(n)}
              className={`h-10 rounded-md text-[12px] font-semibold tabular-nums transition ${
                selected
                  ? hot
                    ? "bg-hot text-white"
                    : mid
                      ? "bg-ember text-black"
                      : "bg-gold text-black"
                  : "bg-surface-2 text-muted hover:bg-line"
              }`}
            >
              {n}
            </button>
          );
        })}
      </div>
      {optional && value !== null ? (
        <button
          type="button"
          className="self-start text-xs text-muted underline-offset-2 hover:underline"
          onClick={() => onChange(null)}
        >
          Clear
        </button>
      ) : null}
    </div>
  );
}

export function PrimaryButton({
  children,
  onClick,
  disabled,
  type = "button",
}: {
  children: ReactNode;
  onClick?: () => void;
  disabled?: boolean;
  type?: "button" | "submit";
}) {
  return (
    <button
      type={type}
      disabled={disabled}
      onClick={onClick}
      className="flex h-12 w-full items-center justify-center rounded-2xl ember-gradient text-[15px] font-semibold text-black shadow-[0_8px_24px_rgba(255,69,0,0.25)] disabled:opacity-40"
    >
      {children}
    </button>
  );
}

export function GhostButton({
  children,
  onClick,
  danger,
}: {
  children: ReactNode;
  onClick?: () => void;
  danger?: boolean;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={`flex h-12 w-full items-center justify-center rounded-2xl border text-[15px] font-semibold ${
        danger ? "border-danger/40 text-danger" : "border-line text-ink"
      }`}
    >
      {children}
    </button>
  );
}

export function EmptyState({
  title,
  body,
  cta,
  onClick,
}: {
  title: string;
  body: string;
  cta: string;
  onClick: () => void;
}) {
  return (
    <div className="flex flex-col items-start gap-3 rounded-3xl border border-line bg-surface px-5 py-6">
      <h2 className="font-display text-xl text-ink">{title}</h2>
      <p className="text-sm leading-6 text-muted">{body}</p>
      <PrimaryButton onClick={onClick}>{cta}</PrimaryButton>
    </div>
  );
}

export function Sheet({
  open,
  title,
  onClose,
  children,
  footer,
}: {
  open: boolean;
  title: string;
  onClose: () => void;
  children: ReactNode;
  footer?: ReactNode;
}) {
  if (!open) return null;
  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center sm:items-center">
      <button
        type="button"
        aria-label="Close"
        className="absolute inset-0 bg-black/70"
        onClick={onClose}
      />
      <div
        role="dialog"
        aria-modal="true"
        aria-label={title}
        className="relative flex max-h-[92dvh] w-full max-w-lg flex-col rounded-t-3xl border border-line bg-bg sm:max-h-[88vh] sm:rounded-3xl"
      >
        <div className="flex items-center justify-between border-b border-line px-5 py-4">
          <h2 className="font-display text-lg tracking-wide text-ink">{title}</h2>
          <button type="button" onClick={onClose} className="text-sm text-muted">
            Close
          </button>
        </div>
        <div className="flex-1 overflow-y-auto px-5 py-4">{children}</div>
        {footer ? <div className="border-t border-line px-5 py-4">{footer}</div> : null}
      </div>
    </div>
  );
}

export function Segmented<T extends string>({
  value,
  onChange,
  options,
  ariaLabel,
}: {
  value: T;
  onChange: (v: T) => void;
  options: Array<{ value: T; label: string }>;
  ariaLabel: string;
}) {
  return (
    <div
      role="radiogroup"
      aria-label={ariaLabel}
      className="grid gap-1 rounded-2xl bg-surface-2 p-1"
      style={{ gridTemplateColumns: `repeat(${options.length}, minmax(0, 1fr))` }}
    >
      {options.map((opt) => {
        const selected = opt.value === value;
        return (
          <button
            key={opt.value}
            type="button"
            role="radio"
            aria-checked={selected}
            onClick={() => onChange(opt.value)}
            className={`h-10 rounded-xl text-sm font-semibold ${
              selected ? "bg-gold text-black" : "text-muted"
            }`}
          >
            {opt.label}
          </button>
        );
      })}
    </div>
  );
}

export function Field({ label, children }: { label: string; children: ReactNode }) {
  return (
    <label className="flex flex-col gap-1.5 text-sm">
      <span className="text-muted">{label}</span>
      {children}
    </label>
  );
}

export function NumberField({
  label,
  value,
  onChange,
  min,
  max,
  step,
}: {
  label: string;
  value: number;
  onChange: (n: number) => void;
  min?: number;
  max?: number;
  step?: number;
}) {
  return (
    <Field label={label}>
      <input
        type="number"
        inputMode="decimal"
        min={min}
        max={max}
        step={step}
        value={Number.isFinite(value) ? value : ""}
        aria-label={label}
        onChange={(e) => onChange(Number(e.target.value))}
        className="h-11 rounded-xl border border-line bg-surface-2 px-3 text-base text-ink outline-none focus:border-gold"
      />
    </Field>
  );
}
