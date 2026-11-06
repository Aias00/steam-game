"""Prepare versioned static sprites; preserve generated originals and approved v002."""
from pathlib import Path
import hashlib,json
from PIL import Image,ImageFilter,ImageDraw,ImageFont,ImageOps
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'output/imagegen/characters-v004'
MAN=ROOT/'art/prompts/characters/v004/manifest.json'
def digest(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def prepare():
    m=json.loads(MAN.read_text())
    for name in ['guard','ranger','engineer','assassin']:
        raw=OUT/f'{name}-sprite-raw.png'
        if not raw.exists(): continue
        im=Image.open(raw); original=(im.size,im.mode); im=im.convert('RGBA'); a=im.getchannel('A')
        assert a.histogram()[0]>im.width*im.height//4,'Expected transparent source'
        a=a.point(lambda x:0 if x<=8 else 255 if x>=240 else x).filter(ImageFilter.MinFilter(3)); im.putalpha(a)
        bbox=a.getbbox(); assert bbox and bbox[0]>0 and bbox[1]>0 and bbox[2]<im.width and bbox[3]<im.height
        im.save(OUT/f'{name}-sprite-clean.png'); files=[]
        for size in [512,256,128,96,64]:
            pad=max(2,round(size*.055)); body=im.crop(bbox);body.thumbnail((size-2*pad,size-2*pad),Image.Resampling.LANCZOS)
            canvas=Image.new('RGBA',(size,size));canvas.paste(body,((size-body.width)//2,size-pad-body.height));p=OUT/f'{name}-sprite-{size}.png';canvas.save(p)
            b=canvas.getchannel('A').getbbox();assert b and min(b[:2])>0 and max(b[2:])<size
            files.append(dict(file=str(p.relative_to(ROOT)),sha256=digest(p),alpha_bbox=b))
        item=next((i for i in m['items'] if i['id']==name and i['kind']=='sprite'),None)
        if item is None:
            item=dict(id=name,kind='sprite',prompt='art/prompts/characters/v004/assassin-sprite.prompt.txt',reference='output/imagegen/characters-v004/assassin-concept.png',output=str(raw.relative_to(ROOT)));m['items'].append(item)
        for field in ['prompt','reference']:
            item[field+'_sha256']=digest(ROOT/item[field])
        item.update(status='generated_processed_checked',actual_raw_size=original[0],actual_raw_mode=original[1],raw_sha256=digest(raw),variants=files,processing='alpha<=8 removed, >=240 normalized; one-source-pixel contraction; aspect-preserving fit, 5.5% padding, foot baseline')
    concept=OUT/'assassin-concept.png'
    if concept.exists():
        im=Image.open(concept); crop=im.crop((330,30,780,480))
        for size in [512,128,64]:crop.resize((size,size),Image.Resampling.LANCZOS).save(OUT/f'assassin-avatar-{size}.png')
        i=next(i for i in m['items'] if i['kind']=='concept');i.update(status='generated_checked',actual_size=im.size,sha256=digest(concept))
    m['status']='generated_processed_checked' if (OUT/'assassin-sprite-96.png').exists() else 'partial_pending_assassin_sprite'
    m['approval']='pending_user_review';m['static_single_direction_only']=True;m['godot_gameplay_unchanged']=True
    MAN.write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n')
    print(m['status'])
if __name__=='__main__':prepare()
