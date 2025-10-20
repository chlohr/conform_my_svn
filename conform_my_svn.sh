#!/bin/bash
#
# C. Lohr 2025 - GPLv3+
#
# Attempt to turn a patological multi-projects SVN repository into a "conformable" way for a svn to git conversion
# For underlaying concepts, refers to http://www.catb.org/~esr/reposurgeon/repository-editing.html#multiproject
#
# This produce a list of repocutter pathrename FROM/TO pairs
# See http://www.catb.org/~esr/reposurgeon/repocutter.html
#
# Audience:
# This script is dedicated to the brave souls who:
# - Have really read the "reposurgeon" documentation
#   http://www.catb.org/~esr/reposurgeon/repository-editing.html
# - Have really tried to experiment it
#   (repotool initmake & make & co.)
# - Are lost between Step 0 and Step 1
#   (If you do not understand what this means, please carefully reread the mentioned documentation)
#
# Warning: This script works on the svndump file of your project


if [ "$#" != 1 ]; then
  echo "Usage: $0 <svndump file>" >&2
  exit 1
fi
DUMP="$1"

if ! file -b $DUMP | grep -qi 'Subversion dumpfile'
then
  echo "Error: '$DUMP' is not an svndump file" >&2
  exit 1
fi


echo "List directories" >&2
DIRS=$(mktemp)
awk '
/^Node-path:/ {path=$2}
/^Node-kind: dir$/ {if (path) print path}
' $DUMP | sort -u -o $DIRS


RENAMES=$(mktemp)

echo "Handle trunks" >&2
sed -ne 's,^\(.*\)/trunk/.*$,\"^\1/trunk\" \"trunk/\1\",pg' $DIRS | sort -u >> $RENAMES


echo "Handle tags" >&2
perl -ne '
if (m{^(.+)/tags/([^/\n]+)}) {
    $left = $1;
    $tag  = $2;
    $left_us = $left;
    $left_us =~ s{/}{_}g;
    print qq("^$left/tags/$tag" "tags/${left_us}_${tag}/$left"\n);
}
' < $DIRS | sort -u >> $RENAMES


echo "Handle branches" >&2
perl -ne '
if (m{^(.+)/branches/([^/\n]+)}) {
    $left = $1;
    $tag  = $2;
    $left_us = $left;
    $left_us =~ s{/}{_}g;
    print qq("^$left/branches/$branch" "branches/${left_us}_${branch}/$left"\n);
}
' < $DIRS | sort -u >> $RENAMES


echo "Handle Remaining" >&2
grep -vE '/trunk|/tags|/branches|/\.svn' $DIRS | sed 's,^\(.*\)$,"^\1" "trunk/\1",' | sort -u >> $RENAMES


echo "Output a shell script with the repocutter commands" >&2
sed -e '1irepocutter pathrename \\' \
	-e 's,^\(.*\)$,\t\1 \\,g' \
	-e "\$a\\\\t < $DUMP | repocutter expunge \\\\" $RENAMES
sed -ne 's,^\(.*/trunk\)$,\t"^trunk/\1$" \\,pg' \
	-ne 's,^\(.*/tags\)$,\t"^trunk/\1$" \\,pg' \
	-ne 's,^\(.*/branches\)$,\t"^trunk/\1$" \\,pg' \
	-e "\$a\\\\t > new_$DUMP" $DIRS
# Why this is not equivalent to expunge "^trunk/.*/trunk$" "^trunk/.*/tags$" "^trunk/.*/branches$" ?

rm -f $DIRS $RENAMES
