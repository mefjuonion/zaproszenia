import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "base-web",
  description: "Next.js on Cloud Run",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
