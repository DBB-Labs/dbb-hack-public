import { test } from '@playwright/test'
test('capturas para skool', async ({ page }) => {
  await page.setViewportSize({ width: 1500, height: 1400 })
  await page.goto('/')
  await page.waitForSelector('#k-vec')
  await page.waitForTimeout(3000)                 // dejar animar radar/osc/actividad
  await page.screenshot({ path: 'fotos/01-consola.png', fullPage: true })
  // hero: solo la parte de arriba (centro de comando)
  await page.screenshot({ path: 'fotos/02-centro-comando.png', clip: { x:0, y:0, width:1500, height:760 } })
  // drawer de un hallazgo
  const fin = page.locator('#finds .find').first()
  if (await fin.count()) { await fin.click(); await page.waitForTimeout(900)
    await page.screenshot({ path: 'fotos/03-drawer-hallazgo.png' }) 
    await page.keyboard.press('Escape'); await page.waitForTimeout(400) }
  // informe embebido
  await page.getByRole('button', { name: /Informe/ }).click()
  await page.waitForTimeout(1200)
  await page.screenshot({ path: 'fotos/04-informe.png', fullPage: true })
})
