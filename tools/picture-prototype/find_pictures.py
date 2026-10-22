import cv2, numpy as np, sys
from ocr_boxes import ocr_boxes

def base_masks(img):
    mx=img.max(axis=2)
    bg=cv2.dilate(mx,cv2.getStructuringElement(cv2.MORPH_RECT,(41,41)))
    bg=cv2.GaussianBlur(bg,(0,0),25).astype(np.float32)+1
    norm=mx.astype(np.float32)/bg
    hsv=cv2.cvtColor(img,cv2.COLOR_BGR2HSV)
    return norm,hsv

def comps(mask,min_box_area=1500,min_ink=300,ink=None):
    n,lab,stats,_=cv2.connectedComponentsWithStats(mask,8)
    out=[]
    for i in range(1,n):
        x,y,bw,bh,a=[int(v) for v in stats[i]]
        if bw*bh<min_box_area: continue
        real=int((ink[y:y+bh,x:x+bw]>0).sum()) if ink is not None else a
        if real<min_ink: continue
        out.append([x,y,bw,bh])
    return out

def pass_solid(norm,hsv):
    ink=((norm<0.82)|(hsv[...,1]>60)).astype(np.uint8)*255
    ink=cv2.morphologyEx(ink,cv2.MORPH_OPEN,cv2.getStructuringElement(cv2.MORPH_ELLIPSE,(7,7)))
    ink=cv2.morphologyEx(ink,cv2.MORPH_CLOSE,cv2.getStructuringElement(cv2.MORPH_ELLIPSE,(15,15)))
    return comps(ink,350,0,None) if False else [ [int(v) for v in s[:4]] for s in cv2.connectedComponentsWithStats(ink,8)[2][1:] if s[4]>=350 ]

def pass_lineart(norm,hsv,text):
    ink=((norm<0.86)|(hsv[...,1]>45)).astype(np.uint8)*255
    for (x,y,bw,bh,t) in text:
        ink[max(0,y-4):y+bh+4,max(0,x-4):x+bw+4]=0
    n,lab,stats,_=cv2.connectedComponentsWithStats(ink,8)
    for i in range(1,n):
        x,y,bw,bh,a=[int(v) for v in stats[i]]
        l,s=max(bw,bh),min(bw,bh)
        if (l>110 and l/max(1,s)>6) or a<260: ink[lab==i]=0
    m=cv2.dilate(ink,cv2.getStructuringElement(cv2.MORPH_ELLIPSE,(11,11)))
    return comps(m,1500,300,ink)

def iou(a,b):
    ax,ay,aw,ah=a; bx,by,bw,bh=b
    ix=max(0,min(ax+aw,bx+bw)-max(ax,bx)); iy=max(0,min(ay+ah,by+bh)-max(ay,by))
    i=ix*iy; return i/(aw*ah+bw*bh-i+1e-9)
def contains(big,small,tol=6):
    bx,by,bw,bh=big; sx,sy,sw,sh=small
    return sx>=bx-tol and sy>=by-tol and sx+sw<=bx+bw+tol and sy+sh<=by+bh+tol

def find(img):
    h,w=img.shape[:2]
    norm,hsv=base_masks(img)
    text=ocr_boxes(img)
    A=pass_solid(norm,hsv); B=pass_lineart(norm,hsv,text)
    def ok(b,minarea=1200):
        x,y,bw,bh=b
        if bw*bh<minarea or bw*bh>0.25*w*h: return False
        if bw>0.8*w and bh<0.12*h: return False
        if x<=2 or y<=2 or x+bw>=w-2 or y+bh>=h-2: return False
        return True
    A=[b for b in A if ok(b,600)]; B=[b for b in B if ok(b,1200)]
    res=[]
    for b in B:
        inside=[a for a in A if contains(b,a)]
        if len(inside)>=2: continue           # B is a merge of several solid pictures: keep the A boxes
        res.append(b)
    for a in A:
        if any(contains(b,a) or iou(a,b)>0.3 for b in res): continue
        if any(contains(a,b) for b in B if b in res): continue
        res.append(a)
    # classify structures
    pics=[];structs=[]
    for b in res:
        x,y,bw,bh=b
        tin=sum(tw*th for (tx,ty,tw,th,t) in text if tx>=x-4 and ty>=y-4 and tx+tw<=x+bw+4 and ty+th<=y+bh+4)
        ratio=tin/(bw*bh)
        # letter-like specks inside (word search grid)
        roi=norm[y:y+bh,x:x+bw]<0.7
        nn,_,st,_=cv2.connectedComponentsWithStats(roi.astype(np.uint8),8)
        specks=sum(1 for s in st[1:] if 8<=s[3]<=40 and 6<=s[2]<=40 and s[4]<400)
        if ratio>0.08 or specks>60: structs.append(b)
        else: pics.append(b)
    pics=[p for p in pics if not any(contains(st,p,10) for st in structs)]
    return pics,structs,text

if __name__=="__main__":
    src,dst,x0,x1=sys.argv[1],sys.argv[2],float(sys.argv[3]),float(sys.argv[4])
    im=cv2.imread(src); H,W=im.shape[:2]; im=im[:,int(x0*W):int(x1*W)]
    pics,structs,text=find(im)
    vis=im.copy()
    for (x,y,w,h) in pics: cv2.rectangle(vis,(x,y),(x+w,y+h),(255,0,0),3)
    for (x,y,w,h) in structs: cv2.rectangle(vis,(x,y),(x+w,y+h),(0,160,0),3)
    cv2.imwrite(dst,vis); print(len(pics),'pictures',len(structs),'structures')
