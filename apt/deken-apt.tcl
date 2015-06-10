# META NAME PdExternalsSearch
# META DESCRIPTION apt backend
# META AUTHOR IOhannes m zmölnig <zmoelnig@iem.at>
# ex: set setl sw=2 sts=2 et

# search:  $ apt-cache madison "pd-${name}"
# install: $ gksudo apt-get -y install "${pkgname}"
##   returns:
##        1: wrong password (or other sudo problem)
##      100: could not get apt-lock (is another process running)
##      100: unknown package

# The minimum version of TCL that allows the plugin to run
package require Tcl 8.4

namespace eval ::deken::apt {
    namespace export search
    namespace export install
    variable distribution
}

if { [ catch { exec lsb_release -si } ::deken::apt::distribution options ] } { unset ::deken::apt::distribution }

# only add this backend, if we are actually running Debian or a derivative
if { [ info exists ::deken::apt::distribution ] } {


proc sorted_keys {hashmap} {
    set x [list]
    foreach {k v} [array get hashmap] {
	lappend x [list $k $v]
    }
    lsort -integer -index 1 $x
}

proc ::deken::apt::search {name} {
    #    set status 0
    #    if {[catch {exec grep foo bar.txt} results options]} {
    #	set details [dict get $options -errorcode]
    #	if {[lindex $details 0] eq "CHILDSTATUS"} {
    #	    set status [lindex $details 2]
    #	} else {
    #	    # Some other error; regenerate it to let caller handle
    #	    return -options $options -level 0 $results
    #	}
    #}
    set name [ string tolower $name ]
    if { "$name" eq "gem" } {
	set pkgname $name
    } else {
	set pkgname pd-$name
    }
    #puts "searching for $pkgname"
    array unset pkgs
    array set pkgs {}
    set io [ open "|apt-cache madison $pkgname" r ]
    while { [ gets $io line ] >= 0 } {
	set llin [ split "$line" "|" ]
	set name_ [ string trim [ lindex $llin 0 ] ]

	if { $pkgname ne $name_ } { continue }
	set ver_  [ string trim [ lindex $llin 1 ] ]
	set info_ [ string trim [ lindex $llin 2 ] ]
	if { "Packages" eq [ lindex $info_ end ] } {
	    set suite [ lindex $info_ 1 ]
	    set arch  [ lindex $info_ 2 ]
	    if { ! [ info exists pkgs($ver_) ] } {
		set pkgs($ver_) [ list $suite $arch ]
	    }
	}
    }
    set result []
    foreach {v inf} [ array get pkgs ] {
	# append 'ID' 'file' 'origin'
	set suite [ lindex $inf 0 ]
	set arch  [ lindex $inf 1 ]
	set id $pkgname/$v
	set f ${pkgname}_${v}_${arch}.deb
	set origin "Provided by ${::deken::apt::distribution} (${suite})"
	lappend result "{$id} {$f} {$origin}"
    }
    return $result
}

proc ::deken::apt::install {pkg} {
    # install: $ gksudo apt-get -y install "${pkgname}"
    # gksudo --  apt-get install -y --show-progress ${pkgname}/${ver}
    set prog "apt-get install -y --show-progress ${pkg}"
    # for whatever reasons, we cannot have 'deken' as the description
    # (it will always show $prog instead)
    set desc deken-apt
    set io [ open "|gksudo -D $desc -- $prog" ]
    while { [ gets $io line ] >= 0 } {
	puts "line: $line"
    }
    #if { [ catch {
    #  puts "installing $pkg"
    #  #exec gksudo -D "deken" -- $prog
    #  exec gksudo -D "deken" ls
    #} io options ] } {  }
    #puts "IO $io"
    #puts "options $options"
}


proc ::deken::apt::test {pkg} {
    set res [::deken::apt::search $pkg]
    foreach r $res {
        set id  [ lindex $r 0 ]
        set f   [ lindex $r 1 ]
        set inf [ lindex $r 2 ]
        puts "$id :: $f"
        puts "         $inf"
    }
}
::deken::apt::test iemnet
::deken::apt::test zexy
::deken::apt::test gem
::deken::apt::install pd-zexy
}
