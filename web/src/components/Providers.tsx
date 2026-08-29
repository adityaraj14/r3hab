"use client";

import { usePathname } from "next/navigation";
import type { ReactNode } from "react";
import { StoreProvider, useStore } from "@/data/store";
import { overduePending } from "@/domain/pendingQueue";
import { sessionToSnapshot } from "@/domain/types";
import { AppShell } from "./AppShell";
import { Onboarding } from "./Onboarding";
import { BrandMark, Wordmark } from "./ui";

function Gate({ children }: { children: ReactNode }) {
  const { ready, settings, sessions, updateSettings } = useStore();
  const pathname = usePathname();
  if (!ready) {
    return (
      <div className="flex min-h-dvh flex-col items-center justify-center gap-4 bg-bg">
        <BrandMark size={72} />
        <Wordmark />
      </div>
    );
  }
  const pending = overduePending(sessions.map(sessionToSnapshot), new Date()).length;
  const hideChrome = pathname === "/demo";
  return (
    <>
      {hideChrome ? children : <AppShell pendingCount={pending}>{children}</AppShell>}
      {!settings.hasCompletedOnboarding && pathname !== "/demo" ? (
        <Onboarding
          onDone={async ({ phase, unit }) => {
            await updateSettings({
              hasCompletedOnboarding: true,
              currentPhase: phase,
              loadUnit: unit,
            });
          }}
        />
      ) : null}
    </>
  );
}

export function Providers({ children }: { children: ReactNode }) {
  return (
    <StoreProvider>
      <Gate>{children}</Gate>
    </StoreProvider>
  );
}
