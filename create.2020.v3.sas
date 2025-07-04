/*******************************************************************
2020 dataset, B0749 whole blood analysis TBI polytrauma

output:	trauma2020v3.csv

references to local drives have been removed
********************************************************************/

libname lib2020 "\Year2020SAS";
libname lib2021 "\Year2021SAS";

%macro countds(fil, comment);
data &fil;
	set &fil nobs=x end=y;
	if y=1 then put "The number of records in dataset &fil = " x "&comment";
run;
%mend countds;

/*******************************************************************
formats
********************************************************************/

data puf_trauma_lookup;
	set lib2020.puf_trauma_lookup;
run;

proc format cntlin=puf_trauma_lookup;
run;

proc format;
	value ais_sev	
		1 = 'Minor'
		2 = 'Moderate'
		3 = 'Serious'
		4 = 'Severe'
		5 = 'Critical'
		6 = 'Unsurvivable'
		9 = 'Not possible to assign';
	value iss_reg
		1 = 'AIS_head'
		2 = 'AIS_face'
		3 = 'AIS_chest'
		4 = 'AIS_abd'
		5 = 'AIS_extrem'
		6 = 'AIS_ext';
run;

/*******************************************************************
Trauma 

- Hospital complications moved to HospitalEvents dataset in 2019
- 24 hour tranfusion data retired 2018
- FinalDischargeDays replaces LOSDays in 2019
- HospitalDischargeDays not in dataset
- EDdischargeDays replaces EDdays in 2019
- Used HRS instead of DAYS variables
********************************************************************/

* Gather patient data;

data puf_trauma;
	* set lib2020.puf_trauma (obs=40000) ;
	set lib2020.puf_trauma ;
	keep inc_key 
	/* patient characteristics */
		AGEYEARS Sex ETHNICITY
		AmericanIndian Asian Black PacificIslander Race_NA Race_UK RaceOther White
		/*ISSversion*/ ISS  PulseRate SBP
		TotalGCS /*GCSq_valid TBIhighestTotalGCS PMGCSQ_valid*/
		InterFacilityTransfer HospitalArrivalHrs PreHospitalCardiacArrest
		PRIMARYMETHODPAYMENT
	/* diagnosis for mechanism of injury */
		PrimaryEcodeICD10 /*AdditionalEcode1 AdditionalEcode2*/ 
	/* transfusion data */
		Blood4Hours Plasma4hours 
		Platelets4hours WholeBlood4hours
	/* procedures */
		/*HIGHESTACTIVATION*/
		HmrrhgCtrlSurgType VTEprophylaxisType
		HmrrhgCtrLSurgHRS /*HmrrhgCtrLSurgDays*/
		ICPEVDRAIN ICPPARENCH ICPO2MONITOR ICPJVBULB ICPNONE  /* cerebral monitoring */
		TBICerebralMonitorHRS /*TBICerebralMonitorDays*/
	/* outcomes */
		TotalICULOS TotalVentDays 
		/*EDdischargeDays*/ EDdischargeHrs EDDischargeDisposition
		HospDischargeDisposition /*FinalDischargeDays*/ FinalDischargeHrs
		WithdrawalLST /*WithdrawalLSTHrs WithdrawalLSTDays*/
	/* Facility */
		/*TEACHINGSTATUS HOSPITALTYPE BEDSIZE VERIFICATIONLEVEL STATEDESIGNATION*/
		;	
run;  

/*******************************************************************
Manipulate variables

Death + withdrawal of care + hospice does not include SNF
*******************************************************************/

data puf_trauma;
	set puf_trauma;

	if Blood4hours > 0 then RedCells4HoursFlag = 1;
		else RedCells4HoursFlag = .;
	if Plasma4hours > 0 then Plasma4hoursFlag = 1;
		else Plasma4hoursFlag = .;
	if Platelets4hours > 0 then Platelets4hoursFlag = 1;
		else Platelets4hoursFlag = .;
	if WholeBlood4hours > 0 then WholeBlood4hoursFlag = 1;
		else WholeBlood4hoursFlag = .;
	
	if Black = 1 then Race = "Black";
		else if White = 1 then Race = "White";
		else if Asian = 1 then Race = "Asian";
		else if Race_UK = 1 then race = "Unknown";
		else if Race_NA = 1 then race = "Unknown";
		else Race = "Other";

	if (HospDischargeDisposition = 5) or (WithdrawalLST = 1) then Dead = 1; 
		else Dead = 0;

	if ( HospDischargeDisposition in (5, 8) ) = 1 OR WithdrawalLST = 1 
		then DeadWithdrawCare = 1; 
		else DeadWithdrawCare = 0;

	if (HospDischargeDisposition = .) and (WithdrawalLST NE 1) then do;
		Dead = .;
		DeadWithdrawCare = .;
	end;

	transfused = 0;
	wb_transfused = 0;

	format	Dead DeadWithdrawCare
			RedCells4HoursFlag Plasma4hoursFlag 
			Platelets4hoursFlag WholeBlood4hoursFlag yn.;
run;

%countds(puf_trauma, all patients)


/*******************************************************************
Include only patients transfused within 4 hours
********************************************************************/

proc sort data=lib04.transfused_patients_2020 out=transfused_patients;
	by inc_key;
run;

proc sort data=puf_trauma;
	by inc_key;
run;

data trauma00;
	merge	puf_trauma (in=in_trauma)
			transfused_patients;
	by inc_key;
	if transfused = . then transfused = 0;
	if wb_transfused = . then wb_transfused = 0;
	if in_trauma;
run;

data trauma01;
	set trauma00;
	where (RedCells4HoursFlag = 1) or (Plasma4hoursFlag = 1) or
	(Platelets4hoursFlag = 1) or (WholeBlood4hoursFlag = 1) or 
	(transfused = 1);

	if WholeBlood4hoursFlag = 1 then wb_transfused = 1;
run;

proc sort data=trauma01;
	by inc_key;
run;

%countds(trauma01, after exclude without any 4 hr transfusion)

/*******************************************************************
Include only patients eligible TQIP adult
********************************************************************/

proc sort 	data=lib2020.tqp_inclusion
			out=tqp_inclusion;
	by inc_key;
run;

data trauma03;
	merge	trauma01 (in = in_trauma)
			tqp_inclusion;
	by inc_key;
	if in_trauma AND (AdultTQIP = 1);
run;

%countds(trauma03, after exclude non-TQIP adults)


/*******************************************************************
Include only patients LOS > 4 hours
********************************************************************/

data trauma04;
	set trauma03;
	where FinalDischargehrs >= 4;
run;

%countds(trauma04, after exclude deaths within 4 hours)

* Eligible patients for analysis dataset;
data eligible;
	set trauma04;
	keep inc_key;
run;


/********************************************************************
AIS  

This splits the data into the 3 versions, 
then merges in the descriptions, then combines them.
********************************************************************/

/********************************************************************
AIS version = 1998 subset

Input:	AIS diagnosis from 2020
		AIS lookup from 2020
		eligible
Output:	AIS1998 with eligible patients
********************************************************************/

data ais1998x;
	set lib2020.puf_aisdiagnosis;
	where AISversion = "AIS 1998";
	keep inc_key AISpredot;
run;

proc sort data=ais1998x;
	by inc_key;
run;

data ais1998y;
	merge	ais1998x (in = in_ais)
			eligible (in = in_eligible);
	by inc_key;
	if in_ais and in_eligible;
run;

proc sort data=ais1998y;
	by AISpredot;
run;

data lookup1998;
	set lib2020.puf_aisdiagnosis_lookup;
	where AISversion = "AIS 1998";
	keep AISpredot AISseverity AISdescription ISSregion;
run;

proc sort data=lookup1998;
	by AISpredot;
run;

data ais1998;
	merge	ais1998y (in = in_ais)
			lookup1998;
	by AISpredot;
	if in_ais;
run;


/********************************************************************
AIS version = 2015 subset

Input:	AIS diagnosis from 2020
		AIS lookup from 2020
Output:	AIS2015 with eligible patients
********************************************************************/

data ais2015x;
	set lib2020.puf_aisdiagnosis;
	where AISversion = "AIS 2015";
	keep inc_key AISpredot;
run;

proc sort data=ais2015x;
	by inc_key;
run;

data ais2015y;
	merge	ais2015x (in = in_ais)
			eligible (in = in_eligible);
	by inc_key;
	if in_ais and in_eligible;
run;

proc sort data=ais2015y;
	by AISpredot;
run;

data lookup2015;
	set lib2020.puf_aisdiagnosis_lookup;
	where AISversion = "AIS 2015";
	keep AISpredot AISseverity AISdescription ISSregion;
run;

proc sort data=lookup2015;
	by AISpredot;
run;

data ais2015;
	merge	ais2015y (in = in_ais)
			lookup2015;
	by AISpredot;
	if in_ais;
run;


/********************************************************************
AIS version = 2005 subset

Input:	AIS diagnosis from 2020
		AIS lookup from 2020
Output:	AIS2005 with eligible patients
********************************************************************/

data ais2005x;
	set lib2020.puf_aisdiagnosis;
	where AISversion = "AIS 2005";
	keep inc_key AISpredot;
run;

proc sort data=ais2005x;
	by inc_key;
run;

data ais2005y;
	merge	ais2005x (in = in_ais)
			eligible (in = in_eligible);
	by inc_key;
	if in_ais and in_eligible;
run;

proc sort data=ais2005y;
	by AISpredot;
run;

data lookup2005;
	set lib2020.puf_aisdiagnosis_lookup;
	where AISversion = "AIS 2005";
	keep AISpredot AISseverity AISdescription ISSregion;
run;

proc sort data=lookup2005;
	by AISpredot;
run;

data ais2005;
	merge	ais2005y (in = in_ais)
			lookup2005;
	by AISpredot;
	if in_ais;
run;


/********************************************************************
AIS 

select highest severity for each region for each patient
********************************************************************/

data ais01;
	set ais2005 ais2015 ais1998;
	keep inc_key AISSeverity ISSRegion;
run;

proc sort data=ais01;
	by inc_key ISSregion AISSeverity;
run;


* Select highest severity for each region per patient;
data ais02;
	set ais01;
	by inc_key ISSregion AISSeverity;
	if last.ISSregion AND last.AISSeverity; 
run; 

************** save for checking *********************************;
data lib04.ais01;
	set ais01;
run;
data lib04.ais02;
	set ais02;
run;


/********************************************************************
Include only patients AIS head > 1 
********************************************************************/

data ais_head;
	set ais02;
	where (ISSRegion = 1) and ( AISSeverity in (2,3,4,5,6) );
	keep inc_key;
run;

data ais;
	merge	ais_head (in = in_head)
			ais02;
	by inc_key;
	if in_head;
	format ISSregion iss_reg.;
run;

proc transpose	data = ais
				out = ais_wide (drop = _NAME_ _LABEL_);
	by inc_key;
	id ISSRegion;
run;

data trauma05;
	merge	trauma04 (in = in_trauma)
			ais_wide (in = in_ais);
	by inc_key;
	if in_trauma and in_ais;
run;

%countds(trauma05, after excluding AIS head < 2)


/*******************************************************************
ECODE  <- mechanism of injury
********************************************************************/

data ecode_lookup;
	set lib2020.puf_ecode_lookup;
	keep ECode Mechanism TraumaType;
run;

proc sort data=ecode_lookup;
	by ecode;
run;

/********************************************************************
Add flag for blunt or penetrating trauma using Ecode
********************************************************************/

proc sort data=trauma05;
	by PrimaryEcodeICD10;
run;


data trauma09;
	merge	trauma05 (in = in_trauma)
			ecode_lookup 	(in=in_ecode 
							rename = (ecode = PrimaryEcodeICD10)) ;
	by PrimaryEcodeICD10;
	in_ecode01 = in_ecode;
	if MECHANISM in (8, 13, 12, 16) then MOI = "MVC ";
		else if MECHANISM in (3) then MOI = "Fall";
		else if MECHANISM in (9) then MOI = "MCC ";
		else if MECHANISM in (11, 21, 10, 15, 14) then MOI = "Ped ";
		else if MECHANISM in (6) then MOI = "GSW ";
		else if MECHANISM in (1) then MOI = "SW  ";
		else MOI = "OTHR";
	if in_trauma;
run;


proc sort data=trauma09;
	by inc_key;
run;

data eligible;
	set trauma09;
	keep inc_key;
run;


/*******************************************************************
HospitalEvents <- complications
********************************************************************/

data puf_HospitalEvents;
	set lib2020.puf_HospitalEvents ;
	drop HospitalEventAnswer_BIU;
	format HospitalEvent HospitalEvent.;
	where HospitalEvent in (4,5,20,35,31,30,40,32,18,22);
run;

proc sort data=puf_HospitalEvents;
	by inc_key HospitalEvent;
run;

data HospitalEvents01;
	merge	puf_HospitalEvents
			eligible (in = in_elig);
	by inc_key;
	if in_elig;
run;

proc transpose	data = HospitalEvents01 
				out = HospitalEvents02 (drop = _NAME_ _LABEL_);
	by inc_key;
	id HospitalEvent;
run;

data HospitalEvents;
	set HospitalEvents02;
	if	(Acute_Kidney_Injury = 1) OR
		(Acute_Respiratory_Distress_Syndr = 1) OR
		(Myocardial_Infarction = 1) OR
		(Stroke_CVA = 1) OR
		(Unplanned_Admission_to_ICU = 1) OR
		(Severe_Sepsis = 1) OR
		(Ventilator_Associated_Pneumonia = 1) OR
		(Unplanned_Visit_to_OR = 1)
	then Complications = 1;
	else Complications = 0;
	format Complications yn.;
run;

data trauma10;
	merge	trauma09
			HospitalEvents;
	by inc_key;
run;


/*******************************************************************
PreExistingConditions  <- comorbidities
********************************************************************/

data puf_PreExistingConditions;
	set lib2020.puf_PreExistingConditions ;
	drop PreExistingConditionAnswer_BIU;
	format PreExistingCondition PreExistingCondition.;
	where PreExistingCondition in (31,25,11,4,26,9,10);
run;

proc sort data=puf_PreExistingConditions;
	by inc_key PreExistingCondition;
run;

data PreExistingConditions01;
	merge 	puf_PreExistingConditions
			eligible (in = in_elig); 
	by inc_key;
	if in_elig;
run; 

proc transpose	data = PreExistingConditions01
				out = PreExistingConditions02 (drop = _NAME_ _LABEL_);
	by inc_key;
	id PreExistingCondition;
run; 

data PreExistingConditions03;
	set PreExistingConditions02;
	if	(Bleeding_Disorder = 1) OR
		(Chronic_Renal_Failure = 1) OR
		(Cerebrovascular_Accident = 1) OR
		(Diabetes_Mellitus = 1) OR
		(Cirrhosis = 1) OR
		(Dementia = 1) OR
		(Anticoagulant_Therapy = 1)
	then PreExistingConditions = 1;
	else PreExistingConditions = 0;
	format PreExistingConditions yn.;
run;  

data trauma11;
	merge	trauma10
			PreExistingConditions03;
	by inc_key;
run;  


/********************************************************************
ICD Procedure for hemorrhage control

Data for each procedure is procedure start time (hours)
********************************************************************/

data ICDprocedure01;
	set lib2020.puf_ICDprocedure;
	drop ICDProcedureVersion HospitalProcedureStartDH_BIU;
run;


data ICDprocedure05;
	merge	ICDprocedure01
			eligible (in = in_elig);
	by inc_key;
	letters3 = substrn(ICDProcedureCode, 1, 3);
	letters4 = substrn(ICDProcedureCode, 1, 4);

	if letters3 in ("03V", "03L", "04V", "04L") then Procedure = "embolization";
	if letters3 = "0NT" then Procedure = "craniectomy";
	if letters4 = "0NB0" then Procedure = "craniectomy";
	if letters4 = "0N80" then Procedure = "craniotomy";

	if in_elig and (Procedure NE "") and (HospitalProcedureStartHrs NE .);
	drop letters3 letters4 ICDProcedureCode HospitalProcedureStartDays;
run;

********save for checking ****************************************;
data lib04.ICDprocedure05;
	set ICDprocedure05;
run;


proc sort data=ICDprocedure05;
	by inc_key HospitalProcedureStartHrs;
run;

* previously I kept all procedures. now keep only first, so some dup code later;

data ICDprocedure05B;
	set ICDprocedure05;
	by inc_key HospitalProcedureStartHrs;
	if first.inc_key;
run;

proc transpose	data = ICDprocedure05B
				out = ICDprocedure06 (drop = _NAME_ _LABEL_);
	by inc_key;
	id Procedure;
run;

data trauma12;
	merge 	trauma11 (in=in_trauma)
			ICDprocedure06;
	by inc_key;
	if in_trauma;
run;


/********************************************************************
trauma - finalize and save the trauma analysis dataset

Calculate hemorrhage control hours
********************************************************************/

data trauma;
	set trauma12;

	WB = wb_transfused; * WB identified with ICD codes;

*	Craniectomy overwrites craniotomy;
	crany_flg = 0;
	crany_hrs = .;
	if craniotomy>0 then do;
		crany_hrs = craniotomy;
		crany_flg = 1;
	end;
	if craniectomy>0 then do;
		crany_hrs = craniectomy;
		crany_flg = 1;
	end;

*	time to hemorrhage control is earliest of OR or embolization;
	hem_flg = 0;
	hem_hrs = .;
	if HMRRHGCTRLSURGHRS>0 then do;
		hem_flg = 1;
		hem_hrs = HMRRHGCTRLSURGHRS;
	end;
	if embolization>0 then do;
		hem_flg = 1;
		if hem_hrs>0 then hem_hrs = min(hem_hrs, embolization);
			else hem_hrs = embolization;
	end;

	format hem_flg yn.;
run;

proc export data=trauma
	outfile="\trauma2020v3.csv"
	dbms = dlm
	replace;
	delimiter=',';
run;
