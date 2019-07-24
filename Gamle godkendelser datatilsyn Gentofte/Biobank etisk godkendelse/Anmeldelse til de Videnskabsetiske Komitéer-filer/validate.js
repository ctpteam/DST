function ValidateDate(formitem, aStrDateFormat) {

   if (aStrDateFormat.toUpperCase() != 'DD-MM-YYYY') {return(true);}

   var strDate  = '' + document.forms[0].item(formitem).value;
   var strDay   = '';
   var strNewDate = '';
   var strMonth = '';
   var strYear  = '';
   var char45   = '-';
   var punktum  = '.';
   var d = new Date();
   var thisYear = '';
   thisYear = '' + d.getFullYear();

   if (strDate == '') {return(true);}

   //Fix DDMM
   if ((strDate.length == 4)) {
      strDate = strDate + thisYear;}

   //Fix D-MM-YYYY
   if (strDate.charAt(1) == char45) {
      strDate = '0' + strDate;}

   //Fix DD-M-YYYY
   if ((strDate.charAt(2) == char45) && (strDate.charAt(4) == char45)) {
      strDate = strDate.substring(0,3) + '0' + strDate.substring(3);}

   //Fix DD-MM-Y, DD-MM-YY and DD-MM-YYY
   if ((strDate.charAt(2) == char45) && (strDate.charAt(5) == char45) && (strDate.length >= 7) && (strDate.length <= 9)) {
      strDate = strDate.substring(0,6) + thisYear.substring(0,10-strDate.length) + strDate.substring(6,strDate.length);}

   //Fix DDMMYYYY
   if ((strDate.charAt(2) != char45) && (strDate.charAt(4) != char45) && (strDate.length == 8)) {
      strDate = strDate.substring(0,2) + '-' + strDate.substring(2,4) + '-' + strDate.substring(4,8);}

   //Fix DDMMYY
   if ((strDate.charAt(2) != char45) && (strDate.charAt(4) != char45) && (strDate.length == 6)) {
      strDate = strDate.substring(0,2) + '-' + strDate.substring(2,4) + '-20' + strDate.substring(4,6);}

   //Fix DD-MM-YYYY....
   strDate = strDate.substring(0,10);

   //DDxMMxYYYY
   strDay   = strDate.substring(0,2);
   strMonth = strDate.substring(3,5);
   strYear  = strDate.substring(6,10);

   strDate = strDate.substring(0,2) + '-' + strDate.substring(3,5) + '-' + strDate.substring(6,10);

   var char0 = '';
   var char1 = '';
   var char3 = '';
   var char4 = '';
   var char6 = '';
   var char7 = '';
   var char8 = '';
   var char9 = '';

   char0 = strDate.substring(0,1);
   char1 = strDate.substring(1,2);
   char3 = strDate.substring(3,4);
   char4 = strDate.substring(4,5);
   char6 = strDate.substring(6,7);
   char7 = strDate.substring(7,8);
   char8 = strDate.substring(8,9);
   char9 = strDate.substring(9,10);

   if (char0 < '0' || char0 > '9' || 
       char1 < '0' || char1 > '9' ||
       char3 < '0' || char3 > '9' ||
       char4 < '0' || char4 > '9' ||
       char6 < '0' || char6 > '9' ||
       char7 < '0' || char7 > '9' ||
       char8 < '0' || char8 > '9' ||
       char9 < '0' || char9 > '9' ) {
      alert('Indtastet dato er ugyldig ! (Benyt venligst formatet ' + aStrDateFormat.toUpperCase() + ')');
      document.forms[0].item(formitem).focus();
      return(false);}

   if (strDay >= '32') {
      alert('Indtastet dag er ugyldig ! (Benyt venligst formatet ' + aStrDateFormat.toUpperCase() + ')');
      document.forms[0].item(formitem).focus();
      return(false);}

   if (strDay <= '0' || strDay <= '00') {
      alert('Indtastet dag er ugyldig ! (Benyt venligst formatet ' + aStrDateFormat.toUpperCase() + ')');
      document.forms[0].item(formitem).focus();
      return(false);}

   if (strMonth >= '13') {
      alert('Indtastet måned er ugyldig ! (Benyt venligst formatet ' + aStrDateFormat.toUpperCase() + ')');
      document.forms[0].item(formitem).focus();
      return(false);}

   if (strMonth <= '0' || strMonth <= '00') {
      alert('Indtastet måned ugyldig ! (Benyt venligst formatet ' + aStrDateFormat.toUpperCase() + ')');
      document.forms[0].item(formitem).focus();
      return(false);}

   if (strYear >= '2100') {
      alert('Indtastet år er ugyldigt ! (Benyt venligst formatet ' + aStrDateFormat.toUpperCase() + ')');
      document.forms[0].item(formitem).focus();
      return(false);}

   if (strYear <= '1900') {
      alert('Indtastet år er ugyldigt ! (Benyt venligst formatet ' + aStrDateFormat.toUpperCase() + ')');
      document.forms[0].item(formitem).focus();
      return(false);}

   document.forms[0].item(formitem).value = strDate;

   return(true);
}

function findbynavn(formnavn,postnrfelt,bynavnfelt){ 
       var programkald='findbynavn.asp?formnavn=' + formnavn + '&postnr=' + document.forms[0].item(postnrfelt).value + '&bynavnfelt=' + bynavnfelt + '&postnrfelt=' + postnrfelt;
       popup=document.open(programkald,'Find','left=3000,top=3000,width=1,height=1,resizable=yes,location=no,directories=no,menubar=no,scrollbars=no,status=yes');
}	


function ValidateDate2(formitem, aStrDateFormat, astrMinimumDate) {
   if( ! ValidateDate(formitem, aStrDateFormat)) {
      return( true );}

   var d = new Date();
   var thisYear = '';
   var thisMonth = '';
   var thisDate = '';
   var strMinimumDate = '' + astrMinimumDate;

   thisYear  = '' + d.getFullYear();
   thisMonth = '0' + (d.getMonth()+1);
   thisDate  = '0' + d.getDate();

   if(thisMonth.length == 3) { thisMonth = thisMonth.substring(1,3); }
   if(thisDate.length == 3) { thisDate = thisDate.substring(1,3); }

   if(strMinimumDate == 'dd'){
      strMinimumDate = '' + thisDate + '-' + thisMonth + '-' + thisYear;}

   var strDate                = '' + document.forms[0].item(formitem).value;
   var strDateYYYYMMDD        = strDate.substring(6,10) + strDate.substring(3,5) + strDate.substring(0,2);
   var strMinimumDateYYYYMMDD = strMinimumDate.substring(6,10) + strMinimumDate.substring(3,5) + strMinimumDate.substring(0,2);

   if (strDate == '') {return(true);}

   if( strDateYYYYMMDD < strMinimumDateYYYYMMDD ) {
      alert('Dato skal ligge efter ' + strMinimumDate + ' !');
      document.forms[0].item(formitem).focus();
      return( true );
      }

   return(true);
}


function ValidateInt(formitem) {
   var strInt   = '' + document.forms[0].item(formitem).value;
   var intInt   = 0;
   try{ intInt = strInt - 0;}
   catch (exception) {
      alert('Den indtastede værdi er ugyldig ! (indtast et heltal) ');
      document.forms[0].item(formitem).focus();
      return (false);}
   if( !((intInt >= 0) && (intInt <= 1000000000))) {
      alert('Den indtastede værdi er ugyldig ! (indtast et heltal) ');
      document.forms[0].item(formitem).focus();
      return (false);}

   return(true);
}

function submitPD(action){
//document.all.PD.innerHTML = document.PD.innerHTML + "<input type=SUBMIT value=X name= '" + action +"'>";
//document.PD.submit();
location = 'projektfunc.asp?action=nyt';
}


function openCalendar(file,header){     
   popup=document.open(file,header,'left='+Math.round(screen.availWidth/2-250/2)+',top='+Math.round(screen.availHeight/2-190/2)+',width=250,height=190,resizable=no,location=no,directories=no,menubar=no,scrollbars=no,status=no');
   popup.window.focus();
}

