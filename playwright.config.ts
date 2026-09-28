import { defineConfig, devices } from '@playwright/test'

// E2E de la consola DBB Labs. Requisito: el lab local arriba (bash dashboard/servir.sh)
// más el lab de kapa21 (supabase + app en :3000) para los tests de ataque en vivo.
export default defineConfig({
  testDir: './e2e',
  fullyParallel: false,          // los tests comparten estado.json (lanzan ataques)
  workers: 1,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 1 : 0,
  reporter: 'list',
  timeout: 60_000,
  use: {
    baseURL: 'http://127.0.0.1:8899',
    trace: 'on-first-retry',
    locale: 'es-CL',
  },
  projects: [{ name: 'escritorio', use: { ...devices['Desktop Chrome'] } }],
  webServer: {
    command: 'python3 servidor.py 8899',
    cwd: './dashboard',
    url: 'http://127.0.0.1:8899',
    reuseExistingServer: true,
    timeout: 20_000,
  },
})
