# *************************************************************************************
# This sample program provides necessary codes to collect data from Statistics Denmark
# to a project in the framwork of The Aalborg/Hiller?d/Gentofte/Rigshospitalet group and
# using data as provided from project 3573 to individual projects.
#
# The example is shaped as a targets pipeline
# 
# Any use of the examples will have to adjust directories to those for a project.
#
# This example is specifically for collecting data from Parquet data files
#
# This program is updated June 2026 to handle parquet objects that are directories
# rather than simple files.
# 
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
# The population defined below is for a cohort study where people enter at some point
# and leave the first time they disappear from BEF.  For studies of trends complete
# annual population are those that are relevant.
# 
# Note for the populat folder:
# - Prior to 1985 there is no bef, but fain can partially replace
# - In particular for the first years it is necessary to use the sexBirth datasets
#   to capture sex and birth date
# - All movements to and from Denmark are in the single vnds dataset
# ************************************************************************************
library(targets)
library(heaven)
library(data.table)
library(foreach)
library(doParallel)
library(dplyr)
library(dbplyr)
library(duckdb)
library(arrow)
library(glue)
# Make start of directories as targets to ease moving between windows, orihect - and Linux server
#setwd('/home/sambahome/zyp3740/zdrev/Workdata/703740/christianTorp-Pedersen/parquet/'),
setwd('z:/Workdata/703740/christianTorp-Pedersen/parquet/')
tar_option_set(packages = c("heaven","data.table","foreach","doParallel","dplyr",
                            "dbplyr","duckdb","arrow","glue"))
list(
#tar_target(dirstart,"/home/sambahome/zyp3740/zdrev/Workdata/703740/rawdata_parquet_ctp"),
tar_target(dirstart,"Z:/Workdata/703740/rawdata_parquet_ctp"),  
tar_target(pop,{
  # ****************************************************************************
  # Population 1980-2022
  # Takes all people from their first presence in DST (fain/bef) between 1980 and 2022
  # Terminates people when they die, immigrate or time ends
  # From 1980-1984 FAIN is used, thereafter BEF
  # ****************************************************************************
  filelist <- list.files(paste0(dirstart,'/Grunddata/Population/'),
                         '^fain',full.names=TRUE)

  fain <- foreach(
    x=seq_along(filelist),.export="filelist",
    .packages=c("data.table","dplyr","dbplyr","duckdb","arrow","glue")) %dopar% {
      
      con <- DBI::dbConnect(duckdb::duckdb(),dbdir=":memory:")  
      on.exit(DBI::dbDisconnect(con,shutdown=TRUE),add=TRUE)
      
      DBI::dbExecute(con,"SET threads=3") # ensures parallel processing even within single parquet directory-objects
      DBI::dbExecute(con,
                     glue("
                    CREATE VIEW parquet_data AS
                    SELECT *
                    FROM parquet_scan('{filelist[x]}/*.parquet') 
               ")
      )              
      
      dat <- tbl(con, "parquet_data") |>
        rename_with(tolower) |>
        select(pnr,koen) |>
        head(10000) |>  # Limit size just for the example
        collect() |>
        as.data.table()
      # Capture referencetid from year in filename
      dat[,referencetid:=as.Date(paste0(sub(".*fain([0-9]{4}).*","\\1",filelist[x]),"-12-31"))]
      dat
    } |>
    data.table::rbindlist()
  # t_person is simple, so we use a simple approach to just read it all
  set_cpu_count(5)
  ds <- arrow::open_dataset(paste0(dirstart,'/Grunddata/Population/t_person.parquet')) # note ref to directory, not single files
  t_person <- ds |> 
          head(10000) |> 
          rename_with(tolower) |>
          select(c(v_pnr,d_foddato)) |>
          as.data.table()
  setnames(t_person,c("pnr","foed_dag")) #align with bef  
    
  fain <- merge(fain,t_person,all.x = TRUE,by="pnr")
  
  # Bef
  
  filelist <- list.files(paste0(dirstart,'/Grunddata/Population/'),
                        '^bef',full.names=TRUE) # Use chatgpt to make alternative regular expressions to select files
  cl <- makeCluster(10) # Parallel processing
  registerDoParallel(cl)
  bef <- foreach(
    x=seq_along(filelist),.export="filelist", .packages=c("data.table","dplyr","dbplyr","duckdb","arrow","glue")) %dopar% {
      
      con <- DBI::dbConnect(duckdb::duckdb(),dbdir=":memory:")  
      on.exit(DBI::dbDisconnect(con,shutdown=TRUE),add=TRUE)
      
      DBI::dbExecute(con,"SET threads=3") # ensures parallel processing even within single parquet directory-objects
      DBI::dbExecute(con,
                    glue("
                    CREATE VIEW parquet_data AS
                    SELECT *
                    FROM parquet_scan('{filelist[x]}/*.parquet') 
               ")
      )              
      dat <- tbl(con, "parquet_data") |>
        rename_with(tolower) |>
        select(pnr,foed_dag,koen,referencetid) |>
        head(10000) |>  # Limit size just for the example
        collect() |>
        as.data.table()
      dat
    } |>
    data.table::rbindlist(ignore.attr=TRUE)
  stopCluster(cl)
  registerDoSEQ()
  gc() 

  dat <- rbind(fain,bef)
  dat <- dat[pnr != ""]
  setkeyv(dat,c("pnr","referencetid"))
  dat[,dist:=fifelse(year(referencetid)>2007,95,370)]
  
  dat[pnr==shift(pnr) & (referencetid-shift(referencetid)>dist),pause:=1] 
  dat[,pause:=nafill(pause, type="locf"),by="pnr"] #mark all after break
  dat <- dat[is.na(pause)] #keep until first pause
  setkeyv(dat,c("pnr","referencetid"))
  dat <- dat[,.(foed_dag=foed_dag[1], koen=koen[1],inn=referencetid[1],out=referencetid[.N]),by="pnr"] 
  dat <- dat[,.SD[1],by="pnr"]
  
  # t_person is simple, so we use a simple approach to just read it all
  set_cpu_count(5)
  ds <- arrow::open_dataset(paste0(dirstart,'/Grunddata/Population/t_person.parquet')) # note ref to directory, not single files
  t_person <- ds |> 
    head(10000) |> 
    rename_with(tolower) |>
    select(c(v_pnr,d_foddato)) |>
    as.data.table()
  setnames(t_person,c("pnr","foed_dag")) #align with bef  
  
  set_cpu_count(5)
  ds <- arrow::open_dataset(paste0(dirstart,'/Grunddata/Population/vnds2024.parquet'))
  vnds <- ds |>
    filter(INDUD_KODE=='U') |> #column select
    head(10000) |> # first 100 rows - only relevant for the example
    collect()
  setDT(vnds)
  names(vnds) <- tolower(names(vnds))
  vnds <- merge(vnds,dat,all.x=TRUE,by="pnr")
  vnds <- vnds[haend_dato>out,.(pnr,haend_dato)]
  setkeyv(vnds,c("pnr","haend_dato"))
  vnds <- vnds[,.SD[1],by="pnr"]
  ds <- arrow::open_dataset(paste0(dirstart,'/Grunddata/Death/dod.parquet'))
  death <- ds |> as.data.table()
  names(death) <- tolower(names(death))
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
tar_target(cancer,{
  ds <- arrow::open_dataset(paste0(dirstart,'/Grunddata/cancer/tumor_aarlig.parquet'))
  cancer <- ds |>
    rename_with(tolower) |>
    semi_join(pnrlist,by="pnr") |> # Limit to pnrlist
    head(10000) |> # first 100 rows - only relevant for the example
    collect()
  setDT(cancer)
  cancer
}),

# ****************************************************************************
#  Death has three files
#  t_dodsaarsag_1 - causes of death prior to 2001
#  t_dodsaarsag_2 - later causes of death with new codes and variables,
#    always a few years behind
#  dod a simple list of death dates from statistics Denmark and cpr-register
# ******************************************************************************/
tar_target(death,{
  # When everying is appropriate to read, then a simple read_parquet suffers
  ds <- arrow::open_dataset(paste0(dirstart,'/Grunddata/death/dod.parquet'))
  dat <- ds
  dat <- merge(dat,pnrlist,by="pnr") 
  dat
}),
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
# A table of NPU-codes is available at: V:/Data/Alle/Blodpr?ver/npu_definition_270918.parquet
# ******************************************************************************
# Data with NPU-codes for laboratory values
# This dataset is huge and needs effecient reading
tar_target(lab, {
    con <- dbConnect(duckdb::duckdb())
    dbExecute(con,"SET threads=20")
    labfiles <- paste0(dirstart,'/Grunddata/laboratory/laboratorieproevesvar.parquet/*.parquet')
    DBI::dbExecute(con,
          glue("
               CREATE VIEW parquet_data AS
               SELECT *
               FROM parquet_scan('{labfiles}')
               ")
    )
    filter <- copy_to(con,pnrlist,temporary=TRUE,overwrite = TRUE)
    labdata <- tbl(con,"parquet_data" ) |>
           head(10000) |> # Short read for the example
           rename_with(tolower) |> # Lower case variable names
           filter(grepl("^NPU0(3|4)",analysiscode)) |> # Select by row
           semi_join(filter,by="pnr") |> # Select in relevant population
           collect()
    dbDisconnect(con,shutdown=TRUE)
    labs <- list(
      potassium='NPU03230',
      sodium='NPU03429'
    )
    lab2 <- findCondition(labdata,"analysiscode",c("pnr","samplingdate","samplevalue"),labs,match="start")
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
  con <- dbConnect(duckdb::duckdb())
  dbExecute(con,"SET threads=10")
  lpr1files <- paste0(dirstart,'/Grunddata/lpr/diag_indl.parquet/*.parquet')
  DBI::dbExecute(con,
                 glue("
               CREATE VIEW parquet_data AS
               SELECT *
               FROM parquet_scan('{lpr1files}')
               ")
  )
  filter <- copy_to(con,pnrlist,temporary=TRUE,overwrite = TRUE)
  diag1 <- tbl(con,"parquet_data") |>
    head(100000) |> # Short read for the example
    rename_with(tolower) |> # Lower case variable names
    filter(grepl("^(DI2|41)",diag) & pattype=="0") |> # Select by row
    #semi_join(filter,by="pnr") |> # Select in relevant population
    collect() |>
    as.data.table()
  dbDisconnect(con,shutdown=TRUE)

  diags <- list(
    ami=c("410","DI21"), # scrutinize depending on scientif purpose
    angina=c("413","DI20")
  )
  diag1a <- findCondition(diag1,"diag",c("pnr","inddto"),diags,match="start")
  #######################LPR3
  con <- dbConnect(duckdb::duckdb())
  dbExecute(con,"SET threads=10")
  diagnoserfiles <- paste0(dirstart,'/Grunddata/lpr/diagnoser.parquet/*.parquet')
  kontakterfiles <- paste0(dirstart,'/Grunddata/lpr/kontakter.parquet/*.parquet')
  filter <- copy_to(con,pnrlist,temporary=TRUE,overwrite = TRUE)
  DBI::dbExecute(con,
            glue("
               CREATE VIEW diagnoser AS
               SELECT *
               FROM parquet_scan('{diagnoserfiles}')
               ")
  )
  DBI::dbExecute(con,
            glue("
               CREATE VIEW kontakter AS
               SELECT *
               FROM parquet_scan('{kontakterfiles}')
               ")
  )
  filter <- copy_to(con,pnrlist,temporary=TRUE,overwrite = TRUE)
  kontakter <- tbl(con,"kontakter")
  diag3 <- tbl(con,"diagnoser") |>
    head(100000) |> # Short read for the example
    select('DW_EK_KONTAKT','diagnosekode') |>
    dplyr::filter(grepl("^(DI2|41)",diagnosekode))  |> # Select by row
    inner_join(kontakter,by='DW_EK_KONTAKT') |>
    select(CPR,diagnosekode,dato_start,dato_start,tidspunkt_start,dato_slut,tidspunkt_slut,kontakttype) |>
    rename_with(tolower) |> # Lower case variable names
    rename(pnr=cpr) |>
    semi_join(filter,by="pnr") |> # Select in relevant population
    collect() |>
    as.data.table()
  dbDisconnect(con,shutdown=TRUE)

  diag3[,start:=as.POSIXct(paste(dato_start,tidspunkt_start))]
  diag3[!is.na(dato_slut) & !is.na(tidspunkt_slut),slut:=as.POSIXct(paste(dato_slut,tidspunkt_slut))]
  diag3[,dif:=slut-start]
  # No pattype, so alternative 12 hours of physical presence
  # OK with this definition for adults,  for children 4 hours or even less
  diag3 <- diag3[kontakttype=="ALCA00" & dif>60*60*12] 
  setnames(diag3,c("dato_start","diagnosekode"),c("inddto","diag"))
  diag3[,c('DW_EK_KONTAKT'):=NULL]
  diag3a <- findCondition(diag3,"diag",c("pnr","inddto"),diags,match="start")
  
  diag <- rbind(diag1,diag3a,fill=TRUE)
  # Further programming to isolate relevant cases or index cases  
}),
 
# ****************************************************************************
# Prescriptions are available in batches for each year.  The amount of data on
# each prescription, but in particular the variable "vnr" can be used to
# combine with other data.  These data are in:
# V:/Data/Alle/LMDBdata
# 
# The following example extracts betablockers and diuretics medication 
# from a range of years
# 
# ******************************************************************************/

tar_target(med,{ # Get medications from 2014-2022
  filelist <- list.files(paste0(dirstart,'/Grunddata/medication/'),
                         '^lmdb20(14|1[5-9]|2[0-2])12.*',full.names=TRUE) # lmdb files 2014-2022
  # Note enforcing "12" after year to ensure that half-year deliveries do not double prescriptions
  cl <- makeCluster(10) # Define cluster with 10 cores
  registerDoParallel(cl)
  dat <- 
    foreach(x=seq_along(filelist),.export="filelist",.packages=c("data.table","dplyr","dbplyr","duckdb","arrow","glue")) %dopar% {
      con <- dbConnect(duckdb::duckdb(),dbdir=":memory:")
      filter <- copy_to(con,pnrlist,temporary=TRUE,overwrite = TRUE)
      DBI::dbExecute(con,"SET threads=3") # ensures parallel processing even within single parquet directory-objects
      DBI::dbExecute(con,
                glue("
                CREATE VIEW parquet_data AS
                SELECT *
                FROM parquet_scan('{filelist[x]}/*.parquet') 
                ")
      )
      dat <- tbl(con,"parquet_data") |>
        rename_with(tolower) |> # lower case names
        semi_join(filter,by="pnr") |>
        filter(grepl("^C0(3|7)",atc)) |> # Just drugs starting with C03 and C07 
        head(10000) |> # first 10000 rows - only relevant for the example
        collect() |>
        as.data.table()
      dbDisconnect(con, shutdown=TRUE)
      dat
    } |> rbindlist()
  stopCluster(cl)
  registerDoSEQ()
  gc() # Garbage collecter, should be used whenever there is risk of memoryleak
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
 
# /****************************************************************************
# Social
# DREAM contains information on public support and area of work. Note the strange
#   format with a variable per week/month. Conversion to a long format with dates
#   can be accomplished with the heaven::importDream function
#
# DREAM will be read with a arrow and without DUCKDB
# ******************************************************************************
tar_target(dream,{
   set_cpu_count(10)
   ds <- open_dataset(paste0(dirstart,'/Grunddata/social/dream202509.parquet'))
   dream <- ds |>
     head(10000) |> # limit for the example
     rename_with(tolower) |>
     select(pnr,starts_with("y_")) |>
     semi_join(pnrlist,by="pnr") |>
     collect() |>
     as.data.table()
   dream2 <- importDREAM(dream)
   dream2
}),

# ******************************************************************************
# ind has income. The most useful variable for most projects is AEKVIVADISP_13 
#   which is personal income adjust to household.
# udda has maximal education each year.  Note that "DST-formater" has formats to
#   convert to useful groups.  The heaven::eduCode has a conversion to ISCED
# 
# The example captures maximal education for an extract of people during a sequence
# of years.
#
# Since the files are quite simple the reading from Parquet uses a simple sequential read
# But the files are read one at a time because the year needs to be defined
# 
# ******************************************************************************/
tar_target(education,{ # Get education from 2014-2022
  filelist <- list.files(paste0(dirstart,'/Grunddata/social/'),
                         '^udda20(14|1[5-9]|2[0-2]).*',full.names=TRUE) # education files 2014-2022
  
  dat <- lapply(1:length(filelist),function(x){
    ds <- open_dataset(filelist[x])
    dat <- ds |>
           head(1000) |> # limit for the example
           select(PNR,HFAUDD) |>
           rename_with(tolower) |>
           collect()
    setDT(dat)
    dat[,year:=2013+x]
    dat
  })

  dat <- merge(dat,edu_code,by="hfaudd",all.x=TRUE)
})
)

 
# ****************************************************************************
# SSS has data from private practice divided in two time periods.
# All entries are based on weekly additions of data from practitioners
# regarding patients.
# 
# *****************************************************************************/

