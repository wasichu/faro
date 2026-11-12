import {defineConfig, devices} from "@playwright/test"

const port = process.env.PLAYWRIGHT_PORT || "4793"

export default defineConfig({
  testDir: "./test/browser",
  fullyParallel: true,
  workers: 2,
  forbidOnly: Boolean(process.env.CI),
  retries: 0,
  timeout: 60_000,
  reporter: [["list"], ["html", {open: "never"}]],
  use: {
    baseURL: `http://localhost:${port}`,
    trace: "retain-on-failure",
    screenshot: "only-on-failure",
  },
  projects: [
    {name: "desktop", use: {...devices["Desktop Chrome"], viewport: {width: 1440, height: 1000}}},
    {name: "mobile", use: {...devices["Pixel 7"], viewport: {width: 390, height: 844}}},
  ],
  webServer: {
    command: "mix ecto.create --quiet && mix ecto.migrate --quiet && mix assets.build && mix phx.server",
    env: {
      MIX_ENV: "test",
      PHX_SERVER: "true",
      PORT: port,
      FARO_TEST_DATABASE: "faro_browser_test",
    },
    url: `http://localhost:${port}`,
    reuseExistingServer: false,
    timeout: 120_000,
    gracefulShutdown: {signal: "SIGTERM", timeout: 5_000},
  },
})
