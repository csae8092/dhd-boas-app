xquery version "3.1";
import module namespace config="http://www.digital-archiv.at/ns/dhd-boas-app/config" at "../modules/config.xqm";
import module namespace app="http://www.digital-archiv.at/ns/dhd-boas-app/templates" at "../modules/app.xql";
declare namespace tei = "http://www.tei-c.org/ns/1.0";
declare option exist:serialize "method=json media-type=text/javascript";

(:transforms a CMFI document into a JSON which can be processed by visjs into a network graph:)

let $result := 
    <result>
    {
        
        for $doc at $pos in collection($app:editions)//tei:TEI
            let $title := $doc//tei:titleStmt/tei:title//text()
            return
                <nodes>
                    <id>{$pos}</id>
                    <title>{$title}</title>
                    <color>red</color>
                </nodes>
    }
    {
        
        for $doc in collection($app:editions)//tei:TEI
            for $person in $doc//tei:titleStmt//tei:author
                let $key := data($person/@ref)
                group by $key
                    return
                        <nodes>
                            <id>{$key}</id>
                            <title>{$person[1]//text()}</title>
                            <color>#00b159</color>
                        </nodes>
    }
    {
         for $org in doc($app:orgIndex)//tei:org[@xml:id]
            let $key := data($org/@xml:id)
            return
                <nodes>
                    <id>{$key}</id>
                    <title>{$org/tei:orgName/text()}</title>
                    <color>#00aedb</color>
                </nodes>
    }
    {
         for $place in doc($app:orgIndex)//tei:org[@xml:id]//tei:placeName
            let $key := data($place/@key)
            group by $key
            return
                <nodes>
                    <id>{$key}</id>
                    <title>{$place[1]/text()[1]}</title>
                    <color>#f37735</color>
                </nodes>
    }
    {
        for $doc at $pos in collection($app:editions)//tei:TEI
            for $person in $doc//tei:titleStmt//tei:author
            let $key := data($person/@ref)
                return
                    <edges>
                        <from>{$pos}</from>
                        <to>{$key}</to>
                    </edges>
    }
    {
        for $doc in collection($app:editions)//tei:TEI
            for $person in $doc//tei:titleStmt//tei:author
            let $key := data($person/@ref)
            let $ref := substring-after($key, '#')
            for $x in doc($app:personIndex)//tei:person[@xml:id=$ref]/tei:affiliation/@ref
                return
                    <edges>
                        <from>{$key}</from>
                        <to>{substring-after($x, '#')}</to>
                    </edges>
    }
    {
         for $org in doc($app:orgIndex)//tei:org[.//tei:placeName]
            let $place := $org//tei:placeName
            let $from := data($org/@xml:id)
            let $to := data($place/@key)
            return
                <edges>
                    <from>{$from}</from>
                    <to>{$to}</to>
                </edges>
    }
     
    </result>
return
    $result
