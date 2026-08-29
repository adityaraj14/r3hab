"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import type { ReactNode } from "react";
import { BrandMark, Wordmark } from "./ui";

const TABS = [
  { href: "/", label: "Today" },
  { href: "/log", label: "Log" },
  { href: "/progress", label: "Progress" },
] as const;

function Tabs({ pendingCount, desktop }: { pendingCount: number; desktop: boolean }) {
  const pathname = usePathname();
  return (
    <ul className={desktop ? "flex gap-6 px-6" : "mx-auto grid max-w-lg grid-cols-3"}>
      {TABS.map((tab) => {
        const active = pathname === tab.href;
        return (
          <li key={tab.href}>
            <Link
              href={tab.href}
              className={`relative flex items-center justify-center font-semibold uppercase tracking-[0.14em] ${
                desktop ? "h-12 text-sm tracking-[0.16em]" : "h-14 text-[13px]"
              } ${active ? "text-gold" : "text-muted"}`}
            >
              {tab.label}
              {tab.href === "/" && pendingCount > 0 ? (
                <span
                  className={`rounded-full bg-hot px-1.5 text-[10px] font-bold text-white ${
                    desktop ? "ml-2" : "absolute right-6 top-2"
                  }`}
                >
                  {pendingCount}
                </span>
              ) : null}
            </Link>
          </li>
        );
      })}
    </ul>
  );
}

export function AppShell({
  children,
  pendingCount = 0,
}: {
  children: ReactNode;
  pendingCount?: number;
}) {
  return (
    <div className="mx-auto flex min-h-dvh w-full max-w-6xl flex-col">
      <header className="sticky top-0 z-30 flex items-center justify-between border-b border-line/80 bg-bg/90 px-4 py-3 backdrop-blur md:px-6">
        <Link href="/" className="flex items-center gap-3">
          <BrandMark size={40} />
          <Wordmark />
        </Link>
        <Link
          href="/settings"
          className="rounded-full border border-line px-3 py-1.5 text-xs font-semibold uppercase tracking-[0.16em] text-muted"
        >
          Settings
        </Link>
      </header>
      <nav className="sticky top-[57px] z-20 hidden border-b border-line bg-bg md:block">
        <Tabs pendingCount={pendingCount} desktop />
      </nav>
      <main className="flex-1 px-4 pb-28 pt-4 md:px-6 md:pb-10 md:pt-6">{children}</main>
      <nav className="fixed inset-x-0 bottom-0 z-30 border-t border-line bg-bg/95 pb-[env(safe-area-inset-bottom)] backdrop-blur md:hidden">
        <Tabs pendingCount={pendingCount} desktop={false} />
      </nav>
    </div>
  );
}
