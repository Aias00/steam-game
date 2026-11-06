"""Extract four authored walk poses non-destructively and export Godot strips."""
from pathlib import Path
import json,hashlib
from PIL import Image,ImageFilter,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'output/imagegen/characters-v005'
RUNTIME=ROOT/'art/runtime/characters'
MANIFEST=ROOT/'art/prompts/characters/v005/manifest.json'
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def prepare():
    manifest=json.loads(MANIFEST.read_text())
    board=Image.new('RGB',(1000,6*190+90),'#172b25');draw=ImageDraw.Draw(board);font=ImageFont.truetype('/System/Library/Fonts/STHeiti Medium.ttc',20)
    draw.text((20,18),'六人四帧迈步动作 / 按移动距离循环播放',font=font,fill='#eedec0')
    for row,item in enumerate(manifest['items']):
        path=ROOT/item['output']
        if not path.exists():continue
        assert digest(ROOT/item['reference'])==item['reference_sha256']
        assert digest(ROOT/item['prompt'])==item['prompt_sha256']
        raw=Image.open(path);im=raw.convert('RGBA');alpha=im.getchannel('A')
        if alpha.histogram()[0] < im.width*im.height//4:
            # RGB chroma fallback, never apply keying to a genuine alpha output.
            pixels=list(im.getdata());im.putdata([(r,g,b,0 if g>100 and g>r*1.5 and g>b*1.5 else a) for r,g,b,a in pixels]);alpha=im.getchannel('A')
        alpha=alpha.point(lambda a:0 if a<=8 else 255 if a>=240 else a).filter(ImageFilter.MinFilter(3));im.putalpha(alpha)
        cells=[];bounds=[]
        for n in range(4):
            box=(n%2*im.width//2,n//2*im.height//2,(n%2+1)*im.width//2,(n//2+1)*im.height//2)
            cell=im.crop(box);bbox=cell.getchannel('A').getbbox();assert bbox, (item['id'],n)
            assert bbox[0]>1 and bbox[1]>1 and bbox[2]<cell.width-1 and bbox[3]<cell.height-1,('Cell clipping',item['id'],n,bbox)
            cells.append(cell.crop(bbox));bounds.append(bbox)
        scale=min(114/max(c.width for c in cells),114/max(c.height for c in cells))
        strip=Image.new('RGBA',(512,128));variants=[]
        for n,cell in enumerate(cells):
            cell=cell.resize((round(cell.width*scale),round(cell.height*scale)),Image.Resampling.LANCZOS)
            frame=Image.new('RGBA',(128,128));frame.paste(cell,((128-cell.width)//2,121-cell.height))
            target=OUT/f"{item['id']}-walk-{n}.png";frame.save(target);strip.paste(frame,(n*128,0))
            variants.append({'file':str(target.relative_to(ROOT)),'sha256':digest(target)})
            preview=frame.resize((160,160),Image.Resampling.LANCZOS)
            board.paste(preview,(150+n*205,row*190+70),preview)
        target=RUNTIME/f"{item['id']}-walk.png";strip.save(target)
        frames=[Image.open(OUT/f"{item['id']}-walk-{n}.png").convert('RGBA') for n in range(4)]
        # Animated review uses an opaque background for predictable GIF disposal.
        gifframes=[]
        for frame in frames:
            canvas=Image.new('RGB',(256,256),'#172b25');fg=frame.resize((256,256),Image.Resampling.LANCZOS);canvas.paste(fg,(0,0),fg);gifframes.append(canvas)
        gifframes[0].save(OUT/f"{item['id']}-walk.gif",save_all=True,append_images=gifframes[1:],duration=100,loop=0)
        item.update(status='processed_pending_visual_review',actual_size=raw.size,actual_mode=raw.mode,raw_sha256=digest(path),cell_bounds=bounds,runtime=str(target.relative_to(ROOT)),runtime_sha256=digest(target),frames=variants)
        draw.text((20,row*190+125),item['id'],font=font,fill='#eedec0')
    board.save(OUT/'walk-contact-sheet.png')
    manifest['status']='processed_pending_visual_review' if all('runtime' in i for i in manifest['items']) else 'partial_generating'
    MANIFEST.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n');print(manifest['status'])
if __name__=='__main__':prepare()
