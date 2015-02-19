xquery version "1.0-ml";

import module namespace colib = "https://github.com/awanczowski/ml-co-occurrence-lib" at "/lib/co-lib.xqy";

let $levels :=
    <levels xmlns="https://github.com/awanczowski/ml-co-occurrence-lib">
        <level>
            <namespace>http://purl.org/dc/elements/1.1/</namespace>
            <localName>source</localName>
        </level>
        <level>
            <namespace>http://purl.org/dc/elements/1.1/</namespace>
            <localName>creator</localName>
        </level>
        <level>
            <namespace>http://purl.org/dc/elements/1.1/</namespace>
            <localName>subject</localName>
        </level>
    </levels>
 
let $tree := colib:build-tree($levels, ())
let $flat := colib:flatten-tree($tree)

return
  ($flat, $tree)
