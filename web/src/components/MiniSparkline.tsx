"use client";

import { useMemo } from "react";
import type { DayValue } from "@/domain/chartAggregates";

export function MiniSparkline({
  points,
  onClick,
  label,
}: {
  points: DayValue[];
  onClick: () => void;
  label: string;
}) {
  const path = useMemo(() => {
    const vals = points.map((p) => p.value);
    const w = 280;
    const h = 48;
    const xs = points.map((_, i) => (points.length <= 1 ? 0 : (i / (points.length - 1)) * w));
    const max = 10;
    const coords = points.map((p, i) => {
      if (p.value === null) return null;
      const y = h - (p.value / max) * (h - 4) - 2;
      return `${xs[i]},${y}`;
    });
    const chunks: string[] = [];
    let current: string[] = [];
    for (const c of coords) {
      if (c === null) {
        if (current.length) chunks.push(current.join(" "));
        current = [];
      } else {
        current.push(c);
      }
    }
    if (current.length) chunks.push(current.join(" "));
    return { chunks, w, h, empty: vals.every((v) => v === null) };
  }, [points]);

  return (
    <button
      type="button"
      onClick={onClick}
      aria-label={`${label}. Open progress explorer`}
      className="w-full rounded-2xl border border-line bg-surface px-4 py-3 text-left"
    >
      <div className="mb-2 flex items-center justify-between">
        <span className="text-xs font-semibold uppercase tracking-[0.16em] text-muted">{label}</span>
        <span className="text-xs text-gold">Open explorer</span>
      </div>
      {path.empty ? (
        <p className="text-sm text-muted">No AM pain yet.</p>
      ) : (
        <svg viewBox={`0 0 ${path.w} ${path.h}`} className="h-12 w-full" role="img" aria-hidden>
          {path.chunks.map((d) => (
            <polyline
              key={d}
              fill="none"
              stroke="url(#ember)"
              strokeWidth="2.5"
              points={d}
            />
          ))}
          <defs>
            <linearGradient id="ember" x1="0" y1="0" x2="1" y2="0">
              <stop offset="0%" stopColor="#ffd56a" />
              <stop offset="100%" stopColor="#ff4500" />
            </linearGradient>
          </defs>
        </svg>
      )}
    </button>
  );
}
