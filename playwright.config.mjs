import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './tests/browser',
  timeout: 240_000,
  expect: { timeout: 15_000 },
  fullyParallel: false,
  workers: 1,
  retries: 0,
  forbidOnly: true,
  outputDir: 'artifacts/browser',
  reporter: [['list'], ['json', { outputFile: 'artifacts/browser-results.json' }], ['html', { outputFolder: 'artifacts/browser-report', open: 'never' }]],
  use: {
    browserName: 'chromium',
    headless: true,
    viewport: { width: 960, height: 600 },
    baseURL: 'http://127.0.0.1:4178',
    actionTimeout: 15_000,
    trace: 'on',
    screenshot: 'only-on-failure',
    launchOptions: { args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--mute-audio'] },
  },
  webServer: { command: 'node tools/serve-web.mjs', url: 'http://127.0.0.1:4178', reuseExistingServer: false, timeout: 15_000 },
});
