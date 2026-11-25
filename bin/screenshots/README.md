# Store screenshots

From the repository root, complete the [development setup](../../README.md#development-setup), then
run:

```sh
dart run open_authenticator:screenshots
```

Open `build/screenshots/index.html` to browse the result. The default campaign produces **162 store
PNGs** and **84 raw Flutter captures** across English, French, German, Italian, Portuguese and
Spanish. It runs headlessly with the project's Flutter SDK and fictional accounts. The white key
artwork and all three poster typefaces are bundled in [assets](assets), alongside the font licenses.
The PSDs are optional.

| Format ID                   | Output dimensions | Slides per language                                         |
|-----------------------------|-------------------|-------------------------------------------------------------|
| `iphone`                    | 1260 × 2736       | Brand, accounts, setup with QR code, device synchronization |
| `ipad`                      | 2064 × 2752       | Same four slides                                            |
| `macos`, `windows`, `linux` | 2880 × 1800       | Same four slides                                            |
| `android-phone`             | 1242 × 2688       | Same four slides                                            |
| `android-tablet-7`          | 2304 × 1440       | Availability, with the app in dark mode                     |
| `android-tablet-10`         | 2560 × 1800       | Download invitation                                         |
| `play-header`               | 1024 × 500        | App logo, name and website                                  |

## Examples

```sh
dart run open_authenticator:screenshots --locale fr --format iphone
dart run open_authenticator:screenshots --scene 03-setup --theme dark
dart run open_authenticator:screenshots --capture-only
dart run open_authenticator:screenshots --compose-only --format linux
dart run open_authenticator:screenshots --config campaign.json --output build/spring-campaign
dart run open_authenticator:screenshots --help
```

Raw PNGs are saved to `sources/<device>/<locale>/<theme>/{accounts,setup}.png` inside the output
directory. Store images are opaque RGB PNGs and go to `store/<format>/<locale>/<theme>/<scene>.png`.
Each run replaces the selected images and updates the gallery to show its selection. Use a separate
output directory to keep another campaign.

Windows and Linux captures include the app’s own `DesktopWindowFrame`. Mac captures use the graphite
title bar and three colored controls from the macOS artwork. Sync slides use the frame of the
displayed companion device. The Android phone poster shows a compact Windows window so the accounts
and right-hand window controls fit together.

`--capture-only` renders the application screens required by the selection. Brand, download and
banner slides can be composed directly. After editing captions, colors or output layouts, use
`--compose-only` with the same output directory to reuse existing raw screens. Recapture after
changing the app UI, device viewport, platform, pixel ratio or interface theme.

## Configuration

Edit [config.json](config.json) or copy it and pass its path with `--config`.

- `locales` selects application language codes. The supplied campaign uses every language in the
  app. Add `"locales": ["fr", "it"]` to select a subset.
- `devices` sets each native Flutter target platform (`android`, `iOS`, `macOS`, `windows`, `linux`)
  and its logical viewport dimensions. `pixelRatio` scales these dimensions for each raw PNG.
- `formats` sets final PNG dimensions, ordered scene IDs and the device to capture. Sync slides show
  the device specified by `companion`. The interface theme defaults to `light` and also accepts
  `dark`.
- `scenes` maps filenames to layouts (`brand`, `accounts`, `setup`, `sync`, `download`, `banner`)
  and localized title/subtitle pairs. The `*` language supplies shared text such as the banner URL.
- Titles use Outfit. Wrap words in `*…*` to switch to green DM Serif Display Italic, or in `**…**`
  for bold Outfit. Feature subtitles use gray DM Mono. Each translation controls its own emphasis
  and punctuation.
- Captions wrap to fit. Use `\n` in a JSON string for an intentional line break. A translation can
  override either field inside `phone` (width/height below 0.6), `portrait` (other tall canvases) or
  `landscape` (square and wide canvases).
- The radial gradient fades from `glow` to `background`. Each layout places the light behind its
  subject. Override `glowCenter` with `[x, y]` and `glowRadius` with the horizontal and vertical
  radii at half intensity, all in fractions of the canvas dimensions. The center may lie outside the
  canvas, as in the Play header.
- `style` also controls the colors of titles, subtitles and italic words (`title`, `subtitle`,
  `accent`) and relative font sizes (`titleScale`, `subtitleScale`). Colors accept `#RRGGBB`. Values
  merge from campaign to format to scene.
- Set `captionBox` or `artworkBox` on a format or scene to position the text, logo or device. The
  brand layout also supports `subtitleBox` to place its tagline independently. Each box uses
  `[left, top, width, height]` as fractions of the canvas. The `play-header` format illustrates
  these settings.

For example, adding this entry to `formats` produces a square German, English, French, Italian and
Portuguese setup poster on the next complete run:

```json
"square": {
  "width": 1600,
  "height": 1600,
  "device": "android-phone",
  "scenes": ["03-setup"],
  "captionBox": [0.06, 0.12, 0.38, 0.76],
  "artworkBox": [0.50, 0.06, 0.44, 0.88]
}
```
