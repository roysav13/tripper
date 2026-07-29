# Feature ideas — cost check

Mark the ones you want. "Costs money?" reflects the underlying API/service, not app store fees. Free-tier numbers are as of July 2026 and change often — re-check before committing to one.

| Want? | Feature | Description | Costs money? |
|---|---|---|---|
| ☐ | Places search & autocomplete | Real destination/place search when adding a trip or place, replacing manual entry | **Yes** — Google Places: free monthly allowance per feature (e.g. ~5,000 Text Search calls/mo), pay-as-you-go beyond that. Free/rate-limited alt: OSM Nominatim (not commercial-grade) |
| ✗ | ~~Day-by-day itinerary builder~~ | Built twice (manual builder, then a derived timeline), withdrawn 2026-07-26 — **currently won't do**. See [ADR-001](adr/ADR-001-itinerary-redesign.md) | No, if manual entry. Becomes "Yes" only if it's powered by live place suggestions (Places API) |
| ☐ | Flight/hotel email parsing | Forward a confirmation email → auto-structured document | **Maybe** — a hand-built parser is free but fragile; a real parsing service (Parseur, Nylas, etc.) is paid, usage-based |
| ☐ | Live flight status/delay tracking | Push alert if a stored flight is delayed or gate-changed | **Yes** — flight data APIs are the priciest item here. AeroDataBox ~$5–150/mo by volume; FlightAware real-time starts at $200/mo minimum |
| ☐ | Destination weather forecast | Forecast for trip dates on the trip screen | **Maybe** — OpenWeatherMap free tier (1,000 calls/day) is generous, likely stays free at personal-app scale |
| ☐ | Visa requirement lookup | Passport country → destination visa rules | **Maybe** — some providers (Travel Buddy) have a free tier; others are custom-priced |
| ☐ | OCR on document photos | Auto-fill passport/flight fields from a photo | **No** — on-device (ML Kit), no per-call cost |
| ☐ | Embassy/emergency contact lookup | Local embassy + emergency numbers per destination | **No** — can ship as a bundled static dataset, no live API needed |
| ☐ | Live GPS route tracking | Background location recording draws your route (Polarsteps-style) | **No** — pure device GPS. Only becomes billable if you reverse-geocode every point through a paid API |
| ☐ | Offline map region downloads | Pre-download a trip's map area for zero-signal use | **No** — free with OSM tiles; still free within Google Maps SDK's personal-use terms |
| ☐ | Translation (camera/text) | Translate signs, menus, phrases | **Yes** if using Google Cloud Translation (500K chars/mo free, then $20/million). **No** if using an on-device translation model instead |
| ☐ | Currency converter (live rates) | Live exchange rates for trip currencies | **Maybe** — free tiers (e.g. 1,500 requests/mo) are enough for personal use; paid only at real scale |
| ☐ | Local transit/walking directions | Directions to a saved place | **Yes** — Google Directions/Distance Matrix, usage-based beyond free allowance |
| ☐ | Journal entries / timeline | Photo + note "steps" per trip, chronological | **No** — fully local |
| ☐ | Auto trip recap (PDF/video) | Generated recap from journal + places + stats | **No** — generated on-device from local data |
| ☐ | Distance / days-traveled stats | Derived stats on the Places tab | **No** — pure local query |
| ☐ | Expense tracking | Log and categorize trip spending | **No** — local, unless paired with live currency conversion |
| ☐ | Expense splitting | Split costs across travelers | **No** — local computation |
| ☐ | Government travel advisory feed | Safety advisories per destination | **Maybe** — some free public feeds exist (e.g. travel-advisory.info); richer sources are custom-priced |
| ☐ | Health/vaccination requirements | Required/recommended vaccinations per destination | **Maybe** — similar mix of free and paid providers |
| ☐ | Flight delay/gate-change alerts | Notification layer on top of flight tracking | **Yes** — rides on the same flight API cost as live flight tracking above |
| ☐ | Weather alerts | Notify on severe weather at destination dates | **Maybe** — rides on the weather API above, still within free tier at personal scale |
| ☐ | Check-in-opens reminders | Local reminder ~24–48h before a stored flight | **No** — computed from data already in the vault, no API call |
| ☐ | Nearby POI / restaurants / sights | Discover places near a pin, with ratings | **Yes** — same Places API cost profile as search/autocomplete |
| ☐ | Personalized destination recommendations | Suggest places based on your wishlist | **Maybe** — a simple rules-based version is free; an AI/LLM-based version has real inference cost |
| ☐ | Packing checklist | Per-trip packing list, optionally weather-aware | **No** — local, only touches the weather API if made weather-aware |

**Pattern:** anything that's pure local computation (journaling, stats, recaps, expenses, packing, check-in reminders, GPS recording, offline maps, on-device OCR) stays free forever. Anything that calls a live third-party data source (places, flights, weather, translation, currency, transit, visas, advisories) has a free tier that's realistically enough for one person's personal trips — the cost only becomes real if this ever has other users or you make a lot of calls per session (e.g. live-searching places character by character).
