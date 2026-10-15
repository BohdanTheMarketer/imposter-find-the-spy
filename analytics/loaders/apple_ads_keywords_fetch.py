import time, jwt, requests, os, json, sys, datetime, warnings
warnings.filterwarnings("ignore")
CLIENT="SEARCHADS.9a079a92-2a52-480c-bb86-272371b0e497"; TEAM=CLIENT; KID="49d9ffcc-ecc5-428d-9616-d10d3b4bfa3f"; ORG=21082690
API="https://api.searchads.apple.com/api/v5"
start, out = datetime.date.fromisoformat(sys.argv[1]), sys.argv[2]
end = datetime.date.today() - datetime.timedelta(days=1)
key=open(os.path.expanduser("~/.secrets/imposter/apple-ads-private.pem")).read()
now=int(time.time())
secret=jwt.encode({"sub":CLIENT,"iss":TEAM,"iat":now,"exp":now+3600,"aud":"https://appleid.apple.com"},key,algorithm="ES256",headers={"kid":KID})
tok=requests.post("https://appleid.apple.com/auth/oauth2/token",data={"grant_type":"client_credentials","client_id":CLIENT,"client_secret":secret,"scope":"searchadsorg"}).json()["access_token"]
H={"Authorization":"Bearer "+tok,"X-AP-Context":f"orgId={ORG}"}
camps=requests.get(f"{API}/campaigns?limit=1000",headers=H).json()["data"]
print("campaigns:",[(c["id"],c["name"],c["status"],c.get("countriesOrRegions")) for c in camps])
def windows():
    s=start
    while s<=end:
        e=min(s+datetime.timedelta(days=89),end); yield s,e; s=e+datetime.timedelta(days=1)
def report(path, s, e, group):
    rows,off=[],0
    while True:
        body={"startTime":s.isoformat(),"endTime":e.isoformat(),"granularity":"DAILY","timeZone":"ORTZ",
              "selector":{"orderBy":[{"field":"localSpend","sortOrder":"DESCENDING"}],"pagination":{"offset":off,"limit":1000}},
              "groupBy":group,"returnRecordsWithNoMetrics":False,"returnRowTotals":False,"returnGrandTotals":False}
        r=requests.post(f"{API}/reports/{path}",headers=H,json=body)
        if not r.ok:
            print("ERR",path,s,e,r.status_code,r.text[:400]); return rows
        d=r.json()["data"]["reportingDataResponse"]; rows+=d.get("row",[])
        pg=r.json().get("pagination") or {}
        off+=1000
        if off>=pg.get("totalResults",0): return rows
loaded=datetime.datetime.utcnow().isoformat()+"Z"; n=0; camp_total=0; kw_total=0; sample=None
with open(out,"w") as f:
    for c in camps:
        for s,e in windows():
            for row in report(f"campaigns/{c['id']}/keywords",s,e,["countryOrRegion"]):
                m=row["metadata"]; sample=sample or row
                for g in row.get("granularity",[]):
                    spend=float((g.get("localSpend") or {}).get("amount",0)); kw_total+=spend
                    f.write(json.dumps({"date":g["date"],"org_id":ORG,"campaign_id":c["id"],"campaign_name":c["name"],
                      "ad_group_id":m.get("adGroupId"),"ad_group_name":m.get("adGroupName"),"keyword_id":m.get("keywordId"),
                      "keyword":m.get("keyword"),"match_type":m.get("matchType"),"country_or_region":m.get("countryOrRegion"),
                      "impressions":g.get("impressions"),"taps":g.get("taps"),"tap_installs":g.get("tapInstalls"),
                      "view_installs":g.get("viewInstalls"),"spend":f"{spend:.2f}",
                      "currency":(g.get("localSpend") or {}).get("currency"),"loaded_at":loaded})+"\n"); n+=1
        # campaign-level total for reconciliation
        for s,e in windows():
            for row in report("campaigns",s,e,[]):
                if row["metadata"]["campaignId"]==c["id"]:
                    camp_total+=sum(float((g.get("localSpend") or {}).get("amount",0)) for g in row.get("granularity",[]))
print("rows:",n,"keyword spend:",round(kw_total,2),"campaign spend:",round(camp_total,2))
print("sample metadata keys:",sorted(sample["metadata"].keys()) if sample else None)
print("sample granularity keys:",sorted(sample["granularity"][0].keys()) if sample else None)
