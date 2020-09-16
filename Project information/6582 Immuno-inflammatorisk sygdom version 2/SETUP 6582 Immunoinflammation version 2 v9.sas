/***********************************************************

Immunoinflammation Version 2 - start 2.3.2017

9-4-18: LFC - Tilf�jelse af kommuneoplysninger
31-8-18: LFC - opdatering i tid
20-12-18: JHW: Opdatering i tid
1-2-19: Tilf�jelse af ATC-kode A12
12/6/19: tilf�jelse af plejehjem
*****************************************************************/

libname pop 'X:\Data\Rawdata_Hurtig\703573\pop';
libname dst 'X:\Data\Rawdata_Hurtig\703573\DST';
libname lmdb 'X:\Data\Rawdata_Hurtig\703573\LMDB';
libname hj 'X:\Data\Rawdata_Hurtig\703573\Hjertestop';
libname lprgrund 'X:\Data\Rawdata_Hurtig\703573\LPRGrund';
libname lprpriv 'X:\Data\Rawdata_Hurtig\703573\LPRPrivat';
libname dnsl 'X:\Data\Rawdata_Hurtig\703573\Nyreregister';
libname ekstd 'X:\Data\Rawdata_Hurtig\703573\Hudsygdomme';
libname kbhamt 'X:\Data\Rawdata_Hurtig\703573\Blodpr�ver\Kbh amt';
libname kpll 'X:\Data\Rawdata_Hurtig\703573\Blodpr�ver\KPLL';
libname nord 'X:\Data\Rawdata_Hurtig\703573\Blodpr�ver\Reg_Nord';
libname roskilde 'X:\Data\Rawdata_Hurtig\703573\Blodpr�ver\Roskilde';
libname blodprov 'X:\Data\Rawdata_Hurtig\703573\Blodpr�ver';
libname plhjem 'X:\Data\Rawdata_Hurtig\703573\Plejehjem';


libname K 'X:\Data\Workdata_Hurtig\703573\6582 Inflammation';
options mergenoby=error;
options validvarname=any;
options nofmterr;


/*****************  POP ***********************************

Indeholder data fra:

- POP 
- seneste udvandring 
- f�rste indvandring
- seneste uddannelse og dato for denne
- f�rste �r hvor pt er kendt i cpr (fain bef)
- dansker/indvandrer/efterkommer 
- oprindelsesland samt type 
- check af cpr-nummer

**************************************************************/
data pop; set pop.pop; 
 fdato=mdy(month(fdato),15,year(fdato));
run;

*F�rste indvandring og seneste udvandring fra DK;
data vandring_ind; set dst.vnds2017;
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

data vandring_ud; set dst.vnds2017;
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
  set %do i= 1980 %to 2016; dst.iepe&i %end;;
 run;
%mend;
%iepe;
proc sort data=iepe; by pnr; run;
data iepe; set iepe;
 by pnr;
 if last.pnr; run;
run;

* F�rste registrering i Familie FAIN og BEF;
%macro fain;
 %do i=1980 %to 2007;
  data fain&i; set dst.fain&i (keep=pnr);
   length bef_year 3;
   bef_year=&i;
  run;
 %end;
 %do i=1986 %to 2018;
  data bef&i; set dst.bef&i (keep=pnr);
   length bef_year 3;
   bef_year=&i;
  run;
 %end;
 data bef_fain; set
  %do i=1980 %to 2007; fain&i  %end;
  %do i=1986 %to 2018; bef&i %end;;
 run;
%mend;
%fain;

proc sort data=bef_fain; by pnr bef_year; run;

data bef_fain; set bef_fain;
 by pnr;
 if first.pnr;
run;
*d�de;
data dod; set dst.dod2017 (keep= pnr doddato); rename doddato=dodsdato; run;
*Samle befolkning;
proc sort data=pop; by pnr; run;
proc sort data=vandring_ind; by pnr; run;
proc sort data=vandring_ud; by pnr; run;
proc sort data=iepe; by pnr; run;
proc sort data=bef_fain; by pnr; run;
proc sort data=dod; by pnr; run;

data pop; merge pop vandring_ind vandring_ud iepe bef_fain dod; by pnr;
if not first.pnr then delete; /*fjerner 2 dobbeltg�ngere om hvem man intet ved*/
*fjerner personer uden k�n og definerer vanlig sex;
if kon='' then delete;
sex=kon=1; drop kon;
* fjerner m�rkelige cpr-numre;
if _cprchk_=0; if _cprtype_=1;

drop _cprchk_ _cprtype_ haend_dato;
run;
proc sort data=pop; by pnr; run;


data k.pop; set pop;
 if dodsdato<'01JAN1990'd and dodsdato ne . then delete;
 label bef_year='Sidste �r med registrering i BEF-register (BEF: Oplysninger om befolkningen)'
	fdato='Afrundet f�dselsdato til den 15. i m�neden'
	first_ind='Dato for f�rste indvandring'
	first_ud='Dato for f�rste udvandring'
	last_ind='Dato for sidste indvandring'
	last_ud='Dato for sidste udvandring'
	pnr='Krypteret CPR nummer'
	sex='K�n (0:Kvinde; 1:Mand)';
	drop dodsdato;
run;



/******************************************************************************************
 PNR
*******************************************************************************************/
data pnr; set K.pop (keep=pnr);
run;
proc sort data=pnr nodupkey; by pnr; run;
data k.pnr; set pnr; run;

/***************************************************************

D�de og D�ds�rsager

Bem�rk at d�ds�rsager EFTER 2001 k�rer efter en anden skala

Denne programstump beregner ogs� en r�kke vanligt brugte d�ds�rsager
Opdateret til ny nomenklatur efter marts 2012

****************************************************************/


data doede; merge dst.dod2013 dst.dod2017; by pnr;
if doddato>'01JAN2002'd then do;
	doedsaars1=''; 
	doedsaars2=''; 
	doedsaars3=''; 
	doedsaars4=''; 
end;
run;

data doede2; set dst.dodsaasg2016;
/* drop C_bopkom c_region c_bopkomf07 c_bopamtF07 C_liste14 C_liste49 d_dodsdato d_findedato d_statdato c_dodsmaade
   c_dodssted c_praecis_dodssted C_FINDESTED C_PRAECIS_FINDESTED C_HAENDELSESSTED C_OBDUKTION c_operation c_laegefunktion
   v_alder c_sex /*15.3.12- tilgrundl�ggende d�d ikke fjernet l�ngere*/ ;
run;

proc sort data=doede; by pnr; run;
proc sort data=doede2; by pnr; run;

data doede; merge doede doede2; by pnr;
if first.pnr;* Removes 4 doublicate death records;
if doddato<'01JAN2002'd then do;
	if 	(substr(doedsaars1,1,3)in('I21','I22') ) or substr(doedsaars1,1,3)='410' or
		(substr(doedsaars2,1,3)in('I21','I22') ) or substr(doedsaars2,1,3)='410' or
		(substr(doedsaars3,1,3)in('I21','I22') ) or substr(doedsaars3,1,3)='410'  
	then dod_ami=1;
	if 	(substr(doedsaars1,1,3)in('I61','I62','I63','I64')) or '431'<=substr(doedsaars1,1,3)<='436' or /*rettet fra 435 til 436 */
		(substr(doedsaars2,1,3)in('I61','I62','I63','I64')) or '431'<=substr(doedsaars2,1,3)<='436' or
		(substr(doedsaars3,1,3)in('I61','I62','I63','I64')) or '431'<=substr(doedsaars3,1,3)<='436'
	then dod_stroke=1;
	if 	substr(doedsaars1,1,1)='I'  or '400'<=substr(doedsaars1,1,3) <='451' or 
	 	substr(doedsaars2,1,1)='I'  or '400'<=substr(doedsaars2,1,3) <='451' or
	 	substr(doedsaars3,1,1)='I'  or '400'<=substr(doedsaars3,1,3) <='451'
	then dod_cv=1; 
end;

array doedsaars[13] c_dodtilgrundl_acme c_dod_1A c_dod_1b c_dod_1c c_dod_1d c_dod_21 c_dod_22 c_dod_23 c_dod_24 c_dod_25 c_dod_26 c_dod_27 c_dod_28; /* stavefejl rettet 15.3.12 */
if doddato>='01JAN2002'd then do i=1 to 13;
	if 	substr(doedsaars[i],1,3) in ('I21','I22')				then dod_ami=1;
	if 	substr(doedsaars[i],1,3) in ('I61','I62','I63','I64') 	then dod_stroke=1;
	if 	substr(doedsaars[i],1,1)='I' 							then dod_cv=1;
end;
run;

proc sort data=doede; by pnr; run;
proc sort data=pnr; by pnr; run;

data k.doede; merge doede (in=data) pnr (in=data2); by pnr;
if data; 
if data2;
label	pnr='Krypteret CPR nummer'
		dod_cv='doedsaarsag cardiovascular (icd10:I, icd8:400-451)'
		dod_ami='doedsaarsag ami (icd10:I21-22, icd8:410)'
		dod_stroke='doedsaarsag stroke (icd10:I61-64, icd8:431-436)';
drop i;
run;

/* Socio�konomi - indt�gter 
  Linket mellem pnr og indt�gt er C-familie indtil 2000 hvorefter det er e-familie*/

/*modificeret s�ledes at der tages h�jde for familiest�rrrelse - 
 dvs. hvis der er to voksne i familien divideres familieindkomst med 1.5 til at f� individual indkomst (OECD modificeret �kvivalent skala)
 Der laves ogs� indeksreguleret indkomst ift. til stigning i forbrugerindeks fra 1989 til 2009 
 S�ledes opreguleres indkomst s� du har �kvivalent indkomst i 1989 som i 2009 ift. forbrugerindeks */

/* NB! Vigtigt at notere at her er tale om skattepligtig indkomst, ikke disponibel indkomst efter skat */ 


/****************LAVER HUSSTANDSINDKOMST ISTEDET FOR FAMILIEINDKOMST FOR AT UNDG� MANGE MISSING VALUES***/	
%macro faik;
 %do i=1989 %to 2017;
 	data indk&i; set dst.ind&i (keep=pnr aekvivadisp_13 PERINDKIALT_13); 
		year=&i.;
  	run;
 %end;
* Samler indkomster fra alle �r;
 data indk;
	set %do i=1989 %to 2017; indk&i %end;;
 run;
 	/*Clear up*/
proc datasets library=work memtype=data nolist;
delete %do i=1989 %to 2017; indk&i %end; ;
run;
%mend;
%faik;

%macro bef;
 %do i=1989 %to 2018;
  data bef&i; set dst.bef&i (keep=pnr efalle familie_type); 
	year=&i.;
  run;

 %end;

* Samler opl om �gtef�lle fra alle �r;
 data bef;
  set %do i=1989 %to 2018; bef&i %end;;
 run;
 	/*Clear up*/
proc datasets library=work memtype=data nolist;
delete %do i=1989 %to 2018; bef&i %end; ;
run;
%mend;
%bef;


proc sort data=indk; by pnr year; run;
proc sort data=bef; by pnr year; run;

data indk_pnr; merge k.pnr (in=data) indk;
 by pnr; if data;
run;

data indk_pnr; merge indk_pnr (in=data) bef;
by pnr year; if data;
run;

data indk_cfalle;set indk;
efalle=pnr;
efalle_indk=PERINDKIALT_13;
keep efalle efalle_indk year;
run;

proc sort data=indk_cfalle; by efalle year; run;
proc sort data= indk_pnr; by efalle year; run;

data indk_pnr; merge indk_pnr (in=data) indk_cfalle; 
by efalle year; if data;
run;

data husstandsindk; set indk_pnr;
 hus_indk=PERINDKIALT_13+efalle_indk;
 if hus_indk=. then hus_indk=PERINDKIALT_13;
 label indiv_indk='Individualindkomst=hustandsindkomst divideret med 1.5 hvis der er to i familien';
 indiv_indk=round(hus_indk);
 *if familie_type in ('01','02','03','04') then indiv_indk=round(indiv_indk/1.5,1); /* 1.5 er OECD modificerede �kvivalensskala for 2 voksne i famile */
 if 1<=familie_type<=4 then indiv_indk=round(indiv_indk/1.5,1); /* 1.5 er OECD modificerede �kvivalensskala for 2 voksne i famile */
run;

/* Regulerer indkomst iht. stigning i forbrugerindeks i perioden jvf. Danmarks Statistik hvor 2015 har indeks 100 */

data husstandsindk; set husstandsindk;
 label hus_indk_index='forbrugerindekseret hustandsindkomst ift. �r 2015 '
  indiv_indk_index='forbrugerindekseret individual indkomst ift. �r 2015 ';
if year=2017 then do; 
  hus_indk_index=round(hus_indk*0.986,1);
  indiv_indk_index=round(indiv_indk*0.986,1);
 end;
if year=2016 then do; 
  hus_indk_index=round(hus_indk*0.997,1);
  indiv_indk_index=round(indiv_indk*0.997,1);
 end;
if year=2015 then do; 
  hus_indk_index=round(hus_indk*1.0,1);
  indiv_indk_index=round(indiv_indk*1.0,1);
 end;
if year=2014 then do; 
  hus_indk_index=round(hus_indk*1.002,1);
  indiv_indk_index=round(indiv_indk*1.002,1);
 end;
if year=2013 then do; 
  hus_indk_index=round(hus_indk*1.008,1);
  indiv_indk_index=round(indiv_indk*1.008,1);
 end;
if year=2012 then do; 
  hus_indk_index=round(hus_indk*1.0161,1);
  indiv_indk_index=round(indiv_indk*1.0161,1);
 end;
if year=2011 then do; 
  hus_indk_index=round(hus_indk*1.040437001,1);
  indiv_indk_index=round(indiv_indk*1.040437001,1);
 end;
 if year=2010 then do; 
  hus_indk_index=round(hus_indk*1.069569237,1);
  indiv_indk_index=round(indiv_indk*1.069569237,1);
 end;
if year=2009 then do; 
  hus_indk_index=round(hus_indk*1.09416933,1);
  indiv_indk_index=round(indiv_indk*1.09416933,1);
 end;
 if year=2008 then do; 
  hus_indk_index=round(hus_indk*1.108393531,1);
  indiv_indk_index=round(indiv_indk*1.108393531,1);
 end;
 if year=2007 then do; 
  hus_indk_index=round(hus_indk*1.146078911,1);
  indiv_indk_index=round(indiv_indk*1.146078911,1);
 end;
 if year=2006 then do; 
  hus_indk_index=round(hus_indk*1.165562252,1);
  indiv_indk_index=round(indiv_indk*1.165562252,1);
 end;
 if year=2005 then do; 
  hus_indk_index=round(hus_indk*1.187707935,1);
  indiv_indk_index=round(indiv_indk*1.187707935,1);
 end;
 if year=2004 then do; 
  hus_indk_index=round(hus_indk*1.209086678,1);
  indiv_indk_index=round(indiv_indk*1.209086678,1);
 end;
 if year=2003 then do; 
  hus_indk_index=round(hus_indk*1.223595718,1);
  indiv_indk_index=round(indiv_indk*1.223595718,1);
 end;
 if year=2002 then do; 
  hus_indk_index=round(hus_indk*1.249291228,1);
  indiv_indk_index=round(indiv_indk*1.249291228,1);
 end;
 if year=2001 then do; 
  hus_indk_index=round(hus_indk*1.279274218,1);
  indiv_indk_index=round(indiv_indk*1.279274218,1);
 end;
 if year=2000 then do; 
  hus_indk_index=round(hus_indk*1.309976799,1);
  indiv_indk_index=round(indiv_indk*1.309976799,1);
 end;
 if year=1999 then do; 
  hus_indk_index=round(hus_indk*1.347966126,1);
  indiv_indk_index=round(indiv_indk*1.347966126,1);
 end;
 if year=1998 then do; 
  hus_indk_index=round(hus_indk*1.381665279,1);
  indiv_indk_index=round(indiv_indk*1.381665279,1);
 end;
 if year=1997 then do; 
  hus_indk_index=round(hus_indk*1.406535254,1);
  indiv_indk_index=round(indiv_indk*1.406535254,1);
 end;
 if year=1996 then do; 
  hus_indk_index=round(hus_indk*1.43747903,1);
  indiv_indk_index=round(indiv_indk*1.43747903,1);
 end;
 if year=1995 then do; 
  hus_indk_index=round(hus_indk*1.469103569,1);
  indiv_indk_index=round(indiv_indk*1.469103569,1);
 end;
 if year=1994 then do; 
  hus_indk_index=round(hus_indk*1.499954743,1);
  indiv_indk_index=round(indiv_indk*1.499954743,1);
 end;
 if year=1993 then do; 
  hus_indk_index=round(hus_indk*1.529953838,1);
  indiv_indk_index=round(indiv_indk*1.529953838,1);
 end;
 if year=1992 then do; 
  hus_indk_index=round(hus_indk*1.548313284,1);
  indiv_indk_index=round(indiv_indk*1.548313284,1);
 end;
 if year=1991 then do; 
  hus_indk_index=round(hus_indk*1.580827863,1);
  indiv_indk_index=round(indiv_indk*1.580827863,1);
 end;
 if year=1990 then do; 
  hus_indk_index=round(hus_indk*1.618767732,1);
  indiv_indk_index=round(indiv_indk*1.618767732,1);
 end;
 if year=1989 then do; 
  hus_indk_index=round(hus_indk*1.660855693,1);
  indiv_indk_index=round(indiv_indk*1.660855693,1);
 end;
run;


proc sort data=husstandsindk; by pnr; run;
data k.husstandsindk; merge k.pnr (in=data) husstandsindk (in=data2);
 by pnr;
 if data; if data2;
 label pnr='Krypteret CPR-nummer'
 efalle='Krypteret CPR-nummer p� ef�lle';
run;

 	/*Final clear up*/
proc datasets library=work memtype=data nolist;
delete husstandsindk indk_pnr indk_cfalle indk bef;
run;

/********************** LMDB *****************
Begr�nset medicin p� begr�nset population - pnr
***********************************************/
%macro lmdb;
data lmdb (keep=pnr vnr eksd korr atc strnum apk packsize);
 set %do i=1995 %to 2018; lmdb.lmdb&i (where=(substr(atc,1,1) in ('C','D','M','N','S','L') 
    or substr(atc,1,3) in ('A01','A02','A03','A04','A05','A06','A07','A10','A12','B01','G03','H02','H03','J01','J02','J03','J04','J05','P01','R01','R03','R05','R06','R07','V01','V03','V04','V08') 
    or substr(atc,1,4) in ('G04B')))
%end;;
run;
%mend;
%lmdb;

/* Udv�lger relevante population*/

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


/**************************************************************** 

 indl_hel v1 (21/7-16 - �ndret af Regitze)

 Finder samtlige held�gnsindl�ggelser (pattype=0)
 - kan bruges til at korrigere for indl�ggelser i medicinmacroen

2017-11-02: length og format af recnum
			general ops�tning

2017-12-04: tilf�jet indm og c_indm

******************************************************************/
%macro indl_hel(direc,start, slut,output);
%do i=&start %to &slut;
	/*DATA*/
	data pop&i; set 
	%if &direc=lprpriv %then lprpriv.lppadm&i; 
	%else lprgrund.lpradm&i; 
	/*KEEP*/
  	(keep=pnr recnum d_inddto d_uddto c_pattype c_indm);
	/*Data management*/
		inddto=d_inddto; drop d_inddto;
		uddto=d_uddto; drop d_uddto;
	    pattype=c_pattype*1; drop c_pattype;
		indm=c_indm*1; drop c_indm;
	run;
%end;

data &output; length recnum $ 20; format recnum $ 20.; set %do i=&start %to &slut; pop&i %end;; 
	where pattype=0;
	length inddto 5 uddto 5 pattype 3 indm 3;
run;

  	/*Clear up*/
proc datasets library=work memtype=data nolist;
delete %do i=&start %to &slut; pop&i %end; ;
run;
%mend;

%indl_hel(lprgrund,1994,2017,Indl_off);
%indl_hel(lprpriv,2002,2017,Indl_priv);

data indl_heldoegn; set Indl_off Indl_priv;
 pnr_ind=pnr||inddto;
 if uddto eq . then delete;
run;

proc sort data=indl_heldoegn;
 by pnr_ind descending uddto;
run;

data indl_heldoegn; set indl_heldoegn;
 by pnr_ind ;
 if first.pnr_ind;
 drop pnr_ind;
 label pnr='Krypteret cpr nummer';
run;

proc sort data=indl_heldoegn; by pnr; run;

data k.indl_heldoegn; merge indl_heldoegn (in=data) k.pnr (in=data2);
	by pnr;
	if data; if data2;
run;


/*****************************************************************************

Diagnoser - samtlige diagnoser p� denne begr�nsede population gemmes
2017-10-31: length af diag koder 
2017-11-01: length og format af recnum i merge 
2018-02-28: opdateret ift. ny levering af lpr, hvor lprhel og lprpop udg�r og lpradm kommer i stedet. 
			Variablen diagmod tilf�jes (OBS at denne variabel er tom i 1994).
2018-08-07: Tilf�jelse af uafsluttede diagnoser - seneste datas�t er nok, hvorfor det ikke er sat ind selve makroen.
**************************************************************************/


%macro lpr(direc,start, slut,output);
%do i=&start %to &slut; /* Year interval */
	/* different for lprgrund and lprpriv and different for lprpriv after 1994*/
	data diag&i;  
	%if &direc.=lprpriv %then
		%do; 
			length c_diag $10;
			set lprpriv.lppdiag&i (keep= recnum C_DIAG C_DIAGTYPE C_TILDIAG);
			diag=c_diag; drop c_diag;
	   		diagtype=c_diagtype; drop c_diagtype;
			tildiag=c_tildiag; drop c_tildiag; 
		%end;
	%if &direc.=lprgrund %then
    	%do;
			length c_diag $10; 
			set lprgrund.lprdiag&i (keep=recnum c_diag c_diagtype %if &i>1994 %then c_tildiag; %else c_diagmod;);
			diag=c_diag; drop c_diag;
	   		diagtype=c_diagtype; drop c_diagtype;
	 		%if &i>1994 %then 
				%do; 
					tildiag=c_tildiag; drop c_tildiag; 
				%end;
			%if &i<1995 %then 
				%do; 
					diagmod=c_diagmod; drop c_diagmod; 
				%end;
    	%end;
		/*Her inds�ttes if-statement, hvis der er afgr�nsning i diagnoser*/
	run;

	/* different for lprpriv and lprgrund - and special case for priv in 2008/9*/
	data pop_diag&i; set 
		/*Load data*/
	%if &direc.=lprpriv %then lprpriv.lppadm&i; 
	%else lprgrund.lpradm&i; 
		/*Keep variables*/
    (keep=pnr recnum 
	%if &direc.=lprpriv %then 
		D_INDDTO C_SGH C_PATTYPE C_SPEC C_INDM C_AFD D_UDDTO;
	%if &direc.=lprgrund %then 
		d_inddto d_uddto c_sgh c_pattype c_indm c_spec c_afd; 
	);
		/*Renaming and converting variables*/
	%if &direc.=lprgrund %then
	   	%do;
			inddto=d_inddto; drop d_inddto;
			uddto=d_uddto; drop d_uddto;
	    	sgh=c_sgh*1; drop c_sgh;  /* *1 to convert from chr to num */
	    	pattype=c_pattype*1;	  drop c_pattype;
			spec=c_spec*1; drop c_spec;
			indm=c_indm*1; drop c_indm;
			afd=c_afd; drop c_afd;
	  	%end;
	 %if &direc.=lprpriv %then
	   	%do;
			inddto=d_inddto; drop d_inddto;
			uddto=d_uddto; drop d_uddto;
	    	sgh=c_sgh*1; drop c_sgh;  /* *1 to convert from chr to num */
	    	pattype=c_pattype*1;	  drop c_pattype;
			spec=c_spec*1; drop c_spec;
			indm=c_indm*1; drop c_indm;
			afd=c_afd; drop c_afd;
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
length inddto 5 uddto 5 sgh 4 pattype 3 indm 3; 
run;
	/*Clear up*/
proc datasets library=work memtype=data nolist;
delete diag: indl_diag: pop_diag:;
run;

%mend;

%lpr(lprgrund,1977,2017,offentlig_diag_indl);
%lpr(lprpriv,2002,2017,privat_diag_indl);

/************** Uafsluttede diagnoser i LPR *******************/
data uafadm; set lprgrund.lpuadm2017 (keep=pnr recnum d_inddto d_uddto c_sgh c_pattype c_indm c_spec c_afd);
	inddto=d_inddto; drop d_inddto;
	uddto=d_uddto; drop d_uddto;
	sgh=c_sgh*1; drop c_sgh;  /* *1 to convert from chr to num */
	pattype=c_pattype*1;	  drop c_pattype;
	spec=c_spec*1; drop c_spec;
	indm=c_indm*1; drop c_indm;
	afd=c_afd; drop c_afd;
run;
proc sort data=uafadm nodupkey; by recnum; run;

data uafdiag; set lprgrund.lpudiag2017 (keep=recnum c_diag c_diagtype c_tildiag);
	diag=c_diag; drop c_diag;
	diagtype=c_diagtype; drop c_diagtype;
	tildiag=c_tildiag; drop c_tildiag;
	/*Her inds�ttes if-statement, hvis der er afgr�nsning i diagnoser*/
run;

proc sort data=uafdiag noduprecs; by recnum; run;

data diaguaf; merge uafadm (in=data) uafdiag (in=data2);
	by recnum;
	if data; if data2;
	length recnum $ 20; format recnum $ 20.;
	length inddto 5 uddto 5 sgh 4 pattype 3 indm 3;
run;

/* Samler private, offentlige og uafsluttede diagnoser i et datas�t */
data diag_indl; set offentlig_diag_indl privat_diag_indl diaguaf; run;

proc sort data=diag_indl; by pnr; run;
proc sort data=k.pnr; by pnr; run;

data k.diag_indl; merge diag_indl (in=data2) k.pnr (in=data); by pnr;
 if data; if data2;
 label 	pnr='Krypteret CPR-nummer'
		pattype='Patienttype';
run;

proc sort data=k.diag_indl noduprecs; by pnr recnum diag; run;

/**************************
Ambulante bes�g tilf�jet  23.6.19 CTP
**************************************/
/* ambulante bes�gsdatoer - tilf�jes EFTER diag_indl */
%macro amb(direc,start, slut,output);
	%do i=&start %to &slut;
		data bes&i; set 
			%if &direc.=lprgrund %then %do; 
				&&direc..lprbes&i (keep=recnum d_ambdto); 
				ambdto=d_ambdto; drop d_ambdto;
			%end;
			%else %do; 
				&&direc..lppbes&i (keep=recnum d_ambdto);
				ambdto=d_ambdto; drop d_ambdto;
			%end;

			run;
		
	%end;
  	

	data &output; 
	length recnum $ 20; format recnum $ 20.;	
	set 
	%do i=&start %to &slut; 
			bes&i 
		%end;;
  	run;

	proc datasets library=work memtype=data nolist;
	delete bes: ;
	run;
%mend;

%amb(lprgrund, 1994, 2017, amb_off)
%amb(lprpriv,2002,2017, amb_priv) 

data uafbes; set lprgrund.lpubes2017 (keep=recnum d_ambdto);
	ambdto=d_ambdto; drop d_ambdto;
	length recnum $ 20; format recnum $ 20.;
run;

data k.amb_datoer; set amb_priv amb_off uafbes; run;

/***********************************
Psyk diagnoser
***********************************/
data lpsydiag; set lprgrund.lpsdiag2017;
	diag=c_diag; tildiag=c_tildiag; diagtype=c_diagtype;
	drop c_diag c_tildiag c_diagtype;
run;

data lpsyadm; set lprgrund.lpsadm2017 (keep= pnr recnum d_inddto d_uddto c_sgh c_pattype c_spec);
	inddto=d_inddto; drop d_inddto;
	uddto=d_uddto; drop d_uddto;
	sgh=c_sgh; drop c_sgh;
	pattype=c_pattype; drop c_pattype;
	spec=c_spec; drop c_spec;
run;

proc sort data=lpsydiag noduprecs; by recnum; run;
proc sort data=lpsyadm nodupkey; by recnum; run;

data k.lpsy_diag_indl; merge lpsyadm(in=data1) lpsydiag(in=data2); 
	by recnum;
	if data2; if data1;
run;

proc sort data=k.lpsy_diag_indl; by pnr; run;

data k.lpsy_diag_indl; merge k.lpsy_diag_indl(in=data) k.pnr(in=data1);
	by pnr;
	if data1; if data;
	label pnr='Krypteret personnummer'
		pattype='Patienttype';
run;

proc sort data=k.lpsy_diag_indl noduprecs; by pnr recnum diag; run;

/*************************************************************
Operationer
*************************************************************/

%macro opr(direc,filtype,start, slut,output);
%do i=&start. %to &slut.;
	%if &direc.=lprgrund %then 
		%do; 
			data &filtype.&i; set lprgrund.&filtype.&i (keep= recnum c_osgh c_opr c_tilopr d_odto);
				osgh=c_osgh*1; drop c_osgh; 
				opr=c_opr; drop c_opr;
				tilopr=c_tilopr; drop c_tilopr;
				odto=d_odto; drop d_odto;
				/*Her inds�ttes if-statement, hvis der er afgr�nsning*/
  			run;
  		%end;
	%if &direc.=lprpriv %then 
		%do;
			data &filtype.&i; set lprpriv.&filtype.&i (keep= recnum c_osgh c_opr C_TILOPR d_odto);
				osgh=c_osgh*1; drop c_osgh; 
				opr=c_opr; drop c_opr;
				tilopr=c_tilopr; drop c_tilopr;
				odto=d_odto; drop d_odto;
				/*Her inds�ttes if-statement, hvis der er afgr�nsning*/
 			run;
		%end;

 	data pop_opr&i; set 
		/*Load data*/
	%if &direc.=lprpriv %then lprpriv.lppadm&i; 
	%else lprgrund.lpradm&i;
		/*Keep variables*/
    (keep=pnr recnum d_inddto d_uddto c_sgh c_pattype c_spec c_indm);
		/*Data management*/
			inddto=d_inddto; drop d_inddto;
			uddto=d_uddto; drop d_uddto;
	    	sgh=c_sgh*1; drop c_sgh;  
	    	pattype=c_pattype*1; drop c_pattype;
			spec=c_spec*1; drop c_spec;
			indm=c_indm*1; drop c_indm;
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
	length inddto 5 uddto 5 osgh 4 sgh 4  pattype 3 indm 3; 
run;
	/*Clear up*/
proc datasets library=work memtype=data nolist;
delete opr: pop_opr: &filtype:;
run;

%mend;

%opr(lprgrund,lprsksop,1996,2017,offentlig_opr);
%opr(lprgrund,lprsksub,1999,2017,ube_offentlig);
%opr(lprpriv,lppsksop,2002,2017,privat_opr);
%opr(lprpriv,lppsksub,2002,2017,ube_privat);

data uafadm; set lprgrund.lpuadm2017 (keep=pnr recnum d_inddto d_uddto c_sgh c_pattype c_spec c_indm);
	inddto=d_inddto; drop d_inddto;
	uddto=d_uddto; drop d_uddto;
	sgh=c_sgh*1; drop c_sgh;  /* *1 to convert from chr to num */
	pattype=c_pattype*1;	  drop c_pattype;
	spec=c_spec*1; drop c_spec;
	indm=c_indm*1; drop c_indm;
run;
proc sort data=uafadm nodupkey; by recnum; run;

data uafopr; set lprgrund.lpusksop2017 (keep=recnum c_osgh c_opr c_tilopr d_odto);
	osgh=c_osgh*1; drop c_osgh; 
	opr=c_opr; drop c_opr;
	tilopr=c_tilopr; drop c_tilopr;
	odto=d_odto; drop d_odto;
	/*Her inds�ttes if-statement, hvis der er afgr�nsning*/
run;
data uafube; set lprgrund.lpusksub2017 (keep=recnum c_osgh c_opr c_tilopr d_odto);
	osgh=c_osgh*1; drop c_osgh; 
	opr=c_opr; drop c_opr;
	tilopr=c_tilopr; drop c_tilopr;
	odto=d_odto; drop d_odto;
	/*Her inds�ttes if-statement, hvis der er afgr�nsning*/
run;

data uafopr2; set uafopr uafube; run;
proc sort data=uafopr2 noduprecs; by recnum; run;

data opruaf; merge uafadm (in=data) uafopr2 (in=data2);
	by recnum;
	if data; if data2;
	length recnum $ 20; format recnum $ 20.;
	length inddto 5 uddto 5 osgh 4 sgh 4 pattype 3 indm 3;
run;

data opr; set offentlig_opr privat_opr ube_offentlig ube_privat opruaf; run;

proc sort data=opr; by pnr; run;

data k.opr; merge opr (in=data2) k.pnr (in=data); by pnr;
 if data; if data2;
 label pnr='Krypteret cpr nummer'
 	   pattype='Patienttype';
 run;

/*Ikke sikkert den fjerner alle "duplicate records"*/
proc sort data=k.opr noduprecs; by pnr recnum opr; run;



/*************************************************************
Uddannelse
*************************************************************/
%macro uddan;
 %do i=1981 %to 2018;
  data uddan&i; set dst.udda&i;
   year=&i;
   if hfaudd='' then delete;
  run;
 %end;
 data uddan; 
  set %do i=1981 %to 2018; uddan&i %end;;
 run;
 	/*Clear up*/
proc datasets library=work memtype=data nolist;
delete %do i=1981 %to 2018; uddan&i %end; ;
run;
%mend;
%uddan;

proc sort data=uddan; by pnr year; run;

data k.uddan; merge uddan (in=data2) k.pnr(in=data); by pnr ;
 if data; if data2;
run;

	/*Clear up*/
proc datasets library=work memtype=data nolist;
delete uddan;
run;


*Uddannelser grupperes efter DISCED skala, vha. sas formatkoder fra DST;

*----------------------------------------------------*
* Allokering af SAS-formater i Danmarks Statistik    *
* Hostede forskermaskiner                            *
*----------------------------------------------------;
libname fmt '\\srvfsenas3\formater\SAS formater i Danmarks Statistik\FORMATKATALOG' access=readonly;
options fmtsearch=(fmt.disced);

data k.uddan; set k.uddan;
udd_niveau_k=put(hfaudd, Audd_niveau_l1l2_k.);
udd_niveau_t=put(hfaudd, Audd_niveau_l1l2_t.);
*drop hfaudd;
label udd_niveau_k='Kode for uddannelsesniveau for h�jst fuldf�rte uddannelse (hfaudd) - grupperet iflg. DISCED'
udd_niveau_t='Tekst for uddannelsesniveau for h�jst fuldf�rte uddannelse (hfaudd) - grupperet iflg. DISCED'
pnr='Krypteret cpr nummer';
run;



/* Thyroideatal fra 2000-2013 samlet i en fil  */
%macro thyr (start, slut, output);
 %do i=&start %to &slut;
  data thyroidea_&i; set kpll.thyroidea_&i;run;
 %end;

* Samler;
 data &output;
  set %do i=&start %to &slut; thyroidea_&i %end;;
 run;
%mend;
%thyr(2000,2013,thyroideatal)

proc sort data=thyroideatal; by pnr; run;
proc sort data=pnr; by pnr; run;

data k.thyroidea; merge pnr (in=data) thyroideatal (in=data2);
 by pnr;
 if data; if data2;
run;


/** Nyreregister - 12-05-2014 / GG **/


data k.dnsl_2013; merge pnr (in=data) dnsl.Dnsl_eksport2013_1 (in=data2);
 by pnr;
 if data; if data2;
run;


data k.dnsl_biokemi_2013; merge pnr (in=data keep=pnr) dnsl.Biokemi_dnsl (in=data2);
 by pnr;
 if data; if data2;
run;


/******************************************/
/*Blodpr�ver fra kbh amt, roskilde og kpll*/
/******************************************/
%macro blodp(lib, data,data2);
 data &data; set &&lib..&data; run;
 proc sort data=&data; by pnr; run;
 data k.&data2; merge &data (in=data) pnr (in=data2); by pnr;
  if data; if data2;
 run;
%mend;
%blodp(roskilde,blodprove_roskilde,blodprove_roskilde);
%blodp(blodprov,sab_cpr1992_2011,sab_cpr1992_2011);
%blodp(kbhamt,results,blodprove_kbhamt);
%blodp(kpll,kpll2013,blodprove_kpll);
%blodp(nord,labka_2006_2007,blodprove_nord0607);
%blodp(nord,labka_2008_2009,blodprove_nord0809);
%blodp(nord,labka_2010_2011,blodprove_nord1011);
%blodp(nord,labka_2012_2013,blodprove_nord1213);
%blodp(nord,labkai_final_2,blodprove_nordfinal); *pr�ver f�r 2006;
data k.analyser_labkaii; set nord.analyser_labkaii;
	label pnr='Krypteret cpr nummer';
run;

data k.analysenavne_kbhamt; set kbhamt.analysenavne; run;

/**************** Psoriasis �sterbro-Herlev Us********/
data k.psor_her_obro; merge pnr(in=Data) ekstd.psor (in=data2);
 by pnr;
 if data; if data2;
run;

/******* Dermbio ***********/
data k.dermbio_07_11; merge ekstd.dermbio_07_11 (in=data) pnr(in=data2); by pnr;
if data; if data2;
run;

/*************************************
Sygesikring
*************************************/
%macro ss;
  data sssy; set %do i=2005 %to 2017; dst.sssy&i (in=k&i. drop=afrper bruhon cprtjek cprtype alderimp koenimp ydersamt) %end; ;
	if k2005 then year=2005; 
	%do i=2006 %to 2017;
	else if k&i. then year=&i.;
	%end;
  run;
%mend;
%ss;

proc sort data=sssy; by pnr; run;

data k.sssy; merge sssy (in=data) k.pnr (in=data2); by pnr;
	if data; 
	if data2;
	label ydernr='Krypteret ydernummer'
		  pnr='Krypteret cpr nummer';
run;

proc datasets library=work memtype=data nolist;
delete sssy;
run;


%macro ss2;
 data sysi; set %do i=1990 %to 2005; dst.sysi&i (drop=sikrekom afrper bruhon henvisni sikgrup sikreamt ydersamt in=k&i.) %end; ;
	if k1990 then year=1990; 
	%do i=1991 %to 2005;
	else if k&i. then year=&i.;
	%end;
	drop grdhon vagtomr;
 run;
%mend;
%ss2;

proc sort data=sysi; by pnr; run;

data k.sysi; merge sysi (in=data) k.pnr (in=data2); by pnr;
	if data; 
	if data2;
	label ydernr='Krypteret ydernummer'
		  pnr='Krypteret cpr nummer'; 
run;

proc datasets library=work memtype=data nolist;
delete sysi;
run;

/************* kommunekoder per �rstal hentet **************/


%macro kommune;
 %do i=1980 %to 2007; 
  data kommune&i;
    set dst.fain&i (keep=pnr kom); 
    year=&i;
	kom1=put(kom,3. -L); drop kom; rename kom1=kom;
	run;
 %end;
 %do i=2008 %to 2018;
  data kommune&i; 
    set dst.bef&i (keep=pnr kom); 
   year=&i;
  run;
  %end;
  data kommune; set %do i=1980 %to 2018; kommune&i %end;; 
  run;	 
%mend;
%kommune;

 proc sort data=kommune; by pnr year; run;
 proc sort data=pnr; by pnr; run;
 data k.kommune; merge kommune pnr (in= data);
  by pnr;
  if data;
  label pnr='Krypteret cpr nummer';
 run;

/***************************************** Plejehjem og pleje ****************/
/******************************************************************************************************
I marts 2018 fik vi leveret AEPI fra DST, da disse plejehjemsdata er blevet en del af DSTs grunddata.
Hidtil blev vores plejehjemsdata genereret ved en anden afdeling i DST vha. imputation (Plhjem).
Der er taget en pragmatisk beslutning om at det plejehjemsdata vi har tidligere har f�et (fra 1994-2015), 
bibeholdes og at der fra 2016 k�res videre med AEPI.

Ultimo 2018 f�r vi besked om at AEPI ikke vil blive opdateret l�ngere. DST siger at vi i stedet skal anvende AEPB.
Efter aftale med Kristian Kragholm besluttes det at for �rene 1994-2016 skal forskerne anvende datas�ttet plejehjem,
som generes i dette standardprogram. Fra 2017 og frem skal forskerne anvende AEPB, som bl.a. generes under hjemmehj�lp.
Forskerne skal dog v�re opm�rksom p� at de to datas�t er opbygget forskelligt. Plejehjem indeholder en fra-variabel
og en til-variabel for hvert �r for hver person, hvorimod AEPB indeholder en record for hver m�ned i hvert �r (hvilket
betyder at en person kan have op til 12 records pr. �r).
******************************************************************************************************/


/*****************************************************
Plejehjem
*********************************************************/
%macro plhjem(direc,input,start,slut,output);
 %do i=&start. %to &slut.;
	%if &direc.=plhjem %then
		%do;
			data &input.&i; set plhjem.&input.&i; 
						vfra=datepart(bop_vfra);
				vtil=datepart(bop_vtil);
				format vfra DDMMYY10. vtil DDMMYY10.;
				drop bop_vfra bop_vtil;
run;
		%end;
	%if &direc.=dst %then
		%do;
			data &input.&i; set dst.&input.&i; aar=&i; run;
		%end;
 %end;

	data &output; set %do i=&start. %to &slut.;
		&input.&i %end;;
		run;

%mend;

%plhjem(plhjem,forsker_,1994,2015,plhjem)
%plhjem(dst,aepi,2016,2016,aepi)

data plhjem; set plhjem;
	rename vtil=bop_vtil vfra=bop_vfra;
run;

data plejehjem; set plhjem aepi; run;

proc sort data=plejehjem; by pnr; run;

data k.plejehjem; merge plejehjem (in=data2) pnr (in=data); by pnr;
 if data; if data2;
 label pnr='Krypteret cpr nummer';
 run;

proc sort data=k.plejehjem noduprecs; by pnr; run;


/*****************************************************
Hjemmehjaelp
*********************************************************/
%macro ae(in,start, slut);
	%do i=&start. %to &slut.; 
	data &in.&i.;
    set dst.&in.&i.;
	aar=&i.;
	/*Er character i 2016 og frem*/
	%if 2016<=&i. %then %do;
		ael_komkodTemp=input(ael_komkod,3.);
		drop ael_komkod;
		rename ael_komkodTemp=AEL_KOMKOD;
	%end;
	run; 
	%end;

	data &in.;
	set %do i=&start. %to &slut.; &in.&i. 
    %end;;
    rename h�nd_mdr=mdr;
	run;
proc sort data=&in.; by pnr; run;
proc sort data=pnr; by pnr; run;
data k.&in.; merge &in. (in=data) pnr (in=data2); by pnr;
	if data; if data2; 
	label pnr='Krypteret cpr nummer';
run;
%mend;

%ae(aefv,2008,2017);
%ae(aelh,2011,2017);
%ae(aepb,2008,2017);
%ae(aetr,2008,2017);

