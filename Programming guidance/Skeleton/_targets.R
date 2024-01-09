# *************************************************************************************
# This sample program provides necessary codes to collect data from Statistics Denmark
# to a project in the framwork of The Aalborg/Hiller?d/Gentofte/Rigshospitalet group and
# using data as provided from project 3573 to individual projects.
#
# The example is shaped as a targets pipeline
# 
# Any use of the examples will have to adjust directories to those for a project.
# 
# Please adhere to a number of useful rules:
# 1. For any project create a folder for each publication
# 2. Maintain a very small number of programs that generate data for a publication
# 3. Keep the final analysis dataset until a publication is published. Intermediary
#    and often large datasets should be deleted as they can be reshaped from raw data
# 4. Keep record of the amount of disk memory you use - and the amount of RAM you use
#     Use the garbage collector: gc() to free memory after extensive use.
# 5. Comment programs generously so both you and others can decode them even after
#    many years.
# 6. Be aware that the only documentation you haves for your project is your programs.
#    Make sure to keep them safe, which includes having them sent out of Statistics
#    Denmark for safe keeping.
# 7. The current examples use targets to create datasets. Use of targets for 
#    data management is encouraged.
# 8. Parallel computing is suggested for reading multiple datasets in folders.
#  
# ***********************************************************************************

# ***********************************************************************************
# The first step of a project is often to define the population. The current example
# assumes you want to define a population which is consistent with the DST definition
# of a population.  This implies that a person needs to be part of "bef" or during
# early years "fain" and that that person is member of the population until the
# person is missing in fain/bef, immigrates out of the country or dies. There is
# no universal method, but the current suggestion does capture people who have
# been away and returned by defining a population starting a particular year. Note
# that special considerations are necessary for newborns and not dealt with here.
# 
# Note for the populat folder:
# - Prior to 1985 there is no bef, but fain can partially replace
# - In particular for the first years it is necessary to use the sexBirth datasets
#   to capture sex and birth date
# - All movements to and from Denmark are in the single vnds dataset
# ************************************************************************************
library(targets)
tar_option_set(packages = c("heaven","data.table","foreach","doParallel","haven"))
list(
tar_target(pop,{
  # ****************************************************************************
  # Population 1980-2022
  # Takes all people from their first presence in DST (fain/bef) between 1980 and 2022
  # Terminates people when they die, immigrate or time ends
  # From 1980-1984 FAIN is used, thereafter BEF
  # ****************************************************************************
  fainlist <- list.files('X:/Data/Rawdata_Hurtig/703775/Grunddata/Population',
                         '^fain',full.names=TRUE)
  fain <- rbindlist(
    lapply(fainlist,function(x){
      #browser()
      dat <- importSAS(x,keep=c("pnr","koen"))
      dat[,referencetid:=as.Date(paste0(substr(x,56,59),"-12-31"))]
      dat
    })
  )
  t_person <- importSAS('X:/Data/Rawdata_Hurtig/703775/Grunddata/Population/t_person.sas7bdat',
                        keep = c("pnr","d_foddato"))
  setnames(t_person,"d_foddato","foed_dag") #align with bef
  fain <- merge(fain,t_person,all.x = TRUE,by="pnr")
  
  beflist <- list.files('X:/Data/Rawdata_Hurtig/703775/Grunddata/Population',
                        '^bef',full.names=TRUE)
  # Another Example going from 1997-2022. Use ChatGPT to generate your own regular expression
  # beflist <- list.files('X:/Data/Rawdata_Hurtig/703775/Grunddata/Population',
  #                        '^bef(199[7-9]|200[0-9]|201[0-9]|202[0-2]).*',full.names = TRUE)
  cl <- makeCluster(10)
  registerDoParallel(cl)
  dat <- rbindlist(
    foreach(x=1:length(beflist),.packages=c("haven","heaven","data.table")) %dopar% {
      dat <- setDT(read_sas(beflist[x],col_select = c("PNR","FOED_DAG","KOEN", "REFERENCETID")))
    }           
  )
  stopCluster(cl)
  registerDoSEQ()
  gc()
  
  names(dat) <- tolower(names(dat)) #fjerner upper case
  dat <- rbind(fain,dat)
  dat <- dat[pnr != ""]
  setkeyv(dat,c("pnr","referencetid"))
  dat[,dist:=fifelse(year(referencetid)>2007,95,370)]
  
  dat[pnr==shift(pnr) & (referencetid-shift(referencetid)>dist),pause:=1] 
  dat[,pause:=nafill(pause, type="locf"),by="pnr"] #mark all after break
  dat <- dat[is.na(pause)] #keep until first pause
  setkeyv(dat,c("pnr","referencetid"))
  dat <- dat[,.(foed_dag=foed_dag[1], koen=koen[1],inn=referencetid[1],out=referencetid[.N]),by="pnr"] 
  dat <- dat[,.SD[1],by="pnr"]
  
  vnds <- importSAS('X:/Data/Rawdata_Hurtig/703775/Grunddata/Population/vnds2022.sas7bdat',
                    where="indud_kode='U'",)
  vnds <- merge(vnds,dat,all.x=TRUE,by="pnr")
  vnds <- vnds[haend_dato>out,.(pnr,haend_dato)]
  setkeyv(vnds,c("pnr","haend_dato"))
  vnds <- vnds[,.SD[1],by="pnr"]
  death <- importSAS('X:/Data/Rawdata_Hurtig/703775/Grunddata/Death/dod.sas7bdat')
  dat <- Reduce(function(x,y){merge(x,y,all.x=TRUE,by="pnr")},list(dat,vnds,death[,.(pnr,doddato)]))
  dat[year(out)>2007,out:=out+91]
  dat[year(out)<2008,out:=out+365]
  dat[doddato<inn,doddato:=NA] # To m?rkelige d?dsfald
  dat[,out:=pmin(out,doddato,haend_dato,na.rm=TRUE)] 
  dat
  }),

# Often useful to limit subsequent data to population of interest
tar_target(pnrlist,{unique(pop[,.(pnr)])}),

# ****************************************************************************
#  Cancer uses the cancer registry t_tumor
# ******************************************************************************
tar_target(cancer,{importSAS("Z:/Workdata/703573/3740 Diabetes/Grunddata/cancer/t_tumor.sas7bdat",
                    filter=pnrlist)}),


# ****************************************************************************
#  Death has three files
#  t_dodsaarsag_1 - causes of death prior to 2001
#  t_dodsaarsag_2 - later causes of death with new codes and variables,
#    always a few years behind
#  dod a simple list of death dates from statistics Denmark and cpr-register
# ******************************************************************************/
tar_target(death,{importSAS("Z:/Workdata/703573/3740 Diabetes/Grunddata/death/dod.sas7bdat",
                             filter=pnrlist)}),
# ****************************************************************************
# Laboratory has data from two distinct sources
# 
# LABKA is the national database for clinical biohemistry. In addition to the main
# file labforsker there are older data from KPLL, Region North, KBH amt and Roskilde 
# which may provide additioanl older values in some cases.  Note that the format of
# these datasets differ.
# 
# This folder will also holde pathological data from Sundhedsdatastyrelsen if requested.
# Visit Sundhedsdatastyrelsen to understand these data;
# 
# The example shows how to extract a couple of simple values 
#
# A table of NPU-codes is available at: V:/Data/Alle/Blodpr?ver/npu_definition_270918.sas7bdat
# ******************************************************************************
# Data with NPU-codes for laboratory values

tar_target(lab, {
    labs <- list(
      kalium='NPU03230',
      natrium='NPU03429'
    )
    kna <- importSAS('Z:/Workdata/703573/3740 Diabetes/Grunddata/laboratory/lab_forsker.sas7bdat',
                          where="analysiscode in ('NPU03230','NPU03429')", obs=10000) #only search 10K records.
    kna2 <- findCondition(kna,"analysiscode",c("patient_cpr","samplingdate","value"),labs,match="start")
    # Finds all occurences and names them appropriately. Additional programmning needs to be done to
    # find the first values, latest value prior to event etc.
  }),

# ****************************************************************************
# Using hospital register data is challenging.  The register was originally organized
# in 1978 as LPR1, extended with more data in 1994 as LPR2.
# 
# LPR 1/2 has a record for each "forl?b" (course) - one record for each hospital department
# that have handled the case and one for a series of related outpatient visits. LPR2/3
# has a pattype which is zero for inpatient treatment and greater numbers for other
# situations. Take particular care with emergency room visits which have changed 
# recording over time.
# 
# In accordance with previous habits of our environemnt we have maintained to produce
# diag_indl which has diagnoses and start/ned of "forl?b"
# opr - which has procedures and examinations
# as well as separate files for psychiatric hospital contacts whens requested for projects
# 
# With LPR3 the system changes. Many more contacts are registered. The concept of
# distinguishing between inpatient and outpatient visits has disappeared.  It is therefore
# necessary to enterrogate instructions from Sundhedsdatastyrelsen. Replacement for "pattype"
# is described by Sundhedsdatastyrelsen and also in www.heart.dk/github
# 
# The simple example below extracts a series of patients with first myocardial
# infarction and angina pectoris from a hospital admission in both LPR1/2 and LPR3
# ******************************************************************************/

tar_target(amiangina,{
  #Lpr1/2
  diag1 <- importSAS('Z:/Workdata/703573/3740 Diabetes/Grunddata/LPR/diag_indl.sas7bdat',
                    where="(diag=:'DI2' or diag=:'41') and pattype=0",obs=10000)
  diags <- list(
    ami=c("410","DI21"), # scrutinize depending on scientif purpose
    angina=c("413","DI20")
  )
  diag1a <- findCondition(diag1,"diag",c("pnr","inddto"),diags,match="start")
  #LPR3
  diag2 <- importSAS('Z:/Workdata/703573/3740 Diabetes/Grunddata/LPR/diagnoser.sas7bdat',
                     where="diagnosekode=:'DI2'",keep=c("DW_EK_KONTAKT","diagnosekode"))
  kontakt <- importSAS('Z:/Workdata/703573/3740 Diabetes/Grunddata/LPR/kontakter.sas7bdat',
                       keep=c("cpr","DW_EK_KONTAKT","dato_start","tidspunkt_start","dato_slut","tidspunkt_slut"),
                       obs=100000)
  kontakt[,start:=as.POSIXct(paste(dato_start,tidspunkt_start))]
  kontakt[!is.na(dato_slut) & !is.na(tidspunkt_slut),slut:=as.POSIXct(paste(dato_slut,tidspunkt_slut))]
  kontakt[,dif:=slut-start]
  kontakt <- kontakt[dif>60*60*12] # 12 hours as replacement for pattype=0 - not universally relevant, in particular children
  kontakt <- kontakt[,.(cpr,dato_start,dw_ek_kontakt)]
  diag21 <- merge(diag2,kontakt,all.x = TRUE,by="dw_ek_kontakt")
  diag21 <- diag21[!is.na(cpr)] #not relevant for real projects
  setnames(diag21,c("cpr","dato_start","diagnosekode"),c("pnr","inddto","diag"))
  diag21[,dw_ek_kontakt:=NULL]
  diag2a <- findCondition(diag21,"diag",c("pnr","inddto"),diags,match="start")
  
  diag <- rbind(diag1a,diag2a)
  # Further programming to isolate relevant cases or index cases  
}),
 
# ****************************************************************************
# Prescriptions are available in batches for each year.  The amount of data on
# each prescription, but in particular the variable "vnr" can be used to
# combine with other data.  These data are in:
# V:\Data\Alle\LMDBdata
# 
# The following example extracts betablockers and diuretics medication 
# from a range of years
# 
# ******************************************************************************/
tar_target(med,{ # Get medications from 2014-2022
  filelist <- list.files('Z:/Workdata/703573/3740 Diabetes/Grunddata/medication/',
                         '^lmdb20(14|1[5-9]|2[0-2]).*',full.names=TRUE) # lmdb files 2014-2022
  cl <- makeCluster(10) # Define cluster with 10 cores
  registerDoParallel(cl)
  dat <- rbindlist(
    foreach(x=1:length(filelist),.packages=c("haven","heaven","data.table")) %dopar% {
      dat <- read_sas(filelist[x],col_select = c("PNR","ATC","eksd","Volume","strnum","PACKSIZE"),n_max=1000) 
      #dat <- importSAS(filelist[x],keep=c(("PNR","ATC","eksd","Volume","strnum","PACKSIZE"), obs=1000)
    }
  )
  stopCluster(cl)
  registerDoSEQ()
  gc() # Garbage collecter, should be used whenever there is risk of memoryleak
  names(dat) <- tolower(names(dat))
  medications <- list(
    diuretics="C03",
    betablocker="c07"
  )
  dat2 <- findCondition(dat,"atc",c("pnr","atc","eksd","volume","packsize"),medications,match="start")
}),

# ****************************************************************************
# Nursing home data comes from a range of sources:
# Plejehjem is a manual dataset created for us by DST by examining all locations
#   where multiple old people lives.  The data includes a from/to for each pnr
#   and each institution.  These data should be used from 1994-2016
# AEPB has from start 2017 one record per mont per pnr for each nursing home.
# AETR has information of training
# AELH has home assistance
# AEFV has information on referral for home assistance
# 
# We are anticipating newer data from Sundhedsdatastyrelsen which may explain
# extra files in some projects.
# 
# The plejehjem data are easy to use.  Several of the others are complicated 
# with variables missing in intervals etc.  It takes care to use these data.
# ******************************************************************************
# 
# /****************************************************************************
# Social
# DREAM contains information on public support and area of work. Note the strange
#   format with a variable per week/month. Conversion to a long format with dates
#   can be accomplished with the heaven::importDream function
# ind has income. The most useful variable for most projects is AEKVIVADISP_13 
#   which is personal income adjust to household.
# udda has maximal education each year.  Note that "DST-formater" has formats to
#   convert to useful groups.  The heaven::eduCode has a conversion to ISCED
# 
# The example captures maximal education for an extract of people during a sequence
# of years.
# 
# ******************************************************************************/
tar_target(education,{ # Get medications from 2014-2022
  filelist <- list.files('Z:/Workdata/703573/3740 Diabetes/Grunddata/social/',
                         '^udda20(14|1[5-9]|2[0-2]).*',full.names=TRUE) # education files 2014-2022
  cl <- makeCluster(10) # Define cluster with 10 cores
  registerDoParallel(cl)
  dat <- rbindlist(
    foreach(x=1:length(filelist),.packages=c("haven","heaven","data.table")) %dopar% {
      dat <- setDT(read_sas(filelist[x],col_select = c("PNR","HFAUDD"),n_max=1000))
      dat[,year:=x+2013] 
    }
  )
  stopCluster(cl)
  registerDoSEQ()
  names(dat) <- tolower(names(dat))
  dat <- merge(dat,edu_code,by="hfaudd",all.x=TRUE)
})
)

 
# ****************************************************************************
# SSS has data from private practice divided in two time periods.
# All entries are based on weekly additions of data from practitioners
# regarding patients.
# 
# *****************************************************************************/

