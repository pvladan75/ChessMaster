# Report for Batch 10

## 1. Sites Changed
**`chess_app/lib/features/assignments/screens/assignment_review_screen.dart`**
- line 156: `padding: const EdgeInsets.all(32)` -> `padding: const EdgeInsets.all(AppSpacing.xxxl)`
- line 159: `SizedBox(height: 12)` -> `SizedBox(height: AppSpacing.md)`
- line 161: `SizedBox(height: 12)` -> `SizedBox(height: AppSpacing.md)`
- line 172: `padding: const EdgeInsets.all(16)` -> `padding: const EdgeInsets.all(AppSpacing.lg)`
- line 175: `SizedBox(height: 12)` -> `SizedBox(height: AppSpacing.md)`
- line 177: `SizedBox(height: 16)` -> `SizedBox(height: AppSpacing.lg)`
- line 209: `padding: const EdgeInsets.all(16)` -> `padding: const EdgeInsets.all(AppSpacing.lg)`
- line 221: `SizedBox(height: 8)` -> `SizedBox(height: AppSpacing.sm)`
- line 244: `padding: const EdgeInsets.all(16)` -> `padding: const EdgeInsets.all(AppSpacing.lg)`
- line 309: `margin: const EdgeInsets.only(bottom: 12)` -> `margin: const EdgeInsets.only(bottom: AppSpacing.md)`
- line 311: `padding: const EdgeInsets.all(12)` -> `padding: const EdgeInsets.all(AppSpacing.md)`
- line 331: `SizedBox(width: 12)` -> `SizedBox(width: AppSpacing.md)`
- line 351: `SizedBox(height: 4)` -> `SizedBox(height: AppSpacing.xs)`
- line 356: `SizedBox(height: 8)` -> `SizedBox(height: AppSpacing.sm)`
- line 363: `SizedBox(height: 8)` -> `SizedBox(height: AppSpacing.sm)`
- line 433: `padding: const EdgeInsets.only(top: 2)` -> `padding: const EdgeInsets.only(top: AppSpacing.xxs)`
- line 453: `padding: const EdgeInsets.only(bottom: 2)` -> `padding: const EdgeInsets.only(bottom: AppSpacing.xxs)`
- line 491: `padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2)` -> `padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs)`
- line 511: `padding: const EdgeInsets.symmetric(vertical: 4)` -> `padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs)`

**`chess_app/lib/features/analysis_studio/widgets/move_tree_widget.dart`**
- line 41: `circular(12)` -> `AppRadii.roundedMd`
- line 43: `padding: const EdgeInsets.all(12.0)` -> `padding: const EdgeInsets.all(AppSpacing.md)`
- line 69: `padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)` -> `padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs)`
- line 93: `SizedBox(width: 4)` -> `SizedBox(width: AppSpacing.xs)`
- line 98: `padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)` -> `padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs)`
- line 123: `SizedBox(width: 4)` -> `SizedBox(width: AppSpacing.xs)`
- line 171: `insetPadding: const EdgeInsets.all(16)` -> `insetPadding: const EdgeInsets.all(AppSpacing.lg)`
- line 179: `padding: const EdgeInsets.all(12.0)` -> `padding: const EdgeInsets.all(AppSpacing.md)`
- line 206: `padding: const EdgeInsets.all(8.0)` -> `padding: const EdgeInsets.all(AppSpacing.sm)`
- line 247: `circular(4)` -> `AppRadii.roundedXs`
- line 249: `vertical: 2` -> `vertical: AppSpacing.xxs`
- line 254: `circular(4)` -> `AppRadii.roundedXs`
- line 306: `vertical: 2` -> `vertical: AppSpacing.xxs`
- line 309: `circular(4)` -> `AppRadii.roundedXs`

**`chess_app/lib/features/analysis_studio/widgets/auto_analysis_dialog.dart`**
- line 117: `circular(16)` -> `AppRadii.roundedLg`
- line 120: `padding: const EdgeInsets.all(20)` -> `padding: const EdgeInsets.all(AppSpacing.xl)`
- line 129: `SizedBox(width: 8)` -> `SizedBox(width: AppSpacing.sm)`
- line 137: `SizedBox(height: 12)` -> `SizedBox(height: AppSpacing.md)`
- line 143: `SizedBox(height: 12)` -> `SizedBox(height: AppSpacing.md)`
- line 237: `circular(8)` -> `AppRadii.roundedSm`
- line 252: `SizedBox(width: 8)` -> `SizedBox(width: AppSpacing.sm)`
- line 268: `SizedBox(height: 16)` -> `SizedBox(height: AppSpacing.lg)`
- line 278: `padding: const EdgeInsets.symmetric(vertical: 12)` -> `padding: const EdgeInsets.symmetric(vertical: AppSpacing.md)`
- line 292: `SizedBox(height: 12)` -> `SizedBox(height: AppSpacing.md)`
- line 299: `SizedBox(height: 8)` -> `SizedBox(height: AppSpacing.sm)`
- line 307: `SizedBox(height: 16)` -> `SizedBox(height: AppSpacing.lg)`
- line 327: `SizedBox(height: 16)` -> `SizedBox(height: AppSpacing.lg)`
- line 333: `SizedBox(height: 8)` -> `SizedBox(height: AppSpacing.sm)`
- line 340: `SizedBox(height: 8)` -> `SizedBox(height: AppSpacing.sm)`
- line 347: `SizedBox(height: 16)` -> `SizedBox(height: AppSpacing.lg)`

## 2. Sites Not Changed
All exact matched values from the gate output were changed.

## 3. Off-Scale Values Left Alone
- **`chess_app/lib/features/assignments/screens/assignment_review_screen.dart`**: Line 494 uses `borderRadius: BorderRadius.circular(99)` which is an off-scale pill shape that wasn't included in the task list, so it was left alone.
- **`chess_app/lib/features/analysis_studio/widgets/move_tree_widget.dart`**: Lines 249 and 306 use `padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2)`. The gate listed only `2 -> AppSpacing.xxs`. The horizontal value `6` is off-scale, so it was left as the raw number `6` while the `2` was replaced.

## 4. Final Status
- `flutter analyze` shows no new errors or warnings.
- `flutter test` passed all tests.
- `dart format` run on the three modified files.
- `git status --porcelain` showed only modifications to the 3 target files. Platform auto-generated directories were reverted with checkout.
