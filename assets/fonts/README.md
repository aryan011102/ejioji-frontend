# Fonts

The two platforms use different typefaces, and that is the only typography
difference in the app. It lives in `lib/core/theme/typography.dart`.

## iOS: San Francisco

Nothing to do. `AppText._family` is null on iOS, so Flutter uses the system
font, which is SF. Do not bundle SF: Apple's licence covers use on Apple
platforms through the system, not redistribution inside an app bundle.

## Android: Google Sans

Google Sans is licensed and is **not** redistributable, so it is not checked
in. The app asks for it by name and falls back to Roboto when it is absent,
which is the correct behaviour on a stock device and needs no code change.

If your build has a licensed copy, drop these three files in beside this
README and uncomment the `fonts:` block in `pubspec.yaml`:

    GoogleSans-Regular.ttf   weight 400
    GoogleSans-Medium.ttf    weight 500
    GoogleSans-Bold.ttf      weight 700

Nothing else changes: `typography.dart` already asks for the family by name.

**Do not commit the font files.** They are covered by `*.ttf` in `.gitignore`.
