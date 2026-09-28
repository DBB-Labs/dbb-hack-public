import { test, expect, Page } from '@playwright/test'

// Espera a que el catálogo de vectores esté pintado.
async function esperarCatalogo(page: Page) {
  await page.waitForFunction(() => document.querySelectorAll('.cv').length > 0, null, { timeout: 15_000 })
}

// Deja marcados SOLO los vectores indicados (para correr rápido).
async function soloVectores(page: Page, ids: string[]) {
  await esperarCatalogo(page)
  await page.evaluate((sel) => {
    document.querySelectorAll<HTMLInputElement>('.cv').forEach((c) => { c.checked = sel.includes(c.value) })
  }, ids)
}

test.describe('Consola DBB Labs', () => {
  test('carga con sus paneles principales', async ({ page }) => {
    await page.goto('/')
    await expect(page.locator('.brand h1')).toContainText('DBB')
    await expect(page.getByText('Panel de control · seleccionar y lanzar')).toBeVisible()
    await expect(page.locator('#prog-pct')).toBeVisible()          // torta de progreso
    await expect(page.locator('#atk')).toBeVisible()               // matriz de ataque
    await expect(page.locator('#feed')).toBeVisible()              // feed
    await expect(page.locator('#k-vec')).toBeVisible()             // KPIs
    await expect(page.getByRole('button', { name: /LANZAR ATAQUE/ })).toBeVisible()
  })

  test('el nivel controla qué vectores se ofrecen', async ({ page }) => {
    await page.goto('/')
    await page.selectOption('#c-niv', 'low')
    await expect(page.locator('#c-vecs')).toContainText('S1')      // estático
    await expect(page.locator('#c-vecs')).not.toContainText('A0')  // vivo no aparece en LOW
    await page.selectOption('#c-niv', 'full')
    await expect(page.locator('#c-vecs')).toContainText('A0')      // vivo aparece en FULL
  })

  test('limpiar deja la consola en blanco', async ({ page }) => {
    await page.goto('/')
    await page.getByRole('button', { name: /Limpiar/ }).click()
    await expect(page.locator('#k-vec')).toHaveText('0')
    await expect(page.locator('#prog-pct')).toHaveText('0%')
  })

  test('lanzar un ataque llega al 100% y llena la matriz', async ({ page }) => {
    await page.goto('/')
    await soloVectores(page, ['A0', 'A6'])                          // externos, rápidos
    await page.getByRole('button', { name: /LANZAR ATAQUE/ }).click()
    await expect(page.locator('#prog-pct')).toHaveText('100%', { timeout: 40_000 })
    await expect(page.locator('#atk')).toContainText('A0')
    await expect(page.locator('#atk')).toContainText('A6')
    // A0 debe salir defendido (la API no expone esquemas sensibles)
    await expect(page.locator('.card', { hasText: 'A0 · Robo externo' })).toContainText('Defendido')
  })

  test('un hallazgo abre el drawer con su prompt de remediación y botón copiar', async ({ page }) => {
    await page.goto('/')
    await soloVectores(page, ['A6'])                                // fuerza bruta → hallazgo
    await page.getByRole('button', { name: /LANZAR ATAQUE/ }).click()
    await expect(page.locator('#prog-pct')).toHaveText('100%', { timeout: 40_000 })
    await page.locator('.card', { hasText: 'A6 · Fuerza bruta' }).click()
    await expect(page.locator('#drawer')).toHaveClass(/open/)
    await expect(page.locator('#drawer-body')).toContainText('Prompt de remediación')
    await expect(page.locator('#drawer').getByRole('button', { name: /Copiar/ })).toBeVisible()
    await page.keyboard.press('Escape')
    await expect(page.locator('#drawer')).not.toHaveClass(/open/)
  })

  test('el informe embebido se despliega con el veredicto', async ({ page }) => {
    await page.goto('/')
    await page.getByRole('button', { name: /Informe/ }).click()
    await expect(page.locator('#informe')).toBeVisible()
    await expect(page.locator('#informe')).toContainText('Informe DBB Labs')
    await expect(page.locator('#informe')).toContainText('Matriz de resultados')
  })
})
