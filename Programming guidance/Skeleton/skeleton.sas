/*************************************************************************************
This sample program provides necessary codes to collect data from Statistics Denmark
to a project in the framwork of The Aalborg/Hillerød/Gentofte/Rigshospitalet group and
using data as provided from project 3573 to individual projects.

Any use of the examples will have to adjust directories to those for a project.

Please adhere to a number of useful rules:
1. For any project create a folder for each publication
2. Maintain a very small number of programs that generate data for a publication
3. Keep the final analysis dataset until a publication is published. Intermediary
   and often large datasets should be deleted as they can be reshaped from raw data
4. Keep record of the amount of disk memory you use - be modst!
5. Comment programs generously so both you and others can decode them even after
   many years.
6. Be aware that the only documentation you haves for your project is your programs.
   Make sure to keep them safe, which includes having them sent out of Statistics
   Denmark for safe keeping.

***********************************************************************************/
options mergenoby=error;
options validvarname=any;
libname temp 'Z:\Workdata\703573\temp_3740';

options autosignon=yes;
options sascmd="sas";
options threads cpucount=10; /* Multithreading with 10 cores*/
%let _start_dt=%sysfunc(datetime()); *starttime;

libname populat 'Z:\Workdata\703573\3740 Diabetes\Grunddata\Population'; 
/***********************************************************************************
The first step of a project is to define the population. The current sample assumes
that you want all danes available in the period from 2005-2015. Note use of multiple
cores and that being a sample program only a few records are obtained from each
dataset (obs=100).

Note for the populat folder:
- Prior to 1985 there is no bef, but fain can partially replace
- In particular for the first years it is necessary to use the sexBirth datasets
  to capture sex and birth date
- All movements to and from Denmark are in the single vnds dataset
************************************************************************************/
%macro befpnr;
  %do i=2005 %to 2007; * bef updated once yearly until 2008;
	 %syslput _local_/remote=t&i;
	 rsubmit t&i wait=no connectpersist=no inheritlib=(temp populat);
	      data temp.bef&i.12; set populat.bef&i.12 (keep= pnr koen foed_dag obs=100);
		  run; 
	endrsubmit;
  %end;
  %let lst= 03 06 09 12; * the four annual updates;
  %let endloop=4;
  %do i=2008 %to 2015; 	/* In this time period data on all quarter exists*/
    %do ii=1 %to &endloop;
	  %syslput _local_/remote=t&i&ii;
      rsubmit t&i&ii wait=no connectpersist=no inheritlib=(temp populat);
        data temp.bef&i.%scan(&lst,&ii); set populat.bef&i.%scan(&lst,&ii)
                                                  (keep= pnr koen foed_dag obs=100);
		run;
      endrsubmit;
    %end;
  %end;
  waitfor _all_;
  signoff _all_;
%mend;
%befpnr;
data pnr; set temp.bef:; run;
proc sort data=populat.pnr noduprec; by pnr; run; * Just one of each;
proc datasets library=temp kill; run; * Clear temp library;

/****************************************************************************
 Cancer uses the cancer registry t_tumor
******************************************************************************/
libname cancer 'Z:\Workdata\703573\3740 Diabetes\Grunddata\cancer';
data t_tumor; set cancer.t_tumor (obs=5000); run;
proc sort data=t_tumor; by pnr; run;
proc sort data=pnr; by pnr; run;
data t_tumor; merge t_tumor (in=data) pnr (in=data2); by pnr; 
 if data; if data2;*isolate case in your population of choise;
run; 
data t_tumor; set t_tumor; by pnr;
 if first.pnr; * select first case of cancer - more useful if sorted by data of cancer;
run;
/****************************************************************************
 Death has three files
 t_dodsaarsag_1 - causes of death prior to 2001
 t_dodsaarsag_2 - later causes of death with new codes and variables,
   always a few years behind
 dod a simple list of death dates from statistics Denmark and cpr-register
******************************************************************************/
libname death 'Z:\Workdata\703573\3740 Diabetes\Grunddata\Death';

data death; set death.dod;
proc sort data=death; by pnr; run;
data death; merge death (in=data) pnr (in=data2); by pnr;
 if data; if data2;
run;

/****************************************************************************
Laboratory has data from two distinct sources

LABKA is the national database for clinical biohemistry. In addition to the main
file labforsker there are older data from KPLL, Region North, KBH amt and Roskilde 
which may provide additioanl older values in some cases.  Note that the format of
these datasets differ.

This folder will also holde pathological data from Sundhedsdatastyrelsen if requested.
Visit Sundhedsdatastyrelsen to understand these data;

The example shows how to extract values 
******************************************************************************/

libname blod 'V:\Data\Alle\Blodprøver'; /* NPU code directory*/
data blod; set blod.npu_definition_270918; run;
options validmemname=extend; *to read variable names with spaces;
data blod; set blod;
 if find('kort definition'n,"kalium","i")>=1; /* all with potassium - note "'n" to read a variable with spaces*/
run;
libname lab 'Z:\Workdata\703573\3740 Diabetes\Grunddata\laboratory';
data pkalium; set lab.lab_forsker (obs=10000); *read only 10000 records;
 if analysiscode='NPU03230';
run;

/****************************************************************************
Using hospital register data is challenging.  The register was originally organized
in 1978 as LPR1, extended with more data in 1994 as LPR2.

LPR 1/2 has a record for each "forløb" (course) - one record for each hospital department
that have handled the case and one for a series of related outpatient visits. LPR2/3
has a pattype which is zero for inpatient treatment and greater numbers for other
situations. Take particular care with emergency room visits which have changed 
recording over time.

In accordance with previous habits of our environemnt we have maintained to produce
diag_indl which has diagnoses and start/ned of "forløb"
opr - which has procedures and examinations
as well as separate files for psychiatric hospital contacts whens requested for projects

With LPR3 the system changes. Many more contacts are registered. The concept of
distinguishing between inpatient and outpatient visits has disappeared.  It is therefore
necessary to enterrogate instructions from Sundhedsdatastyrelsen. Replacement for "pattype"
is described by Sundhedsdatastyrelsen and also in www.heart.dk/github

The simple example below extracts a series of patients with first myocardial
infarction from a hospital admission in both LPR1/2 and LPR3
******************************************************************************/
libname lpr 'Z:\Workdata\703573\3740 Diabetes\Grunddata\LPR';
data ami; set lpr.diag_indl (where=(diag=:'410' or diag=:'I21') obs=1000
  keep=pnr diag inddto pattype); 
 if pattype='0';
 drop pattype;
run;

proc sort data=ami; by pnr inddto; run;
data ami; set ami; by pnr inddto;
 if first.inddto;
run;

data diagami2; set lpr.diagnoser (where=(diagnosekode=:'DI21') obs=1000);
 keep DW_EK_KONTAKT diagnosekode;
run;
/* kontakter gets a record everytime a new contacty including a hospitalisation is started*/
data kontakt; set lpr.kontakter (keep= cpr DW_EK_KONTAKT dato_start tidspunkt_start dato_slut tidspunkt_slut);
 start=dhms(dato_start,0,0,tidspunkt_start);
 slut=dhms(dato_slut,0,0,tidspunkt_slut);
 dif=slut-start;
 if dif>60*60*12; *duration>12 hours, not a universal solution in particular for children;
 keep cpr dato_start DW_EK_KONTAKT;
run;

proc sort data=kontakt; by DW_EK_KONTAKT; run;
proc sort data=diagami2; by DW_EK_KONTAKT; run;

data ami2; merge kontakt (in=data) diagami2 (in=data2); by DW_EK_KONTAKT; 
  if data; if data2;
  rename cpr=pnr dato_start=inddto diagnosekode=diag;
run;

data ami; set ami ami2; run;
proc sort data=ami; by pnr inddto; run;
data ami; set ami; by pnr inddto;
 if first.inddto;
run;

/****************************************************************************
Prescriptions are available in batches for each year.  The amount of data on
each prescription, but in particular the variable "vnr" can be used to
combine with other data.  These data are in:
V:\Data\Alle\LMDBdata

The following example extracts cardioavascular medication from a range of years

******************************************************************************/
options autosignon=yes;
options sascmd="sas";
options threads cpucount=10; /* Multithreading with 10 cores*/
libname med 'Z:\Workdata\703573\3740 Diabetes\Grunddata\medication';
libname temp 'Z:\Workdata\703573\temp_3740';
%macro med;
  %do i=2008 %to 2015; 	
	  %syslput _local_/remote=m&i;
      rsubmit m&i wait=no connectpersist=no inheritlib=(temp med);
        data temp.med&i ; set med.lmdb&i (keep= pnr atc eksd obs=100);
		run;
      endrsubmit;
   %end;
  waitfor _all_;
  signoff _all_;
%mend;
%med;
data med; set temp.med:; run;
proc datasets library=temp kill; run; * Clear temp library;


/****************************************************************************
Nursing home data comes from a range of sources:
Plejehjem is a manual dataset created for us by DST by examining all locations
  where multiple old people lives.  The data includes a from/to for each pnr
  and each institution.  These data should be used from 1994-2016
AEPB has from start 2017 one record per mont per pnr for each nursing home.
AETR has information of training
AELH has home assistance
AEFV has information on referral for home assistance

We are anticipating newer data from Sundhedsdatastyrelsen which may explain
extra files in some projects.

The plejehjem data are easy to use.  Several of the others are complicated 
with variables missing in intervals etc.  It takes care to use these data.
******************************************************************************/

/****************************************************************************
Social
DREAM contains information on public support and area of work. Note the strange
  format with a variable per week/month. Conversion to a long format with dates
  can be accomplished with the heaven::importDream function
ind has income. The most useful variable for most projects is AEKVIVADISP_13 
  which is personal income adjust to household.
udda has maximal education each year.  Note that "DST-formater" has formats to
  convert to useful groups.  The heaven::eduCode has a conversion to ISCED

The example captures maximal education for an extract of people during a sequence
of years.

******************************************************************************/

options autosignon=yes;
options sascmd="sas";
options threads cpucount=10; /* Multithreading with 10 cores*/
libname soc 'Z:\Workdata\703573\3740 Diabetes\Grunddata\social';
libname temp 'Z:\Workdata\703573\temp_3740';
%macro udda;
  %do i=2008 %to 2015; 	
	  %syslput _local_/remote=s&i;
      rsubmit s&i wait=no connectpersist=no inheritlib=(temp soc);
        data temp.udda&i ; set soc.udda&i (keep= pnr hfaudd obs=100);
		 year=&i; * Such once per year datasets may not include the year 
		            - which fortunately can be added;
		run;
      endrsubmit;
   %end;
  waitfor _all_;
  signoff _all_;
%mend;
%udda;
data udda; set temp.udda:; run;
proc datasets library=temp kill; run; * Clear temp library;

/****************************************************************************
SSS has data from private practice divided in two time periods.
All entries are based on weekly additions of data from practitioners
regarding patients.

******************************************************************************/

