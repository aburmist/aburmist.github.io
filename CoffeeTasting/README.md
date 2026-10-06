# Coffee Tasting

A native iPhone app for talking through coffee tasting notes.

The home screen is the live camera. A white mug of hot coffee sits at the bottom of the screen;
its coffee stays level as you tilt the phone, wobbles when you move, and when you tip the top of
the phone toward your face the mug rises to your lips and you "drink" it. Tap the mug to start
talking: your words appear above the cup as faint, foggy typewriter text. When you're done you
review, edit and save the note. Saved notes live in History with a small Stats screen and sharing.

Everything is first-party Apple: SwiftUI, SceneKit, AVFoundation, CoreMotion, Speech, SwiftData,
Swift Charts. No third-party dependencies.

## Requirements

- Xcode 15 or newer, iOS 17 or newer.
- A physical iPhone for the full experience. The Simulator has no camera or motion sensors
  (the app falls back to a plain background and lets you drag the cup to tilt it), and
  dictation may be unavailable there.
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) to produce the Xcode project file.

## Setup

```bash
brew install xcodegen
cd CoffeeTasting
xcodegen generate
open CoffeeTasting.xcodeproj
```

In Xcode, pick your team under *Signing & Capabilities* (or set `DEVELOPMENT_TEAM` in
`project.yml`), choose your iPhone as the run destination, and press Run.

The generated `.xcodeproj` is ignored by git on purpose. Re-run `xcodegen generate` whenever
you add or remove source files.

## Tests

Product → Test (⌘U) runs the unit tests for the pure-logic pieces: the slosh spring, the
drinking-gesture detector, the fill/refill model, the typewriter reveal, descriptor extraction
and the stats aggregation.

## Layout

```
CoffeeTasting/
  project.yml                 XcodeGen spec (targets, Info.plist keys, schemes)
  CoffeeTasting/
    App/                      app entry point, permissions
    Home/                     camera background, home screen
    Cup/                      SceneKit mug, liquid surface + shader, motion, slosh / drink / fill models
    Tasting/                  speech recognition, typewriter, foggy transcript, review sheet
    History/                  history list, note detail, stats
    Models/                   SwiftData model, flavor vocabulary, descriptor extraction
    Resources/                asset catalog
  CoffeeTastingTests/         XCTest unit tests
```

## How the cup works

- **Liquid.** The surface is a finely tessellated disk. A Metal geometry shader modifier displaces
  vertex heights by a plane (the tilt) plus small ripples whose amplitude follows how fast the
  surface is moving, and recomputes normals so highlights move with the waves. Because the disk
  itself never rotates, the liquid always meets the cup wall cleanly.
- **Slosh.** `CoffeeSloshSimulator` is an underdamped spring: gravity from CoreMotion sets the
  target slope, the spring overshoots and settles.
- **Drinking.** `DrinkGestureDetector` watches gravity's `z` component (positive when the top of
  the phone tips toward you). With hysteresis and a low-pass filter it produces a 0…1 factor
  that scales the mug up, moves it toward the camera and tips its near rim down, while the
  liquid climbs the near wall. Past 0.7 the cup starts to empty (`CupFillModel`); an empty cup
  refills after a few idle seconds, and saving a note always pours a fresh cup.

## Moving to its own repository later

The folder is self-contained. To extract it with history:

```bash
git subtree split --prefix=CoffeeTasting -b coffee-tasting-only
```
