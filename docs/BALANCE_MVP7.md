# MVP 7 Balance Report

Generated: 2026-10-03 (headless simulation + code review)

## Faction Starting Resources

| Campaign | Money | Units | Factory | Vehicle | Unit Cap |
|----------|-------|-------|---------|---------|----------|
| Juan | $4,000 | Juan + 3×B1 | L1 | Utility | 30+1 |
| Zie (Fauzi) | $4,500 | Zie + 3×B1 | L1 | SUV | 30+1 |
| Andrés (Atha) | $5,500 | Andrés + 3×B1 | L2 | Utility | 30+1 |
| Nabil | $6,500 | Nabil + 3×B2 | L1 | Van* | 24+1 |

*Van uses utility stats (no separate van in VehiclesDB — uses &"utility").

## Weapon DPS (damage × RoF × accuracy)

| Weapon | DPS | Range | Notes |
|--------|-----|-------|-------|
| Pistol | 14.6 | 260 | starter |
| SMG | 42.0 | 220 | close range shredder |
| Shotgun | 28.8 | 160 | 6 pellets, falloff not modeled |
| Rifle | 46.2 | 340 | best all-rounder |
| Sniper | 34.0 | 600 | high alpha |
| LMG | 59.4 | 320 | highest DPS, slow reload |

## Unit TTK (time-to-kill vs B1 100HP, rifle)

- Rifle vs B1: ~2.2s (100 / 46.2)
- Rifle vs B2 (170HP): ~3.7s
- Rifle vs B3 (250HP): ~5.4s
- Sniper vs B1: ~2.9s but one-shots on 2 hits

## Economy

- Factory L1: 2 cargo / 30s = 4 cargo/min
- Dealer price: $150/cargo at full demand, ~$105 at half
- Income: ~$600/min at full demand (L1), ~$1800/min (L4)
- B1 salary: $35/120s = $17.5/min per unit
- 10× B1 payroll: $175/min (sustainable on L1 factory)

## Special Units

- Cost $5,000-$7,500, salary $350-$500/120s
- HP 250-450, strong weapons
- Triad Synergy (Zie): +20% damage when 3 specials within 360px
- Verdict: powerful but not invincible (focus fire counters)

## DEA Response

- Heat 60%+ for 120s → 60s travel → 4× DEA raiders
- Heat sources: kill +8, drug sale +5, decay -0.5/s
- Player must manage heat or face raids

## Recommendations

1. Sniper may be underpowered (low DPS for cost) — consider +damage.
2. Shotgun lacks damage falloff — add for balance.
3. Nabil's van should get own stats (currently utility clone).
4. Dealer 4 placeholder needs real implementation.
5. Death animation placeholder (uses rotated idle).
