# Spend без keyword (Search Tab, Search Match): ad group × країна × день мінус сума keyword-рядків → keyword_id = 0.
import time, jwt, requests, os, json, sys, datetime, warnings
from collections import defaultdict
warnings.filterwarnings("ignore")
CLIENT="SEARCHADS.9a079a92-2a52-480c-bb86-272371b0e497"; TEAM=CLIENT; KID="49d9ffcc-ecc5-428d-9616-d10d3b4bfa3f"; ORG=21082690
API="https://api.searchads.apple.com/api/v5"
start, kw_file, out = datetime.date.fromisoformat(sys.argv[1]), sys.argv[2], sys.argv[3]
end = datetime.date.today() - datetime.timedelta(days=1)
key=open(os.path.expanduser("~/.secrets/imposter/apple-ads-private.pem")).read()
now=int(time.time())
secret=jwt.encode({"sub":CLIENT,"iss":TEAM,"iat":now,"exp":now+3600,"aud":"https://appleid.apple.com"},key,algorithm="ES256",headers={"kid":KID})
tok=requests.post("https://appleid.apple.com/auth/oauth2/token",data={"grant_type":"client_credentials","client_id":CLIENT,"client_secret":secret,"scope":"searchadsorg"}).json()["access_token"]
H={"Authorization":"Bearer "+tok,"X-AP-Context":f"orgId={ORG}"}
camps=requests.get(f"{API}/campaigns?limit=1000",headers=H).json()["data"]
kw=defaultdict(lambda:[0.0,0,0,0,0])  # spend, impressions, taps, tap_installs, view_installs
for line in open(kw_file):
    r=json.loads(line); k=(r["date"],r["ad_group_id"],r["country_or_region"]); a=kw[k]
    a[0]+=float(r["spend"]); a[1]+=r["impressions"] or 0; a[2]+=r["taps"] or 0; a[3]+=r["tap_installs"] or 0; a[4]+=r["view_installs"] or 0
def windows():
    s=start
    while s<=end:
        e=min(s+datetime.timedelta(days=89),end); yield s,e; s=e+datetime.timedelta(days=1)
loaded=datetime.datetime.utcnow().isoformat()+"Z"; n=0; total=0.0
with open(out,"w") as f:
    for c in camps:
        for s,e in windows():
            off=0
            while True:
                body={"startTime":s.isoformat(),"endTime":e.isoformat(),"granularity":"DAILY","timeZone":"UTC",
                      "selector":{"orderBy":[{"field":"localSpend","sortOrder":"DESCENDING"}],"pagination":{"offset":off,"limit":1000}},
                      "groupBy":["countryOrRegion"],"returnRecordsWithNoMetrics":False,"returnRowTotals":False,"returnGrandTotals":False}
                r=requests.post(f"{API}/reports/campaigns/{c['id']}/adgroups",headers=H,json=body)
                if not r.ok: print("ERR",c["id"],s,r.status_code,r.text[:200]); break
                for row in r.json()["data"]["reportingDataResponse"].get("row",[]):
                    m=row["metadata"]
                    for g in row.get("granularity",[]):
                        a=kw.get((g["date"],m["adGroupId"],m.get("countryOrRegion")),[0.0,0,0,0,0])
                        spend=float((g.get("localSpend") or {}).get("amount",0))-a[0]
                        imp=(g.get("impressions") or 0)-a[1]; taps=(g.get("taps") or 0)-a[2]
                        ti=(g.get("tapInstalls") or 0)-a[3]; vi=(g.get("viewInstalls") or 0)-a[4]
                        if abs(spend)<0.005 and imp<=0 and taps<=0 and ti<=0 and vi<=0: continue
                        total+=spend
                        f.write(json.dumps({"date":g["date"],"org_id":ORG,"campaign_id":c["id"],"campaign_name":c["name"],
                          "ad_group_id":m["adGroupId"],"ad_group_name":m.get("adGroupName"),"keyword_id":0,
                          "keyword":"(no keyword)","match_type":"SEARCH_MATCH_OR_TAB","country_or_region":m.get("countryOrRegion"),
                          "impressions":max(imp,0),"taps":max(taps,0),"tap_installs":max(ti,0),"view_installs":max(vi,0),
                          "spend":f"{spend:.2f}","currency":(g.get("localSpend") or {}).get("currency"),"loaded_at":loaded})+"\n"); n+=1
                off+=1000
                if off>=(r.json().get("pagination") or {}).get("totalResults",0): break
print("residual rows:",n,"residual spend:",round(total,2))
