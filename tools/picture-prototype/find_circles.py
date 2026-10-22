# Prototype of the empty-circle finder (ported to Swift as PagePalsImport/CircleFinder.swift).
# Usage: edit the image path below, run: python3 find_circles.py  (needs opencv-python, numpy)
import cv2, numpy as np, math
img=cv2.imread('/root/.claude/uploads/19c057a3-6f0e-57d4-87e8-90a97d73812c/ab9fcfae-image.png')
s=1754/img.shape[1]
img=cv2.resize(img,None,fx=s,fy=s,interpolation=cv2.INTER_AREA)
H,W=img.shape[:2]
mx=img.max(axis=2).astype(np.float32)
bg=cv2.blur(cv2.dilate(mx,np.ones((41,41))),(51,51))
norm=mx/(bg+1)
gx=cv2.Sobel(norm,cv2.CV_32F,1,0,ksize=3); gy=cv2.Sobel(norm,cv2.CV_32F,0,1,ksize=3)
mag=np.hypot(gx,gy)
ys,xs=np.nonzero(mag>0.6)
print('edge px',len(ys))
ux=gx[ys,xs]/mag[ys,xs]; uy=gy[ys,xs]/mag[ys,xs]
acc=np.zeros((H,W),np.float32)
RMIN,RMAX=22,46
for r in range(RMIN,RMAX+1,2):
    for sg in (1,-1):
        cx=np.rint(xs+sg*ux*r).astype(int); cy=np.rint(ys+sg*uy*r).astype(int)
        ok=(cx>=0)&(cx<W)&(cy>=0)&(cy<H)
        np.add.at(acc,(cy[ok],cx[ok]),1)
acc=cv2.GaussianBlur(acc,(0,0),2)
print(acc.max())
thr=0.5*acc.max()
cands=[]
mxacc=cv2.dilate(acc,np.ones((25,25)))
py,px=np.nonzero((acc>=mxacc)&(acc>25))
print(len(py))
def sample(cx,cy,r,ang):
    x=int(round(cx+r*math.cos(ang))); y=int(round(cy+r*math.sin(ang)))
    return (x,y)
found=[]
for cy,cx in zip(py,px):
    best=None
    for r in range(RMIN,RMAX+1):
        hit=0; tot=0
        for k in range(72):
            a=2*math.pi*k/72
            ok=False
            for d in (-2,-1,0,1,2):
                x,y=sample(cx,cy,r+d,a)
                if 0<=x<W and 0<=y<H and norm[y,x]<0.88: ok=True;break
            hit+=ok; tot+=1
        cov=hit/tot
        if best is None or cov>best[0]: best=(cov,r)
    cov,r=best
    if cov<0.8: continue
    # interior
    yy,xx=np.ogrid[:H,:W]
    m=(xx-cx)**2+(yy-cy)**2<=(0.7*r)**2
    inner=norm[m]
    dark=(inner<0.9).mean()
    found.append((cx,cy,r,cov,dark))
for f in found: print([round(float(v),2) for v in f])
out=img.copy()
for cx,cy,r,cov,dark in found:
    col=(0,200,0) if dark<0.03 else (0,0,255)
    cv2.circle(out,(int(cx),int(cy)),int(r),col,2)
cv2.imwrite('circ2_out.png',out)
