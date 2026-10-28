import "./globals.css";

import { Inter as FontSans } from "next/font/google";
import { ThemeProvider } from "@/components/theme/theme-provider";
import { Nav } from "@/components/layout/nav";
import { Footer } from "@/components/layout/footer";
import { CloudflareWebAnalytics } from "@/components/analytics";
import { UnconnectedNotice } from "@/components/unconnected-notice";

import { siteConfig } from "@/site.config";
import { cn } from "@/lib/utils";

import type { Metadata } from "next";

const font = FontSans({
  subsets: ["latin"],
  variable: "--font-sans",
});

export const metadata: Metadata = {
  title: siteConfig.site_name,
  description:
    "A starter template for Next.js with WordPress as a headless CMS.",
  metadataBase: new URL(siteConfig.site_domain),
  alternates: {
    canonical: "/",
  },
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" suppressHydrationWarning>
      <head />
      <body className={cn("min-h-screen font-sans antialiased", font.variable)}>
        <ThemeProvider
          attribute="class"
          defaultTheme="system"
          enableSystem
          disableTransitionOnChange
        >
          <UnconnectedNotice />
          <Nav />
          {children}
          <Footer />
        </ThemeProvider>
        <CloudflareWebAnalytics />
      </body>
    </html>
  );
}
