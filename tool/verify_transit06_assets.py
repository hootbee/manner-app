"""Verify lossless runtime layers and foreground-subtracted hit masks against a supplied v2 package.
Usage: python tool/verify_transit06_assets.py <extracted-v2-package>
Requires Pillow. Does not write source artwork or runtime assets.
"""
from pathlib import Path
from PIL import Image, ImageChops
import hashlib
import json
import sys

source = Path(sys.argv[1])
target = Path(__file__).resolve().parents[1] / 'app/assets/transit06'
manifest = json.loads((target / 'runtime_manifest.json').read_text(encoding='utf-8'))
assert manifest['pivot'] == [711, 836]
for relative in manifest['assets']:
    original = relative.replace('.webp', '.png')
    a = Image.open(source / original).convert('RGBA')
    b = Image.open(target / relative).convert('RGBA')
    assert a.size == b.size == (1536, 1024), relative
    assert a.tobytes() == b.tobytes(), relative
    assert hashlib.sha256((source / original).read_bytes()).hexdigest() == manifest['originalSha256'][original]

def alpha(relative):
    return Image.open(source / ('assets/runtime/' + relative + '.png')).convert('RGBA').getchannel('A').point(lambda v: 255 if v else 0)

base = ImageChops.multiply(alpha('masks/backrest_drag_start_mask'), alpha('furniture/front_backrest_rotating'))
counts = {}
for who in ['mongmong', 'dangdang', 'nyangnyang']:
    for pose, passenger in [('initial','working'), ('asking','working'), ('asking','agree')]:
        allowed = base.copy()
        for foreground in [f'characters/{who}_{pose}', f'passenger/rear_{passenger}', 'furniture/front_fixed_seat_base', 'furniture/front_fixed_armrest_support', 'furniture/rear_fixed_table_laptop']:
            allowed = ImageChops.subtract(allowed, alpha(foreground))
        expected = bytearray(1536 * 1024 // 8)
        count = 0
        for i, v in enumerate(allowed.tobytes()):
            if v:
                expected[i >> 3] |= 1 << (i & 7)
                count += 1
        relative = f'hit/{who}_{pose}_{passenger}.mask'
        assert bytes(expected) == (target / relative).read_bytes(), relative
        counts[relative] = count
# Initial selected-monkey composite must match supplied independent-layer verification.
composite = Image.new('RGBA', (1536,1024))
for rel in ['background/train_cabin_empty','furniture/rear_fixed_seat','furniture/front_fixed_seat_base','furniture/front_backrest_rotating','characters/mongmong_initial','passenger/rear_working','furniture/rear_fixed_table_laptop','furniture/front_fixed_armrest_support','overlays/conversation']:
    composite.alpha_composite(Image.open(source / ('assets/runtime/'+rel+'.png')).convert('RGBA'))
reference=Image.open(source / 'verification/initial_from_runtime_layers.png').convert('RGBA')
assert composite.tobytes() == reference.tobytes(), 'Initial composite differs'
print(json.dumps({'lossless_layers_verified':len(manifest['assets']), 'corrected_masks_verified':counts, 'initial_composite_pixel_equal':True}, ensure_ascii=False, indent=2))