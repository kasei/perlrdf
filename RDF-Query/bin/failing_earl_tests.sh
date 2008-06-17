#!/bin/sh

roqet -q -e 'PREFIX earl: <http://www.w3.org/ns/earl#> SELECT ?test FROM <earl-syntax.ttl> WHERE { [ earl:test ?test ; earl:result [ earl:outcome earl:fail ] ] }' | cut -d '<' -f 2 | cut -d '>' -f 1
roqet -q -e 'PREFIX earl: <http://www.w3.org/ns/earl#> SELECT ?test FROM <earl-eval.ttl> WHERE { [ earl:test ?test ; earl:result [ earl:outcome earl:fail ] ] }' | cut -d '<' -f 2 | cut -d '>' -f 1
