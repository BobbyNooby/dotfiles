"""The shell's side of the Google connection (scripts/google runs this with Hermes' Python).

It reuses Hermes' google-workspace skill (~/.hermes/skills/productivity/google-workspace):
the same OAuth token (~/.hermes/google_token.json), refreshed the same way, so you sign in once
and both Hermes and the shell use it. Prints JSON; on failure {"error": "..."} and exit 1.

  events FROM_ISO TO_ISO   events from every calendar you show in Google Calendar
  unread                   unread mails in the inbox, and the account's address
  whoami                   the account's address (Gmail, or the primary calendar's id)
  auth-url                 start signing in: prints the Google link (Calendar + Gmail only)
  auth-code URL_OR_CODE    finish it: saves the account's token

One account per run: scripts/google points HERMES_HOME at a folder holding that account's token.
"""
import json
import os
import sys

# The skill's code lives in the real ~/.hermes; HERMES_HOME may point at one account's folder
SKILL = os.environ.get("GOOGLE_SKILL_DIR") or os.path.expanduser(
    "~/.hermes/skills/productivity/google-workspace/scripts")
sys.path.insert(0, SKILL)


def out(obj, code=0):
    print(json.dumps(obj, ensure_ascii=False))
    sys.exit(code)


try:
    import google_api  # Hermes' wrapper: token loading + refresh
except Exception as e:  # skill missing or Hermes' Python lacks the Google libraries
    if sys.argv[1:2] not in (["auth-url"], ["auth-code"]):
        out({"error": f"Hermes' Google skill isn't available: {e}"}, 1)


def events(time_min, time_max):
    svc = google_api.build_service("calendar", "v3")
    found = []
    cals = svc.calendarList().list().execute().get("items", [])
    for cal in cals:
        if not cal.get("selected", cal.get("primary", False)):
            continue  # hidden in Google Calendar: hidden here too
        page = None
        while True:
            res = svc.events().list(
                calendarId=cal["id"], timeMin=time_min, timeMax=time_max,
                singleEvents=True, orderBy="startTime", maxResults=250, pageToken=page,
            ).execute()
            for ev in res.get("items", []):
                if ev.get("status") == "cancelled":
                    continue
                start, end = ev.get("start", {}), ev.get("end", {})
                found.append({
                    "id": ev.get("id"),
                    "calendar": cal.get("summaryOverride") or cal.get("summary", ""),
                    "color": ev.get("backgroundColor") or cal.get("backgroundColor", ""),
                    "title": ev.get("summary", "(no title)"),
                    "allDay": "date" in start,
                    "start": start.get("dateTime") or start.get("date"),
                    "end": end.get("dateTime") or end.get("date"),
                    "location": ev.get("location", ""),
                    "link": ev.get("htmlLink", ""),
                    "meet": ev.get("hangoutLink", ""),
                })
            page = res.get("nextPageToken")
            if not page:
                break
    found.sort(key=lambda e: e["start"] or "")
    return found


# Signing in. Like the skill's setup.py, but asks only for Calendar + Gmail (setup.py asks for
# all eight Workspace permissions). Same redirect and PKCE flow; the token format is the same,
# so Hermes reads it as usual.
SCOPES = [
    "https://www.googleapis.com/auth/calendar",
    "https://www.googleapis.com/auth/gmail.readonly",
    "https://www.googleapis.com/auth/gmail.send",
    "https://www.googleapis.com/auth/gmail.modify",
]
REDIRECT = "http://localhost:1"
HOME = os.environ.get("HERMES_HOME", os.path.expanduser("~/.hermes"))
PENDING = os.path.join(HOME, "google_oauth_pending.json")


def write_private(path, data):
    fd = os.open(path + ".tmp", os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as f:
        json.dump(data, f)
    os.replace(path + ".tmp", path)


def auth_url():
    from google_auth_oauthlib.flow import Flow
    flow = Flow.from_client_secrets_file(os.path.join(HOME, "google_client_secret.json"),
                                         scopes=SCOPES, redirect_uri=REDIRECT,
                                         autogenerate_code_verifier=True)
    url, state = flow.authorization_url(access_type="offline", prompt="consent")
    write_private(PENDING, {"state": state, "code_verifier": flow.code_verifier})
    return {"auth_url": url}


def auth_code(pasted):
    from urllib.parse import parse_qs, urlparse
    from google_auth_oauthlib.flow import Flow
    pend = json.load(open(PENDING))
    code, granted = pasted.strip(), SCOPES
    if code.startswith("http"):
        q = parse_qs(urlparse(code).query)
        if "code" not in q:
            return {"error": "That address has no code in it: copy the whole address of the localhost:1 page"}
        if q.get("state", [pend["state"]])[0] != pend["state"]:
            return {"error": "That's from an older sign-in: start again"}
        granted = (q.get("scope") or [" ".join(SCOPES)])[0].split()
        code = q["code"][0]
    flow = Flow.from_client_secrets_file(os.path.join(HOME, "google_client_secret.json"),
                                         scopes=granted, redirect_uri=REDIRECT,
                                         state=pend["state"], code_verifier=pend["code_verifier"])
    os.environ["OAUTHLIB_RELAX_TOKEN_SCOPE"] = "1"  # you may untick some permissions
    flow.fetch_token(code=code)
    token = json.loads(flow.credentials.to_json())
    token["type"] = token.get("type") or "authorized_user"
    token["scopes"] = list(getattr(flow.credentials, "granted_scopes", None) or granted)
    write_private(os.path.join(HOME, "google_token.json"), token)
    os.remove(PENDING)
    return {"ok": True, "scopes": token["scopes"]}


def whoami():
    try:
        return {"account": google_api.build_service("gmail", "v1").users().getProfile(userId="me").execute().get("emailAddress", "")}
    except SystemExit:
        raise
    except Exception:  # no Gmail permission: the primary calendar's id is the address
        cals = google_api.build_service("calendar", "v3").calendarList().list().execute().get("items", [])
        return {"account": next((c["id"] for c in cals if c.get("primary")), "")}


def unread():
    svc = google_api.build_service("gmail", "v1")
    inbox = svc.users().labels().get(userId="me", id="INBOX").execute()
    me = svc.users().getProfile(userId="me").execute()
    return {"unread": inbox.get("messagesUnread", 0), "account": me.get("emailAddress", "")}


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    try:
        if cmd == "events" and len(sys.argv) == 4:
            result = events(sys.argv[2], sys.argv[3])
        elif cmd == "unread":
            result = unread()
        elif cmd == "whoami":
            result = whoami()
        elif cmd == "auth-url":
            result = auth_url()
        elif cmd == "auth-code" and len(sys.argv) == 3:
            result = auth_code(sys.argv[2])
        else:
            out({"error": "usage: events FROM TO | unread"}, 1)
    except SystemExit:  # Hermes' wrapper exits (after printing to stderr) when not signed in
        out({"error": "not connected", "notConnected": True}, 1)
    except BaseException as e:  # network down, token revoked, API not enabled...
        out({"error": f"{type(e).__name__}: {e}"}, 1)
    out(result)
