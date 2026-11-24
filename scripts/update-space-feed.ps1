param([switch]$Scheduled, [datetime]$Now = [datetime]::UtcNow)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Get-UpdateDays([datetime]$Date) {
    # A reproducible selection of 2-4 weekdays; no persisted counters or fake dates.
    $day = (([int]$Date.DayOfWeek + 6) % 7)
    $monday = $Date.Date.AddDays(-$day).ToString('yyyy-MM-dd')
    $hash = [System.Security.Cryptography.SHA256]::HashData(
        [Text.Encoding]::UTF8.GetBytes("space-radar:$monday"))
    $count = 2 + ($hash[0] % 3)
    @(0..6 | Sort-Object { $hash[1 + $_] } | Select-Object -First $count)
}

function Escape-Markdown([string]$Text) {
    $plain = [System.Net.WebUtility]::HtmlDecode($Text)
    $plain = ($plain -replace '<[^>]*>', '' -replace '\s+', ' ').Trim()
    $plain = $plain.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;')
    [regex]::Replace($plain, '[\\`*_{}\[\]()!|#]', { param($m) '\' + $m.Value })
}

function Get-Headlines([string]$Name, [string]$Url, [string]$Domain) {
    $response = Invoke-WebRequest -Uri $Url -TimeoutSec 30 -MaximumRetryCount 2 -RetryIntervalSec 3
    if ($response.Content.Length -gt 2000000) { throw "$Name feed is unexpectedly large" }
    $settings = [System.Xml.XmlReaderSettings]::new()
    $settings.DtdProcessing = [System.Xml.DtdProcessing]::Prohibit
    $settings.XmlResolver = $null
    $reader = [System.Xml.XmlReader]::Create([IO.StringReader]::new($response.Content), $settings)
    $xml = [xml]::new()
    try { $xml.Load($reader) } finally { $reader.Dispose() }
    $articles = @(foreach ($item in $xml.SelectNodes('/rss/channel/item')) {
        $titleNode = $item.SelectSingleNode('title')
        $linkNode = $item.SelectSingleNode('link')
        $dateNode = $item.SelectSingleNode('pubDate')
        if (!$titleNode -or !$linkNode -or !$dateNode) { continue }
        $uri = $null
        if (![uri]::TryCreate($linkNode.InnerText, [UriKind]::Absolute, [ref]$uri)) { continue }
        if ($uri.Scheme -ne 'https' -or !($uri.Host -eq $Domain -or $uri.Host.EndsWith(".$Domain"))) { continue }
        try {
            $date = [datetimeoffset]::Parse($dateNode.InnerText, [Globalization.CultureInfo]::InvariantCulture)
        } catch { continue }
        $title = Escape-Markdown $titleNode.InnerText
        if (!$title) { continue }
        [pscustomobject]@{ Source=$Name; Title=$title; Link=$uri.AbsoluteUri; Date=$date }
    })
    if ($articles.Count -eq 0) { throw "$Name returned no valid headlines; keeping the current README" }
    @($articles | Sort-Object Date -Descending | Select-Object -First 3)
}

function Update-Feed {
    if ($Scheduled) {
        $weekday = (([int]$Now.DayOfWeek + 6) % 7)
        if ($weekday -notin (Get-UpdateDays $Now)) {
            Write-Host 'No feed update scheduled today.'
            return
        }
    }
    # Fetch all sources before changing anything; a failed source leaves the README intact.
    $articles = @(
        Get-Headlines 'NASA' 'https://www.nasa.gov/feed/' 'nasa.gov'
        Get-Headlines 'ESA' 'https://www.esa.int/rssfeed/TopNews' 'esa.int'
    )
    $lines = @($articles | Sort-Object Date -Descending | ForEach-Object {
        $date = $_.Date.ToString('yyyy-MM-dd')
        $link = $_.Link.Replace('(', '%28').Replace(')', '%29').Replace('>', '%3E')
        "- [$($_.Title)](<$link>) — $($_.Source) · $date"
    })
    $path = Join-Path $PSScriptRoot '../README.md'
    $original = [IO.File]::ReadAllText($path).Replace("`r`n", "`n")
    $start = '<!-- SPACE-FEED:START -->'
    $end = '<!-- SPACE-FEED:END -->'
    if ([regex]::Matches($original, [regex]::Escape($start)).Count -ne 1 -or
        [regex]::Matches($original, [regex]::Escape($end)).Count -ne 1) {
        throw 'Expected exactly one pair of feed markers'
    }
    $from = $original.IndexOf($start) + $start.Length
    $to = $original.IndexOf($end)
    if ($to -lt $from) { throw 'Feed markers are out of order' }
    $updated = $original.Substring(0, $from) + "`n" + ($lines -join "`n") + "`n" + $original.Substring($to)
    if ($updated -ceq $original) {
        Write-Host 'No new headlines; no file change.'
        return
    }
    [IO.File]::WriteAllText($path, $updated, [Text.UTF8Encoding]::new($false))
    Write-Host "Updated $($lines.Count) linked headlines."
}

if ($MyInvocation.InvocationName -ne '.') { Update-Feed }
