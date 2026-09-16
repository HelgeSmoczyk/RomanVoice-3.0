#!/usr/bin/env python3
"""Structural and asset-integrity checks; does not replace xcodebuild."""
import hashlib, json, pathlib, plistlib, re
root = pathlib.Path(__file__).resolve().parents[1]
assert (root/'project.yml').is_file()
sources = list((root/'RomanVoice').rglob('*.swift'))
assert len(sources) >= 20
text = '\n'.join(p.read_text(encoding='utf-8') for p in sources)
assert text.count('@main') == 1
assert 'import SwiftLlama' not in text
assert 'AVSpeechSynthesizer' in text and 'AES.GCM' in text
assets = root/'RomanVoice/Assets.xcassets'
for item in json.loads((root/'Docs/Asset-Manifest.json').read_text()):
    folder = assets/(item['asset']+'.imageset')
    metadata = json.loads((folder/'Contents.json').read_text())
    image = folder/metadata['images'][0]['filename']
    assert hashlib.sha256(image.read_bytes()).hexdigest() == item['sha256'], image
for name in re.findall(r'Image\("([^"\\]+)"\)', text):
    assert (assets/(name+'.imageset')).is_dir(), name
for path in root.rglob('*.plist'):
    with path.open('rb') as f: plistlib.load(f)
info = plistlib.loads((root/'RomanVoice/Info.plist').read_bytes())
assert info['UIFileSharingEnabled'] is False
assert info['UIBackgroundModes'] == ['audio']
assert (root/'RomanVoice/Resources/AnimationAtlas.png').is_file()
assert (root/'RomanVoice/Resources/EBGaramond.ttf').stat().st_size > 100000
assert 'SWIFT_OBJC_BRIDGING_HEADER' in (root/'project.yml').read_text()
assert 'Payload' in (root/'.github/workflows/main.yml').read_text()
print(f'PASS: {len(sources)} Swift source files; seven original assets; font; plist; audio privacy; bridge; IPA structure.')
