import type { Metadata } from "next";
import Link from "next/link";
import { LegalDoc } from "@/components/LegalDoc";
import { DISCLAIMER } from "@/domain/types";

export const metadata: Metadata = {
  title: "Support — R3hab",
  description: "Help for the R3hab patellar tendinopathy log. Not a medical device.",
};

export default function SupportPage() {
  return (
    <LegalDoc title="Support">
      <p>{DISCLAIMER}</p>
      <p>
        R3hab is a personal patellar tendinopathy log — jumper&apos;s knee only. It is not a
        clinic, not a medical device, and not a protocol for other injuries.
      </p>
      <p>
        <span className="font-semibold text-ink">24h resolve.</span> Log a seated-extension
        session; it starts Pending. The next morning, mark Better / Same / Worse. Same → Stay.
        Better → Stay, or Progress after 3 clean sessions. Worse → Soft cut first. Mild pain
        during load is OK if the next morning is not worse.
      </p>
      <p>
        <span className="font-semibold text-ink">Export.</span> Settings → Export JSON. That
        file stays on your device until you share it. Import replaces local logs from a backup
        you choose.
      </p>
      <p>
        Privacy, storage, and HealthKit (native steps only):{" "}
        <Link href="/privacy" className="text-gold underline-offset-2 hover:underline">
          /privacy
        </Link>
        .
      </p>
      <p>
        Issues and contact:{" "}
        <a
          href="https://github.com/adityaraj14/r3hab"
          className="text-gold underline-offset-2 hover:underline"
        >
          github.com/adityaraj14/r3hab
        </a>
        .
      </p>
    </LegalDoc>
  );
}
