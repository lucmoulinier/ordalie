proc UtiliseCCode {} {
    return 1
    
    if {0 && [catch {package require tcc} Msg]} {
	puts "failed package require"
	return 0
    } else {
	puts "package loaded"
	flush stdout
    }

#    package require tcc
    tcc::reset
    tcc::cproc csum {double a double b} double {return a+b;}
    set c [csum 4.2 5.01]
    if {$c != 9.21} {return 0}

    return 1
}


proc Init_C_Boot {} {
    return

    tcc::reset
    tcc::ccode {
	#include <stdio.h>
	#include <stdlib.h>
	#include <tcl.h>
	static double
	SeqMatch(char *seq1, char *seq2, int l)	{
	    int r, i;
	    
	    r = 0;
	    for (i=0;i<l;i++) {
		if (seq1[i] != '.' && seq1[i] == seq2[i]) r++;
	    }

	    return (double)r;
	}
    }
        
    tcc::ccommand Ccode_DoBootstrap {dummy interp objc objv} {
	char *pil0, *pil;
	char **tseq=NULL;
	int seed, ip, nseq, r, i, j, alen, nboot;
	int l,l1,l2, *tlg;
	Tcl_Obj *Mres;	
	double dist, rd;
	double **tres=NULL;
	
	int pobjc;
	Tcl_Obj **pobjv;
	
	if (Tcl_ListObjGetElements(interp,objv[1],&pobjc,&pobjv) != TCL_OK) {
	    return TCL_ERROR;
	}
	alen = pobjc;
	
	Tcl_GetIntFromObj(interp,objv[2],&seed);
	srand(seed);
	
	pil0 =Tcl_GetByteArrayFromObj(pobjv[1],&nseq);
	tseq =(char **)calloc(nseq+1,sizeof(char *));
	for (i=0; i<nseq; i++) { 
	    tseq[i] = (char *)calloc(alen+1, sizeof(char));
	}
	tseq[nseq] = NULL;

	tres = (double **)calloc(nseq+1,sizeof(double *));
	for (i=0; i<nseq; i++) { 
	    tres[i] = (double *)calloc(nseq+1, sizeof(double));
	}
	tres[nseq] = NULL;

	tlg = (int *)calloc(nseq+1, sizeof(int));

	for (i=0; i<alen; i++) {
	    rd = ((double)rand()/((double)(RAND_MAX)+(double)(1)));
	    ip = (int)(rd*(double)alen);
	    
	    pil=Tcl_GetByteArrayFromObj(pobjv[ip],&nseq);
	    for (j=0; j<nseq; j++) {
		tseq[j][i]=pil[j];
	    }
	}

	for (i=0; i<nseq; i++) {
	    l=0;
	    for (j=0;j<alen;j++) {
		if (tseq[i][j] != '.') l++;
	    }
	    tlg[i] = l;
	}

	for (i=0; i<nseq; i++) {
	    tres[i][i] = 0.0;
	    l1=tlg[i];
	    for (j=i+1; j<nseq; j++) {
		l2=tlg[j];
		dist = 1. - (SeqMatch(tseq[i],tseq[j],alen)/(double)(l1<l2?l1:l2));
		tres[i][j] = tres[j][i] = dist;
	    }
	}

	Mres = Tcl_NewListObj(0,NULL);
	for (i=0; i<nseq; i++) {
	    for (j=0; j<nseq; j++) {
		Tcl_ListObjAppendElement(interp,Mres,Tcl_NewDoubleObj(tres[i][j]));
	    }
	}
	
	Tcl_SetObjResult(interp,Mres);
	return TCL_OK;
    }

    return
}

proc Init_C_Pairwise {} {
    return

    tcc::reset
    tcc::ccode {
	#include <stdio.h>
	#include <stdlib.h>
	#include <tcl.h>
	static double
	SeqMatch(char *seq1, char *seq2, int l)	{
	    int r, i;
	    
	    r = 0;
	    for (i=0;i<l;i++) {
		if (seq1[i] != '.' && seq1[i] == seq2[i]) r++;
	    }

	    return (double)r;
	}
    }
        
    tcc::ccommand Ccode_Pairwise {dummy interp objc objv} {
	char *seq0, **tseq=NULL;
	int nseq, i, j, alen;
	int l,l1,l2;
	Tcl_Obj *Mres;
	Tcl_Obj **Lseq, *Tpci, *pair;
	double **tres, *tlg, dist;
	
	if (Tcl_ListObjGetElements(interp,objv[1],&nseq,&Lseq) != TCL_OK) {
	    return TCL_ERROR;
	}
	
	seq0 =Tcl_GetByteArrayFromObj(Lseq[1],&alen);
	printf("nseq %d alen %d\n",nseq,alen);
	fflush(stdout);
	tseq =(char **)calloc(nseq+1,sizeof(char *));
	for (i=0; i<nseq; i++) { 
	    tseq[i] = (char *)calloc(alen+1, sizeof(char));
	}
	tseq[nseq] = NULL;
	tres = (double **)calloc(nseq+1,sizeof(double *));
	for (i=0; i<nseq; i++) { 
	    tres[i] = (double *)calloc(nseq+1, sizeof(double));
	}
	tres[nseq] = NULL;
	tlg =(double *)calloc(nseq+1, sizeof(double));

	for (i=0;i<nseq;i++) {
	    tseq[i] = Tcl_GetByteArrayFromObj(Lseq[i],&alen);
	    l=0;
	    for (j=0;j<alen;j++) {
		if (tseq[i][j] != '.') l++;
	    }
	    tlg[i]=(double)l;
	}

	for (i=0; i<nseq; i++) {
	    for (j=i+1; j<nseq; j++) {
		dist = SeqMatch(tseq[i],tseq[j],alen);
		tres[i][j] = tres[j][i] = dist;
	    }
	}

	Tpci = Tcl_NewListObj(0,NULL);
	for (i=0; i<nseq; i++) {
	    l1=tlg[i];
	    tres[i][i]=l1;
	    for (j=0; j<nseq; j++) {
		l2=tlg[j];
		pair = Tcl_NewListObj(0,NULL);
		dist = tres[i][j]/(double)(l1<l2?l1:l2);
		Tcl_ListObjAppendElement(interp,pair,Tcl_NewDoubleObj(dist));
		Tcl_ListObjAppendElement(interp,pair,Tcl_NewIntObj(l1));
		Tcl_ListObjAppendElement(interp,pair,Tcl_NewIntObj(l2));
		Tcl_ListObjAppendElement(interp,pair,Tcl_NewDoubleObj((l1<l2?(double)(l1)/l2:(double)(l2)/l1)));
		Tcl_ListObjAppendElement(interp,Tpci,pair);
	    }
	}
	
	Tcl_SetObjResult(interp,Tpci);
	return TCL_OK;
    }

    return
}


proc C_DoBootstrap {Ln Lpil} {
    
    return [Ccode_DoBootstrap $Lpil [expr {int(rand()*280167)}]]
}

proc C_DoBootstrap2 {Ln Lpil Lrd} {
    
    return [Ccode_DoBootstrap $Lpil $Lrd]
}


proc Init_C_Random {} {
    tcc::reset
    tcc::ccode {
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <time.h>
#include <tcl.h>
    }
    tcc::ccommand Crand {dummy interp objc objv} {
	int i, seed, ip, alen;
	double rd;
	Tcl_Obj *Lrd;

	Tcl_GetIntFromObj(interp,objv[1],&alen);
	Tcl_GetIntFromObj(interp,objv[2],&seed);
	printf("seed %d\n",seed);
	fflush(stdout);
	srand(seed);

	Lrd = Tcl_NewListObj(0,NULL);
	for (i=0;i<alen;i++) {
	    rd = ((double)rand()/((double)(RAND_MAX)+(double)(1)));
	    ip = (int)(rd*(double)alen);
	    Tcl_ListObjAppendElement(interp,Lrd,Tcl_NewIntObj(ip));
	}
	
	Tcl_SetObjResult(interp,Lrd);
	return TCL_OK;
    }

    return
}

proc C_Random {alen} {
    return [Crand $alen [expr {int(rand()*280167)}]]
}

























