"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { useStore } from "@/data/store";
import { BrandMark, PrimaryButton, Wordmark } from "@/components/ui";

export default function DemoPage() {
  const { ready, loadDemo } = useStore();
  const router = useRouter();
  const [status, setStatus] = useState("Loading demo week…");

  useEffect(() => {
    if (!ready) return;
    void (async () => {
      await loadDemo();
      setStatus("Demo week is in. Today has a prescription, a pending 24h, and charts.");
    })();
  }, [ready, loadDemo]);

  return (
    <div className="mx-auto flex min-h-dvh w-full max-w-md flex-col items-center justify-center gap-5 px-6 text-center">
      <BrandMark size={72} />
      <Wordmark />
      <p className="font-display text-3xl leading-none">Dogfood in under 3 minutes</p>
      <ol className="w-full list-decimal space-y-2 pl-5 text-left text-sm leading-6 text-muted">
        <li>Today — read the prescription, start the session, log left + right extension.</li>
        <li>Resolve the pending 24h (Better / Same / Worse).</li>
        <li>Progress — open explorer, brush/zoom, toggle L/R load vs AM pain, tap a point.</li>
      </ol>
      <p className="text-sm text-gold">{status}</p>
      <PrimaryButton onClick={() => router.push("/")}>Open Today</PrimaryButton>
    </div>
  );
}
