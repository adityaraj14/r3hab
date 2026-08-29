import type { Metadata, Viewport } from "next";
import { Oswald } from "next/font/google";
import { PwaRegister } from "@/components/PwaRegister";
import { Providers } from "@/components/Providers";
import "./globals.css";

const oswald = Oswald({
  subsets: ["latin"],
  variable: "--font-display",
  weight: ["500", "600", "700"],
});

export const metadata: Metadata = {
  title: "R3hab",
  description: "Patellar tendinopathy rehab. Progressive loading. 24h pain loop.",
  applicationName: "R3hab",
  manifest: "/manifest.webmanifest",
  appleWebApp: {
    capable: true,
    statusBarStyle: "black-translucent",
    title: "R3hab",
  },
  icons: {
    icon: "/r3hab-mark.png",
    apple: "/r3hab-mark.png",
  },
};

export const viewport: Viewport = {
  themeColor: "#000000",
  width: "device-width",
  initialScale: 1,
  viewportFit: "cover",
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html lang="en" className={`${oswald.variable} h-full dark`}>
      <body className="min-h-full bg-bg text-ink antialiased">
        <PwaRegister />
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}
