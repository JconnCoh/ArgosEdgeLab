$o='D:\B8TEST1'
if(Test-Path -LiteralPath $o){throw 'D:\B8TEST1 already exists.'}
[void](New-Item -ItemType Directory -Path $o)
$s=Join-Path $o 'preview.py'
$py=@'
import cv2,gc,json,pathlib
out=pathlib.Path(r'D:\B8TEST1')
rows=[]
for name in ('BF','DF'):
 p=pathlib.Path(r'D:\KLARFExport\B8R1')/(name+'.bmp')
 im=cv2.imread(str(p),cv2.IMREAD_GRAYSCALE)
 if im is None: raise RuntimeError('decode failed: '+str(p))
 scale=1800.0/max(im.shape)
 small=cv2.resize(im,None,fx=scale,fy=scale,interpolation=cv2.INTER_AREA)
 enhanced=cv2.createCLAHE(clipLimit=2.5,tileGridSize=(8,8)).apply(small)
 raw=out/(name+'_preview.png'); enh=out/(name+'_enhanced.png')
 if not cv2.imwrite(str(raw),small) or not cv2.imwrite(str(enh),enhanced): raise RuntimeError('write failed')
 rows.append({'channel':name,'sourceShape':[int(im.shape[0]),int(im.shape[1])],'previewShape':[int(small.shape[0]),int(small.shape[1])],'preview':str(raw),'enhanced':str(enh)})
 del im,small,enhanced;gc.collect()
print(json.dumps({'state':'PASS_BACKSIDE_PAIR_PREVIEW','opencvVersion':cv2.__version__,'rows':rows}))
'@
[IO.File]::WriteAllText($s,$py,(New-Object Text.UTF8Encoding($false)))
$env:PYTHONPATH='D:\AFCV1\rt'
$r=@(& 'D:\AFCV1\rt\python.exe' -B $s)
if($LASTEXITCODE-ne 0-or$r.Count-ne 1){throw "Preview failed: exit=$LASTEXITCODE rows=$($r.Count)"}
$r[0]
