# Test only (run by in-container.sh): patches a COPY of the installed collections so that SHOW GRANTS
# for chosen accounts gives an injected result. /var/tmp/inject.json maps "user@host" to a list of
# actions, one used per SHOW GRANTS for that account: "pass" runs it, "2013" or "1227" raises that
# error as the server would, "matched" returns a row as for an account the server answers for.
# argv: the mysql_query module file of the copy.
import re
import sys

path = sys.argv[1]
src = open(path).read()
m = re.search(r"^([ \t]*)cursor\.execute\((\w+), (\w+)\)", src, re.M)
if not m:
    sys.exit("no cursor.execute(<query>, <args>) in " + path)
indent, q, a = m.groups()
src = src[:m.start()] + "%s%s, %s = _inject(%s, %s)\n" % (indent, q, a, q, a) + src[m.start():]
helper = '''
def _inject(query, args):
    import json
    import os
    f = "/var/tmp/inject.json"
    if not query.startswith("SHOW GRANTS") or not args or not os.path.exists(f):
        return query, args
    with open(f) as fh:
        plan = json.load(fh)
    actions = plan.get("%s@%s" % (args[0], args[1])) or []
    if not actions:
        return query, args
    action = actions.pop(0)
    with open(f, "w") as fh:
        json.dump(plan, fh)
    if action == "pass":
        return query, args
    if action == "matched":
        return "SELECT 'GRANT USAGE ON *.* (injected)' AS g", None
    import pymysql
    messages = {"2013": "Lost connection to MySQL server during query",
                "1227": "Access denied; you need (at least one of) the SUPER privilege(s) for this operation"}
    raise pymysql.err.OperationalError(int(action), messages[action])


'''
m = re.search(r"^def main\(", src, re.M)
src = src[:m.start()] + helper.lstrip("\n") + src[m.start():]
open(path, "w").write(src)
