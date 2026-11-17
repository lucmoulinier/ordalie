#rR ordali_source

if {! [info exists OrdaliDir]} {
    set OrdaliDir $env(ORDALIDIR)
}
if {! [info exists OrdaliDejaSource] || ! $OrdaliDejaSource} {
    set OrdaliDejaSource 1
    set OrdSrcDir [file join $OrdaliDir src]
    
    set ListOfOrdaliFiles [list \
		    ordali_StrucObj.tcl \
		    ordali_admin.tcl \
		    ordali_affiche.tcl \
		    ordali_aligne.tcl \
		ordali_annotation.tcl \
		    ordali_barcode.tcl \
		    ordali_calculs.tcl \
		    ordali_ccode.tcl \
		    ordali_cluster.tcl \
		    ordali_conservation.tcl \
		    ordali_crc.tcl \
		    ordali_data.tcl \
		    ordali_db.tcl \
		    ordali_doc.tcl \
		    ordali_features.tcl \
		    ordali_graphic3d.tcl \
		    ordali_groupsim.tcl \
		    ordali_html.tcl \
		    ordali_jsd.tcl \
		    ordali_kabsch.tcl \
		    ordali_math.tcl \
		    ordali_mode.tcl \
		    ordali_ordali.tcl \
		    ordali_ordfile.tcl \
		    ordali_overview.tcl \
		    ordali_outils.tcl \
		    ordali_pdb.tcl \
		    ordali_preferences.tcl \
		    ordali_print.tcl \
		    ordali_residu.tcl \
		    ordali_sdp.tcl \
		    ordali_selection.tcl \
		    ordali_seqlab.tcl \
		    ordali_sequence.tcl \
		    ordali_services.tcl \
		    ordali_setup.tcl \
		    ordali_spinoff.tcl \
		    ordali_superposition.tcl \
		    ordali_surface.tcl \
		    ordali_talk.tcl \
		    ordali_tlog.tcl \
		    ordali_tooltip.tcl \
		    ordali_trackball.tcl \
		    ordali_tree.tcl \
		    ordali_viandox.tcl \
		    ordali_visu3d.tcl \
		    ordali_vrp.tcl \
		    ordali_web.tcl \
		    ordali_xml.tcl]

    foreach f $ListOfOrdaliFiles {
	if {[string index $f 0] ne "#"} {
	    source [file join $OrdSrcDir $f]
	}
	}
}







