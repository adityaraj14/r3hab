"use client";

import { Suspense } from "react";
import { ProgressView } from "@/components/ProgressView";

export default function ProgressPage() {
  return (
    <Suspense fallback={<div className="text-muted">Loading progress…</div>}>
      <ProgressView />
    </Suspense>
  );
}
