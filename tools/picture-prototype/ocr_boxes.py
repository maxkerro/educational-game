import cv2, numpy as np, sys, subprocess, csv, io
def ocr_boxes(img, min_conf=50):
    cv2.imwrite('/tmp/_ocr.png',img)
    out=subprocess.run(['tesseract','/tmp/_ocr.png','-','-l','eng','--psm','11','tsv'],capture_output=True,text=True).stdout
    boxes=[]
    for row in csv.DictReader(io.StringIO(out),delimiter='\t',quoting=csv.QUOTE_NONE):
        try: c=float(row['conf'])
        except: continue
        t=(row.get('text') or '').strip()
        if c>=min_conf and len(t)>=2 and any(ch.isalpha() for ch in t):
            boxes.append((int(row['left']),int(row['top']),int(row['width']),int(row['height']),t))
    return boxes
def find_pictures(img):
    h,w=img.shape[:2]
    mx=img.max(axis=2)
    bg=cv2.dilate(mx,cv2.getStructuringElement(cv2.MORPH_RECT,(41,41)))
    bg=cv2.GaussianBlur(bg,(0,0),25).astype(np.float32)+1
    norm=mx.astype(np.float32)/bg
    hsv=cv2.cvtColor(img,cv2.COLOR_BGR2HSV)
    ink=((norm<0.86)|(hsv[...,1]>45)).astype(np.uint8)*255
    text=ocr_boxes(img)
    for (x,y,bw,bh,t) in text:
        pad=4
        ink[max(0,y-pad):y+bh+pad, max(0,x-pad):x+bw+pad]=0
    # remove long thin components (writing lines, rules, frames)
    n,lab,stats,_=cv2.connectedComponentsWithStats(ink,8)
    for i in range(1,n):
        x,y,bw,bh,a=[int(v) for v in stats[i]]
        long_,short=max(bw,bh),min(bw,bh)
        if (long_>110 and long_/max(1,short)>6) or (a<260):
            ink[lab==i]=0
    m=cv2.dilate(ink,cv2.getStructuringElement(cv2.MORPH_ELLIPSE,(11,11)))
    n,lab,stats,_=cv2.connectedComponentsWithStats(m,8)
    boxes=[]
    for i in range(1,n):
        x,y,bw,bh,a=[int(v) for v in stats[i]]
        if bw*bh<1500 or bw*bh>0.25*w*h: continue
        real=int((ink[y:y+bh,x:x+bw]>0).sum())
        if real<300: continue
        if bw>0.8*w and bh<0.12*h: continue          # header band
        if x<=2 or y<=2 or x+bw>=w-2 or y+bh>=h-2: continue   # touches crop edge
        boxes.append((x,y,bw,bh,real))
    return boxes,text
if __name__=="__main__":
    src,dst,x0,x1=sys.argv[1],sys.argv[2],float(sys.argv[3]),float(sys.argv[4])
    im=cv2.imread(src); H,W=im.shape[:2]
    im=im[:,int(x0*W):int(x1*W)]
    boxes,text=find_pictures(im)
    vis=im.copy()
    for (x,y,w,h,a) in boxes: cv2.rectangle(vis,(x,y),(x+w,y+h),(255,0,0),3)
    for (x,y,w,h,t) in text: cv2.rectangle(vis,(x,y),(x+w,y+h),(0,200,0),1)
    cv2.imwrite(dst,vis); print(len(boxes),'pictures,',len(text),'text words')
