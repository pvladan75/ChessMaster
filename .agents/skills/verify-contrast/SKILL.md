---
name: verify-contrast
description: Verifies WCAG 2.1 contrast ratios and touch targets for Mislisha UI tokens and widgets.
---

# Contrast & Accessibility Verification Workflow

## Surface Luminances (Dark Theme)
- Canvas: `#0F172A` (L = 0.0088)
- Surface: `#1E293B` (L = 0.0218)
- SurfaceRaised: `#334155` (L = 0.0514)

Do not trust these from memory either — recompute them if a surface token changes.

## Contrast Formula

$$\text{Ratio} = \frac{L_{\text{lighter}} + 0.05}{L_{\text{darker}} + 0.05}$$

The lighter colour is always the numerator, whichever of the two is the
foreground. Applied the other way round the ratio comes out below 1, which is
the signature of having swapped them.

Relative luminance, per channel $C \in \{R,G,B\}$ scaled to $[0,1]$:

$$c = \begin{cases} C/12.92 & C \le 0.03928 \\ \left(\frac{C+0.055}{1.055}\right)^{2.4} & \text{otherwise}\end{cases}$$

$$L = 0.2126\,c_R + 0.7152\,c_G + 0.0722\,c_B$$

**Compute it, do not estimate it.** Two lines of `node -e` are enough, and every
contrast defect found on this project so far was a number somebody wrote down
without running it.

## Verification Checklist
1. Body text $\ge 4.5:1$ **against the surface it actually sits on**. A token that passes on `canvas` and `surface` can still fail on `surfaceRaised` — `textMuted`, `accentAlt` and `brand` all do.
2. Large text, icons, borders, badges $\ge 3.0:1$.
3. **Measure both directions.** A token raised to read well *against* a dark surface becomes a light *background*, and white on it will fail. Whenever a token can be either foreground or background, check both. This is how the primary filled button shipped at 2.72:1.
4. Buttons on coloured backgrounds (brand, accent, danger, warning, success, info) must use a dark foreground. `#0F172A` gives 6.56:1 on `brand` and $\ge 6.7:1$ on every other accent; `#000000` gives 7.72:1 on `brand`. Both pass — do not quote a figure for one while using the other.
5. All interactive targets at least $48\times 48\text{dp}$ — the users are children aged 7–14.
6. Check 360 dp portrait for overflow. In a release build an overflowing `Row` is clipped silently, so the only reliable catch is a widget test at `Size(360, 640)`, where it throws.
