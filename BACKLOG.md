# MeterScience Backlog

## Bugs

(none)

---

## Feature Requests

(none yet)

---

## Resolved

### ~~Edit Meter - Type and Digits not editable~~
**Reported:** 2025-12-15 | **Fixed:** 2025-12-15

Changed read-only labels to editable controls:
- Meter Type → Picker (electric, gas, water, solar, other)
- Digit Count → Stepper (4-8 range)

Also updated backend API to accept `meter_type` on PATCH.
