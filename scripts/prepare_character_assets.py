"""Prepare v002 reference-derived portraits and static sprites; keep API originals."""
from pathlib import Path
import hashlib
import json
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'output/imagegen/characters-v002'
MANIFEST = ROOT / 'art/prompts/characters/v002/manifest.json'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def prepare():
    manifest = json.loads(MANIFEST.read_text())
    for item in manifest['items']:
        name = item['character']
        source = ROOT / item['planned_raw_output']
        assert digest(ROOT / item['reference']) == item['reference_sha256']
        assert digest(ROOT / item['prompt_file']) == item['prompt_sha256']
        with Image.open(source) as original:
            original_size = original.size
            original_mode = original.mode
            image = original.convert('RGBA')
        alpha = image.getchannel('A')
        histogram = alpha.histogram()
        assert histogram[0] > image.width * image.height // 4, 'Expected real background alpha'
        # The service supplied alpha rather than the requested green key. Keep it;
        # remove near-invisible matte noise and contract only one source pixel.
        alpha = alpha.point(lambda a: 0 if a <= 8 else (255 if a >= 240 else a))
        alpha = alpha.filter(ImageFilter.MinFilter(3))
        image.putalpha(alpha)
        bbox = alpha.getbbox()
        assert bbox and bbox[0] > 0 and bbox[1] > 0
        assert bbox[2] < image.width and bbox[3] < image.height, 'Figure touches source edge'
        image.save(OUTPUT / f'{name}-sprite-clean.png')
        cropped = image.crop(bbox)
        files = []
        for size in [512, 256, 128, 96, 64]:
            padding = max(2, round(size * 0.055))
            body = cropped.copy()
            body.thumbnail((size - padding * 2, size - padding * 2), Image.Resampling.LANCZOS)
            canvas = Image.new('RGBA', (size, size), (0, 0, 0, 0))
            canvas.paste(body, ((size - body.width) // 2, size - padding - body.height))
            target = OUTPUT / f'{name}-sprite-{size}.png'
            canvas.save(target)
            visible = canvas.getchannel('A').getbbox()
            assert visible and canvas.getpixel((0, 0))[3] == 0
            assert visible[0] >= 1 and visible[1] >= 1
            assert visible[2] < size and visible[3] < size
            files.append({'file':str(target.relative_to(ROOT)), 'size':[size,size],
                          'sha256':digest(target), 'alpha_bbox':list(visible)})
        item.update({'status':'generated_processed_and_checked', 'raw_sha256':digest(source),
                     'actual_raw_size':list(original_size), 'actual_raw_mode':original_mode,
                     'raw_size_matches_request':original_size == (1024,1024),
                     'raw_background':'Service returned real RGBA alpha, not the requested green key',
                     'processing':'Remove alpha<=8 noise; normalize alpha>=240; one-pixel source matte contract; crop visible bounds; preserve aspect ratio; bottom-align with 5.5% padding',
                     'source_alpha_bbox':list(bbox), 'sprite_variants':files,
                     'avatar_files':[{'file':str((OUTPUT/f'{name}-avatar-{size}.png').relative_to(ROOT)),
                                      'sha256':digest(OUTPUT/f'{name}-avatar-{size}.png')}
                                     for size in [512,128,64]]})
        print(name, 'source', original_size, original_mode, 'alpha background verified;', len(files), 'sprite variants checked')
    manifest['status'] = 'generated_processed_and_checked'
    manifest['no_actual_gameplay_or_animation_added'] = True
    MANIFEST.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')


if __name__ == '__main__':
    prepare()
