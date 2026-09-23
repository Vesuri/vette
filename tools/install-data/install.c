/* Standalone Vette! 1.02 installer. No archive/filesystem libraries.
 * All large workspaces live in BSS; decoding is iterative and bounded.
 * StuffIt format references and table licensing: see README.md.
 */
#include "io.h"
#include "sha256.h"
#include <string.h>
#include "sit13_tables.h"
#define BUFSIZE 4096
#define LIMIT (32UL*1024*1024)
#define REQUIRE(x,msg) do { if(!(x)) return fail(msg); } while(0)
#define TRY(x) do { if(!(x)) return 0; } while(0)
static const char *error;
static unsigned char input[BUFSIZE],output[BUFSIZE],history[65536],scratch[4096];
static File archive,ndif,raw,writing,checking;
static char workdir[1024],paths[4][1100],targets[2][1100];
static unsigned owned,committed;
static char publishdir[1024],staged[2][1100];
static unsigned publish_owned;
static const char *names[2]={"Color VETTE!","VETTE!.Data"};
static const uint32_t sizes[2]={1587389,577498};
static const char *hashes[2]={
    "77e80078116e6aef0f257381466cf9cfc77108c75404138c002c68fbde7b896b",
    "e3db29fcc7b51a5275857bb06ff4ffb082d9aebb9f4045eb71ce23ba243a075f"};
static int fail(const char *s) { if(!error) error=s; return 0; }
static uint16_t be16(const unsigned char *p) { return (uint16_t)((p[0]<<8)|p[1]); }
static uint32_t be32(const unsigned char *p) { return ((uint32_t)be16(p)<<16)|be16(p+2); }
static int span(uint32_t off,uint32_t n,uint32_t size) { return off<=size && n<=size-off; }
static int readat(File *f,uint32_t off,void *p,uint32_t n) {
    REQUIRE(!io_cancelled(),"Installation cancelled.");
    REQUIRE(span(off,n,f->size),"Truncated file or invalid file offset.");
    REQUIRE((f->pos==off || io_seek(f,off)) && io_read(f,p,n),"Cannot read input file."); return 1;
}
static int writebytes(File *f,const void *p,uint32_t n) {
    REQUIRE(!io_cancelled(),"Installation cancelled.");
    REQUIRE(io_write(f,p,n),"Cannot write output (disk full or write error)."); return 1;
}
static int closefile(File *f) { REQUIRE(io_close(f),"Cannot close output file (write error)."); return 1; }
static int join(char *out,unsigned cap,const char *dir,const char *name) {
    size_t a=strlen(dir),b=strlen(name);
    REQUIRE(a+b+2<cap,"Installation path is too long.");
    memcpy(out,dir,a);
    if(a && dir[a-1]!='/' && dir[a-1]!=':') out[a++]='/';
    memcpy(out+a,name,b+1); return 1;
}

/* Bounded compressed input, LSB-first bit reader. */
static File *infile;
static uint32_t inoff,inleft;
static unsigned ipos,ilen,bits,nbits;
static void begin_input(File *f,uint32_t off,uint32_t len) {
    infile=f; inoff=off; inleft=len; ipos=ilen=bits=nbits=0;
}
static unsigned getbyte(void) {
    unsigned n;
    if(error) return 0;
    if(ipos==ilen) {
        if(!inleft) { fail("Truncated compressed stream."); return 0; }
        n=inleft>BUFSIZE?BUFSIZE:(unsigned)inleft;
        if(!readat(infile,inoff,input,n)) return 0;
        inoff+=n; inleft-=n; ipos=0; ilen=n;
    }
    return input[ipos++];
}
static uint32_t getbits(unsigned n) {
    uint32_t value=0; unsigned i;
    for(i=0;i<n;i++) {
        if(!nbits) { bits=getbyte(); nbits=8; }
        value|=(uint32_t)(bits&1)<<i; bits>>=1; nbits--;
    }
    return value;
}
static uint16_t crc_table[256];
static void crc_init(void) {
    unsigned i,j; uint16_t c;
    for(i=0;i<256;i++) { c=(uint16_t)i; for(j=0;j<8;j++) c=(uint16_t)((c>>1)^((c&1)?0xa001:0)); crc_table[i]=c; }
}
static uint16_t crc_byte(uint16_t c,unsigned b) { return (uint16_t)((c>>8)^crc_table[(c^b)&255]); }

/* The same output/history workspace serves SIT13 and ADC. Matches may overlap. */
static File *outfile;
static uint32_t produced,wanted;
static unsigned opos;
static uint16_t crc;
static void begin_output(File *f,uint32_t n) { outfile=f; wanted=n; produced=opos=crc=0; }
static int flush_output(void) { if(opos) { TRY(writebytes(outfile,output,opos)); opos=0; } return 1; }
static int emit(unsigned b) {
    REQUIRE(produced<wanted,"Decompressed data exceeds its declared size.");
    history[produced&65535]=(unsigned char)b; output[opos++]=(unsigned char)b;
    produced++; crc=crc_byte(crc,b);
    if(opos==BUFSIZE) TRY(flush_output());
    return !error;
}
static int match(uint32_t distance,uint32_t n) {
    REQUIRE(distance && distance<=65536 && distance<=produced,"Invalid compressed back-reference.");
    REQUIRE(n<=wanted-produced,"Compressed match exceeds declared output size.");
    while(n--) TRY(emit(history[(produced-distance)&65535]));
    return 1;
}

/* Prefix trees, iterative construction and traversal. A negative edge is a symbol. */
typedef struct { int16_t child[644][2]; unsigned nodes; } Tree;
static Tree trees[4];
static int lengths[321];
static void tree_init(Tree *t) { memset(t,0,sizeof(*t)); t->nodes=1; }
static int tree_add(Tree *t,uint32_t code,unsigned len,unsigned symbol,int lowfirst) {
    unsigned node=1,i,b; int16_t *edge;
    REQUIRE(len && len<=32,"Invalid Huffman code length.");
    for(i=0;i<len;i++) {
        b=(code>>(lowfirst?i:len-1-i))&1; edge=&t->child[node][b];
        if(i+1==len) { REQUIRE(!*edge,"Overlapping Huffman codes."); *edge=-(int16_t)(symbol+1); }
        else {
            REQUIRE(*edge>=0,"Overlapping Huffman codes.");
            if(!*edge) { REQUIRE(t->nodes+1<644,"Huffman tree is too large."); *edge=(int16_t)++t->nodes; }
            node=(unsigned)*edge;
        }
    }
    return 1;
}
static int canonical(Tree *t,unsigned count) {
    uint32_t code=0; unsigned len,i; int exhausted=0;
    tree_init(t);
    for(len=1;len<=32;len++) {
        if(len>1) { if(code&0x80000000UL) exhausted=1; code<<=1; }
        for(i=0;i<count;i++) if(lengths[i]==(int)len) {
            REQUIRE(!exhausted && (len==32 || code<(1UL<<len)),"Oversubscribed Huffman table.");
            TRY(tree_add(t,code,len,i,0)); if(code==0xffffffffUL) exhausted=1; code++;
        }
    }
    return 1;
}
static unsigned symbol(Tree *t) {
    int node=1; unsigned i;
    for(i=0;i<32 && !error;i++) {
        node=t->child[node][getbits(1)];
        if(node<0) return (unsigned)(-node-1);
        if(!node) break;
    }
    fail("Invalid Huffman symbol."); return 0;
}
static int dynamic_tree(Tree *t,unsigned count) {
    unsigned i=0,v,repeat; int length=0;
    while(i<count && !error) {
        v=symbol(&trees[3]); repeat=1;
        if(v<31) length=(int)v+1;
        else if(v==31) length=-1;
        else if(v==32) length++;
        else if(v==33) length--;
        else if(v==34) repeat=1+getbits(1);
        else if(v==35) repeat=3+getbits(3);
        else if(v==36) repeat=11+getbits(6);
        REQUIRE(length>=-1 && length<=32 && repeat<=count-i,"Invalid dynamic Huffman table.");
        while(repeat--) lengths[i++]=length;
    }
    REQUIRE(!error,"Invalid Huffman table."); return canonical(t,count);
}
static int sit13(void) {
    unsigned h=getbyte(),mode=h>>4,i,v,n,offbits,current=0; uint32_t distance;
    if(!mode) {
        tree_init(&trees[3]);
        for(i=0;i<37;i++) TRY(tree_add(&trees[3],MetaCodes[i],MetaCodeLengths[i],i,1));
        TRY(dynamic_tree(&trees[0],321));
        if(h&8) memcpy(&trees[1],&trees[0],sizeof(Tree));
        else TRY(dynamic_tree(&trees[1],321));
        TRY(dynamic_tree(&trees[2],(h&7)+10));
    } else {
        REQUIRE(mode<=5,"Unsupported StuffIt Huffman table.");
        for(i=0;i<321;i++) lengths[i]=FirstCodeLengths[mode-1][i];
        TRY(canonical(&trees[0],321));
        for(i=0;i<321;i++) lengths[i]=SecondCodeLengths[mode-1][i];
        TRY(canonical(&trees[1],321));
        for(i=0;i<OffsetCodeSize[mode-1];i++) lengths[i]=OffsetCodeLengths[mode-1][i];
        TRY(canonical(&trees[2],OffsetCodeSize[mode-1]));
    }
    while(!error) {
        v=symbol(&trees[current]);
        if(v==320) break;
        if(v<256) { TRY(emit(v)); current=0; }
        else {
            current=1;
            if(v<318) n=v-256+3;
            else n=65+getbits(v==318?10:15);
            offbits=symbol(&trees[2]);
            REQUIRE(offbits<=16,"Invalid StuffIt distance code.");
            distance=offbits<2?offbits+1:(1UL<<(offbits-1))+getbits(offbits-1)+1;
            TRY(match(distance,n));
        }
    }
    REQUIRE(!error && produced==wanted,"StuffIt output size mismatch.");
    return flush_output();
}
typedef struct { uint32_t off,packed,size; unsigned method; uint16_t crc; } SitFork;
static SitFork forks[2];

static int find_image(void) {
    unsigned remaining,entries=0,found=0,version,flags,hs,nl,extra,hasresource;
    uint32_t pos,dataoff,rc,dc; uint16_t headercrc,computed;
    TRY(readat(&archive,0,scratch,100));
    REQUIRE(!memcmp(scratch,"StuffIt (c)1997-",15) && scratch[82]==5,"Expected a StuffIt 5 archive.");
    REQUIRE(!(scratch[83]&128),"Encrypted StuffIt archives are unsupported.");
    REQUIRE(be32(scratch+84)==archive.size,"StuffIt archive size mismatch.");
    remaining=be16(scratch+92); pos=be32(scratch+94);
    while(remaining && !error) {
        REQUIRE(++entries<=4096,"Too many StuffIt entries."); remaining--;
        TRY(readat(&archive,pos,scratch,48));
        REQUIRE(be32(scratch)==0xa5a5a5a5UL,"Invalid StuffIt entry header.");
        version=scratch[4]; hs=be16(scratch+6); flags=scratch[9]; nl=be16(scratch+30);
        REQUIRE(version>=1 && version<=3 && hs>=48 && hs<=sizeof(scratch),"Unsupported StuffIt entry header.");
        REQUIRE(!(flags&32),"Encrypted StuffIt entries are unsupported.");
        if((flags&64) && be32(scratch+34)==0xffffffffUL) { pos+=48; remaining++; continue; }
        REQUIRE((flags&64) || !scratch[47],"Password-protected StuffIt entry.");
        REQUIRE(nl<=hs-48,"Invalid StuffIt filename length.");
        TRY(readat(&archive,pos,scratch,hs));
        headercrc=be16(scratch+32); scratch[32]=scratch[33]=0; computed=0;
        for(extra=0;extra<hs;extra++) computed=crc_byte(computed,scratch[extra]);
        REQUIRE(computed==headercrc,"StuffIt entry header CRC mismatch.");
        if(flags&64) { remaining+=be16(scratch+46); REQUIRE(remaining<=4096,"Too many StuffIt entries."); }
        dc=(flags&64)?0:be32(scratch+38);
        hasresource=nl==10 && !memcmp(scratch+48,"VETTE!.img",10);
        if(hasresource && !(flags&64)) {
            REQUIRE(!found,"Multiple VETTE!.img entries in archive.");
            forks[1].size=be32(scratch+34); forks[1].packed=dc;
            forks[1].method=scratch[46]; forks[1].crc=be16(scratch+42);
        }
        extra=version==1?36:32;
        TRY(readat(&archive,pos+hs,scratch,extra));
        rc=0; dataoff=pos+hs+extra;
        if(be16(scratch)&1) {
            TRY(readat(&archive,dataoff,scratch,14)); dataoff+=14;
            REQUIRE(!scratch[13],"Password-protected resource fork.");
            rc=be32(scratch+4);
            if(hasresource && !(flags&64)) {
                forks[0].size=be32(scratch); forks[0].packed=rc;
                forks[0].crc=be16(scratch+8); forks[0].method=scratch[12]; forks[0].off=dataoff;
            }
        } else REQUIRE(!hasresource,"NDIF image has no resource fork.");
        REQUIRE(span(dataoff,rc,archive.size) && span(dataoff+rc,dc,archive.size),"StuffIt payload outside archive.");
        if(hasresource && !(flags&64)) { forks[1].off=dataoff+rc; found=1; }
        pos=dataoff+rc+dc;
    }
    REQUIRE(found,"No VETTE!.img in this archive.");
    return 1;
}
static int unpack_fork(unsigned i) {
    SitFork *s=&forks[i];
    REQUIRE(s->size && s->size<=LIMIT,"Unsupported image fork size.");
    REQUIRE(s->method==0 || s->method==13,"Unsupported StuffIt compression method (expected 0 or 13).");
    REQUIRE(io_open(&writing,paths[i],1),"Cannot create temporary image fork.");
    begin_input(&archive,s->off,s->packed); begin_output(&writing,s->size);
    if(s->method==13) TRY(sit13());
    else { REQUIRE(s->size==s->packed,"Invalid raw StuffIt fork size."); while(produced<wanted && !error) TRY(emit(getbyte())); TRY(flush_output()); }
    REQUIRE(!error && crc==s->crc,"StuffIt fork CRC mismatch.");
    TRY(closefile(&writing)); return 1;
}

/* NDIF: locate bcem 128 in the original resource map; no native forks needed. */
static uint32_t bcem,bcemlen;
static int find_bcem(void) {
    uint32_t data,map,dl,ml,tl,refs,res; unsigned nt,i,nr,j;
    TRY(readat(&checking,0,scratch,16));
    data=be32(scratch); map=be32(scratch+4); dl=be32(scratch+8); ml=be32(scratch+12);
    REQUIRE(span(data,dl,checking.size) && span(map,ml,checking.size) && ml>=28,"Invalid NDIF resource map.");
    TRY(readat(&checking,map+24,scratch,2)); tl=be16(scratch);
    REQUIRE(span(tl,2,ml),"Invalid NDIF type list."); tl+=map;
    TRY(readat(&checking,tl,scratch,2)); nt=be16(scratch)+1;
    REQUIRE(nt<=256 && span(tl-map+2,nt*8,ml),"Invalid NDIF resource types.");
    for(i=0;i<nt;i++) {
        TRY(readat(&checking,tl+2+i*8,scratch,8));
        if(memcmp(scratch,"bcem",4)) continue;
        nr=be16(scratch+4)+1; refs=tl+be16(scratch+6);
        REQUIRE(nr<=1024 && span(refs-map,nr*12,ml),"Invalid NDIF resource references.");
        for(j=0;j<nr;j++) {
            TRY(readat(&checking,refs+j*12,scratch,12));
            if(be16(scratch)!=128) continue;
            res=be32(scratch+4)&0xffffffUL;
            REQUIRE(span(res,4,dl),"Invalid bcem offset.");
            TRY(readat(&checking,data+res,scratch,4)); bcemlen=be32(scratch); bcem=data+res+4;
            REQUIRE(span(res+4,bcemlen,dl) && bcemlen>=128,"Invalid bcem size."); return 1;
        }
    }
    return fail("NDIF block map bcem 128 is missing.");
}
static int decode_ndif(void) {
    uint32_t sectors,count,i,start,next,off,len,total; unsigned type,b,n; uint32_t distance;
    REQUIRE(io_open(&checking,paths[0],0) && io_open(&ndif,paths[1],0),"Cannot open temporary NDIF forks.");
    TRY(find_bcem()); TRY(readat(&checking,bcem,scratch,128));
    REQUIRE(be16(scratch)==11,"Unsupported NDIF map version.");
    sectors=be32(scratch+68); count=be32(scratch+124);
    REQUIRE(sectors && sectors<=LIMIT/512 && count>=2 && count<=1024 && 128+count*12<=bcemlen,"Invalid NDIF block map.");
    total=sectors<<9;
    REQUIRE(io_open(&writing,paths[2],1),"Cannot create temporary HFS image.");
    for(i=0;i<count;i++) {
        TRY(readat(&checking,bcem+128+i*12,scratch,12));
        start=be32(scratch)>>8; type=scratch[3]; off=be32(scratch+4); len=be32(scratch+8);
        REQUIRE(start<=sectors && writing.pos==(start<<9),"Noncontiguous or unordered NDIF map.");
        if(type==255) { REQUIRE(i==count-1 && start==sectors && !len,"Invalid NDIF terminator."); break; }
        REQUIRE(i+1<count,"Missing NDIF terminator.");
        TRY(readat(&checking,bcem+140+i*12,scratch,4)); next=be32(scratch)>>8;
        REQUIRE(next>start && next<=sectors,"Invalid NDIF sector range.");
        begin_output(&writing,(next-start)<<9);
        if(type==0) {
            REQUIRE(!len,"Invalid NDIF empty extent.");
            memset(output,0,sizeof(output));
            while(produced<wanted) { n=wanted-produced>BUFSIZE?BUFSIZE:(unsigned)(wanted-produced); TRY(writebytes(&writing,output,n)); produced+=n; }
        } else {
            REQUIRE(span(off,len,ndif.size),"NDIF chunk lies outside data fork.");
            begin_input(&ndif,off,len);
            if(type==2) {
                REQUIRE(len==wanted,"Wrong raw NDIF chunk size.");
                while(produced<wanted && !error) TRY(emit(getbyte()));
            } else if(type==131) {
                while(produced<wanted && !error) {
                    b=getbyte();
                    if(b&128) { n=(b&127)+1; while(n-- && !error) TRY(emit(getbyte())); }
                    else {
                        if(b&64) { n=(b&63)+4; distance=getbyte()<<8; distance+=getbyte()+1; }
                        else { n=((b>>2)&15)+3; distance=((b&3)<<8)+getbyte()+1; }
                        TRY(match(distance,n));
                    }
                }
            } else return fail("Unsupported NDIF chunk type.");
            REQUIRE(!error && produced==wanted && inleft==0 && ipos==ilen,"NDIF chunk size mismatch.");
            TRY(flush_output());
        }
    }
    REQUIRE(writing.pos==total,"Incomplete HFS image.");
    TRY(closefile(&writing)); TRY(closefile(&checking)); TRY(closefile(&ndif));
    return 1;
}

/* Read-only HFS. Catalog/extent leaf chains are walked iteratively. */
typedef struct { uint16_t start,count; } Extent;
typedef struct { Extent ext[128]; unsigned n; uint32_t size,cnid; } Fork;
static Fork catalog,overflow,files[2];
static unsigned char nodebuf[4096],mdb[162];
static uint32_t allocation,blocksize,blockshift,blocks;
static uint32_t tree_node,tree_left; static unsigned node_size;
static uint32_t directory_id;
static int add_extents(Fork *f,const unsigned char *p) {
    unsigned i; uint32_t start,count;
    for(i=0;i<3;i++,p+=4) {
        start=be16(p); count=be16(p+2); if(!count) continue;
        REQUIRE(start<blocks && count<=blocks-start && f->n<128,"Invalid or excessive HFS extents.");
        { unsigned j; uint32_t total=count;
          for(j=0;j<f->n;j++) total+=f->ext[j].count;
          REQUIRE(total<=blocks,"HFS extent lengths exceed volume size."); }
        f->ext[f->n].start=(uint16_t)start; f->ext[f->n++].count=(uint16_t)count;
    }
    return 1;
}
static uint32_t fork_blocks(const Fork *f) { unsigned i; uint32_t n=0; for(i=0;i<f->n;i++) n+=f->ext[i].count; return n; }
static int fork_read(Fork *f,uint32_t off,void *out,uint32_t len) {
    unsigned i; uint32_t bytes,n; unsigned char *p=out;
    REQUIRE(span(off,len,f->size),"HFS fork read exceeds logical size.");
    for(i=0;i<f->n && len;i++) {
        bytes=(uint32_t)f->ext[i].count<<blockshift;
        if(off>=bytes) { off-=bytes; continue; }
        n=bytes-off; if(n>len) n=len;
        TRY(readat(&raw,allocation+((uint32_t)f->ext[i].start<<blockshift)+off,p,n));
        p+=n; len-=n; off=0;
    }
    REQUIRE(!len,"HFS fork extents are incomplete."); return 1;
}
static int tree_begin(Fork *f) {
    TRY(fork_read(f,0,nodebuf,40));
    REQUIRE(nodebuf[8]==1,"Invalid HFS B-tree header.");
    node_size=be16(nodebuf+32); tree_node=be32(nodebuf+24); tree_left=be32(nodebuf+36);
    REQUIRE(node_size>=512 && node_size<=4096 && !(node_size&(node_size-1)) && tree_left<=65536,"Unsupported HFS B-tree geometry.");
    return 1;
}
static int tree_next(Fork *f) {
    uint32_t offset=0,n=tree_node; unsigned shift=0,s=node_size;
    REQUIRE(tree_left-- && n,"Cyclic HFS B-tree leaf chain.");
    while(s>1) { s>>=1; shift++; }
    REQUIRE(n<=f->size>>shift,"Invalid HFS leaf number."); offset=n<<shift;
    TRY(fork_read(f,offset,nodebuf,node_size));
    REQUIRE(nodebuf[8]==255 && be16(nodebuf+10)<(node_size-14)/2,"Invalid HFS leaf node.");
    tree_node=be32(nodebuf); return 1;
}
static int record(unsigned i,unsigned char **key,unsigned *kl,unsigned char **body,unsigned *bl) {
    unsigned a=be16(nodebuf+node_size-2-2*i),b=be16(nodebuf+node_size-4-2*i),r;
    REQUIRE(a>=14 && b>a && b<=node_size-2*(be16(nodebuf+10)+1),"Invalid HFS record offsets.");
    *kl=nodebuf[a]; r=a+1+*kl; r=(r+1)&~1U;
    REQUIRE(*kl && r<=b,"Invalid HFS record key.");
    *key=nodebuf+a+1; *body=nodebuf+r; *bl=b-r; return 1;
}
static int extend_fork(Fork *f,unsigned type) {
    unsigned i,kl,bl,found; uint32_t before; unsigned char *k,*b;
    while((fork_blocks(f)<<blockshift)<f->size) {
        before=fork_blocks(f); found=0; TRY(tree_begin(&overflow));
        while(tree_node && !found) {
            TRY(tree_next(&overflow));
            for(i=0;i<be16(nodebuf+10);i++) {
                TRY(record(i,&k,&kl,&b,&bl));
                REQUIRE(kl==7 && bl>=12,"Invalid HFS overflow record.");
                if(k[0]==type && be32(k+1)==f->cnid && be16(k+5)==before) { TRY(add_extents(f,b)); found=1; break; }
            }
        }
        REQUIRE(found && fork_blocks(f)>before,"Missing HFS overflow extents.");
    }
    return 1;
}
static int scan_catalog(int findfiles) {
    unsigned i,kl,bl,n,j; unsigned char *k,*b;
    TRY(tree_begin(&catalog));
    while(tree_node) {
        TRY(tree_next(&catalog));
        for(i=0;i<be16(nodebuf+10);i++) {
            TRY(record(i,&k,&kl,&b,&bl));
            REQUIRE(kl>=6 && k[5]<=31 && 6U+k[5]<=kl && bl,"Invalid HFS catalog record."); n=k[5];
            if(!findfiles && b[0]==1 && n==21 && !memcmp(k+6,"(Folder) Color VETTE!",21)) {
                REQUIRE(bl>=10 && !directory_id,"Ambiguous Color VETTE! folder."); directory_id=be32(b+6);
            }
            if(findfiles && b[0]==2 && be32(k+1)==directory_id) {
                for(j=0;j<2;j++) if(n==strlen(names[j]) && !memcmp(k+6,names[j],n)) {
                    REQUIRE(bl>=98 && !files[j].size,"Invalid or duplicate game file.");
                    files[j].cnid=be32(b+20); files[j].size=be32(b+36);
                    REQUIRE(files[j].size==sizes[j],"Unsupported Vette! version (file size differs).");
                    TRY(add_extents(&files[j],b+86));
                }
            }
        }
    }
    return 1;
}
static SHA256 sha;
static int verify_file(File *f,unsigned index) {
    uint32_t off=0,n; unsigned i; unsigned char digest[32]; const char *hex="0123456789abcdef";
    REQUIRE(f->size==sizes[index],"Installed file has an unsupported size."); sha_init(&sha);
    while(off<f->size) { n=f->size-off; if(n>BUFSIZE) n=BUFSIZE; TRY(readat(f,off,scratch,n)); sha_update(&sha,scratch,n); off+=n; }
    sha_final(&sha,digest);
    for(i=0;i<32;i++) REQUIRE(hex[digest[i]>>4]==hashes[index][i*2] && hex[digest[i]&15]==hashes[index][i*2+1],"Game data SHA-256 mismatch: damaged or unsupported original version.");
    return 1;
}
static int extract_hfs(void) {
    unsigned j; uint32_t off,n;
    REQUIRE(io_open(&raw,paths[2],0),"Cannot reopen raw HFS image.");
    TRY(readat(&raw,1024,mdb,sizeof(mdb)));
    REQUIRE(be16(mdb)==0x4244,"Invalid HFS volume signature.");
    blocks=be16(mdb+18); blocksize=be32(mdb+20); allocation=(uint32_t)be16(mdb+28)<<9;
    REQUIRE(blocksize>=512 && blocksize<=65536 && !(blocksize&(blocksize-1)),"Unsupported HFS allocation block size.");
    blockshift=0; n=blocksize; while(n>1) { blockshift++; n>>=1; }
    REQUIRE(span(allocation,blocks<<blockshift,raw.size),"HFS allocation area exceeds image.");
    overflow.cnid=3; overflow.size=be32(mdb+130); TRY(add_extents(&overflow,mdb+134));
    catalog.cnid=4; catalog.size=be32(mdb+146); TRY(add_extents(&catalog,mdb+150));
    REQUIRE(overflow.size && overflow.size<raw.size && catalog.size && catalog.size<raw.size,"Invalid HFS metadata size.");
    REQUIRE((fork_blocks(&overflow)<<blockshift)>=overflow.size,"Fragmented HFS overflow file is unsupported.");
    TRY(extend_fork(&catalog,0)); TRY(scan_catalog(0));
    REQUIRE(directory_id,"Color VETTE! folder is missing."); TRY(scan_catalog(1));
    /* The NDIF forks are no longer needed: reuse their owned temporary paths. */
    for(j=0;j<2;j++) {
        REQUIRE(files[j].size,"Required Color VETTE! file is missing."); TRY(extend_fork(&files[j],255));
        REQUIRE(io_open(&writing,paths[j],1),"Cannot create extracted game file.");
        for(off=0;off<files[j].size;off+=n) { n=files[j].size-off; if(n>BUFSIZE) n=BUFSIZE; TRY(fork_read(&files[j],off,scratch,n)); TRY(writebytes(&writing,scratch,n)); }
        TRY(closefile(&writing)); REQUIRE(io_open(&checking,paths[j],0),"Cannot verify extracted game file.");
        TRY(verify_file(&checking,j)); TRY(closefile(&checking)); io_message(names[j]);
    }
    TRY(closefile(&raw)); return 1;
}
static int perform(const char *source,const char *dest,const char *temp) {
    unsigned i,existing=0; char suffix[32]; uint32_t off,n;
    REQUIRE(io_open(&archive,source,0),"Cannot open source archive.");
    crc_init(); TRY(find_image());
    if(!io_exists(dest)) REQUIRE(io_mkdir(dest),"Cannot create destination directory.");
    for(i=0;i<2;i++) TRY(join(targets[i],sizeof(targets[i]),dest,names[i]));
    /* Existing originals are accepted only when byte-identical. Never overwrite them. */
    for(i=0;i<2;i++) if(io_exists(targets[i])) {
        REQUIRE(io_open(&checking,targets[i],0),"Cannot read existing game data.");
        TRY(verify_file(&checking,i)); TRY(closefile(&checking));
        existing++;
    }
    if(existing==2) return 1;
    for(i=0;i<100;i++) {
        memcpy(suffix,".vette-install-00",18); suffix[15]="0123456789abcdef"[i>>4]; suffix[16]="0123456789abcdef"[i&15];
        TRY(join(workdir,sizeof(workdir),temp,suffix));
        if(io_mkdir(workdir)) { owned=1; break; }
    }
    REQUIRE(owned,"Cannot create installer temporary directory.");
    TRY(join(paths[0],sizeof(paths[0]),workdir,"image.rsrc"));
    TRY(join(paths[1],sizeof(paths[1]),workdir,"image.data"));
    TRY(join(paths[2],sizeof(paths[2]),workdir,"image.raw"));
    io_message("Extracting VETTE!.img from StuffIt archive...");
    TRY(unpack_fork(0)); TRY(unpack_fork(1)); TRY(closefile(&archive));
    io_message("Decoding NDIF disk image..."); TRY(decode_ndif());
    io_message("Extracting and verifying original game files..."); TRY(extract_hfs());
    /* Stage on the destination volume: the selected scratch volume may differ. */
    for(i=0;i<100;i++) {
        memcpy(suffix,".vette-publish-00",17); suffix[14]="0123456789abcdef"[i>>4]; suffix[15]="0123456789abcdef"[i&15];
        TRY(join(publishdir,sizeof(publishdir),dest,suffix));
        if(io_mkdir(publishdir)) { publish_owned=1; break; }
    }
    REQUIRE(publish_owned,"Cannot create destination staging directory.");
    for(i=0;i<2;i++) {
        TRY(join(staged[i],sizeof(staged[i]),publishdir,names[i]));
        REQUIRE(io_open(&checking,paths[i],0),"Cannot read verified game file.");
        REQUIRE(io_open(&writing,staged[i],1),"Cannot create destination staging file.");
        for(off=0;off<sizes[i];off+=n) {
            n=sizes[i]-off; if(n>BUFSIZE) n=BUFSIZE;
            TRY(readat(&checking,off,scratch,n)); TRY(writebytes(&writing,scratch,n));
        }
        TRY(closefile(&checking)); TRY(closefile(&writing));
        REQUIRE(io_open(&checking,staged[i],0),"Cannot verify destination staging file.");
        TRY(verify_file(&checking,i)); TRY(closefile(&checking));
    }
    for(i=0;i<2;i++) {
        if(io_exists(targets[i])) {
            REQUIRE(io_open(&checking,targets[i],0),"Cannot verify existing game file.");
            TRY(verify_file(&checking,i)); TRY(closefile(&checking));
        } else {
            REQUIRE(io_rename(staged[i],targets[i]),"Cannot install verified game file."); committed|=1U<<i;
        }
    }
    return 1;
}
int install_data(const char *source,const char *dest,const char *temp) {
    unsigned i; int ok=perform(source,dest,temp);
    io_close(&archive); io_close(&ndif); io_close(&raw); io_close(&writing); io_close(&checking);
    if(!ok) for(i=0;i<2;i++) if(committed&(1U<<i)) io_remove(targets[i]);
    if(publish_owned) {
        for(i=0;i<2;i++) if(staged[i][0] && io_exists(staged[i]) && !io_remove(staged[i]))
            io_message("Warning: could not remove a staging file.");
        if(!io_remove(publishdir)) io_message("Warning: could not remove destination staging directory.");
    }
    if(owned) {
        for(i=0;i<3;i++) if(paths[i][0] && io_exists(paths[i]) && !io_remove(paths[i]))
            io_message("Warning: could not remove a temporary installer file.");
        if(!io_remove(workdir)) { io_message("Temporary directory could not be removed:"); io_message(workdir); }
    }
    if(!ok) { io_message(error?error:"Installation failed."); return 20; }
    io_message("Original Vette! 1.02 data installed and verified."); return 0;
}
