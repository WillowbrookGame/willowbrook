"""Rebuild original Skyhill low-poly GLBs with Python 3 (no dependencies)."""
import json
import math
from pathlib import Path
import random
import struct
import zlib

OUT = Path(__file__).parent
rng = random.Random(814)
MOSS = ("477547", "568348", "5c894d", "63904e", "558251")
STONE = ("526366", "657776", "6c807b", "758780", "485c62", "607570")
WOOD = ("95643c", "a67649", "b37f51", "be8a58", "9f6c43")
GRASS = ("688f48", "72964b", "72984d", "75984f", "69924d")
MEADOW = ("8ba750", "8eab55", "91ad59", "89a853", "93ab56")

def palette_png(colors):
    def chunk(kind, data):
        return struct.pack(">I",len(data))+kind+data+struct.pack(">I",zlib.crc32(kind+data))
    return (bytes.fromhex("89504e470d0a1a0a")
            + chunk(b"IHDR",struct.pack(">IIBBBBB",len(colors),1,8,2,0,0,0))
            + chunk(b"IDAT",zlib.compress(bytes(1)+b"".join(bytes.fromhex(c) for c in colors)))
            + chunk(b"IEND",b""))

class Mesh:
    def __init__(self):
        self.p, self.n, self.c = [], [], []

    def tri(self, a, b, c, color, outside):
        ab = tuple(y-x for x, y in zip(a,b))
        ac = tuple(y-x for x, y in zip(a,c))
        n = tuple(ab[i-2]*ac[i-1] - ab[i-1]*ac[i-2] for i in range(3))
        mag = math.sqrt(sum(t*t for t in n))
        if mag < 1e-8:
            return
        n = tuple(t/mag for t in n)
        if sum(u*v for u,v in zip(n,outside)) < 0:
            b,c = c,b
            n = tuple(-t for t in n)
        self.p.extend((a,b,c))
        self.n.extend((n,)*3)
        self.c.extend((color,)*3)

    def quad(self, a, b, c, d, color, outside, color2=None):
        self.tri(a,b,c,color,outside)
        self.tri(a,c,d,color2 or color,outside)

    def save(self, name, *, double=False, emission=None):
        palette=sorted(set(self.c))
        uvs={color:(i+.5)/len(palette) for i,color in enumerate(palette)}
        raw = b"".join(struct.pack("<3f",*v) for table in (self.p,self.n) for v in table)
        raw += b"".join(struct.pack("<2f",uvs[color],.5) for color in self.c)
        count=len(self.p)
        png=palette_png(palette)
        mat={"pbrMetallicRoughness":{"metallicFactor":0,"roughnessFactor":.95,"baseColorTexture":{"index":0}}, "doubleSided":double}
        if emission:
            mat["emissiveFactor"]=emission
        doc={
            "asset":{"version":"2.0","generator":"Willowbrook Skyhill scenery"},
            "scene":0, "scenes":[{"nodes":[0]}], "nodes":[{"name":name,"mesh":0}],
            "meshes":[{"name":name,"primitives":[{"attributes":{"POSITION":0,"NORMAL":1,"TEXCOORD_0":2},"material":0}]}],
            "materials":[mat],"buffers":[{"byteLength":len(raw)+len(png)}],
            "images":[{"bufferView":3,"mimeType":"image/png"}],
            "textures":[{"source":0,"sampler":0}],
            "samplers":[{"magFilter":9728,"minFilter":9728,"wrapS":33071,"wrapT":33071}],
            "bufferViews":[{"buffer":0,"byteOffset":k*count*12,"byteLength":count*(8 if k==2 else 12),"target":34962} for k in range(3)]
                           + [{"buffer":0,"byteOffset":len(raw),"byteLength":len(png)}],
            "accessors":[{"bufferView":k,"componentType":5126,"count":count,"type":"VEC2" if k==2 else "VEC3"} for k in range(3)]
        }
        for which, fun in (("min",min),("max",max)):
            doc["accessors"][0][which]=[fun(c) for c in zip(*self.p)]
        raw+=png
        raw+=bytes(-len(raw)%4)
        js=json.dumps(doc,separators=(",",":")).encode("ascii")
        js+=b" "*(-len(js)%4)
        (OUT/(name+".glb")).write_bytes(struct.pack("<4sII",b"glTF",2,28+len(js)+len(raw))+struct.pack("<I4s",len(js),b"JSON")+js+struct.pack("<I4s",len(raw),b"BIN\0")+raw)

def ring(m, first, second, colors):
    for i,a in enumerate(first):
        j=(i+1)%len(first)
        b,c,d=first[j],second[j],second[i]
        m.quad(a,b,c,d,rng.choice(colors),(a[0]+b[0],0,a[2]+b[2]),rng.choice(colors))

def cap(m, points, y, colors):
    for i,a in enumerate(points):
        m.tri(a,points[(i+1)%len(points)],(0,y,0),rng.choice(colors),(0,1,0))

def cliff(name,w,h,d,top=True):
    m=Mesh()
    # Near-vertical rock strata preserve the silhouette of the collision proxy.
    profile=[(-1,-.945),(-.91,-1),(-.28,-1),(.33,-1),(.92,-1),(1,-.94),(1,.03),(1,.95),(.91,1),(.17,1),(-.33,1),(-.92,1),(-1,.944),(-1,.03)]
    levels=[]
    for row,(height,taper) in enumerate(((-.5,1),(-.26,1),(-.04,.996),(.20,1),(.427,1),(.5,.982))):
        levels.append([(x*w/2*taper, (height+(rng.uniform(-.065,.065) if 0<row<5 else 0))*h,z*d/2*taper) for x,z in profile])
    for i in range(len(levels)-1):
        ring(m, levels[i],levels[i+1], MOSS if top and i==4 else STONE)
    if top:
        cap(m,levels[-1],h/2,MOSS)
    else:
        cap(m,levels[-1],h/2,STONE)
    m.save(name)

def ground(name,w,d,y,palette,meadow=False):
    m=Mesh()
    x_count, z_count = (12,14) if meadow else (15,16)
    grid=[]
    for row in range(z_count+1):
        grid.append([(w*(i/x_count-.5)+(rng.uniform(-1.6,1.6) if 0<i<x_count else 0),y,d*(row/z_count-.5)+(rng.uniform(-1.7,1.7) if 0<row<z_count else 0)) for i in range(x_count+1)])
    for row in range(z_count):
        for i in range(x_count):
            a,b,c,e=grid[row][i],grid[row][i+1],grid[row+1][i+1],grid[row+1][i]
            m.quad(a,b,c,e,rng.choice(palette),(0,1,0),rng.choice(palette))
    if meadow:
        # An irregular mown strip (guidance underfoot, with no raised collision).
        for z in range(-43,39,6):
            off=.55*math.sin(z*.12)
            next_off=.55*math.sin((z+6)*.12)
            m.quad((-4+off,y+.008,z),(4+off,y+.008,z),(4+next_off,y+.008,z+6),(-4+next_off,y+.008,z+6),"a3b767",(0,1,0))
            m.quad((-.19,y+.016,z),(.19,y+.016,z),(.19,y+.016,z+2.9),(-.19,y+.016,z+2.9),"e4dda6",(0,1,0))
    m.save(name)

def box(m,x,y,z,w,h,d,col):
    for k,axis in enumerate(((1,0,0),(0,1,0),(0,0,1))):
        j,l=(k+1)%3,(k+2)%3
        for sign in (-1,1):
            vs=[]
            for j_sign,l_sign in ((-1,-1),(1,-1),(1,1),(-1,1)):
                t=[x,y,z]
                for a,s in ((k,sign),(j,j_sign),(l,l_sign)):
                    t[a]+=(w,h,d)[a]*s/2
                vs.append(tuple(t))
            m.quad(*vs,col,tuple(sign*a for a in axis))

def deck():
    m=Mesh()
    for i in range(19):
        z = -5.7 + i*.632
        for x,w in ((-4.36,4.14),(-.15,4.18),(4.21,4.43)):
            box(m,x,.48,z,w,.18,.604,rng.choice(WOOD))
    for x in (-5.6,0,5.6):
        box(m,x,.10,0,.34,.52,11.92,"785135")
    for z in (-5.64,5.64):
        box(m,0,.02,z,12.8,.60,.40,"89603f")
    m.save("cedar-launch-deck")

def tube(m,sections,col,sides=9):
    rings=[[(x, y+radius*math.cos(i*math.tau/sides), z+radius*math.sin(i*math.tau/sides)) for i in range(sides)] for x,y,z,radius in sections]
    for row in range(len(rings)-1):
        for i in range(sides):
            j=(i+1)%sides
            theta=(i+.5)*math.tau/sides
            m.quad(rings[row][i],rings[row][j],rings[row+1][j],rings[row+1][i],col[row],(0,math.cos(theta),math.sin(theta)))

def cues():
    m=Mesh()
    box(m,0,2.75,0,.15,5.5,.15,"785b49")
    box(m,0,5.46,0,.27,.16,.27,"e2c67e")
    tube(m,[(.12,5.28,0,.36),(.47,5.24,0,.32),(.84,5.16,.04,.27),(1.24,5.03,.06,.20),(1.58,4.87,.05,.13)],
         ["e38b36","fbdf97","e99736","fbdf97"])
    m.save("canvas-windsock",double=True)
    m=Mesh()
    for ribbon in range(2):
        for i in range(10):
            def pt(j,side):
                angle=j*.25+ribbon*math.pi
                return (.34*math.sin(angle)+side*.105*math.sin(j*math.pi/13+.4),j*.37-1.6,.32*math.cos(angle)+side*.04)
            m.quad(pt(i,-1),pt(i,1),pt(i+1,1),pt(i+1,-1),("86d6df","b7eaef","cef4ed")[i%3],(0,0,1))
    m.save("curling-wind-ribbon",double=True,emission=[.08,.19,.21])

def water():
    m=Mesh()
    for i in range(9):
        for j in range(8):
            def pt(k,l):
                t=k/9
                return (3.35-4.1*t*t+.18*math.sin(l*1.8+k*.9), .85+8.0-17.28*t, (l/8-.5)*(5.1+2.0*t)+.16*math.sin(k+l))
            m.quad(pt(i,j),pt(i,j+1),pt(i+1,j+1),pt(i+1,j),
                   rng.choice(("57b7bb","8ddce0","a8e6df","73ccd5","65c6ca")),(-1,0,0))
    m.save("cascade-water",double=True,emission=[.035,.11,.12])
    m=Mesh()
    def ellipse(rx,rz,y):
        return [(math.cos(i*math.tau/20)*(rx+rng.uniform(-.3,.3)),y,math.sin(i*math.tau/20)*(rz+rng.uniform(-.35,.35))) for i in range(20)]
    borders=[ellipse(7.8,6,0),ellipse(6.9,5.4,.012),ellipse(4.3,3.35,.018)]
    ring(m,borders[0],borders[1],("83c8bd","8ed3c3","82c3b9"))
    ring(m,borders[1],borders[2],("5eb5b0","66bdb7","58afa9"))
    cap(m,borders[-1],.02,("509da0","52a6a8","57acae"))
    m.save("cascade-pool",double=True)
    m=Mesh()
    for _ in range(25):
        x,z=rng.uniform(-1.9,1.9),rng.uniform(-3.3,3.3)
        y=rng.uniform(-.16,.50)
        size=rng.uniform(.10,.72)
        m.tri((x-size,y,z),(x+size,y+.07,z+.12),(x,y+size*.56,z+.21),rng.choice(("aff1eb","dcf6e9","effbf0")),(0,0,1))
    m.save("cascade-spray",double=True,emission=[.08,.14,.15])

def skyline():
    m=Mesh()
    for x,z,h,w,d in ((-91,-265,47,130,110),(3,-301,63,150,120),(109,-270,51,140,114),(155,-222,42,150,120),(-151,-188,32,118,109)):
        rows=[]
        for j,(frac,y) in enumerate(((1,-13),(.80,h*.42),(.50,h*.78),(.17,h))):
            rows.append([(x+math.cos(i*math.tau/10)*(w/2)*frac+rng.uniform(-4,4),y+rng.uniform(-4,4),z+math.sin(i*math.tau/10)*(d/2)*frac+rng.uniform(-4,4)) for i in range(10)])
        for j in range(len(rows)-1):
            for i in range(10):
                a,b=rows[j][i],rows[j][(i+1)%10]
                m.quad(a,b,rows[j+1][(i+1)%10],rows[j+1][i],rng.choice(("617e80","6b8586","6f898b","779394")),(a[0]+b[0]-2*x,0,a[2]+b[2]-2*z))
        for i in range(10):
            m.tri(rows[-1][i],rows[-1][(i+1)%10],(x,h+1,z),"7f9a98",(0,1,0))
    m.save("distant-ridges")

if __name__ == "__main__":
    ground("valley-grass",240,271,2.5,GRASS)
    ground("landing-field",94,107,.35,MEADOW,True)
    cliff("launch-bluff",27,26,26)
    cliff("west-cliffs",28,13,67)
    cliff("east-cliffs",14,23,72)
    cliff("scenic-ridge",19,13.5,12)
    deck()
    cues()
    water()
    skyline()
