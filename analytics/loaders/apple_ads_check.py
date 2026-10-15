import time, jwt, requests, os, json, warnings
warnings.filterwarnings("ignore")
CLIENT="SEARCHADS.9a079a92-2a52-480c-bb86-272371b0e497"; TEAM=CLIENT; KID="49d9ffcc-ecc5-428d-9616-d10d3b4bfa3f"
key=open(os.path.expanduser("~/.secrets/imposter/apple-ads-private.pem")).read()
now=int(time.time())
secret=jwt.encode({"sub":CLIENT,"iss":TEAM,"iat":now,"exp":now+86400*180,"aud":"https://appleid.apple.com"},key,algorithm="ES256",headers={"kid":KID})
r=requests.post("https://appleid.apple.com/auth/oauth2/token",data={"grant_type":"client_credentials","client_id":CLIENT,"client_secret":secret,"scope":"searchadsorg"})
print("token:",r.status_code, r.text[:150] if not r.ok else "ok")
if r.ok:
    t=r.json()["access_token"]
    a=requests.get("https://api.searchads.apple.com/api/v5/acls",headers={"Authorization":"Bearer "+t})
    print("acls:",a.status_code)
    for o in a.json().get("data",[]): print(" org:",o.get("orgId"),o.get("orgName"),o.get("currency"),o.get("roleNames"),o.get("timeZone"))
