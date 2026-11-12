import {test, expect} from "@playwright/test"
import assert from "node:assert/strict"

test("plays a round and independently verifies the saved audit", async ({page}, testInfo) => {
  const name = testInfo.project.name
  const mobile = name === "mobile"
  const errors = []
  page.on("pageerror", error => errors.push(error.message))
  await page.goto('/play');
  await page.waitForSelector('.phx-connected');
  const commitment = page.locator('span.break-all.font-mono').first();
  const original = (await commitment.textContent()).trim();
  assert.match(original,/^[a-f0-9]{64}$/);
  await page.getByRole('button',{name:'Custom',exact:true}).click();
  await page.locator('#client-seed-form input').fill(`  browser ${name} seed  `);
  await page.locator('#apply-client-seed-draft').click();
  await expect(page.locator('#client-seed-form')).toHaveCount(0);
  assert.equal((await commitment.textContent()).trim(),original);
  await page.locator('#bet-amount-form input').fill('2500');
  await page.locator('[phx-click="place_bet"][phx-value-rank="1"]:visible').click();
  await expect(page.locator('#game-table')).toContainText('2,500 sats');
  await page.locator('#toggle-keep-bets').click();
  await expect(page.locator('#toggle-keep-bets')).toContainText('Repeating Bets');
  await page.screenshot({path:testInfo.outputPath("gameplay.png"),fullPage:true});
  assert(await page.evaluate(()=>document.documentElement.scrollWidth <= window.innerWidth),`${name} horizontal overflow`);
  for(let index=1; index<=24; index++){
    await page.locator('#deal-turn').click();
    await expect(page.locator('#game-table')).toContainText(new RegExp(`Turn\\s+${index+1}\\s*/\\s*25`));
    if(index===3){
      await page.locator('#toggle-keep-bets').click();
      await expect(page.locator('#toggle-keep-bets')).toHaveText('Repeat Bets');
    }
  }
  const pool=page.locator('#ctt-card-pool [data-ctt-card]');
  await expect(pool).toHaveCount(3);
  const cards=await pool.evaluateAll(nodes=>nodes.map(el=>({rank:Number(el.dataset.rank),suit:el.dataset.suit})));
  assert.deepEqual(cards,[...cards].sort((a,b)=>a.rank-b.rank || a.suit.localeCompare(b.suit)));
  if(new Set(cards.map(card=>card.rank)).size===1){
    await page.locator('#skip-ctt').click();
  } else {
    for(let index=0;index<3;index++){
      const slot=page.locator(`[data-ctt-slot="${index}"]`);
      if(!mobile && index===0){await pool.first().dragTo(slot);}
      else {await pool.first().click(); await slot.click();}
      await expect(slot.locator('img')).toHaveCount(1);
      await expect(pool).toHaveCount(2-index);
    }
    await page.locator('#place-ctt-bet').click();
    await expect(page.locator('#place-ctt-bet')).toBeDisabled();
    await page.locator('#reveal-final-cards').click();
  }
  await expect(page.locator('#new-round')).toBeVisible();
  const href=await page.getByRole('link',{name:'Audit Round',exact:true}).getAttribute('href');
  await page.goto(href);
  await page.waitForSelector('.phx-connected');
  await expect(page.locator('#round-verification')).toHaveAttribute('data-verified','true');
  await page.screenshot({path:testInfo.outputPath("audit.png"),fullPage:true});
  const verifier=await page.getByRole('link',{name:'Open in manual verifier →'}).getAttribute('href');
  await page.goto(verifier);
  await page.waitForSelector('.phx-connected');
  await page.getByRole('button',{name:'Verify Shuffle',exact:true}).click();
  await expect(page.locator('#verification-result')).toBeVisible();
  await expect(page.locator('#verification-error')).toHaveCount(0);
  await page.locator('#nonce').fill('18446744073709551616');
  await page.getByRole('button',{name:'Verify Shuffle',exact:true}).click();
  await expect(page.locator('#verification-error')).toBeVisible();
  assert.deepEqual(errors,[]);
})
