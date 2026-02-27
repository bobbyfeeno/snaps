import { ScrollViewStyleReset } from 'expo-router/html';
import type { PropsWithChildren } from 'react';

// This file controls the HTML shell for the Expo web build.
// It allows us to set the viewport meta tag to prevent pinch-zoom
// and ensure the app fills the full screen without zoom/scroll artifacts.

export default function Root({ children }: PropsWithChildren) {
  return (
    <html lang="en">
      <head>
        <meta charSet="utf-8" />
        <meta httpEquiv="X-UA-Compatible" content="IE=edge" />
        {/* Prevent pinch-to-zoom and fix layout in corner bug */}
        <meta
          name="viewport"
          content="width=device-width, initial-scale=1, maximum-scale=1, minimum-scale=1, user-scalable=no, viewport-fit=cover"
        />
        {/* Ensure root fills the screen */}
        <ScrollViewStyleReset />
        <style dangerouslySetInnerHTML={{
          __html: `
            html, body, #root {
              width: 100%;
              height: 100%;
              margin: 0;
              padding: 0;
              overflow: hidden;
              background-color: #0a0a0a;
            }
          `
        }} />
      </head>
      <body>{children}</body>
    </html>
  );
}
