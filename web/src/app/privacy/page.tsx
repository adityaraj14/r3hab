import type { Metadata } from "next";
import { LegalDoc } from "@/components/LegalDoc";
import { DISCLAIMER } from "@/domain/types";

export const metadata: Metadata = {
  title: "Privacy — R3hab",
  description: "R3hab is a local-only patellar tendinopathy diary. No account. No tracking.",
};

export default function PrivacyPage() {
  return (
    <LegalDoc title="Privacy">
      <p>{DISCLAIMER}</p>
      <p>
        R3hab is a personal, local-only diary for patellar tendinopathy. There is no account, no
        sign-in, and no server that stores your health data. The web app does not track you,
        analytics are not included, and nothing is sold or shared with advertisers.
      </p>
      <p>
        Pain scores, sessions, check-ins, and settings stay on this device (IndexedDB in the
        browser). Export is a JSON file you choose to download. Import is a file you choose to
        open. We do not upload backups.
      </p>
      <p>
        HealthKit is native-only (the iOS app). When used, it reads step count to help Phase A
        exit — not pain, not sessions, not a full activity graph. The web PWA does not use
        HealthKit.
      </p>
      <p>
        Contact:{" "}
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
