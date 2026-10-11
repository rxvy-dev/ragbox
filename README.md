# RAGBOX

**A free, open-source ragdoll physics sandbox for Android.**
No accounts. No ads. No purchases. No internet. Everything stays on your device.

Spawn people, hand them guns, build machines out of thrusters and pistons, wire up traps,
drop a nuke, slow time down and watch it all fall apart.

Ragbox is an original game in the ragdoll-sandbox genre (think Melon Sandbox / People
Playground). All art is drawn procedurally in code and every sound is synthesised on the
device, so the project contains **no third-party assets** and **no third-party packages**:
it builds with nothing but the Flutter SDK.

## Features

| | |
|---|---|
| **20 human types** | Civilian, Worker, Soldier, Riot Officer, Knight, Firefighter, Astronaut, Zombie (bites infect, victims rise again), Skeleton, Android, Combat Droid, Alien, Giant, Gnome, Mummy, Cyborg, Ninja, Monarch, Brute, Crash Dummy |
| **Character editor** | Base type, colours, hair, size, toughness, armour, team, behaviour |
| **31 firearms & energy weapons** | Pistol, revolver, hand cannon, machine pistol, SMGs, assault rifle, carbine, battle rifle, sniper, anti-materiel rifle, musket, shotguns, blunderbuss, LMG, minigun, rocket & grenade launchers, flamethrower, laser, railgun, tesla gun, cryo ray, gravity gun, medi beam, crossbow, nail gun, flare gun, plasma cannon, water blaster |
| **16 melee weapons** | Knife, machete, longsword, katana, fire axe, scythe, spear, hammers, bat, crowbar, mace, frying pan, shovel, pipe wrench, working chainsaw |
| **12 explosives** | Grenade, cluster bomb, dynamite, C4, sticky bomb, landmine, fire bottle, explosive barrel, gas canister, firework, holy grenade, tactical nuke |
| **8 vehicles** | Car, pickup, dune buggy, monster truck, motorbike, bus, tank (fires shells), cart |
| **Machines** | Thrusters, motor wheels, pistons, hydraulic press, fans, electromagnets, conveyors, launch pads, anti-gravity field, singularity core, balloons, chains |
| **Electrical** | Battery, generator, button, switch, timer, motion sensor, laser tripwire, pressure plate, NOT gate, lamp, siren, shock pad, tesla coil — wire anything to anything |
| **Traps** | Saw blades, spike traps, bear traps, gas burners, sentry turrets |
| **26 props** | Crates, planks, glass that shatters, bricks, concrete, fridges, TVs, sofas, anvils, boulders, balls… |
| **Tools** | Drag, Use, Rope, Spring, Weld, Pin, Wire, Build (draw static or dynamic blocks in 6 materials), Fire, Blast, Cut, Heal, Delete |
| **10 maps** | Flatlands, Endless Plain (40 km), Zero-G Void, Proving Grounds, Rooftops, Rolling Hills, Facility, Moon Base, Frozen Lake, Spike Pit |
| **Simulation** | Verlet ragdolls with muscles that stand up, walk, flee and fight; per-limb damage, bleeding, armour and ricochets, dismemberment, fire spread, electricity, freezing, explosions with line-of-sight falloff |
| **Controls** | Pause, slow motion (½, ¼, ⅒), gravity from −100 % to 300 %, undo, freeze, flip, clone |
| **Saving** | Autosave, manual saves with thumbnails, rename/duplicate/delete, export a scene or a full backup to a file and import it back |

Gore can be switched off in Settings (blood, wounds and dismemberment are then disabled).

## Controls

* **One finger on an object** – grab and drag it; let go mid-swing to throw. Frozen/pinned things move rigidly.
* **Shooting (Melon style)** – hold a gun with one finger, then put a **second finger** where you want to shoot. The gun swings to point at it and fires; auto weapons keep firing while the second finger stays down, and sliding it moves your aim. Works the same when you're holding a person who holds a gun. Melee weapons swing toward the second finger; the gravity gun grabs while it's down and launches when you lift it.
* **One finger on empty space** – pan. **Two fingers on empty space** – pinch to zoom.
* **Tap** – select; the small panel on the right lets you activate ⚡, freeze ❄, flip, clone, ignite, delete, heal, kill or make a person drop their weapon.
* **SPAWN** – opens the item menu (categories, search, long-press or ★ to favourite). Tap an item, then tap the world to place it (repeatable), or press **CENTER**.
* **Arm someone** – drop a weapon's handle on a person's hand. Soldiers then shoot hostiles on their own.
* **Wiring** – pick the Wire tool, tap a power source (battery, button, timer, sensor…) then a device (lamp, thruster, piston, C4, tank, shock pad…).
* **Back button** – opens the pause menu (save, load, clear, exit).

## Build and install on your phone (Linux)

Requirements:

* [Flutter SDK](https://docs.flutter.dev/get-started/install/linux/android) **3.27 or newer** (stable channel) with the Android toolchain (`flutter doctor` should show *Android toolchain* ✓ — run `flutter doctor --android-licenses` once)
* `adb` (Android platform-tools, comes with the Android SDK)
* On each phone/tablet: *Settings → About → tap Build number 7×*, then *Developer options → USB debugging* on. Plug it in and accept the "Allow USB debugging" prompt.

Then, from this folder:

```bash
./build_install.sh
```

The script generates the Gradle wrapper for your Flutter version (first run only — it never
overwrites the game's own files), builds the release APK, copies it to `dist/`, installs it on
**every** connected device and launches it.

```bash
./build_install.sh --no-install   # just build dist/ragbox-v1.0.0.apk
./build_install.sh --test         # run the unit tests first
```

Manual equivalent:

```bash
flutter create --platforms=android --org dev.rxvy --project-name ragbox .   # once
flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

## Publish to GitHub with the APK

```bash
./publish.sh                      # creates/pushes rxvy-dev/ragbox and a v1.0.0 release with the APK
REPO=someone/ragbox ./publish.sh  # different repository
REBUILD=1 ./publish.sh            # force a fresh build first
```

Needs `git` and the GitHub CLI (`gh auth login`). Bump `version:` in `pubspec.yaml` for a new release.
There is also a GitHub Actions workflow (`.github/workflows/build.yml`) that builds the APK and
attaches it to any `v*` tag you push.

> The release APK is signed with your machine's Flutter debug key, which is fine for
> sideloading. If you install builds made on two different machines, uninstall the old one first.

## Project layout

```
lib/
  engine/physics.dart   Verlet particles, sticks, angle limits, capsule/polygon collisions, raycasts
  game/sandbox.dart     World: entities, joints, wires & power, bullets, explosions, fire, save/load
  game/entity.dart      Entity base class, materials, damage, drawing helpers
  game/human.dart       Ragdoll humans: types, muscles, AI, damage model, rendering
  game/weapons.dart     Guns, melee weapons, projectiles
  game/props.dart       Props, explosives, balloons, blocks
  game/machines.dart    Vehicles, machines, traps, electrical parts
  game/maps.dart        Maps
  game/catalog.dart     Spawnable item registry
  core/                 Local storage, synthesised sound, Android bridge
  ui/                   Menus, game HUD, spawn menu, editors
android/app/src/main/   Manifest (no INTERNET permission), MainActivity.kt (SoundPool + file picker), icon
test/                   Simulation, save/load and power tests
```

Adding a new item is usually one entry in a list (`Guns.all`, `Melees.all`, `Props.all`,
`HumanTypes.all`) — it appears in the spawn menu automatically with a live-rendered icon.

## Privacy

Ragbox has no network code and its release build requests **no permissions at all**. Scenes,
characters and settings live in the app's private storage. Exports only happen when you choose a
location in the system file picker.

## License

[MIT](LICENSE) © 2026 rxvy and Ragbox contributors.
