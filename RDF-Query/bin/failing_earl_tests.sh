#!/bin/tcsh

foreach i (earl*.ttl)
if (-e $i) then
roqet -q -e "PREFIX earl: <http://www.w3.org/ns/earl#> SELECT ?test FROM <${i}> WHERE { [ earl:test ?test ; earl:result [ earl:outcome earl:failed ] ] } ORDER BY ?test" | cut -d '<' -f 2 | cut -d '>' -f 1
endif
end
