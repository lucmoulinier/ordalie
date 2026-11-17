import re,sys
src,dst=sys.argv[1],sys.argv[2]
t=open(src,encoding='utf-8').read()
n0=len(t)
subs=[
 (r'(if \{\$Password==""\} \{ set Password )"[^"]*"(?: ; append Password \[string toupper \$User\])?', r'\1""'),
 (r'password=\[spdecode \{[^}]*\}\]', 'password='),
 (r'password=(?!\$|\[|")[^\s"\]]+', 'password='),
 (r'--password=[^\s]+', '--password='),
 (r'set Secret "[^\n]*', 'set Secret ""'),
]
tot=0
for a,b in subs:
    t,n=re.subn(a,b,t); tot+=n; print(n,a)
open(dst,'w',encoding='utf-8').write(t)
print('remplacements',tot)
