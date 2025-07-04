/************************************************************************
Identify patients transfused within 4 hours based on ICD procedure codes

output:	transfused_patients_2021.sas7bdat with transfused flags

references to local drives have been removed
************************************************************************/

libname lib2020 "\Year2020SAS";
libname lib2021 "\Year2021SAS";

ods rtf style=statistical startpage=yes notoc_data
file = '\transfusion_codes_2021.rtf';

* keep inc_key patients with procedure code when procedure < 4 hours;

data ICDprocedure00;
	set lib2021.puf_ICDprocedure ;
	* set lib2021.puf_ICDprocedure (obs=100000) ;
	where hospitalprocedurestarthrs < 4;
	drop ICDProcedureVersion HospitalProcedureStartDH_BIU
		hospitalprocedurestarthrs hospitalprocedurestartdays;
run;

* first obtain transfusion codes;

data ICDprocedure01;
	set ICDprocedure00;
	drop inc_key;
run;

proc sort data=ICDprocedure01 nodupkey;
	by icdprocedurecode;
run;

proc sort data=lib2021.puf_ICDprocedure_lookup out=icd_lookup;
	by icdprocedurecode;
run;

data ICDprocedure02;
	merge ICDprocedure01 icd_lookup;
	by icdprocedurecode;
run;

* does not include plasma cryoprecipitate;

data ICDprocedure03;
	set ICDprocedure02;
	where ((substr(icdprocedurecode_desc, 1, 28)="Transfusion of Nonautologous") or
		(substr(icdprocedurecode_desc, 1, 25)="Transfusion of Autologous"))
		and
		((substr(icdprocedurecode_desc, 27, 12)="Fresh Plasma") or
		(substr(icdprocedurecode_desc, 30, 12)="Fresh Plasma") or
		(substr(icdprocedurecode_desc, 27, 13)="Frozen Plasma") or
		(substr(icdprocedurecode_desc, 30, 13)="Frozen Plasma") or
		(substr(icdprocedurecode_desc, 27, 10)="Frozen Red") or
		(substr(icdprocedurecode_desc, 30, 10)="Frozen Red") or
		(substr(icdprocedurecode_desc, 27, 9)="Platelets") or
		(substr(icdprocedurecode_desc, 30, 9)="Platelets") or
		(substr(icdprocedurecode_desc, 27, 9)="Red Blood") or
		(substr(icdprocedurecode_desc, 30, 9)="Red Blood") or
		(substr(icdprocedurecode_desc, 27, 11)="Whole Blood") or
		(substr(icdprocedurecode_desc, 30, 11)="Whole Blood")) ;
run;

* procedure codes for transfusions, reviewed by clinical team;

data transfusions;
	set ICDprocedure03;
	where(
	(substr(icdprocedurecode_desc, 48, 8) NE "Products") and
	(substr(icdprocedurecode_desc, 49, 8) NE "Products") and
	(substr(icdprocedurecode_desc, 52, 8) NE "Products") and
	(substr(icdprocedurecode_desc, 45, 8) NE "Products") and
	(substr(icdprocedurecode_desc, 51, 8) NE "Products") and
	(substr(icdprocedurecode_desc, 47, 8) NE "Products"));
	drop ICD_version;
run;

data wb_transfusions;
	set transfusions;
	where (substr(icdprocedurecode_desc, 27, 11)="Whole Blood") or
		  (substr(icdprocedurecode_desc, 30, 11)="Whole Blood") ;
run;

title1	"Transfusion codes";
title2	"Does not include plasma cryoprecipitate";
proc print data=transfusions;
run;

data lib04.transfusion_codes;
	set transfusions;
run;

proc export data=transfusions
	outfile="\transfusion_codes_2021.csv"
	dbms = dlm
	replace;
	delimiter=',';
run;

* set transfusion flags in files with codes;

data transfusions_include;
	set transfusions;
	transfused = 1;
	drop icdprocedurecode_desc;
run;

proc sort data=transfusions_include;
	by icdprocedurecode;
run;

data wb_transfusions_include;
	set wb_transfusions;
	wb_transfused = 1;
	drop icdprocedurecode_desc;
run;

proc sort data=wb_transfusions_include;
	by icdprocedurecode;
run;

* merge transfusion flags into patient file by codes;

proc sort data=ICDprocedure00;
	by icdprocedurecode;
run;

data transfused_patients01;
	merge	ICDprocedure00 (in = in_proc)
			transfusions_include (in = in_trans);
	by icdprocedurecode;
	if in_proc and in_trans;
run;

data transfused_patients02;
	merge	transfused_patients01 (in = in_trans)
			wb_transfusions_include;
	by icdprocedurecode;
	if wb_transfused = . then wb_transfused = 0;
	if in_trans;
run;

* sort by prioritizing WB flag;

proc sort data=transfused_patients02;
	by inc_key descending wb_transfused;
run;

data lib04.transfused_patients_2021;
	set transfused_patients02;
	by inc_key descending wb_transfused;
	drop icdprocedurecode;
	if first.inc_key;
run;


quit; ods rtf close;
