# Runs the unmodified reference code group_sim_sdp.py (Capra & Singh
# 2008, compbio.cs.princeton.edu/specificity, Python 2) and writes :
#   <out>      : its final scores in full precision (repr), one per column
#   <out>.aln  : the alignment as it read it : name, group index
#                (order of the group ids given, -1 : no group), sequence
# Usage : python2.7 groupsim_refrun.py <group_sim_sdp.py> <out> [options] alignfile gid1 gid2 ...
import sys, runpy
script, out = sys.argv[1], sys.argv[2]
sys.argv = [script, '-o', out + '.ref.txt'] + sys.argv[3:]
g = runpy.run_path(script, run_name='__main__')
f = open(out, 'w')
for i, s in enumerate(g['scores']):
    f.write('%d\t%s\n' % (i, 'None' if s is None else repr(s)))
f.close()
gi = {}
for k, gid in enumerate(g['group_ids']):
    for n in g['gids_to_seqs'][gid]:
        gi[n] = k
f = open(out + '.aln', 'w')
for n, (name, seq) in enumerate(zip(g['names'], g['alignment'])):
    f.write('%s\t%d\t%s\n' % (name, gi.get(n, -1), seq))
f.close()
