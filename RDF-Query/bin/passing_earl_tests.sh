#!/bin/sh

roqet -q -s earl-syntax.ttl -e 'PREFIX earl: <http://www.w3.org/ns/earl#> SELECT ?test WHERE { [ earl:test ?test ; earl:result [ earl:outcome earl:pass ] ] }' | cut -d '<' -f 2 | cut -d '>' -f 1
roqet -q -s earl-eval.ttl -e 'PREFIX earl: <http://www.w3.org/ns/earl#> SELECT ?test WHERE { [ earl:test ?test ; earl:result [ earl:outcome earl:pass ] ] }' | cut -d '<' -f 2 | cut -d '>' -f 1
