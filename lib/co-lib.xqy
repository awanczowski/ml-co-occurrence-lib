xquery version "1.0-ml";

(:~
: This module provides functions that help explore your range indexes. This will
: build an XML tree out with branch elements that have the co-occurring values.
:
: @author Andrew Wanczowski
: @version 0.1
:)

module namespace colib = "https://github.com/awanczowski/ml-co-occurrence-lib";

declare default collation "http://marklogic.com/collation/codepoint";

(:~
: This function colib:queries the database to build a tree of results
: Source -> Creator -> Subject
: @param $levels the configuration elements pointing to the range index.
: @param $query a query or queries to bind the search.
: @return a nested node of key and values.
:)
declare function  colib:build-tree(
 $levels as element(colib:levels),
 $query as cts:query*
) as element(colib:tree)*
{
  let $firstLevel as element(colib:level) := ($levels/colib:level)[1]

  let $qname as xs:QName :=
      fn:QName(
        $firstLevel/colib:namespace/text(),
        $firstLevel/colib:localName/text()
      )

  let $collation as xs:string? :=
      if($firstLevel/colib:collation/text())
      then fn:concat("collation=", $firstLevel/colib:collation/text())
      else ()

  return
    element { xs:QName("colib:tree") } {
      for $key in cts:element-values($qname, (), (), $query)
      let $newQuery := cts:element-range-query($qname, "=", $key, $collation)
      let $branches as element(colib:branch)* :=
          colib:build-branches(
            ($levels/colib:level)[2 to fn:last()],
            $firstLevel,
            ($query,$newQuery)
          )
      return
        element { xs:QName("colib:branch") } {
          attribute key { $firstLevel/colib:localName/text() },
          attribute value { $key },
          attribute freq { cts:frequency($key) },
          $branches
        }
    }
};


(:~
: This function queries the database to build a branch of results
: for example Source -> Creator -> Subject
: @param $levels a set of configuration elements.
: @param $previous the previous level that you were on
: @param $query a query or queries to bind the search.
: @return a nested node of key and values.
:)
declare private function colib:build-branches(
 $levels as element(colib:level)*,
 $previous as element(colib:level)*,
 $query as cts:query*
) as element(colib:branch)*
{

  let $prev as element(colib:level) :=
    if(fn:exists($previous))
    then $previous
    else $levels[1]

  let $prevQName as xs:QName :=
      fn:QName(
        $prev[1]/colib:namespace/text(),
        $prev[1]/colib:localName/text()
      )

  let $next as element(colib:level)? :=
    if(fn:exists($previous))
    then $levels[1]
    else $levels[2]

  let $nextQName as xs:QName :=
      fn:QName(
        $next[1]/colib:namespace/text(),
        $next[1]/colib:localName/text()
      )

  let $collation1 as xs:string? :=
      if($prev/colib:collation/text())
      then fn:concat("collation-1=", $prev/colib:collation/text())
      else ()

  let $collation2 as xs:string? :=
      if($next/colib:collation/text())
      then fn:concat("collation-2=", $next/colib:collation/text())
      else ()

  return
        if(fn:exists($previous)) then
          (: Do a co-occurence to see what nodes children are in the tree :)
          let $co :=
            cts:element-value-co-occurrences(
              $prevQName,
              $nextQName,
              ("map", $collation1, $collation2),
              cts:and-query($query)
            )

          for $key in map:keys($co)
          return
               (: Child Branches :)
               for $value in map:get($co,$key)
               let $collation :=
                   if($next/colib:collation/text())
                   then fn:concat("collation=", $next/colib:collation/text())
                   else ()

               let $newQuery := cts:element-range-query($nextQName,"=", $value, $collation)
               return
               element { xs:QName("colib:branch") } {
                 attribute key { $next/colib:localName/text()} ,
                 attribute value { $value },
                 attribute freq { cts:frequency($value) },
                 colib:build-branches($levels[2 to fn:last()], $prev, ($query,$newQuery))
               }
       else ()
};

(:~
: This will flatten the tree structure into result rows.
: @param $tree the tree to be flattened.
: @return an element that contains all the flatten branches.
:)
declare function colib:flatten-tree($tree as element(colib:tree)) as element(colib:results) {
  element { xs:QName("colib:results") } {
    for $element in $tree/colib:branch
    return colib:flatten-branch($element)
  }
};

(:~
: This will flatten a branch and all its children into result row.
: @param $branch the branch to be flattened.
: @return a result element that contains all the flatten branches.
:)
declare private function colib:flatten-branch($branch as element(colib:branch)) as element(colib:result)* {
    if($branch/colib:branch)
    then colib:flatten-branch($branch/colib:branch)
    else
      element{ xs:QName("colib:result") } {
        for $anc in $branch/ancestor-or-self::colib:branch
        return
          element { xs:QName($anc/@key) } {
             $anc/@freq,
             fn:string($anc/@value)
          }
      }
};
