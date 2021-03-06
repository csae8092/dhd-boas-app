xquery version "3.1";
module namespace app="http://www.digital-archiv.at/ns/dhd-boas-app/templates";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace pkg="http://expath.org/ns/pkg";
declare namespace repo="http://exist-db.org/xquery/repo";
declare namespace functx = 'http://www.functx.com';
import module namespace templates="http://exist-db.org/xquery/templates" ;
import module namespace config="http://www.digital-archiv.at/ns/dhd-boas-app/config" at "config.xqm";
import module namespace kwic = "http://exist-db.org/xquery/kwic" at "resource:org/exist/xquery/lib/kwic.xql";


declare variable $app:xslCollection := $config:app-root||'/resources/xslt';
declare variable $app:data := $config:app-root||'/data';
declare variable $app:meta := $config:app-root||'/data/meta';
declare variable $app:editions := $config:app-root||'/data/editions';
declare variable $app:indices := $config:app-root||'/data/indices';
declare variable $app:placeIndex := $config:app-root||'/data/indices/listplace.xml';
declare variable $app:personIndex := $config:app-root||'/data/indices/listperson.xml';
declare variable $app:orgIndex := $config:app-root||'/data/indices/listorg.xml';
declare variable $app:workIndex := $config:app-root||'/data/indices/listwork.xml';
declare variable $app:defaultXsl := doc($config:app-root||'/resources/xslt/xmlToHtml.xsl');
declare variable $app:projectName := doc(concat($config:app-root, "/expath-pkg.xml"))//pkg:title//text();
declare variable $app:authors := normalize-space(string-join(doc(concat($config:app-root, "/repo.xml"))//repo:author//text(), ', '));
declare variable $app:description := doc(concat($config:app-root, "/repo.xml"))//repo:description/text();


declare function functx:contains-case-insensitive
  ( $arg as xs:string? ,
    $substring as xs:string )  as xs:boolean? {

   contains(upper-case($arg), upper-case($substring))
 } ;

 declare function functx:escape-for-regex
  ( $arg as xs:string? )  as xs:string {

   replace($arg,
           '(\.|\[|\]|\\|\||\-|\^|\$|\?|\*|\+|\{|\}|\(|\))','\\$1')
 } ;

declare function functx:substring-after-last
  ( $arg as xs:string? ,
    $delim as xs:string )  as xs:string {
    replace ($arg,concat('^.*',$delim),'')
 };

 declare function functx:substring-before-last
  ( $arg as xs:string? ,
    $delim as xs:string )  as xs:string {

   if (matches($arg, functx:escape-for-regex($delim)))
   then replace($arg,
            concat('^(.*)', functx:escape-for-regex($delim),'.*'),
            '$1')
   else ''
 } ;

 declare function functx:capitalize-first
  ( $arg as xs:string? )  as xs:string? {

   concat(upper-case(substring($arg,1,1)),
             substring($arg,2))
 } ;
 
(:~
 : returns the names of the previous, current and next document  
:)

declare function app:next-doc($collection as xs:string, $current as xs:string) {
let $all := sort(xmldb:get-child-resources($collection))
let $currentIx := index-of($all, $current)
let $prev := if ($currentIx > 1) then $all[$currentIx - 1] else false()
let $next := if ($currentIx < count($all)) then $all[$currentIx + 1] else false()
return 
    ($prev, $current, $next)
};

declare function app:doc-context($collection as xs:string, $current as xs:string) {
let $all := sort(xmldb:get-child-resources($collection))
let $currentIx := index-of($all, $current)
let $prev := if ($currentIx > 1) then $all[$currentIx - 1] else false()
let $next := if ($currentIx < count($all)) then $all[$currentIx + 1] else false()
let $amount := count($all)
return 
    ($prev, $current, $next, $amount, $currentIx)
};


declare function app:fetchEntity($ref as xs:string){
    let $entity := collection($config:app-root||'/data/indices')//*[@xml:id=$ref]
    let $type: = if (contains(node-name($entity), 'place')) then 'place'
        else if  (contains(node-name($entity), 'person')) then 'person'
        else 'unkown'
    let $viewName := if($type eq 'place') then(string-join($entity/tei:placeName[1]//text(), ', '))
        else if ($type eq 'person' and exists($entity/tei:persName/tei:forename)) then string-join(($entity/tei:persName/tei:surname/text(), $entity/tei:persName/tei:forename/text()), ', ')
        else if ($type eq 'person') then $entity/tei:placeName/tei:surname/text()
        else 'no name'
    let $viewName := normalize-space($viewName)

    return
        ($viewName, $type, $entity)
};

declare function local:everything2string($entity as node()){
    let $texts := normalize-space(string-join($entity//text(), ' '))
    return
        $texts
};

declare function local:viewName($entity as node()){
    let $name := node-name($entity)
    return
        $name
};


(:~
: returns the name of the document of the node passed to this function.
:)
declare function app:getDocName($node as node()){
let $name := functx:substring-after-last(document-uri(root($node)), '/')
    return $name
};

(:~
: returns the (relativ) name of the collection the passed in node is located at.
:)
declare function app:getColName($node as node()){
let $root := tokenize(document-uri(root($node)), '/')
    let $dirIndex := count($root)-1
    return $root[$dirIndex]
};

(:~
: renders the name element of the passed in entity node as a link to entity's info-modal.
:)
declare function app:nameOfIndexEntry($node as node(), $model as map (*)){

    let $searchkey := xs:string(request:get-parameter("searchkey", "No search key provided"))
    let $withHash:= '#'||$searchkey
    let $entities := collection($app:editions)//tei:TEI//*[@ref=$withHash]
    let $terms := (collection($app:editions)//tei:TEI[.//tei:term[./text() eq substring-after($withHash, '#')]])
    let $noOfterms := count(($entities, $terms))
    let $hit := collection($app:indices)//*[@xml:id=$searchkey]
    let $name := if (contains(node-name($hit), 'person'))
        then
            <a class="reference" data-type="listperson.xml" data-key="{$searchkey}">{normalize-space(string-join($hit/tei:persName[1], ', '))}</a>
        else if (contains(node-name($hit), 'place'))
        then
            <a class="reference" data-type="listplace.xml" data-key="{$searchkey}">{normalize-space(string-join($hit/tei:placeName[1], ', '))}</a>
        else if (contains(node-name($hit), 'org'))
        then
            <a class="reference" data-type="listorg.xml" data-key="{$searchkey}">{normalize-space(string-join($hit/tei:orgName[1], ', '))}</a>
        else if (contains(node-name($hit), 'bibl'))
        then
            <a class="reference" data-type="listwork.xml" data-key="{$searchkey}">{normalize-space(string-join($hit/tei:title[1], ', '))}</a>
        else
            functx:capitalize-first($searchkey)
    return
    <h1 style="text-align:center;">
        <small>
            <span id="hitcount"/>{$noOfterms} Treffer für</small>
        <br/>
        <strong>
            {$name}
        </strong>
    </h1>
};

(:~
 : href to document.
 :)
declare function app:hrefToDoc($node as node()){
let $name := functx:substring-after-last($node, '/')
let $href := concat('show.html','?document=', app:getDocName($node))
    return $href
};

(:~
 : href to document.
 :)
declare function app:hrefToDoc($node as node(), $collection as xs:string){
let $name := functx:substring-after-last($node, '/')
let $href := concat('show.html','?document=', app:getDocName($node), '&amp;directory=', $collection)
    return $href
};

(:~
 : a fulltext-search function
 :)
 declare function app:ft_search($node as node(), $model as map (*)) {
 if (request:get-parameter("searchexpr", "") !="") then
 let $searchterm as xs:string:= request:get-parameter("searchexpr", "")
 for $hit in collection(concat($config:app-root, '/data/editions/'))//*[.//tei:p[ft:query(.,$searchterm)]]
    let $href := concat(app:hrefToDoc($hit), "&amp;searchexpr=", $searchterm)
    let $score as xs:float := ft:score($hit)
    order by $score descending
    return
    <tr>
        <td>{$score}</td>
        <td class="KWIC">{kwic:summarize($hit, <config width="40" link="{$href}" />)}</td>
        <td align="center"><a href="{app:hrefToDoc($hit)}">{app:getDocName($hit)}</a></td>
    </tr>
 else
    <div>Nothing to search for</div>
 };

declare function app:indexSearch_hits($node as node(), $model as map(*),  $searchkey as xs:string?, $path as xs:string?){
let $indexSerachKey := $searchkey
let $searchkey:= '#'||$searchkey
let $entities := collection($app:data)//tei:TEI[.//*/@ref=$searchkey]
let $terms := collection($app:editions)//tei:TEI[.//tei:term[./text() eq substring-after($searchkey, '#')]]
for $title in ($entities, $terms)
    let $docTitle := string-join(root($title)//tei:titleStmt/tei:title[@type='main']//text(), ' ')
    let $hits := if (count(root($title)//*[@ref=$searchkey]) = 0) then 1 else count(root($title)//*[@ref=$searchkey])
    let $collection := app:getColName($title)
    let $snippet :=
        for $entity in root($title)//*[@ref=$searchkey]
                let $before := $entity/preceding::text()[1]
                let $after := $entity/following::text()[1]
                return
                    <p>… {$before} <strong><a href="{concat(app:hrefToDoc($title, $collection), "&amp;searchkey=", $indexSerachKey)}"> {$entity//text()[not(ancestor::tei:abbr)]}</a></strong> {$after}…<br/></p>
    let $zitat := $title//tei:msIdentifier
    let $collection := app:getColName($title)
    return
            <tr>
               <td>{$docTitle}</td>
               <td>{$hits}</td>
               <td>{$snippet}<p style="text-align:right">{<a href="{concat(app:hrefToDoc($title, $collection), "&amp;searchkey=", $indexSerachKey)}">{app:getDocName($title)}</a>}</p></td>
            </tr>
};

(:~
 : creates a basic person-index derived from the  '/data/indices/listperson.xml'
 :)
declare function app:listPers($node as node(), $model as map(*)) {
    let $hitHtml := "hits.html?searchkey="
    for $person in doc($app:personIndex)//tei:listPerson/tei:person
        let $ref := '#'||data($person/@xml:id)
        let $gnd := $person/tei:idno/text()
        let $affiliation := for $x in $person//tei:affiliation
            return
                <li>{normalize-space($x/text())}</li>
        let $gnd_link := if ($gnd != "no gnd provided") then
            <a href="{$gnd}">{$gnd}</a>
            else
            "-"
        let $places := for $x in $person//tei:affiliation
            let $org_id := substring-after($x/@ref, '#')
            let $place := doc($app:orgIndex)//tei:org[@xml:id=$org_id]//tei:placeName/text()
                return
                    <li>
                        {$place}
                    </li>
        let $abstracts := for $x in collection($app:editions)//tei:TEI[.//tei:author[@ref=$ref]]
            return 
            <li>
                <a href="{app:hrefToDoc($x)}">
                    {normalize-space(string-join($x//tei:titleStmt/tei:title//text()))}
               </a>
            </li>
            return
            <tr>
                <td>
                    <a href="{concat($hitHtml,data($person/@xml:id))}">{$person/tei:persName/tei:surname}</a>
                </td>
                <td>
                    {$person/tei:persName/tei:forename}
                </td>
                <td>
                    {$abstracts}
                </td>
                <td>
                    {$affiliation}
                </td>
                <td>
                    {$places}
                </td>
                <td>
                    {$gnd_link}
                </td>
            </tr>
};

(:~
 : creates a basic place-index derived from the  '/data/indices/listplace.xml'
 :)
declare function app:listPlace($node as node(), $model as map(*)) {
    let $hitHtml := "hits.html?searchkey="
    for $org in doc($app:orgIndex)//tei:org[.//tei:placeName[@key]]
        let $place := $org//tei:location
        let $place_id := data($place//tei:placeName[@key]/@key)
        let $lat := tokenize($place//tei:geo/text(), ' ')[2]
        let $lng := tokenize($place//tei:geo/text(), ' ')[1]
            group by $place_id
            return
            <tr>
                <td>
                    {$place[1]/tei:placeName/text()}
                </td>
                <td>{
                    for $x in doc($app:orgIndex)//tei:org[.//tei:placeName[@key=$place_id[1]]]
                    return 
                        <li>{$x/tei:orgName[1]}</li>
                }</td>
                <td>{$place_id}</td>
                <td>{$lat[1]}</td>
                <td>{$lng[1]}</td>
            </tr>
};

(:~
 : returns header information about the current collection
 :)
declare function app:tocHeader($node as node(), $model as map(*)) {

    let $collection := request:get-parameter("collection", "")
    let $colName := if ($collection)
        then
            $collection
        else
            "editions"
    let $docs := count(collection(concat($config:app-root, '/data/', $colName, '/'))//tei:TEI)
    let $infoDoc := doc($app:meta||"/"||$colName||".xml")
    let $colLabel := $infoDoc//tei:title[1]/text()
    let $infoUrl := "show.html?document="||$colName||".xml&amp;directory=meta"
    let $apiUrl := "../../../../exist/restxq/dhd-boas-app/api/collections/"||$colName
    return
        <div class="card-header" style="text-align:center;">
            <h1>{$docs} Dokumente in {$colLabel}</h1>
            <h3>
                <a>
                    <i class="fas fa-info" title="Info zum Personenregister" data-toggle="modal" data-target="#exampleModal"/>
                </a>
                |
                <a href="{$apiUrl}">
                    <i class="fas fa-download" title="Liste der TEI Dokumente"/>
                </a>
            </h3>
        </div>
};

(:~
 : returns context information about the current collection displayd in a bootstrap modal
 :)
declare function app:tocModal($node as node(), $model as map(*)) {

    let $collection := request:get-parameter("collection", "")
    let $colName := if ($collection)
        then
            $collection
        else
            "editions"
    let $infoDoc := doc($app:meta||"/"||$colName||".xml")
    let $colLabel := $infoDoc//tei:title[1]/text()
   let $params :=
        <parameters>
            <param name="app-name" value="{$config:app-name}"/>
            <param name="collection-name" value="{$colName}"/>
            <param name="projectName" value="{$app:projectName}"/>
            <param name="authors" value="{$app:authors}"/>
           {
                for $p in request:get-parameter-names()
                    let $val := request:get-parameter($p,())
                        return
                           <param name="{$p}"  value="{$val}"/>
           }
        </parameters>
    let $xsl := doc($app:xslCollection||"/modals.xsl")
    let $modalBody := transform:transform($infoDoc, $xsl, $params)
    return
        <div class="modal" tabindex="-1" role="dialog" id="exampleModal">
        <div class="modal-dialog" role="document">
            <div class="modal-content">
                <div class="modal-header">
                    <h5 class="modal-title">{$colLabel}</h5>
                </div>
                <div class="modal-body">
                   {$modalBody}
                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-secondary" data-dismiss="modal">Schließen</button>
                </div>
            </div>
        </div>
    </div>
};

(:~
 : creates a basic table of contents derived from the documents stored in '/data/editions'
 :)
declare function app:toc($node as node(), $model as map(*)) {

    let $collection := request:get-parameter("collection", "")
    let $docs := if ($collection)
        then
            collection(concat($config:app-root, '/data/', $collection, '/'))//tei:TEI
        else
            collection(concat($config:app-root, '/data/editions/'))//tei:TEI
    for $title in $docs
        let $date := $title//tei:title//text()
        let $doctype := string-join($title//tei:keywords[@n='subcategory']//text(), '')
        let $keywords := for $x in $title//tei:keywords[@n='keywords']//tei:term/text() return <li>{$x}</li>
        let $topics := for $x in $title//tei:keywords[@n='topics']//tei:term/text() return <li>{$x}</li>
        let $authors := for $x in $title//tei:titleStmt//tei:author
            return
                <li>{string-join(($x//tei:forename, $x//tei:surname),' ')}</li>
        let $auth_count := count($title//tei:titleStmt//tei:author)
        let $link2doc := if ($collection)
            then
                <a href="{app:hrefToDoc($title, $collection)}">{$date}</a>
            else
                <a href="{app:hrefToDoc($title)}">{$date}</a>
        let $orgs := for $x in $title//tei:titleStmt//tei:author
            let $auth_id := substring-after(data($x/@ref), '#')
            let $orgs := doc($app:personIndex)//tei:person[@xml:id=$auth_id]//tei:affiliation[@ref]
            for $x in $orgs
                let $org_id := substring-after(data($x/@ref), '#')
                let $org := doc($app:orgIndex)//tei:org[@xml:id=$org_id]
                group by $org_id
                return $org[1]
        
        let $orgname := for $x in $orgs
            let $name := if ($x//tei:idno[1]/text()) 
                then
                    <a href="{$x//tei:idno[1]/text()}">{$x//tei:orgName[1]/text()}</a>
                else
                    $x//tei:placeName[1]/text()
            return <li>{$name}</li>

        let $org_count := count($orgs)
        
        let $locations := for $x in $orgs
            return $x//tei:location
        
        let $loc_count := count($locations)
        
        let $places := for $x in $locations
            let $placeName := if ($x//tei:placeName[1]/@key) then <a href="{$x//tei:placeName[1]/@key}">{$x//tei:placeName[1]/text()}</a> else $x//tei:placeName[1]/text()
            let $id := $placeName/@ref
                return <li>{$placeName}</li>
        
        let $coords := for $x in $locations
            return <li>{$x//tei:geo}</li>
        
        return
        <tr>
            <td>{$authors}</td>
            <td>{$auth_count}</td>
            <td>{$link2doc}</td>
            <td>{$doctype}</td>
            <td>{$keywords}</td>
            <td>{$topics}</td>
            <td>{$orgname}</td>
            <td>{$org_count}</td>
            <td>{$places}</td>
            <td>{$loc_count}</td>
            <td>{$coords}</td>
        </tr>
};

(:~
 : perfoms an XSLT transformation
:)
declare function app:XMLtoHTML ($node as node(), $model as map (*), $query as xs:string?) {
let $ref := xs:string(request:get-parameter("document", ""))
let $refname := substring-before($ref, '.xml')
let $xmlPath := concat(xs:string(request:get-parameter("directory", "editions")), '/')
let $xml := doc(replace(concat($config:app-root,'/data/', $xmlPath, $ref), '/exist/', '/db/'))
let $collectionName := util:collection-name($xml)
let $collection := functx:substring-after-last($collectionName, '/')
let $neighbors := app:doc-context($collectionName, $ref)
let $prev := if($neighbors[1]) then 'show.html?document='||$neighbors[1]||'&amp;directory='||$collection else ()
let $next := if($neighbors[3]) then 'show.html?document='||$neighbors[3]||'&amp;directory='||$collection else ()
let $amount := $neighbors[4]
let $currentIx := $neighbors[5]
let $progress := ($currentIx div $amount)*100
let $xslPath := xs:string(request:get-parameter("stylesheet", ""))
let $xsl := if($xslPath eq "")
    then
        if(doc($config:app-root||'/resources/xslt/'||$collection||'.xsl'))
            then
                doc($config:app-root||'/resources/xslt/'||$collection||'.xsl')
        else if(doc($config:app-root||'/resources/xslt/'||$refname||'.xsl'))
            then
                doc($config:app-root||'/resources/xslt/'||$refname||'.xsl')
        else
            $app:defaultXsl
    else
        if(doc($config:app-root||'/resources/xslt/'||$xslPath||'.xsl'))
            then
                doc($config:app-root||'/resources/xslt/'||$xslPath||'.xsl')
            else
                $app:defaultXsl
let $path2source := string-join(('../../../../exist/restxq', $config:app-name,'api/collections', $collection, $ref), '/')
let $params :=
<parameters>
    <param name="app-name" value="{$config:app-name}"/>
    <param name="collection-name" value="{$collection}"/>
    <param name="path2source" value="{$path2source}"/>
    <param name="prev" value="{$prev}"/>
    <param name="next" value="{$next}"/>
    <param name="amount" value="{$amount}"/>
    <param name="currentIx" value="{$currentIx}"/>
    <param name="progress" value="{$progress}"/>
    <param name="projectName" value="{$app:projectName}"/>
    <param name="authors" value="{$app:authors}"/>
    
   {
        for $p in request:get-parameter-names()
            let $val := request:get-parameter($p,())
                return
                   <param name="{$p}"  value="{$val}"/>
   }
</parameters>
return
    transform:transform($xml, $xsl, $params)
};

(:~
 : creates a basic work-index derived from the  '/data/indices/listbibl.xml'
 :)
declare function app:listBibl($node as node(), $model as map(*)) {
    let $hitHtml := "hits.html?searchkey="
    for $item in doc($app:workIndex)//tei:listBibl/tei:bibl
    let $author := normalize-space(string-join($item/tei:author//text(), ' '))
    let $gnd := $item//tei:idno/text()
    let $gnd_link := if ($gnd) 
        then
            <a href="{$gnd}">{$gnd}</a>
        else
            'no normdata provided'
   return
        <tr>
            <td>
                <a href="{concat($hitHtml,data($item/@xml:id))}">{$item//tei:title[1]/text()}</a>
            </td>
            <td>
                {$author}
            </td>
            <td>
                {$gnd_link}
            </td>
        </tr>
};

(:~
 : creates a basic organisation-index derived from the  '/data/indices/listorg.xml'
 :)
declare function app:listOrg($node as node(), $model as map(*)) {
    let $hitHtml := "hits.html?searchkey="
    for $item in doc($app:orgIndex)//tei:listOrg/tei:org
        let $xmlid := data($item/@xml:id)
        let $ref := '#'||$xmlid
        let $located := $item//tei:placeName/text()
        let $gnd := $item//tei:idno[@type='GND']/text()
        let $rel_persons := for $x in doc($app:personIndex)//tei:person[./tei:affiliation[@ref=$ref]]
            let $pers_id := data($x/@xml:id)
            let $first_name := $x//tei:forename
            let $last_name := $x//tei:surname
            return
                <li><a href="{concat($hitHtml, $pers_id)}">{$last_name}, {$first_name}</a></li>
        let $abstracts := for $x in doc($app:personIndex)//tei:person[./tei:affiliation[@ref=$ref]]
            let $pers_id := '#'||data($x/@xml:id)
            for $abstract in collection($app:editions)//tei:TEI[.//tei:author[@ref=$pers_id]]
                return 
                <li>
                    <a href="{app:hrefToDoc($abstract)}">
                        {normalize-space(string-join($abstract//tei:titleStmt/tei:title//text()))}
                   </a>
                </li> 
        let $gnd_link := if ($gnd) 
            then
                <a href="{$gnd}">{$gnd}</a>
            else
                'no normdata provided'
       return
            <tr>
                <td>
                    {$item//tei:orgName[1]/text()}
                </td>
                <td>
                    {$located}
                </td>
                <td>
                    {$rel_persons}
                </td>
                <td>
                    {$abstracts}
                </td>
                <td>
                    {$gnd_link}
                </td>
            </tr>
};

(:~
 : fetches the first document in the given collection
 :)
declare function app:firstDoc($node as node(), $model as map(*)) {
    let $all := sort(xmldb:get-child-resources($app:editions))
    let $href := "show.html?document="||$all[1]||"&amp;directory=editions"
        return
            <a class="btn btn-main btn-outline-primary btn-lg" href="{$href}" role="button">Start Reading</a>
};


