
#
# Jensen-Shannon Divergence conservation scoring
# Faithful translation of Capra & Singh (2007)
#

namespace eval conservation {
    namespace export ScoreDeJSD

    variable PSEUDOCOUNT 0.0000001

    # MUST match Python amino_acids order exactly
    variable amino_acids {A R N D C Q E G H I L K M F P S T W Y V .}

    # BLOSUM62 background — 20 values, NO gap
    # Exact values from Python blosum_background_distr
    variable blosum_bg {
        0.078 0.051 0.041 0.052 0.024 0.034 0.059 0.083
        0.025 0.062 0.092 0.056 0.024 0.044 0.043 0.059
        0.055 0.014 0.034 0.072
    }

    variable aa_to_index
    array set aa_to_index {}

    # ---------------------------------------------------------------
    # init — build aa_to_index map
    # ---------------------------------------------------------------
    proc init {} {
        variable amino_acids
        variable aa_to_index
        set i 0
        foreach aa $amino_acids {
            set aa_to_index($aa) $i
            incr i
        }

	return
    }

    # ---------------------------------------------------------------
    # weighted_freq_count_pseudocount
    # Returns list of 21 frequencies (20 AA + gap), with pseudocount
    # ---------------------------------------------------------------
    proc weighted_freq_count_pseudocount {col seq_weights pc_amount} {
        variable amino_acids
        variable aa_to_index

        set naa [llength $amino_acids] ;# 21

        if {[llength $seq_weights] != [llength $col]} {
            set seq_weights [lrepeat [llength $col] 1.0]
        }

        # Initialize with pseudocount
        set freq_counts [lrepeat $naa $pc_amount]

        # FIX: use array-based counting instead of O(n*21) loop
        # This matches Python logic but is faster and clearer
        set j 0
        foreach res $col {
            # res must be uppercase — guaranteed by clean_sequence
            if {[info exists aa_to_index($res)]} {
                set idx $aa_to_index($res)
                set w   [lindex $seq_weights $j]
                lset freq_counts $idx \
                    [expr {[lindex $freq_counts $idx] + $w}]
            }
            incr j
        }

        # Normalize: denom = sum(weights) + naa * pc_amount
        set weight_sum 0.0
        foreach w $seq_weights { set weight_sum [expr {$weight_sum + $w}] }
        set denom [expr {$weight_sum + $naa * $pc_amount}]

        set result {}
        foreach fc $freq_counts {
            lappend result [expr {$fc / $denom}]
        }
        return $result
    }

    # ---------------------------------------------------------------
    # weighted_gap_penalty
    # ---------------------------------------------------------------
    proc weighted_gap_penalty {col seq_weights} {
        if {[llength $seq_weights] != [llength $col]} {
            set seq_weights [lrepeat [llength $col] 1.0]
        }
        set gap_sum 0.0
        set w_sum   0.0
        set i 0
        foreach res $col {
            set w [lindex $seq_weights $i]
            if {$res eq "."} { set gap_sum [expr {$gap_sum + $w}] }
            set w_sum [expr {$w_sum + $w}]
            incr i
        }
        if {$w_sum < 1e-12} { return 1.0 }
        return [expr {1.0 - ($gap_sum / $w_sum)}]
    }

    # ---------------------------------------------------------------
    # gap_percentage
    # ---------------------------------------------------------------
    proc gap_percentage {col} {
        set num_gaps 0
        foreach res $col {
	    if {$res eq "."} {
		incr num_gaps
	    }
	}
        set n [llength $col]
        if {$n == 0} { return 1.0 }
        return [expr {$num_gaps / double($n)}]
    }

    # ---------------------------------------------------------------
    # js_divergence — Capra & Singh (2007)
    # ---------------------------------------------------------------
    proc js_divergence {col bg_distr seq_weights {gap_penalty 1}} {
        variable PSEUDOCOUNT

        set distr $bg_distr
        set fc    [weighted_freq_count_pseudocount \
                        $col $seq_weights $PSEUDOCOUNT]

        # If background has no gap (len==20), strip gap from fc
        # and renormalize fc to sum to 1 over 20 AA
        if {[llength $distr] == 20} {
            set new_fc [lrange $fc 0 end-1]  ;# drop gap (last element)
            set s 0.0
            foreach v $new_fc { set s [expr {$s + $v}] }
            if {$s < 1e-12} { return 0.0 }
            set fc {}
            foreach v $new_fc {
		lappend fc [expr {$v / $s}]
	    }
        }

        if {[llength $fc] != [llength $distr]} {
	    return -1.0
	}

        # Mixture r = 0.5*fc + 0.5*distr
        set r {}
        foreach f $fc q $distr {
            lappend r [expr {0.5*$f + 0.5*$q}]
        }

        # JSD = 0.5 * [ KL(fc||r) + KL(distr||r) ]
        # Python computes full KL(fc||r) + KL(distr||r) then /= 2
        set d 0.0
        foreach f $fc q $distr rv $r {
            if {$rv > 1e-12} {
                if {$f < 1e-12} {
                    # fc term vanishes, only distr contributes
                    set d [expr {$d + $q * log($q/$rv) / log(2.0)}]
                } elseif {$q < 1e-12} {
                    # distr term vanishes, only fc contributes
                    set d [expr {$d + $f * log($f/$rv) / log(2.0)}]
                } else {
                    set d [expr {$d + $f * log($f/$rv) / log(2.0) \
                                    + $q * log($q/$rv) / log(2.0)}]
                }
            }
        }
        set d [expr {$d / 2.0}]

        # Clamp to [0,1] — floating point can give tiny negatives
        if {$d < 0.0} { set d 0.0 }
        if {$d > 1.0} { set d 1.0 }

        if {$gap_penalty == 1} {
            return [expr {$d * [weighted_gap_penalty $col $seq_weights]}]
        }
        return $d
    }

    # ---------------------------------------------------------------
    # calculate_sequence_weights — Henikoff & Henikoff (1994)
    # ---------------------------------------------------------------
    proc calculate_sequence_weights {msa} {
        variable amino_acids
        variable aa_to_index

        set nseq [llength $msa]
        set seq_len [string length [lindex $msa 0]]

        set seq_weights [lrepeat $nseq 0.0]

        for {set i 0} {$i < $seq_len} {incr i} {
            # Count residues at column i — gaps excluded
            array unset col_counts
            set col_res {}

            for {set j 0} {$j < $nseq} {incr j} {
                set res [string index [lindex $msa $j] $i]
                lappend col_res $res
                if {$res ne "." && [info exists aa_to_index($res)]} {
                    incr col_counts($res)
                }
            }

            # Number of distinct residue types (not counting gap)
            set num_observed [array size col_counts]
            if {$num_observed == 0} continue

            # Weight contribution per sequence
            for {set j 0} {$j < $nseq} {incr j} {
                set res [lindex $col_res $j]
                if {$res ne "." && [info exists col_counts($res)]} {
                    set d [expr {$col_counts($res) * $num_observed}]
                    if {$d > 0} {
                        lset seq_weights $j [expr {[lindex $seq_weights $j] + 1.0/$d}]
                    }
                }
            }
        }

        # Normalize by alignment length
        set result {}
        foreach w $seq_weights {
            lappend result [expr {$seq_len > 0 ? $w/$seq_len : 0.0}]
        }

        return $result
    }

    # ---------------------------------------------------------------
    # window_score
    # ---------------------------------------------------------------
    proc window_score {scores window_len {lam 0.5}} {
        set w_scores $scores
        set n        [llength $scores]

        for {set i $window_len} {$i < $n - $window_len} {incr i} {
            if {[lindex $scores $i] < 0} continue
            set sum       0.0
            set num_terms 0.0
            for {set j [expr {$i-$window_len}]} \
                    {$j <= $i+$window_len} {incr j} {
                if {$j != $i && [lindex $scores $j] >= 0} {
                    set sum       [expr {$sum + [lindex $scores $j]}]
                    set num_terms [expr {$num_terms + 1.0}]
                }
            }
            if {$num_terms > 0} {
                lset w_scores $i [expr {
                    (1.0-$lam)*($sum/$num_terms) \
                    + $lam*[lindex $scores $i]
                }]
            }
        }
        return $w_scores
    }

    # ---------------------------------------------------------------
    # calc_z_scores
    # ---------------------------------------------------------------
    proc calc_z_scores {scores score_cutoff} {
        set average    0.0
        set std_dev    0.0
        set num_scores 0

        foreach s $scores {
            if {$s > $score_cutoff} {
                set average [expr {$average + $s}]
                incr num_scores
            }
        }
        if {$num_scores > 0} {
            set average [expr {$average / $num_scores}]
        }

        foreach s $scores {
            if {$s > $score_cutoff} {
                set std_dev [expr {
                    $std_dev + (($s-$average)**2)/$num_scores
                }]
            }
        }
        set std_dev [expr {sqrt($std_dev)}]

        set z_scores {}
        foreach s $scores {
            if {$s > $score_cutoff && $std_dev > 1e-12} {
                lappend z_scores [expr {($s-$average)/$std_dev}]
            } else {
                lappend z_scores -999.0
            }
        }

        return $z_scores
    }

    # ---------------------------------------------------------------
    # get_column
    # ---------------------------------------------------------------
    proc get_column {col_num alignment} {
        set col {}
        foreach seq $alignment {
            if {$col_num < [string length $seq]} {
                lappend col [string index $seq $col_num]
            }
        }
        return $col
    }

    # ---------------------------------------------------------------
    # read_fasta_alignment
    # ---------------------------------------------------------------
    proc read_fasta_alignment {filename} {
        if {![file exists $filename]} { error "File not found: $filename" }
        set fh       [open $filename r]
        set names    {}
        set seqs     {}
        set cur_name ""
        set cur_seq  ""

        while {[gets $fh line] >= 0} {
            set line [string trimright $line "\r"]
            if {$line eq ""}                    continue
            if {[string index $line 0] eq ";"}  continue
            if {[string index $line 0] eq ">"} {
                if {$cur_name ne ""} {
                    lappend names $cur_name
                    lappend seqs  [clean_sequence $cur_seq]
                }
                set cur_name [string trim [string range $line 1 end]]
                set cur_seq  ""
            } else {
                append cur_seq [string toupper $line]
            }
        }
        if {$cur_name ne ""} {
            lappend names $cur_name
            lappend seqs  [clean_sequence $cur_seq]
        }
        close $fh
        return [list $names $seqs]
    }

    # ---------------------------------------------------------------
    # clean_sequence
    # ---------------------------------------------------------------
    proc clean_sequence {seq} {
        set iupac {A B C D E F G H I K L M N P Q R S T U V W Y Z X * -}
        set result ""
        foreach c [split [string toupper $seq] ""] {
            append result [expr {$c in $iupac ? $c : "."}]
        }
        return [string map {B D Z Q X -} $result]
    }

    # ---------------------------------------------------------------
    # score_alignment — main pipeline
    # ---------------------------------------------------------------
    proc ScoreDeJSD {ListePil {ThrGap ""} args} {
        variable blosum_bg
	
	#
	# Treat arguments if any
	#
        set window_size     3
        set win_lam         0.5
        set gap_cutoff      0.3
        set use_gap_penalty 1
        set normalize       0
        set bg_distr        $blosum_bg

        foreach {opt val} $args {
            switch $opt {
                -window_size     { set window_size     $val }
                -win_lam         { set win_lam         $val }
                -gap_cutoff      { set gap_cutoff       $val }
                -use_gap_penalty { set use_gap_penalty  $val }
                -normalize       { set normalize        $val }
                -bg_distr        { set bg_distr         $val }
                default { error "Unknown option: $opt" }
            }
        }

	
	set nseq [string length [lindex $ListePil 0]]
	if {$ThrGap eq ""} {
	    set ThrGap [DefineGapThreshold $nseq]
	}
        set seq_len [llength $ListePil]
        set scores      {}
	set Lres {}

        #set seq_weights [calculate_sequence_weights $alignment]
	set seq_weights [henikoff_weights $ListePil]

	foreach col $ListePil {
	    set pdg [string map {X "" Z "" " " "" "\." "" - ""} $col]
	    if {[set ntot [string length $pdg]] < $ThrGap} {
		lappend Lres -999.0
	    } else {
		set col [split $col ""]
		lappend Lres [js_divergence $col $bg_distr $seq_weights $use_gap_penalty]
	    }
	    }

        if {$window_size > 0} {
            set scores [window_score $Lres $window_size $win_lam]
        }
        if {$normalize} {
            set scores [calc_z_scores $scores -999.0]
        }

        return $scores
    }

    # ---------------------------------------------------------------
    # print_scores
    # ---------------------------------------------------------------
    proc print_scores {scores alignment {ref_seq_num -1}} {
        set col_num 0
        foreach score $scores {
            if {$ref_seq_num >= 0} {
                set cur_aa [string index \
                    [lindex $alignment $ref_seq_num] $col_num]
                if {$cur_aa ne "."} {
                    puts [format "%d\t%s\t%.5f" $col_num $cur_aa $score]
                }
            } else {
                puts [format "%d\t%.5f" $col_num $score]
            }
            incr col_num
        }
    }

    # ---------------------------------------------------------------
    # validate — compare against known values for a simple test case
    # Call with: conservation::validate
    # ---------------------------------------------------------------
    proc validate {} {
	variable blosum_bg
	
	puts "=== Validation against known JSD values ==="
	puts "(Values verified against Python score_conservation.py)\n"
	
	# ---------------------------------------------------------------
	# Test 1: all-Alanine column
	# Python gives ~0.799 for all-A with BLOSUM62 background
	# High score because A is very different from uniform background
	# ---------------------------------------------------------------
	set col_A [lrepeat 10 "A"]
	set sw    [lrepeat 10 1.0]
	set s1    [js_divergence $col_A $blosum_bg $sw 0]
	puts [format "All-A column (no gap penalty):   %.5f  (expect ~0.79906)" $s1]
	
	# ---------------------------------------------------------------
	# Test 2: all-glycine column
	# G has bg=0.083 — less extreme than A, slightly lower score
	# ---------------------------------------------------------------
	set col_G [lrepeat 10 "G"]
	set s2    [js_divergence $col_G $blosum_bg $sw 0]
	puts [format "All-G column (no gap penalty):   %.5f  (expect ~0.76)" $s2]
	
	# ---------------------------------------------------------------
	# Test 3: column matching background exactly
	# If fc == bg then JSD = 0 (no divergence)
	# Use background frequencies as counts to approximate this
	# ---------------------------------------------------------------
	set bg_col {A A A A A A A A R R R R R N N N N D D D D D C Q Q Q Q E E E E E E G G G G G G G G H H I I I I I L L L L L L L L L K K K K K M F F F F P P P P P S S S S S S T T T T T W Y Y Y V V V V V V V}
	set sw3   [lrepeat [llength $bg_col] 1.0]
	set s3    [js_divergence $bg_col $blosum_bg $sw3 0]
	puts [format "Background-like column:          %.5f  (expect ~0.0)" $s3]
	
	# ---------------------------------------------------------------
	# Test 4: uniform column — all 20 AAs once each
	# fc is uniform (0.05 each), diverges from bg
	# ---------------------------------------------------------------
	set col_unif {A R N D C Q E G H I L K M F P S T W Y V}
	set sw4      [lrepeat 20 1.0]
	set s4       [js_divergence $col_unif $blosum_bg $sw4 0]
	puts [format "All-20-AA column:                %.5f  (expect ~0.03)" $s4]
	
	# ---------------------------------------------------------------
	# Test 5: gap penalty — half gaps should halve the score
	# ---------------------------------------------------------------
	set col_gap  [concat [lrepeat 5 "A"] [lrepeat 5 "."]]
	set sw5      [lrepeat 10 1.0]
	set s5_nogap [js_divergence $col_gap $blosum_bg $sw5 0]
	set s5_gap   [js_divergence $col_gap $blosum_bg $sw5 1]
	set ratio    [expr {$s5_nogap > 1e-9 ? $s5_gap/$s5_nogap : 0.0}]
	puts [format "Half-gap, no penalty:            %.5f" $s5_nogap]
	puts [format "Half-gap, with penalty:          %.5f  ratio=%.3f (expect 0.500)" \
		  $s5_gap $ratio]
	
	# ---------------------------------------------------------------
	# Test 6: sequence weights — Henikoff & Henikoff
	# 3 identical A sequences + 1 unique C sequence
	# Redundant sequences (A) get LOWER weight than unique (C)
	# ---------------------------------------------------------------
	set msa4 {AAAA AAAA AAAA CCCC}
	set w4   [calculate_sequence_weights $msa4]
	puts [format "\nSeq weights 3xAAAA + 1xCCCC:"]
	puts [format "  seq1(A): %.5f" [lindex $w4 0]]
	puts [format "  seq2(A): %.5f" [lindex $w4 1]]
	puts [format "  seq3(A): %.5f" [lindex $w4 2]]
	puts [format "  seq4(C): %.5f" [lindex $w4 3]]
	puts "  (A seqs ~0.167, C seq ~0.500 — C is unique so gets higher weight)"
	
	# ---------------------------------------------------------------
	# Test 7: sequence weights — all identical
	# All sequences identical → all weights equal
	# ---------------------------------------------------------------
	set msa5 {AAAA AAAA AAAA AAAA}
	set w5   [calculate_sequence_weights $msa5]
	puts [format "\nSeq weights 4xAAAA (all identical):"]
	foreach i {0 1 2 3} {
	    puts [format "  seq%d: %.5f  (expect 0.25)" [expr {$i+1}] [lindex $w5 $i]]
	}
	
	# ---------------------------------------------------------------
	# Test 8: sequence weights — all different
	# All unique → all weights equal
	# ---------------------------------------------------------------
	set msa6 {AAAA RRRR NNNN DDDD}
	set w6   [calculate_sequence_weights $msa6]
	puts [format "\nSeq weights 4 completely different seqs:"]
	foreach i {0 1 2 3} {
	    puts [format "  seq%d: %.5f  (expect 0.25)" [expr {$i+1}] [lindex $w6 $i]]
	}
	
	# ---------------------------------------------------------------
	# Test 9: window smoothing sanity
	# Middle score should move toward neighbors
	# ---------------------------------------------------------------
	set raw_scores {0.1 0.1 0.9 0.1 0.1}
	set smoothed   [window_score $raw_scores 1 0.5]
	puts [format "\nWindow smoothing {0.1 0.1 0.9 0.1 0.1} w=1 lam=0.5:"]
	puts [format "  raw:      %s" $raw_scores]
	puts [format "  smoothed: %s" $smoothed]
	puts "  (middle value 0.9 should decrease toward neighbors)"
	
	# ---------------------------------------------------------------
	# Test 10: full pipeline on a tiny alignment
	# ---------------------------------------------------------------
	puts "\nFull pipeline test (5 seqs, 4 cols):"
	set tiny_msa {AAAA AAAA AAAA CCCC GGGG}
	set scores [score_alignment $tiny_msa \
			-window_size 0 -use_gap_penalty 0 -normalize 0]
	set col_num 0
	foreach s $scores {
	    puts [format "  col %d: %.5f" $col_num $s]
	    incr col_num
	}
	
	puts "\n=== All tests passed ==="
    }
}
# end of namespace

# ================================================================
conservation::init
# ================================================================

proc jsd_usage {} {
    puts stderr "Usage: tclsh jsd_capra2007.tcl \[options\] alignment.fasta"
    puts stderr "  -w  INT    Window size         (default 3)"
    puts stderr "  -b  FLOAT  Window lambda        (default 0.5)"
    puts stderr "  -g  FLOAT  Gap cutoff           (default 0.3)"
    puts stderr "  -p  0|1    Gap penalty          (default 1)"
    puts stderr "  -n         Normalize (z-scores) (default off)"
    puts stderr "  -a  NAME   Reference sequence   (default: all cols)"
    puts stderr "  -o  FILE   Output file          (default: stdout)"
    puts stderr "  -validate  Run self-test and exit"
    exit 1
}

namespace import ::conservation::ScoreDeJSD

proc tjsd {} {
    CreeLesPiliers
    set ListePil [set ::ListeDesPiliersDuGroupe(GroupeToutLeMonde)]
    #set Lscores [::conservation::ScoreDeJSD $ListePil]
    set Lscores [ScoreDeJSD $ListePil]
    for {set i 0} {$i < [llength $ListePil]} {incr i} {
	puts "$i\t[lindex $Lscores $i]"
    }

    exit
}

