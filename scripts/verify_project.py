#!/usr/bin/env python3
"""RomanVoice structural, CI, asset and UI-contract checks. Does not replace xcodebuild."""
from pathlib import Path
import hashlib
import json
import plistlib
import re
import sys

root = Path(__file__).resolve().parents[1]
errors = []

def check(condition, message):
    if not condition:
        errors.append(message)

check((root / 'project.yml').is_file(), 'project.yml fehlt')
check((root / '.github/workflows/main.yml').is_file(), 'GitHub-Workflow fehlt')

# Swift/project structure
sources = sorted((root / 'RomanVoice').rglob('*.swift'))
check(len(sources) >= 20, f'Zu wenige Swift-Dateien: {len(sources)}')
source_text = '\n'.join(p.read_text(encoding='utf-8') for p in sources)
check(source_text.count('@main') == 1, '@main muss genau einmal vorkommen')
check('import SwiftLlama' not in source_text, 'Unerlaubter SwiftLlama-Import vorhanden')
check('AVSpeechSynthesizer' in source_text, 'AVSpeechSynthesizer fehlt')
check('AES.GCM' in source_text, 'AES.GCM fehlt')
check(source_text.count('struct ConstructionView: View') == 1, 'ConstructionView muss genau einmal definiert sein')
check(source_text.count('final class Navigation: ObservableObject') == 1, 'Navigation muss genau einmal definiert sein')
check(source_text.count('struct RootView: View') == 1, 'RootView muss genau einmal definiert sein')

# Detect case-insensitive path collisions in the actual working tree.
seen = {}
for p in root.rglob('*'):
    if p.is_file():
        rel = p.relative_to(root).as_posix()
        seen.setdefault(rel.casefold(), []).append(rel)
for same in seen.values():
    if len(same) > 1:
        errors.append('Groß-/Kleinschreibungs-Kollision: ' + ', '.join(sorted(same)))

assets = root / 'RomanVoice/Assets.xcassets'

def referenced_filenames(metadata):
    names = set()
    def walk(value):
        if isinstance(value, dict):
            filename = value.get('filename')
            if isinstance(filename, str) and filename:
                names.add(filename)
            for child in value.values():
                walk(child)
        elif isinstance(value, list):
            for child in value:
                walk(child)
    walk(metadata)
    return names

# Every image/app-icon set must have exactly one correctly cased Contents.json,
# every referenced payload must exist, and no stale payload may remain.
for folder in sorted(list(assets.glob('*.imageset')) + list(assets.glob('*.appiconset'))):
    files = [p for p in folder.iterdir() if p.is_file()]
    content_variants = [p for p in files if p.name.casefold() == 'contents.json']
    check(len(content_variants) == 1, f'{folder.relative_to(root)}: Contents.json mehrfach/fehlend')
    check(any(p.name == 'Contents.json' for p in content_variants), f'{folder.relative_to(root)}: Contents.json falsche Schreibweise')
    canonical = folder / 'Contents.json'
    if not canonical.is_file():
        continue
    try:
        metadata = json.loads(canonical.read_text(encoding='utf-8'))
    except Exception as exc:
        errors.append(f'{canonical.relative_to(root)}: ungültiges JSON: {exc}')
        continue
    refs = referenced_filenames(metadata)
    for name in refs:
        check((folder / name).is_file(), f'{folder.relative_to(root)}: referenzierte Datei fehlt: {name}')
    payloads = {p.name for p in files if p.name != 'Contents.json'}
    extra = sorted(payloads - refs)
    missing = sorted(refs - payloads)
    check(not extra, f'{folder.relative_to(root)}: nicht zugewiesene Asset-Datei(en): {extra}')
    check(not missing, f'{folder.relative_to(root)}: fehlende Asset-Datei(en): {missing}')

# Manifest hashes for the seven controlled reference/start assets.
manifest_path = root / 'Docs/Asset-Manifest.json'
try:
    manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
except Exception as exc:
    manifest = []
    errors.append(f'Asset-Manifest ungültig: {exc}')
for item in manifest:
    folder = assets / f"{item['asset']}.imageset"
    canonical = folder / 'Contents.json'
    if not canonical.is_file():
        errors.append(f"{item['asset']}: Contents.json fehlt")
        continue
    metadata = json.loads(canonical.read_text(encoding='utf-8'))
    refs = sorted(referenced_filenames(metadata))
    if not refs:
        errors.append(f"{item['asset']}: keine Bilddatei in Contents.json")
        continue
    image = folder / refs[0]
    if not image.is_file():
        errors.append(f"{item['asset']}: Bilddatei fehlt: {refs[0]}")
        continue
    actual = hashlib.sha256(image.read_bytes()).hexdigest()
    check(actual == item['sha256'], f"{item['asset']}: SHA-256 stimmt nicht ({image.name})")

# All Image("...") references must resolve to an imageset.
for name in re.findall(r'Image\("([^"\\]+)"\)', source_text):
    check((assets / f'{name}.imageset').is_dir(), f'Swift referenziert fehlendes Asset: {name}')

# Plists/resources/project settings.
for path in root.rglob('*.plist'):
    try:
        with path.open('rb') as f:
            plistlib.load(f)
    except Exception as exc:
        errors.append(f'{path.relative_to(root)}: ungültige plist: {exc}')
try:
    info = plistlib.loads((root / 'RomanVoice/Info.plist').read_bytes())
    check(info.get('UIFileSharingEnabled') is False, 'UIFileSharingEnabled muss false sein')
    check(info.get('UIBackgroundModes') == ['audio'], 'UIBackgroundModes muss [audio] sein')
except Exception as exc:
    errors.append(f'Info.plist nicht lesbar: {exc}')
check((root / 'RomanVoice/Resources/AnimationAtlas.png').is_file(), 'AnimationAtlas.png fehlt')
font = root / 'RomanVoice/Resources/EBGaramond.ttf'
check(font.is_file() and font.stat().st_size > 100000, 'EBGaramond.ttf fehlt/ist zu klein')
project_yml = (root / 'project.yml').read_text(encoding='utf-8') if (root / 'project.yml').is_file() else ''
check('SWIFT_OBJC_BRIDGING_HEADER' in project_yml, 'Bridging-Header-Einstellung fehlt')

# Today's start-screen/UI-test contract.
nav = root / 'RomanVoice/UI/Navigation.swift'
nav_text = nav.read_text(encoding='utf-8') if nav.is_file() else ''
for label in ['Bibliothek', 'Lesen', 'Hören', 'Importieren']:
    check(f'"{label}"' in nav_text, f'Navigation: {label} fehlt')
for room in ['BIBLIOTHEK', 'LESEN', 'HÖREN', 'IMPORTIEREN']:
    check(f'"{room}"' in nav_text, f'Navigation: Raumtitel {room} fehlt')
check('.accessibilityLabel("Zurück")' in nav_text, 'Zurück-Accessibility-Label fehlt')
check('.accessibilityIdentifier("Zurück")' in nav_text, 'Zurück-Accessibility-Identifier fehlt')
check('geometry.safeAreaInsets.top + 8' in nav_text, 'Zurück-Button ist nicht an obere Safe Area gebunden')

test = root / 'UITests/SalonUITests.swift'
test_text = test.read_text(encoding='utf-8') if test.is_file() else ''
for token in ['Bibliothek', 'Lesen', 'Hören', 'Importieren', 'BIBLIOTHEK', 'LESEN', 'HÖREN', 'IMPORTIEREN', 'Zurück']:
    check(token in test_text, f'UITest-Vertrag fehlt: {token}')
check('app.scrollViews.count' in test_text, 'UITest prüft ScrollView-Freiheit nicht')

# CI sequence must prepare, verify, generate and later package Payload.
workflow = (root / '.github/workflows/main.yml').read_text(encoding='utf-8') if (root / '.github/workflows/main.yml').is_file() else ''
for token in ['bash scripts/prepare_dependencies.sh', 'python3 scripts/verify_project.py', 'xcodegen generate', 'Payload']:
    check(token in workflow, f'Workflow-Bestandteil fehlt: {token}')

if errors:
    print('FAIL: RomanVoice-Projektprüfung')
    for e in errors:
        print(' -', e)
    sys.exit(1)

print(
    f'PASS: {len(sources)} Swift-Dateien; {len(manifest)} Manifest-Assets; '
    'keine Asset-Altlasten/Case-Kollisionen; Startplatz/UI-Test-Vertrag; '
    'Ressourcen; Plists; Bridge; CI/IPA-Struktur.'
)
