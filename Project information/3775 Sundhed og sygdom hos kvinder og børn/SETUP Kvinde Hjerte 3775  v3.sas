/***********************************************************

Kvinder og Hjertesygdom - start 3.2.12

*****************************************************************/

libname pop 'X:\Data\Rawdata_Hurtig\703573\pop';
libname dst 'X:\Data\Rawdata_Hurtig\703573\DST';
libname lmdb 'X:\Data\Rawdata_Hurtig\703573\LMDB';
libname lprgrund 'X:\Data\Rawdata_Hurtig\703573\LPRGrund';
libname lprpriv 'X:\Data\Rawdata_Hurtig\703573\LPRPrivat';

libname K 'X:\Data\Workdata_Hurtig\703573\3775 Kvinde Hjerte';
options mergenoby=error;

/*****************  POP ***********************************

Indeholder data fra:

- POP 
- seneste udvandring 
- første indvandring
- seneste uddannelse og dato for denne
- første år hvor pt er kendt i cpr (fain bef)
- dansker/indvandrer/efterkommer 
- oprindelsesland samt type 
- check af cpr-nummer

**************************************************************/
data pop; set pop.pop; 
 fdato=mdy(month(fdato),15,year(fdato));
run;

*Første indvandring og seneste udvandring fra DK;
data vandring_ind; set dst.vnds2015;
 where indud_kode='I';
run;
proc sort data=vandring_ind; by pnr haend_dato;
data vandring_ind; set vandring_ind;
 retain first_ind last_ind;
 by pnr;
 if first.pnr then 
  do;
   first_ind=haend_dato; last_ind=.;
  end;
 if last.pnr then
  do;
   last_ind=haend_dato;
   output;
  end;
 drop indud_kode;
 format last_ind first_ind date7.;
run;

data vandring_ud; set dst.vnds2015;
 where indud_kode='U';
run;
proc sort data=vandring_ud; by pnr haend_dato;
data vandring_ud; set vandring_ud;
 retain first_ud last_ud;
 by pnr;
 if first.pnr then 
  do;
   first_ud=haend_dato; last_ud=.;
  end;
 if last.pnr then
  do;
   last_ud=haend_dato;
   output;
  end;
 drop indud_kode;
 format last_ud first_ud date7.;
run;

* IEtype og indvandringsland;
%macro iepe;
 data iepe; 
  set %do i= 1980 %to 2015; dst.iepe&i %end;;
 run;
%mend;
%iepe;
proc sort data=iepe; by pnr; run;
data iepe; set iepe;
 by pnr;
 if last.pnr; run;
run;

* Første registrering i Familie FAIN og BEF;
%macro fain;
 %do i=1980 %to 2007;
  data fain&i; set dst.fain&i (keep=pnr);
   length bef_year 3;
   bef_year=&i;
  run;
 %end;
 %do i=1986 %to 2016;
  data bef&i; set dst.bef&i (keep=pnr);
   length bef_year 3;
   bef_year=&i;
  run;
 %end;
 data bef_fain; set
  %do i=1980 %to 2007; fain&i  %end;
  %do i=1986 %to 2016; bef&i %end;;
 run;
%mend;
%fain;

proc sort data=bef_fain; by pnr bef_year; run;

data bef_fain; set bef_fain;
 by pnr;
 if first.pnr;
run;
*døde;
data dod; set dst.dod2015 (keep= pnr doddato); rename doddato=dodsdato; run;
*Samle befolkning;
proc sort data=pop; by pnr; run;
proc sort data=vandring_ind; by pnr; run;
proc sort data=vandring_ud; by pnr; run;
proc sort data=iepe; by pnr; run;
proc sort data=bef_fain; by pnr; run;
proc sort data=dod; by pnr; run;

data pop; merge pop vandring_ind vandring_ud iepe bef_fain dod; by pnr;
if not first.pnr then delete; /*fjerner 2 dobbeltgængere om hvem man intet ved*/
*fjernet personer uden køn og definerer vanlig sex;
if kon='' then delete;
sex=kon=1; drop kon;
* fjerner mærkelige cpr-numre;
if _cprchk_=0; if _cprtype_=1;

/* *gruppering af opr_land;
length oprland $7;
if opr_land in (0,5001,5800,5999) then oprland='Uoplyst';
if 5100<opr_land<5200 or opr_land=5901 or opr_land=5902 then oprland='Øvrige Europa';
if opr_land=5100 then oprland='Danmark';
if 5200<=opr_land<5300 then oprland='Afrika';
if 5300<=opr_land<5400 then oprland='Vest';
if 5400<=opr_land<5500 then oprland='Oest'; 
*/

drop _cprchk_ _cprtype_ haend_dato dodsdato/*opr_land*/ ;
run;
proc sort data=pop; by pnr; run;

data K.pop; set pop; 
 if fdato<'01JAN2010'd;
 if sex=0;
 label bef_year='Sidste år med registrering i BEF-register (BEF: Oplysninger om befolkningen)'
	fdato='Afrundet fødselsdato til den 15. i måneden'
	first_ind='Dato for første indvandring'
	first_ud='Dato for første udvandring'
	last_ind='Dato for sidste indvandring'
	last_ud='Dato for sidste udvandring'
	pnr='Krypteret CPR nummer'
	/* oprland='Oprindelsesland inddelt i Danmark, Øvrige Europa, Afrika, Øst, Vest og Uoplyst' */
	sex='Køn (0:Kvinde; 1:Mand)';
	run;

/******************************************************************************************
 PNR
*******************************************************************************************/

data pnr; set K.pop (keep=pnr); run;
proc sort data=pnr nodupkey; by pnr; run;

/**************************************************************** 

 indl_hel v1 (21/7-16 - ændret af Regitze)

 Finder samtlige heldøgnsindlæggelser (pattype=0)
 - kan bruges til at korrigere for indlæggelser i medicinmacroen

******************************************************************/
%macro indl_hel(direc,start, slut,output);
%do i=&start %to &slut;
	data pop&i; set %if &direc=lprpriv %then &&direc..hel&i; %else %if &i<1994 %then &&direc..lprHEL&i; %else &&direc..lprPOP&i; 
  	(keep=pnr recnum %if &direc=lprpriv %then %do; inddto pattype %if &i=2009 or &i=2008 %then d_uddto; %else uddto; %end;
  	%else d_inddto d_uddto c_pattype;);
		%if &direc=lprgrund %then %do;
			inddto=d_inddto; drop d_inddto;
			uddto=d_uddto; drop d_uddto;
	    	pattype=c_pattype*1; drop c_pattype;
		%end;
		%if &direc=lprpriv %then %do;
			pattype2=pattype*1; drop pattype; rename pattype2=pattype;
	    		%if &i=2009 or &i=2008 %then %do;
	      			uddto=d_uddto; drop d_uddto;
	     		%end;
		%end;
	run;
%end;

data &output; set %do i=&start %to &slut; pop&i %end;; 
	where pattype=0;
	length inddto 5 uddto 5 pattype 3;
run;
%mend;

%indl_hel(lprgrund,1994,2015,Indl_off);
%indl_hel(lprpriv,2002,2012,Indl_priv);

data indl_heldoegn(keep=pnr recnum inddto uddto pattype pnr_ind); set Indl_off Indl_priv;
 pnr_ind=pnr||inddto;
 if uddto eq . then delete;
run;

proc sort data=indl_heldoegn;
 by pnr_ind descending uddto;
run;

data k.indl_heldoegn; set indl_heldoegn;
 by pnr_ind ;
 if first.pnr_ind;
 drop pnr_ind;
 label pnr='Krypteret cpr nummer';
run;

/***************************************************************

Døde og Dødsårsager

Bemærk at dødsårsager EFTER 2001 kører efter en anden skala

Denne programstump beregner også en række vanligt brugte dødsårsager
Opdateret til ny nomenklatur efter marts 2012

****************************************************************/
proc sort data=dst.dod2013; by pnr; run;
proc sort data=dst.dod2015; by pnr; run;

data doede; merge dst.dod2013 dst.dod2015;
by pnr;
 if doddato>'01JAN2002'd then
 do;
  doedsaars1=''; doedsaars2=''; doedsaars3=''; doedsaars4=''; 
 end;
run;

data doede2; set dst.dodsaasg2014 ;
/* drop C_bopkom c_region c_bopkomf07 c_bopamtF07 C_liste14 C_liste49 d_dodsdato d_findedato d_statdato c_dodsmaade
   c_dodssted c_praecis_dodssted C_FINDESTED C_PRAECIS_FINDESTED C_HAENDELSESSTED C_OBDUKTION c_operation c_laegefunktion
   v_alder c_sex /*15.3.12- tilgrundlæggende død ikke fjernet længere*/ ;
run;

proc sort data=doede; by pnr; run;
proc sort data=doede2; by pnr; run;

data doede; merge doede doede2; by pnr;
 if first.pnr;* Removes 4 doublicate death records;

 if doddato<'01JAN2002'd then
  do;
   if (substr(doedsaars1,1,3)in('I21','I22') ) or substr(doedsaars1,1,3)='410' or
    (substr(doedsaars2,1,3)in('I21','I22') ) or substr(doedsaars2,1,3)='410' or
    (substr(doedsaars3,1,3)in('I21','I22') ) or substr(doedsaars3,1,3)='410'  
   then dod_ami=1;
   if (substr(doedsaars1,1,3)in('I61','I62','I63','I64')) or 431<=substr(doedsaars1,1,3)<=436 or /*rettet fra 435 til 436 */
    (substr(doedsaars2,1,3)in('I61','I62','I63','I64')) or 431<=substr(doedsaars2,1,3)<=436 or
    (substr(doedsaars3,1,3)in('I61','I62','I63','I64')) or  431<=substr(doedsaars3,1,3)<=436
   then dod_stroke=1;
   if substr(doedsaars1,1,1)='I'  or 400<=substr(doedsaars1,1,3) <=451 or 
     substr(doedsaars2,1,1)='I'  or 400<=substr(doedsaars2,1,3) <=451 or
     substr(doedsaars3,1,1)='I'  or 400<=substr(doedsaars3,1,3) <=451
   then dod_cv=1; 
  end;

 array doedsaars[13] c_dodtilgrundl_acme c_dod_1A c_dod_1b c_dod_1c c_dod_1d c_dod_21 c_dod_22 c_dod_23 c_dod_24 c_dod_25 c_dod_26 c_dod_27 c_dod_28; /* stavefejl rettet 15.3.12 */
 if doddato>='01JAN2002'd then 
 do i=1 to 13;
  if substr(doedsaars[i],1,3) in ('I21','I22')  then dod_ami=1;
  if substr(doedsaars[i],1,3) in ('I61','I62','I63','I64') then dod_stroke=1;
  if substr(doedsaars[i],1,1)='I' then dod_cv=1;
 end;
run;

proc sort data=doede; by pnr; run;
proc sort data=pnr; by pnr; run;
data k.doede; merge doede (in=data) pnr (in=data2); by pnr;
 if data; if data2;
 label 	pnr='Krypteret CPR nummer'
		dod_cv='doedsaarsag cardiovascular (icd10:I, icd8:400-451)'
		dod_ami='doedsaarsag ami (icd10:I21-22, icd8:410)'
		dod_stroke='doedsaarsag stroke (icd10:I61-64, icd8:431-436)';
drop i;
run;

/* Socioøkonomi - indtægter 
  Linket mellem pnr og indtægt er C-familie indtil 2000 hvorefter det er e-familie*/

/*modificeret således at der tages højde for familiestørrrelse - 
 dvs. hvis der er to voksne i familien divideres familieindkomst med 1.5 til at få individual indkomst (OECD modificeret ækvivalent skala)
 Der laves også indeksreguleret indkomst ift. til stigning i forbrugerindeks fra 1989 til 2009 
 Således opreguleres indkomst så du har ækvivalent indkomst i 1989 som i 2009 ift. forbrugerindeks */

/* NB! Vigtigt at notere at her er tale om skattepligtig indkomst, ikke disponibel indkomst efter skat */ 


/****************LAVER HUSSTANDSINDKOMST ISTEDET FOR FAMILIEINDKOMST FOR AT UNDGÅ MANGE MISSING VALUES***/	
%macro faik;
 %do i=1989 %to 2013;
  data indk&i; set dst.indh&i (keep=pnr PERINDKIALT); year=&i.;run;
 %end;
data indk2014; set dst.ind2014 (keep=pnr perindkialt_13);
perindkialt=perindkialt_13; drop perindkialt_13;
year=2014;
run;
* Samler indkomster fra alle år;
 data indk;
  set %do i=1989 %to 2014; indk&i %end;;
 run;
%mend;
%faik;

%macro bef;
 %do i=1989 %to 2014;
  data bef&i; set dst.bef&i (keep=pnr efalle familie_type); year=&i.;run;

 %end;

* Samler opl om ægtefælle fra alle år;
 data bef;
  set %do i=1989 %to 2014; bef&i %end;;
 run;
%mend;
%bef;

proc sort data=pnr; by pnr; run;
proc sort data=indk; by pnr year; run;
proc sort data=bef; by pnr year; run;

data indk_pnr; merge pnr (in=data) indk;
 by pnr; if data;
run;

data indk_pnr; merge indk_pnr (in=data) bef;
by pnr year; if data;
run;

data indk_cfalle;set indk;
efalle=pnr;
efalle_indk=PERINDKIALT;
keep efalle efalle_indk year;
run;

proc sort data=indk_cfalle; by efalle year; run;
proc sort data= indk_pnr; by efalle year; run;

data indk_pnr; merge indk_pnr (in=data) indk_cfalle;
by efalle year; if data;
run;

data husstandsindk; set indk_pnr;
 hus_indk=PERINDKIALT+efalle_indk;
 if hus_indk=. then hus_indk=PERINDKIALT;
 label indiv_indk='Individualindkomst=hustandsindkomst divideret med 1.5 hvis der er to i familien';
 indiv_indk=round(hus_indk);
 *if familie_type in ('01','02','03','04') then indiv_indk=round(indiv_indk/1.5,1); /* 1.5 er OECD modificerede ækvivalensskala for 2 voksne i famile */
 if 1<=familie_type<=4 then indiv_indk=round(indiv_indk/1.5,1); /* 1.5 er OECD modificerede ækvivalensskala for 2 voksne i famile */
run;

/* Regulerer indkomst iht. stigning i forbrugerindeks i perioden jvf. Danmarks Statistik hvor 2009 har indeks 100 */
/* Indeks fundet på dst.dk/da/Statistik/emner/prisindeks/forbrugerprisindeks-og-aarlig-inflation*/

data husstandsindk; set husstandsindk;
 label hus_indk_index='forbrugerindekseret hustandsindkomst ift. år 2009 '
  indiv_indk_index='forbrugerindekseret indivdualindkomst ift. år 2009 ';
if year=2014 then do;
  hus_indk_index=round(hus_indk*0.916472,1);
  indiv_indk_index=round(indiv_indk*0.916472,1);
 end;
if year=2013 then do;
  hus_indk_index=round(hus_indk*0.921712,1);
  indiv_indk_index=round(indiv_indk*0.921712,1);
 end;
if year=2012 then do;
  hus_indk_index=round(hus_indk*0.928930,1);
  indiv_indk_index=round(indiv_indk*0.928930,1);
 end;
if year=2011 then do; 
  hus_indk_index=round(hus_indk*0.951279,1);
  indiv_indk_index=round(indiv_indk*0.951279,1);
 end;
 if year=2010 then do; 
  hus_indk_index=round(hus_indk*0.977456,1);
  indiv_indk_index=round(indiv_indk*0.977456,1);
 end;
if year=2009 then do; 
  hus_indk_index=round(hus_indk*1.0,1);
  indiv_indk_index=round(indiv_indk*1.0,1);
 end;
 if year=2008 then do; 
  hus_indk_index=round(hus_indk*1.013215,1);
  indiv_indk_index=round(indiv_indk*1.013215,1);
 end;
 if year=2007 then do; 
  hus_indk_index=round(hus_indk*1.047659,1);
  indiv_indk_index=round(indiv_indk*1.047659,1);
 end;
 if year=2006 then do; 
  hus_indk_index=round(hus_indk*1.065593,1);
  indiv_indk_index=round(indiv_indk*1.065593,1);
 end;
 if year=2005 then do; 
  hus_indk_index=round(hus_indk*1.085838,1);
  indiv_indk_index=round(indiv_indk*1.085838,1);
 end;
 if year=2004 then do; 
  hus_indk_index=round(hus_indk*1.105504,1);
  indiv_indk_index=round(indiv_indk*1.105504,1);
 end;
 if year=2003 then do; 
  hus_indk_index=round(hus_indk*1.118285,1);
  indiv_indk_index=round(indiv_indk*1.118285,1);
 end;
 if year=2002 then do; 
  hus_indk_index=round(hus_indk*1.141638,1);
  indiv_indk_index=round(indiv_indk*1.141638,1);
 end;
 if year=2001 then do; 
  hus_indk_index=round(hus_indk*1.169239,1);
  indiv_indk_index=round(indiv_indk*1.169239,1);
 end;
 if year=2000 then do; 
  hus_indk_index=round(hus_indk*1.19684,1);
  indiv_indk_index=round(indiv_indk*1.19684,1);
 end;
 if year=1999 then do; 
  hus_indk_index=round(hus_indk*1.231779,1);
  indiv_indk_index=round(indiv_indk*1.231779,1);
 end;
 if year=1998 then do; 
  hus_indk_index=round(hus_indk*1.26245,1);
  indiv_indk_index=round(indiv_indk*1.26245,1);
 end;
 if year=1997 then do; 
  hus_indk_index=round(hus_indk*1.285685,1);
  indiv_indk_index=round(indiv_indk*1.285686,1);
 end;
 if year=1996 then do; 
  hus_indk_index=round(hus_indk*1.313898,1);
  indiv_indk_index=round(indiv_indk*1.313898,1);
 end;
 if year=1995 then do; 
  hus_indk_index=round(hus_indk*1.341656,1);
  indiv_indk_index=round(indiv_indk*1.341656,1);
 end;
 if year=1994 then do; 
  hus_indk_index=round(hus_indk*1.369717,1);
  indiv_indk_index=round(indiv_indk*1.369717,1);
 end;
 if year=1993 then do; 
  hus_indk_index=round(hus_indk*1.397111,1);
  indiv_indk_index=round(indiv_indk*1.397111,1);
 end;
 if year=1992 then do; 
  hus_indk_index=round(hus_indk*1.414398,1);
  indiv_indk_index=round(indiv_indk*1.414398,1);
 end;
 if year=1991 then do; 
  hus_indk_index=round(hus_indk*1.444291,1);
  indiv_indk_index=round(indiv_indk*1.444291,1);
 end;
 if year=1990 then do; 
  hus_indk_index=round(hus_indk*1.478946,1);
  indiv_indk_index=round(indiv_indk*1.478946,1);
 end;
 if year=1989 then do; 
  hus_indk_index=round(hus_indk*1.517866,1);
  indiv_indk_index=round(indiv_indk*1.517866,1);
 end;
run;
proc sort data=husstandsindk; by pnr; run;
data k.husstandsindk; merge pnr (in=data) husstandsindk (in=data2);
 by pnr;
 if data; if data2;
 label pnr='Krypteret CPR-nummer'
 efalle='Krypteret CPR-nummer på efælle';
run;



/********************** LMDB *****************
Al medicin på begrænset population - pnr
***********************************************/

%macro lmdb;
data lmdb (keep=pnr vnr eksd korr atc strnum apk packsize);
 set %do i=1995 %to 2017; lmdb.lmdb&i (where=(substr(atc,1,1) in ('C','D','L','M','N','S') 
    or substr(atc,1,3) in ('A01','A02','A03','A04','A05','A06','A07','A10','G02','G03','H02','H03',
	'J01','J02','J03','J04','J05','P01','R01','R03','R06','V01','V03','V04') 
    or substr(atc,1,4) in ('G04B')))
%end;;
run;
%mend;
%lmdb;

/* Udvælger relevante population*/
proc sort data=lmdb; by pnr; run;
data lmdb; merge lmdb (in=data2) pnr (in=data); by pnr;
 if data; if data2;
run;


/****Macro til korrektion ***/

%macro korriger(vi,vu);

proc sort data = &vi;
by pnr vnr descending eksd descending korr;
run;

data &vu(drop = slet_apk korr);
set &vi;
retain slet_apk;
by pnr vnr;

	if first.vnr then slet_apk = 0;
	if korr = '1' then do;
		slet_apk = slet_apk + apk;
		delete;
	end;
	if korr = '0' and slet_apk = apk then do;
		slet_apk = 0;
		delete;
	end;
	if korr = '0' and slet_apk > apk then do;
		slet_apk = slet_apk - apk;
		delete;
	end;
	if korr = '0' and slet_apk < apk then do;
		apk = apk - slet_apk;
		slet_apk = 0;
	end;
run;

%mend;
%korriger (lmdb,lmdb);

data k.lmdb; set lmdb (keep=pnr vnr eksd atc strnum apk packsize);
	label pnr='Krypteret cpr nummer';
run;

/*****************************************************************************

Diagnoser - samtlige diagnoser på denne begrænsede population gemmes
Gemmer pnr diagnose inddto uddto og kun for heldøgnsindlæggelser

**************************************************************************/

%macro lpr(direc,start, slut,output);
%do i=&start %to &slut; /* Year interval */
	/* different for lprgrund and lprpriv and different for lprpriv after 1994*/
	data diag&i;  
	%if &direc.=lprpriv %then
		%do; 
			length diag $10;
			set lprpriv.diag&i (keep= recnum diag diagtype %if &i>1994 %then tildiag;);
		%end;
	%if &direc.=lprgrund %then
    	%do;
			length c_diag $10; 
			set lprgrund.lprdiag&i (keep=recnum c_diag c_diagtype %if &i>1994 %then c_tildiag;);
			diag=c_diag; drop c_diag;
	   		diagtype=c_diagtype; drop c_diagtype;
	 		%if &i>1994 %then 
				%do; 
					tildiag=c_tildiag; drop c_tildiag; 
				%end;
    	%end;
	run;
	/* different for lprpriv and lprgrund - and special case for priv in 2008/9*/
	data pop_diag&i; set 
		/*Load data*/
	%if &direc.=lprpriv %then lprpriv.hel&i; 
	%else %if &i<1994 %then lprgrund.lprHEL&i; 
	%else lprgrund.lprPOP&i; 
		/*Keep variables*/
    (keep=pnr recnum 
	%if &direc.=lprpriv %then 
		%do; 
			inddto sgh pattype spec indm
			%if &i<2007 %then nyafd; 
			%else afd; 
			%if &i=2009 or &i=2008 %then d_uddto; 
			%else uddto; 
		%end;
	%if &direc.=lprgrund %then 
		%do; 
			d_inddto d_uddto c_sgh c_pattype c_indm c_spec 
			%if 2003<&i and &i<2008 %then c_nyafd; 
			%else c_afd; 
		%end;
	);
		/*Data management*/
	%if &direc.=lprgrund %then
	   	%do;
			inddto=d_inddto; drop d_inddto;
			uddto=d_uddto; drop d_uddto;
	    	sgh=c_sgh*1; drop c_sgh;  /* *1 to convert from chr to num */
	    	pattype=c_pattype*1;	  drop c_pattype;
			spec=c_spec*1; drop c_spec;
			indm=c_indm*1; drop c_indm;
			%if 2003<&i and &i<2008 %then 
				%do;
					afd=c_nyafd; drop c_nyafd;
				%end;
			%else 
				%do;
					afd=put(c_afd,8. -L); drop c_afd;
				%end;
	   	%end;
	 %if &direc.=lprpriv %then
	   	%do;
	    	sgh2=sgh*1; drop sgh; rename sgh2=sgh;
			spec2=spec*1; drop spec; rename spec2=spec;
			pattype2=pattype*1; drop pattype; rename pattype2=pattype;
			indm2=indm*1; drop indm; rename indm2=indm;
	    	%if &i=2009 or &i=2008 %then
	     		%do;
	      			uddto=d_uddto; drop d_uddto;
	     		%end;
			%if &i<2007 %then
				%do;
					afd=nyafd; drop nyafd;
				%end;
	   	%end;
  	run;

    	/*Sort data*/
	proc sort data=diag&i noduprecs; by recnum; run;
 	proc sort data=pop_diag&i nodupkey; by recnum; run;
		/*Merge*/
	data indl_diag&i; merge diag&i (in=data) pop_diag&i (in=data2); by recnum;
   		if data; if data2;
	run;
%end;
	/*Combine data*/
data &output; length recnum $ 20; format recnum $ 20.; set %do i=&start %to &slut; indl_diag&i %end;; 
  	/* restriction of data lengths */
length inddto 5 uddto 5 sgh 3 pattype 3 spec 3 indm 3; 
run;
	/*Clear up*/
proc datasets library=work memtype=data nolist;
delete diag: indl_diag: pop_diag:;
run;

%mend;

%lpr(lprgrund,1977,2015,offentlig_diag_indl);
%lpr(lprpriv,2002,2012,privat_diag_indl);

data diag_indl; set offentlig_diag_indl privat_diag_indl; run;

proc sort data=diag_indl; by pnr; run;
proc sort data=pnr; by pnr; run;

data k.diag_indl; merge diag_indl (in=data2) pnr (in=data); by pnr;
 if data; if data2;
 label 	pnr='Krypteret CPR-nummer'
		pattype='Patienttype';
run;

proc sort data=k.diag_indl noduprecs; by pnr recnum diag; run;

/*****************************************************************************
Operationer 
**************************************************************************/

%macro opr(direc,filtype,start, slut,output);
%do i=&start. %to &slut.;
	%if &direc.=lprgrund %then 
		%do; 
			data &filtype.&i; set lprgrund.&filtype.&i (keep= recnum c_osgh c_opr c_tilopr d_odto);
				osgh=c_osgh*1; drop c_osgh; 
				opr=c_opr; drop c_opr;
				tilopr=c_tilopr; drop c_tilopr;
				odto=d_odto; drop d_odto;
  			run;
  		%end;
	%if &direc.=lprpriv %then 
		%do;
			data &filtype.&i; set lprpriv.&filtype.&i (keep= recnum osgh opr 
    												   %if not(&i=2007) %then odto tilopr; 
													  );/* Ingen oddto hos private i 2007*/
				osgh1=osgh*1; drop osgh; rename osgh1=osgh;
				opr1=put(opr,8. -L); drop opr; rename opr1=opr;
 			run;
		%end;

 	data pop_opr&i; set 
		/*Load data*/
	%if &direc.=lprpriv %then lprpriv.hel&i; 
	%else %if &i<1994 %then lprgrund.lprHEL&i; 
	%else lprgrund.lprPOP&i;
		/*Keep variables*/
    (keep=pnr recnum 
	%if &direc.=lprpriv %then 
		%do; 
			inddto sgh pattype spec indm
			%if &i=2009 or &i=2008 %then d_uddto; 
			%else uddto; 
		%end;
	%if &direc.=lprgrund %then d_inddto d_uddto c_sgh c_pattype c_spec c_indm; 
    );
		/*Data management*/
	%if &direc.=lprgrund %then
	  	%do;
			inddto=d_inddto; drop d_inddto;
			uddto=d_uddto; drop d_uddto;
	    	sgh=c_sgh*1; drop c_sgh;  
	    	pattype=c_pattype*1; drop c_pattype;
			spec=c_spec*1; drop c_spec;
			indm=c_indm*1; drop c_indm;
	   	%end;
	%if &direc.=lprpriv %then
		%do;
	   		sgh2=sgh*1; drop sgh; rename sgh2=sgh;
			spec2=spec*1; drop spec; rename spec2=spec;
			pattype2=pattype*1; drop pattype; rename pattype2=pattype;
			indm2=indm*1; drop indm; rename indm2=indm;
	   		%if &i=2009 or &i=2008 %then
	   			%do;
	   				uddto=d_uddto; drop d_uddto;
	   			%end;
	   	%end;
	run;
    	/*Sort data*/
	proc sort data=&filtype.&i; by recnum; run;
  	proc sort data=pop_opr&i; by recnum; run; /*recnum er allerede unique*/
		/*Merge*/
	data opr&i; merge &filtype.&i (in=data) pop_opr&i (in=data2); by recnum;
    	if data; if data2;
  	run;
%end;
	/*Combine data*/
data &output; length recnum $ 20; format recnum $ 20.; set %do i=&start. %to &slut.; opr&i %end;; 
	length inddto 5 uddto 5 osgh 3 pattype 3 indm 3; 
run;
	/*Clear up*/
proc datasets library=work memtype=data nolist;
delete opr: pop_opr: &filtype:;
run;

%mend;

%opr(lprgrund,lprsksop,1996,2015,offentlig_opr);
%opr(lprgrund,lprsksub,1999,2015,ube_offentlig);
%opr(lprpriv,sksopr,2002,2012,privat_opr);
%opr(lprpriv,sksube,2002,2012,ube_privat);

data opr; set offentlig_opr privat_opr ube_offentlig ube_privat; run;

proc sort data=opr; by pnr; run;

data k.opr; merge opr (in=data2) pnr (in=data); by pnr;
 if data; if data2;
 label pnr='Krypteret cpr nummer'
 	   pattype='Patienttype';
 run;

proc sort data=k.opr noduprecs; by pnr recnum opr; run;

/*************************************************************
Uddannelse
*************************************************************/
%macro uddan;
 %do i=1981 %to 2016;
  data uddan&i; set dst.udda&i;
   year=&i;
   if hfaudd='' then delete;
  run;
 %end;
 data uddan; 
  set %do i=1981 %to 2016; uddan&i %end;;
 run;
%mend;
%uddan;

proc sort data=uddan; by pnr year; run;

data k.uddan; merge uddan (in=data2) pnr(in=data); by pnr ;
 if data; if data2;
run;


/************************************************************
KOTRE
**********************************************************************/

data kotre2016; set dst.kotre2016; run;
proc sort data=kotre2016; by pnr; run;

data k.kotre2016; merge kotre2016 (in=data) pnr (in=data2); by pnr;
 if data; if data2;
 label pnr='Krypteret cpr nummer';
 run;

