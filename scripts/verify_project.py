#!/usr/bin/env python3
"""Structural and asset-integrity checks; does not replace xcodebuild."""
import hashlib
import json
import pathlib
import plistlib
import re
import struct

root = pathlib.Path(__file__).resolve().parents[1]
romanvoice = root / 'RomanVoice'
assets = romanvoice / 'Assets.xcassets'

# Asset-catalog metadata must use the exact Apple filename casing.
app_icon_set = assets / 'AppIcon.appiconset'
assert (app_icon_set / 'Contents.json').is_file(), 'AppIcon.appiconset/Contents.json fehlt oder hat falsche Groß-/Kleinschreibung'
assert not (app_icon_set / 'contents.json').exists(), 'Veraltete AppIcon-Metadatei contents.json gefunden'
app_icon_meta = json.loads((app_icon_set / 'Contents.json').read_text(encoding='utf-8'))
app_icon_names = [entry.get('filename') for entry in app_icon_meta.get('images', []) if entry.get('filename')]
assert app_icon_names == ['AppIcon.png'], f'Unerwartete AppIcon-Dateien: {app_icon_names}'
app_icon = app_icon_set / 'AppIcon.png'
assert app_icon.is_file(), 'AppIcon.png fehlt'
png = app_icon.read_bytes()
assert png[:8] == b'\x89PNG\r\n\x1a\n', 'AppIcon.png ist keine gültige PNG-Datei'
width, height = struct.unpack('>II', png[16:24])
assert (width, height) == (1024, 1024), f'AppIcon muss 1024x1024 sein, ist aber {width}x{height}'

for catalog_dir in assets.iterdir():
    if catalog_dir.is_dir() and catalog_dir.suffix in {'.imageset', '.appiconset'}:
        contents = catalog_dir / 'Contents.json'
        assert contents.is_file(), f'Contents.json fehlt oder hat falsche Schreibweise: {catalog_dir}'
        catalog_meta = json.loads(contents.read_text(encoding='utf-8'))
        referenced = {entry.get('filename') for entry in catalog_meta.get('images', []) if entry.get('filename')}
        for filename in referenced:
            assert (catalog_dir / filename).is_file(), f'Referenziertes Asset fehlt: {catalog_dir / filename}'
        payload_files = {p.name for p in catalog_dir.iterdir() if p.is_file() and p.name != 'Contents.json' and not p.name.startswith('.')}
        assert payload_files == referenced, (
            f'Nicht zugewiesene oder fehlende Asset-Datei in {catalog_dir}: '
            f'Dateien={sorted(payload_files)}, Contents.json={sorted(referenced)}'
        )


assert (root / 'project.yml').is_file(), 'project.yml fehlt'
assert (romanvoice / 'ConstructionView.swift').is_file(), 'RomanVoice/ConstructionView.swift fehlt im App-Target'
assert not (root / 'ConstructionView.swift').exists(), 'ConstructionView.swift liegt fälschlich außerhalb des App-Targets'

sources = list(romanvoice.rglob('*.swift'))
assert len(sources) >= 20, f'Zu wenige Swift-Quelldateien: {len(sources)}'
text = '\n'.join(p.read_text(encoding='utf-8') for p in sources)

assert text.count('@main') == 1, '@main muss genau einmal vorkommen'
assert 'import SwiftLlama' not in text, 'Veralteter SwiftLlama-Import gefunden'
assert 'AVSpeechSynthesizer' in text and 'AES.GCM' in text, 'Audio- oder Verschlüsselungsbaustein fehlt'

# Catch accidental duplicate top-level Swift declarations before xcodebuild.
declarations = {}
pattern = re.compile(
    r'^(?:(?:@\w+(?:\([^\n]*\))?\s+)|(?:(?:public|internal|private|fileprivate|open|final|indirect|nonisolated)\s+))*'
    r'(struct|class|enum|protocol|actor)\s+([A-Za-z_][A-Za-z0-9_]*)',
    re.MULTILINE,
)
for source in sources:
    source_text = source.read_text(encoding='utf-8')
    for _, name in pattern.findall(source_text):
        declarations.setdefault(name, []).append(source)
duplicates = {name: paths for name, paths in declarations.items() if len(paths) > 1}
assert not duplicates, 'Doppelte Swift-Typen: ' + '; '.join(
    f"{name}: {', '.join(str(p.relative_to(root)) for p in paths)}"
    for name, paths in sorted(duplicates.items())
)

manifest = json.loads((root / 'Docs/Asset-Manifest.json').read_text(encoding='utf-8'))
for item in manifest:
    folder = assets / (item['asset'] + '.imageset')
    assert folder.is_dir(), f"Asset fehlt: {item['asset']}"
    metadata = json.loads((folder / 'Contents.json').read_text(encoding='utf-8'))
    filenames = [entry.get('filename') for entry in metadata.get('images', []) if entry.get('filename')]
    assert filenames, f"Keine Bilddatei in {folder}"
    image = folder / filenames[0]
    actual = hashlib.sha256(image.read_bytes()).hexdigest()
    assert actual == item['sha256'], f"SHA256 stimmt nicht: {image} ({actual})"

for name in re.findall(r'Image\("([^"\\]+)"\)', text):
    assert (assets / (name + '.imageset')).is_dir(), f'Fehlendes Image-Asset: {name}'

for room_asset in [
    'RomanVoice_Icon_Bibliothek',
    'RomanVoice_Icon_Lesen',
    'RomanVoice_Icon_Hoeren',
    'RomanVoice_Icon_Importieren',
]:
    assert (assets / (room_asset + '.imageset')).is_dir(), f'Fehlendes dynamisches Startplatz-Asset: {room_asset}'

for path in root.rglob('*.plist'):
    with path.open('rb') as f:
        plistlib.load(f)

info = plistlib.loads((romanvoice / 'Info.plist').read_bytes())
assert info['UIFileSharingEnabled'] is False
assert info['UIBackgroundModes'] == ['audio']
assert (romanvoice / 'Resources/AnimationAtlas.png').is_file()
assert (romanvoice / 'Resources/EBGaramond.ttf').stat().st_size > 100000
assert 'SWIFT_OBJC_BRIDGING_HEADER' in (root / 'project.yml').read_text(encoding='utf-8')
assert 'Payload' in (root / '.github/workflows/main.yml').read_text(encoding='utf-8')

# Startplatz and UI tests must describe the same four current routes.
nav = (romanvoice / 'UI/Navigation.swift').read_text(encoding='utf-8')
ui_test = (root / 'UITests/SalonUITests.swift').read_text(encoding='utf-8')
for button, room in [
    ('Bibliothek', 'BIBLIOTHEK'),
    ('Lesen', 'LESEN'),
    ('Hören', 'HÖREN'),
    ('Importieren', 'IMPORTIEREN'),
]:
    assert f'return "{button}"' in nav, f'Navigation-Button fehlt: {button}'
    assert f'= "{room}"' in nav, f'Raumtitel fehlt: {room}'
    assert f'"{button}"' in ui_test, f'UI-Test kennt Button nicht: {button}'
    assert f'"{room}"' in ui_test, f'UI-Test kennt Raumtitel nicht: {room}'
assert '.accessibilityIdentifier("Zurück")' in nav, 'Zurück-Identifier fehlt'
assert 'app.buttons["Zurück"]' in ui_test, 'UI-Test prüft Zurück nicht'

print(
    f'PASS: {len(sources)} Swift source files; '
    f'{len(manifest)} manifest assets; font; plist; audio privacy; bridge; '
    'IPA structure; AppIcon; source placement; duplicate-type check; Startplatz/UI-test contract.'
)
