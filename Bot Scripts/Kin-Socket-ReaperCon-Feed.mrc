; Kin's GitHub Feed for ReaperCon
; https://github.com/Th3GrimRipp3r/ReaperCon/commits/master.atom

; 2013-03-12 v1.1 Added channel trigger and polling timer
; 2013-03-12 v1.0

; --------- Events

on *:CONNECT:{ if ($network == GeekShed) { ReaperConFeed.Enable } }
on *:DISCONNECT:{ if ($network == GeekShed) { ReaperConFeed.Disable } }
on *:TEXT:!ReaperCon:#ReaperCon:{
  if ($nick !isop $chan) && ($nick !ishop $chan) { return }
  unset %ReaperConFeed.Last
  ReaperConFeed.Get !msg $chan
}
alias ReaperConFeed.Enable { .timerReaperConFeed.Check 0 120 ReaperConFeed.Check }
alias ReaperConFeed.Disable { .timerReaperConFeed.Check 0 120 ReaperConFeed.Check }
alias ReaperConFeed.Check { if ($me ison #ReaperCon) { ReaperConFeed.Get !msg #ReaperCon } }

; -------- Socket

alias ReaperConFeed.Get {
  ReaperConFeed.Timeout 

  var %callback $1-
  if (!%callback) || (!$istok(say msg echo notice describe,$replace($1,!,),32)) { %callback = !echo -ta }

  if $hget(ReaperConFeed) { hfree ReaperConFeed }
  hadd -m ReaperConFeed Host github.com
  hadd ReaperConFeed Path /Th3GrimRipp3r/ReaperCon/commits/master.atom
  hadd ReaperConFeed Callback %callback
  hadd ReaperConFeed File $qt($mIRCdir $+ ReaperConFeed. $+ $ctime $+ .dat)

  .timerReaperConFeed 1 12 ReaperConFeed.Timeout 
  sockopen -e ReaperConFeed github.com 443
}

alias -l ReaperConFeed.Timeout {
  if ($sock(ReaperConFeed)) .sockclose ReaperConFeed
  if $hget(ReaperConFeed) { 
    var %file $hget(ReaperConFeed,File)
    if ($exists(%file)) { .remove %file }
  }
  if $hget(ReaperConFeed) { hfree ReaperConFeed }
  .timerReaperConFeed off
}

on *:SOCKOPEN:ReaperConFeed: {
  var %host $hget(ReaperConFeed,Host), %path $hget(ReaperConFeed,Path)

  sockwrite -nt $sockname GET %path HTTP/1.0
  sockwrite -nt $sockname HOST: %host
  sockwrite -nt $sockname $crlf
}
on *:SOCKREAD:ReaperConFeed: {
  var %callback $hget(ReaperConFeed,Callback)
  var %file $hget(ReaperConFeed,File)

  if ($sockerr) { %callback 04Socket Error in SOCKREAD - $sock($sockname).wserr -  $sock($sockname).wsmsg | .sockclose $sockname | halt }
  ; .timerReaperConFeed off

  while ($sock($sockname).rq) {
    ; sockread -fn $sock($sockname).rq &br
    sockread -f $sock($sockname).rq &br
    bwrite %file -1 -1 &br
  }
  bunset &br
}
on *:SOCKCLOSE:ReaperConFeed: { ReaperConFeed.Close }

alias -l ReaperConFeed.Close {
  var %callback $hget(ReaperConFeed,Callback)

  var %id 1
  if ($ReaperConFeed.Parse(%callback,$hget(ReaperConFeed,File),%id) == $true) {
    var %out $ReaperConTag

    %out = %out $Colorize(05,$Hash.GetData(%id,Name))
    %out = %out -> $Colorize(07,$left($Hash.GetData(%id,Title),208)) <-
    %out = %out $iif($Hash.GetData(%id,Updated),$+($chr(91),$v1,$chr(93)))
    %out = %out $iif($Hash.GetData(%id,Link),$left($v1,120))

    set %ReaperConFeed.Last %out
    if (%callback) { %callback %out }
  }

  ReaperConFeed.Timeout 
}

alias ReaperConFeed.Parse {
  var %callback $1, %file $2, %id $gettok($3,1,32), %bfound $null

  ; var %data $Kin.Parser.Find(%file,<entry>,</entry>)
  var %data $Kin.Parser.Find(%file,<entry>,<content)

  if ($regex(%data,/<link [^>]*? href="([^"]+)/)) { noop $Hash.SetData(%id,Link,$regml(1)) }
  if ($regex(%data,/<title>([^<]*)<\/title>/)) { noop $Hash.SetData(%id,Title,$regml(1)) }
  if ($regex(%data,/<updated>([^<]*)<\/updated>/)) { noop $Hash.SetData(%id,Updated,$regml(1)) }
  if ($regex(%data,/<name>([^<]*)<\/name>/)) { noop $Hash.SetData(%id,Name,$regml(1)) | %bfound = $true }
  ; if ($regex(%data,/<content>([^<]*)/m)) { noop $Hash.SetData(%id,Content,$regml(1)) }

  return %bfound
}

;-------- 

alias Colorize { return $iif($regex(color,$1,/^(0?\d|1[01-5])$/),$+($chr(03),$1,$$2-,$chr(03),$chr(15)),$1-) }
alias ReaperConTag { return $+($chr(40),$Colorize(06,ReaperCon),$chr(41)) }

alias -l Hash.GetData { return $hget(ReaperConFeed,$+(Entry.,$1,.,$$2)) }
alias -l Hash.SetData { hadd ReaperConFeed $+(Entry.,$1,.,$$2) $3- }

;-------- Helper Aliases

; 2012-12-01 v1.0 Kin's Binary Data File Parser Find Alias
alias -l Kin.Parser.Find {
  var %replaceascii 0 9 10 13

  var %file $1
  var %starttext $2
  var %stoptext $3
  if (!$exists(%file)) { return $null }
  bread %file 0 $file(%file).size &br

  var %start $bfind(&br,0,%starttext)
  if (%start == $null) || (%start <= 0) { return $null }

  var %stop $bfind(&br,%start,%stoptext)
  inc %stop $len(%stoptext)
  if (%stop == $null) || (%stop <= 0) { return $null }

  var %each $numtok(%replaceascii,32)
  while (%each) {
    var %char $gettok(%replaceascii,%each,32)
    var %ix $bfind(&br,%start,%char)
    while (%ix <= %stop) && (%ix > 0) {
      bset &br %ix 32
      var %ix $bfind(&br,%start,%char)
    }
    dec %each
  }

  var %output $bvar(&br,%start,$calc(%stop - %start)).text

  bunset &br
  return %output
}