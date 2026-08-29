"use client";

import Link from "next/link";
import type { ReactNode } from "react";
import { BrandMark, Wordmark } from "./ui";

export function LegalDoc({ title, children }: { title: string; children: ReactNode }) {
  return (
    <div className="mx-auto flex min-h-dvh w-full max-w-lg flex-col px-5 pb-[max(2rem,env(safe-area-inset-bottom))] pt-[max(1.25rem,env(safe-area-inset-top))]">
      <Link href="/" className="flex items-center gap-3">
        <BrandMark size={40} />
        <Wordmark />
      </Link>
      <h1 className="mt-8 font-display text-3xl leading-none tracking-wide text-ink">{title}</h1>
      <div className="mt-6 flex flex-col gap-4 text-sm leading-6 text-muted">{children}</div>
      <nav className="mt-10 flex gap-5 text-xs font-semibold uppercase tracking-[0.14em] text-gold">
        <Link href="/privacy">Privacy</Link>
        <Link href="/support">Support</Link>
        <Link href="/">App</Link>
      </nav>
    </div>
  );
}
