libname library "Q:\Forsk-DanskHjertestopregister\Hjertestopregister til brug uden for DST";

proc format library=library;
 value dhr_bin 1='No' 2='Yes' other='missing';
 value doc 1='No' 2='EMS doctor' 3 ='Other doctor' other='missing';
 value statusbi 1='Not ROSC' 2='ROSC' other='missing';
 value irytme 1='Shockable' 2='Non-shockable' other='missing';
 value sted 1='Private home' 2= 'Natural resort' 3= 'Traffic area' 4= 'Other' other='missing';
 value stedbi 1='Private home' 2 = 'Public area' other='missing';
 value status 1='Resuscitation terminated' 2= 'Ongoing CPR' 3= 'Palpable pulse/other signs of life' 4= 'Patient awake, GCS > 8' other='missing';
 value region_final 1='Hovedstaden' 2= 'Sjaelland' 3= 'Midt' 4= 'Syddanmark' 5= 'Nordjylland' other='missing';
 value age10_ 1='0-9' 2= '10-19' 3= '20-29' 4= '30-39' 5= '40-49' 6= '50-59' 7= '60-69' 8= '70-79' 9='80-89' 10='>89' other='missing';
 value sex 1='Man' 0='Woman' other='missing';
 value cause_new 1="Presumed cardiac cause of arrest" 2="Traumatic" 3="Suicide" 4="Overdose" other='missing';
 value gender 0="Female" 1="Male";


*Renaming old variables to english;

value iden 1='danish cardiac arrest registry' 2='EMS vehicle, Capital Region of Denmark';
value atjen 1='Falck' 2='Frederiksberg fire department' 3='Copenhagen fire department' 4='Roskilde fire department' 5='Gentofte' 6='Karup' 7='Samsø' 8='Other' 9='Response' 10='EMS vehicle (ALB)' 999='Unkown';
value skemaversion 1='Old registration form (2001-2004)' 2='New registration form (2005 and onwards)' 3='EMS vehicle';
value rekon 0='No' 1='Yes' 2='Yes, extra 2010 at 2014 update', 9='missing';
value bevid 1='No' 2='Yes' 9='missing';
value bevidems 1='No' 2='Yes' 9='missing' 98='missing';
value hlr 1='No' 2='Yes' 9='missing' 98='missing';
value defibi 1='No' 2='Yes, publicy available AED' 2='Yes, other AED' 9='missing' 98='missing';
value doci 1='No' 2='EMS doctor' 3='Other doctor' 9='missing';
value ekg 1='No' 2='Yes' 9='missing';
value irytme 1='Shockable rhythm (VT/VF)' 2='Non-shockable rhythm (other rhythm)' 9='missing';
value emshlr 1='No' 2='Yes' 9='missing';
value emsdc 1='No' 2='Yes' 9='missing';
value emsdcgl 1='No' 2='Yes' 9='missing';
value roscint 1='No' 2='Yes' 9='missing';
value statusny 1='Patient declared dead' 2='Ongoing CPR' 3='ROSC' 4='Patient awake' 9='missing' 98='missing';
value statusgl 1='Patient declared dead' 2='Ongoing CPR' 3='ROSC' 9='missing' 98='missing';
run;
