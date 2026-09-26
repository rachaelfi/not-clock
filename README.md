# Not Clock

A cross-platform clock app built with Flutter. Alarms, a sleep alarm with a
night sky and sunrise simulator, world clocks, a stopwatch, and timers.

## Features

**Alarms** — repeat days, custom sounds, snooze, and a flashing-screen option.

**Sleep** — set a sleep alarm and see how long you'll actually get. Two optional
screens go with it:

- **Night Clock** — a dimming clock over a sky that follows the time of day.
  Stars from 7 PM, sunrise from 4 AM, daylight from 8 AM, with shooting stars
  at night. The screen dims after 12 seconds and wakes on a tap.
- **Sunrise simulator** — for the last 5–30 minutes before the alarm, the
  screen walks through a color preset and the backlight climbs from near-dark
  to full, reaching white as the alarm sounds. Five presets to choose from.

**World Clock** — live timezone and daylight-saving data per city.

**Stopwatch** — laps with best and worst marked.

**Timers** — several at once, with a selectable finish sound.

**Themes** — Catppuccin's four flavors plus the original Midnight, and fourteen
accent colors. Everything that used to be purple follows the accent.

**Seven languages** — English, Spanish, French, Portuguese, Korean, Dutch,
German.

## Running it

```bash
flutter pub get
flutter run
```

For a quick look at layout and theming without a device:

```bash
flutter run -d chrome
```

Rate, Share, and Send feedback need a real device — there's no app store or
mail client in a browser. The sunrise can't drive the backlight on web either,
though the colors still animate.

## Project layout

```
lib/
  main.dart                 app entry, SettingsProvider, bottom nav
  config/                   app IDs, sounds, sunrise presets, credits
  l10n/                     ARB translation files
  models/                   AlarmData, AppSettings, WorldClockCity
  screens/                  one file per screen
  services/                 alarm scheduling, audio, storage, brightness
  theme/app_theme.dart      palettes and resolved colors
```

Anything user-visible reads its colors from `AppColors`:

```dart
final c = SettingsProvider.of(context).colors;
```

and its text from the generated localizations:

```dart
final t = AppLocalizations.of(context);
```

## Before shipping

Fill in `lib/config/app_config.dart`:

- `appStoreId` — digits only, from App Store Connect
- `androidPackageId` — must match `applicationId` in `android/app/build.gradle`
- `developerName`, `supportEmail`
- `websiteUrl`, `privacyPolicyUrl`, `termsUrl`

The legal pages live in a separate repo and are served by GitHub Pages. A
privacy policy URL is required by both stores before you can publish.

Android also needs a `<queries>` block in `AndroidManifest.xml` for the Play
Store and share intents — see `SETUP.md`.

## Translations

Strings live in `lib/l10n/app_*.arb`. `app_en.arb` is the template: a key
missing there breaks the build, while a key missing from the others just falls
back to English.

After editing any ARB file:

```bash
flutter gen-l10n
```

Deliberately left in English: Catppuccin flavor and accent names, sunrise
preset names, and sound file names. They're proper nouns or filenames, and
translating them would break the link to what they're called elsewhere.

## Known limitations

**Alarms only fire while the app is running.** `AlarmScheduler` is a Dart timer,
not an OS-level alarm. Backgrounding the app or restarting the phone means no
alarm. Fixing this needs native scheduling on both platforms and is the single
biggest piece of work left.

**The Night Clock needs the screen to stay on.** Add `wakelock_plus` and
uncomment the two lines in `night_clock_screen.dart`, or the display sleeps and
the sunrise never happens.

**App icon switching is UI only.** The choice persists, but changing the real
launcher icon needs alternate icons registered natively on both platforms.

**`AlarmData.daysString` and `timeUntilString` are English-only.** They build
sentences inside the model where `AppLocalizations` can't reach. Fixing it
means moving that formatting into a helper that takes localizations.

## Sound credits

Sounds come from Pixabay, Mixkit, and Freesound (CC0). None of these require
attribution, but `lib/config/credits.dart` has a `soundCredits` list ready if
that changes — the Sounds section in About appears on its own once it has
entries.

## Built with

Flutter, and: `shared_preferences`, `audioplayers`, `http`, `intl`,
`url_launcher`, `share_plus`, `in_app_review`, `device_info_plus`,
`screen_brightness`, `file_picker`.

Colors from [Catppuccin](https://catppuccin.com) (MIT).