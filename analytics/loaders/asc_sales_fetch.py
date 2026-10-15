import time, jwt, requests, os, gzip, io, datetime, sys, warnings
from concurrent.futures import ThreadPoolExecutor
warnings.filterwarnings("ignore")
ISS="6d7538b8-bc63-428c-8ec2-42cb6c43caf9"; KID="69AVX6PM25"; VENDOR="94139603"
KEY=open(os.path.expanduser(f"~/.secrets/imposter/AuthKey_{KID}.p8")).read()
OUT=sys.argv[1]; os.makedirs(OUT, exist_ok=True)
def tok():
    now=int(time.time())
    return jwt.encode({"iss":ISS,"iat":now,"exp":now+1100,"aud":"appstoreconnect-v1"},KEY,algorithm="ES256",headers={"kid":KID,"typ":"JWT"})
T=tok()
def fetch(d):
    path=f"{OUT}/{d}.tsv"
    if os.path.exists(path): return d,"cached"
    for attempt in range(4):
        r=requests.get("https://api.appstoreconnect.apple.com/v1/salesReports",headers={"Authorization":"Bearer "+T},
          params={"filter[frequency]":"DAILY","filter[reportType]":"SALES","filter[reportSubType]":"SUMMARY",
                  "filter[vendorNumber]":VENDOR,"filter[reportDate]":d,"filter[version]":"1_1"},timeout=60)
        if r.status_code==200:
            open(path,"w").write(gzip.GzipFile(fileobj=io.BytesIO(r.content)).read().decode()); return d,"ok"
        if r.status_code==404: return d,"none"
        time.sleep(3*(attempt+1))
    return d,f"fail {r.status_code} {r.text[:120]}"
today=datetime.date.today()
days=[(today-datetime.timedelta(days=i)).isoformat() for i in range(1,367)]
res=dict(ThreadPoolExecutor(6).map(fetch,days))
ok=sorted(d for d,s in res.items() if s in("ok","cached"))
print("with data:",len(ok),"first:",ok[0] if ok else None,"last:",ok[-1] if ok else None)
print("no report:",sum(s=="none" for s in res.values()))
for d,s in res.items():
    if s.startswith("fail"): print(d,s)
