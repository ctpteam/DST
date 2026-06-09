# *************************************************************************************
# BEST PRACTICE TEMPLATE
# Danish register research with targets + DuckDB + Parquet
# *************************************************************************************
#
# Purpose
# -------
# This file is intended as a guide for projects that read converted DST/SDS register
# data stored as Parquet directory datasets.  It is deliberately verbose: comments
# explain why each pattern is used, so the file can be copied and adapted for new
# studies.
#
# Main principles
# ---------------
# 1. Do heavy work inside DuckDB: scan, select columns, filter rows, and join to the
#    study population before collect().
# 2. Use Arrow mainly for small/simple datasets or for interactive inspection.
# 3. Do not place head() early in a pipeline.  Use TEST_LIMIT at the END of the SQL
#    query.  Remove or set TEST_LIMIT <- NULL for production runs.
# 4. Avoid oversubscription.  Use either many DuckDB threads in one process, or many
#    R workers with few DuckDB threads each.  Do not multiply both without thinking.
# 5. Prefer simple SQL predicates such as LIKE over R regex helpers such as grepl()
#    when scanning very large Parquet datasets.
# 6. Collect only the columns needed for the analysis.
#
# Before production use
# ---------------------
# - Run with TEST_LIMIT <- 10000 while developing.
# - Inspect the generated queries with EXPLAIN ANALYZE for the largest targets.
# - Then set TEST_LIMIT <- NULL and rebuild the relevant targets.
#
# *************************************************************************************

library(targets)
library(data.table)
library(DBI)
library(duckdb)
library(glue)
library(heaven)
library(dplyr)

# Optional but useful for users who continue to use Arrow for small extracts.
library(arrow)

# Set project working directory here if needed.
setwd("Z:/Workdata/703740/christianTorp-Pedersen/parquet/")

tar_option_set(
  packages = c(
    "data.table", "DBI", "duckdb", "glue", "heaven", "arrow","dplyr"
  )
)

# =============================================================================
# User configuration
# =============================================================================

# TEST_LIMIT controls fast development runs.
# - Use a number, for example 10000, while testing code.
# - Set to NULL for production.
#
# IMPORTANT: this template places TEST_LIMIT at the end of the SQL query.  This is
# different from putting head() first in a dplyr pipeline.  The filters and joins are
# still tested before DuckDB returns only a limited number of rows.
#TEST_LIMIT <- 10000L
TEST_LIMIT <- NULL

# Threads used by a single DuckDB connection.  For one very large read, using many
# threads in one connection is usually better than splitting the work across many R
# workers.  If running many targets in parallel, reduce this value.
DUCKDB_THREADS <- 20L

# =============================================================================
# Helper functions
# =============================================================================

sql_quote_path <- function(path) {
  # SQL string literal for Windows paths.  DuckDB accepts forward slashes, so convert
  # backslashes to forward slashes to avoid escaping surprises.
  path <- gsub("\\\\", "/", path)
  paste0("'", gsub("'", "''", path), "'")
}

parquet_glob <- function(path) {
  # The converted datasets are directory datasets: dataset.parquet/part_000000.parquet.
  # parquet_scan() should receive the individual part files, not the _SUCCESS marker.
  paste0(gsub("\\\\", "/", path), "/*.parquet")
}

limit_clause <- function(n = TEST_LIMIT) {
  if (is.null(n)) "" else glue("\nLIMIT {as.integer(n)}")
}

open_duckdb <- function(threads = DUCKDB_THREADS) {
  # Setting threads in config makes the intention explicit at connection creation.
  # PRAGMA is repeated as a safeguard for older code paths and for readability.
  con <- DBI::dbConnect(
    duckdb::duckdb(),
    dbdir = ":memory:",
    config = list(threads = as.character(threads))
  )
  DBI::dbExecute(con, glue("PRAGMA threads={as.integer(threads)}"))
  con
}

copy_pnr_filter <- function(con, pnrlist, table_name = "pnr_filter") {
  # A temporary DuckDB table is the preferred way to join a study population to a
  # large Parquet scan.  It avoids collecting the whole register into R.
  DBI::dbWriteTable(con, table_name, as.data.frame(pnrlist), temporary = TRUE, overwrite = TRUE)
  invisible(table_name)
}

explain_query <- function(con, sql) {
  # Use during development for large targets:
  # explain_query(con, my_sql)
  DBI::dbGetQuery(con, paste("EXPLAIN ANALYZE", sql))
}

read_sql_dt <- function(con, sql) {
  # Centralized collect step.  All heavy work should already be in sql.
  x <- DBI::dbGetQuery(con, sql)
  data.table::setDT(x)
  x
}

# =============================================================================
# targets pipeline
# =============================================================================

list(
  tar_target(
    dirstart,
    "Z:/Workdata/703740/rawdata_parquet_ctp"
  ),
  
  # ---------------------------------------------------------------------------
  # Population
  # ---------------------------------------------------------------------------
  # The population target defines the study base.  It is intentionally allowed to
  # collect into R because the following person-level interval logic is easier and
  # clearer in data.table.  The expensive reads, however, still select only relevant
  # columns before collecting.
  # ---------------------------------------------------------------------------
tar_target(pop, {
    con <- open_duckdb(threads = DUCKDB_THREADS)
    on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
    
    pop_dir <- file.path(dirstart, "Grunddata", "Population")
    
    # FAIN files: 1980-1984.  We read each directory dataset and add reference date
    # from the filename.  LIMIT is at the end of each query for testing only.
    fain_dirs <- list.files(pop_dir, pattern = "^fain", full.names = TRUE)
    fain <- rbindlist(lapply(fain_dirs, function(path) {
      yr <- sub(".*fain([0-9]{4}).*", "\\1", basename(path))
      sql <- glue("        
                  SELECT         
                  pnr,          
                  koen,          
                  DATE '{yr}-12-31' AS referencetid        
                  FROM parquet_scan({sql_quote_path(parquet_glob(path))})        
                  WHERE pnr IS NOT NULL AND pnr <> ''        
                  {limit_clause()}
                  ")
      read_sql_dt(con, sql)
    }), fill = TRUE)
    
    # BEF files: 1985 onwards.  BEF already contains referencetid.
    bef_dirs <- list.files(pop_dir, pattern = "^bef", full.names = TRUE)
    bef <- rbindlist(lapply(bef_dirs, function(path) {
      sql <- glue("        
                  SELECT       
                  pnr,         
                  foed_dag,          
                  koen,               
                  FROM parquet_scan({sql_quote_path(parquet_glob(path))})      
                  WHERE pnr IS NOT NULL AND pnr <> ''      
                  {limit_clause()}
                  ")
      read_sql_dt(con, sql)
    }), fill = TRUE, ignore.attr=TRUE)
    
    dat <- rbindlist(list(fain, bef), fill = TRUE)
    names(dat) <- tolower(names(dat))
    dat <- dat[pnr != ""]
    #dat[, referencetid := as.Date(referencetid)]
    
    # t_person supplies birth date.  We use DuckDB for consistency and select only
    # the needed columns.
    t_person_sql <- glue("      
                         SELECT        
                         v_pnr AS pnr,        
                         d_foddato AS foed_dag_person      
                         FROM parquet_scan({sql_quote_path(parquet_glob(file.path(pop_dir, 't_person.parquet')))})      
                         WHERE v_pnr IS NOT NULL AND v_pnr <> ''      
                         {limit_clause()}    
                         ")
    t_person <- read_sql_dt(con, t_person_sql)
    
    dat <- merge(dat, t_person, by = "pnr", all.x = TRUE)
    
    setkeyv(dat, c("pnr", "referencetid"))
    
    # Define first continuous period of presence in the population registers.
    dat[, dist := fifelse(data.table::year(referencetid) > 2007, 95, 370)]
    dat[pnr == shift(pnr) & (referencetid - shift(referencetid) > dist), pause := 1]
    dat[, pause := nafill(pause, type = "locf"), by = "pnr"]
    dat <- dat[is.na(pause)]
    
    dat <- dat[, .(
      foed_dag = foed_dag[1],
      foed_dag_person = foed_dag_person[1]
      koen = koen[1],
      inn = referencetid[1],
      out = referencetid[.N]
    ), by = "pnr"]
    
    # Emigration after leaving BEF/FAIN.
    vnds_sql <- glue("
                     SELECT        
                     pnr,        
                     haend_dato     
                     FROM parquet_scan({sql_quote_path(parquet_glob(file.path(pop_dir, 'vnds2024.parquet')))})      
                     WHERE indud_kode = 'U'      
                     {limit_clause()}
                    ")
    vnds <- read_sql_dt(con, vnds_sql)
    names(vnds) <- tolower(names(vnds))
    vnds[, haend_dato := as.Date(haend_dato)]
    vnds <- merge(vnds, dat[, .(pnr, out)], by = "pnr", all.x = FALSE)
    vnds <- vnds[haend_dato > out, .(pnr, haend_dato)]
    setkeyv(vnds, c("pnr", "haend_dato"))
    vnds <- vnds[, .SD[1], by = "pnr"]
    
    # Death date.
    death_sql <- glue("
                      SELECT        
                      pnr,        
                      doddato      
                      FROM parquet_scan({sql_quote_path(parquet_glob(file.path(dirstart, 'Grunddata', 'Death', 'dod.parquet')))})      
                      WHERE pnr IS NOT NULL AND pnr <> ''      
                      {limit_clause()}    
                    ")
    death <- read_sql_dt(con, death_sql)
    names(death) <- tolower(names(death))
    death[, doddato := as.Date(doddato)]
    
    dat <- Reduce(
      function(x, y) merge(x, y, by = "pnr", all.x = TRUE),
      list(dat, vnds, death)
    )
    
    dat[data.table::year(out) > 2007, out := out + 91]
    dat[data.table::year(out) < 2008, out := out + 365]
    dat[doddato < inn, doddato := NA]
    dat[, out := pmin(out, doddato, haend_dato, na.rm = TRUE)]
    dat[is.na(foed_dag) | foed_dag != foed_dag_person, foed_dag := foed_dag_person]
    dat[, foed_dag_person := NULL]
    dat[]
  }),
  
tar_target(
    pnrlist,
    unique(pop[, .(pnr)])
  ),
  
  # ---------------------------------------------------------------------------
  # Cancer registry
  # ---------------------------------------------------------------------------
tar_target(cancer, {
    con <- open_duckdb(threads = DUCKDB_THREADS)
    on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
    copy_pnr_filter(con, pnrlist)
    
    sql <- glue("      
                SELECT c.*      
                FROM parquet_scan({sql_quote_path(parquet_glob(file.path(dirstart, 'Grunddata', 'cancer', 'tumor_aarlig.parquet')))}) AS c
                INNER JOIN pnr_filter AS f        
                ON c.pnr = f.pnr
                {limit_clause()}
               ")
    
    dat <- read_sql_dt(con, sql)
    names(dat) <- tolower(names(dat))
    dat
  }),
  
  # ---------------------------------------------------------------------------
  # Death
  # ---------------------------------------------------------------------------
  tar_target(death, {
    con <- open_duckdb(threads = DUCKDB_THREADS)
    on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
    copy_pnr_filter(con, pnrlist)
    
    sql <- glue("\n      
                SELECT d.*      
                FROM parquet_scan({sql_quote_path(parquet_glob(file.path(dirstart, 'Grunddata', 'death', 'dod.parquet')))}) 
                AS d      
                INNER JOIN pnr_filter AS f        
                ON d.pnr = f.pnr      
                {limit_clause()}    
               ")
    
    dat <- read_sql_dt(con, sql)
    names(dat) <- tolower(names(dat))
    dat
  }),
  
  # ---------------------------------------------------------------------------
  # Laboratory data
  # ---------------------------------------------------------------------------
  # LABKA/laboratory data are usually huge.  The key optimization is to join to the
  # population and filter by analysis code before collect().  Prefer LIKE over regex
  # if the condition is a simple prefix.
  # Reading restircted in the example to NPU03/4 - sodium, potassium
  # ---------------------------------------------------------------------------
tar_target(lab, {
    con <- open_duckdb(threads = DUCKDB_THREADS)
    on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
    copy_pnr_filter(con, pnrlist)
    
    lab_path <- file.path(dirstart, "Grunddata", "laboratory", "laboratorieproevesvar.parquet")
    
    sql <- glue("      
                SELECT        
                l.pnr,        
                l.analysiscode,        
                l.samplingdate,        
                l.samplevalue     
                FROM parquet_scan({sql_quote_path(parquet_glob(lab_path))}) 
                AS l      INNER JOIN pnr_filter AS f        
                ON l.pnr = f.pnr     
                WHERE l.analysiscode LIKE 'NPU03%'         
                OR l.analysiscode LIKE 'NPU04%'      
                {limit_clause()}    
               ")
    
    # During performance work, uncomment this line to see where time is spent:
    # print(explain_query(con, sql))
    
    labdata <- read_sql_dt(con, sql)
    names(labdata) <- tolower(names(labdata))
    labs <- list(
      potassium = "NPU03230",
      sodium = "NPU03429"
    )
    
    findCondition(
      labdata,
      "analysiscode",
      c("pnr", "samplingdate", "samplevalue"),
      labs,
      match = "start"
    )
  }),
  
  # ---------------------------------------------------------------------------
  # Hospital diagnoses: LPR1/2 and LPR3
  # ---------------------------------------------------------------------------
tar_target(amiangina, {
    con <- open_duckdb(threads = DUCKDB_THREADS)
    on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
    copy_pnr_filter(con, pnrlist)
    
    # LPR1/2.  Prefix matching is written as LIKE expressions rather than grepl().
    diag1_sql <- glue("      
                      SELECT        
                      d.pnr,        
                      d.diag,        
                      d.inddto,        
                      d.pattype      
                      FROM parquet_scan({sql_quote_path(parquet_glob(file.path(dirstart, 'Grunddata', 'lpr', 'diag_indl.parquet')))}) AS d      
                      INNER JOIN pnr_filter AS f        
                      ON d.pnr = f.pnr      
                      WHERE d.pattype = '0'        
                      AND (d.diag LIKE 'DI2%' OR d.diag LIKE '41%')      
                      {limit_clause()}    
                     ")
    diag1 <- read_sql_dt(con, diag1_sql)
    setDT(diag1)
    names(diag1) <- tolower(names(diag1))
    diags <- list(
      ami = c("410", "DI21"),
      angina = c("413", "DI20")
    )
    diag1a <- findCondition(diag1, "diag", c("pnr", "inddto"), diags, match = "start")
    
    # LPR3.  Join diagnoses to contacts inside DuckDB before collect().
    diag3_sql <- glue("      
                      SELECT        
                      k.cpr AS pnr,        
                      d.diagnosekode AS diag,        
                      k.dato_start,\n        k.tidspunkt_start,        
                      k.dato_slut,\n        k.tidspunkt_slut,        
                      k.kontakttype      
                      FROM parquet_scan({sql_quote_path(parquet_glob(file.path(dirstart, 'Grunddata', 'lpr', 'diagnoser.parquet')))}) AS d      
                      INNER JOIN parquet_scan({sql_quote_path(parquet_glob(file.path(dirstart, 'Grunddata', 'lpr', 'kontakter.parquet')))}) AS k        
                      ON d.dw_ek_kontakt = k.dw_ek_kontakt      
                      INNER JOIN pnr_filter AS f        
                      ON k.cpr = f.pnr      
                      WHERE d.diagnosekode LIKE 'DI2%'         
                      OR d.diagnosekode LIKE '41%'      
                      {limit_clause()}    
                     ")
    diag3 <- read_sql_dt(con, diag3_sql)
    names(diag3) <- tolower(names(diag3))
    setDT(diag3)
    
    diag3[, start := as.POSIXct(paste(dato_start, tidspunkt_start))]
    diag3[!is.na(dato_slut) & !is.na(tidspunkt_slut), slut := as.POSIXct(paste(dato_slut, tidspunkt_slut))]
    diag3[, dif := slut - start]
    diag3 <- diag3[kontakttype == "ALCA00" & dif > 60 * 60 * 12]
    setnames(diag3, c("dato_start", "diag"), c("inddto", "diag"), skip_absent = TRUE)
    diag3a <- findCondition(diag3, "diag", c("pnr", "inddto"), diags, match = "start")
    
    rbindlist(list(diag1a, diag3a), fill = TRUE)
  }),
  
  # ---------------------------------------------------------------------------
  # Medication
  # ---------------------------------------------------------------------------
tar_target(med, {
    con <- open_duckdb(threads = DUCKDB_THREADS)
    on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
    copy_pnr_filter(con, pnrlist)
    
    med_dir <- file.path(dirstart, "Grunddata", "medication")
    med_dirs <- list.files(med_dir, pattern = "^lmdb20(14|1[5-9]|2[0-2])12.*", full.names = TRUE)
    
    dat <- rbindlist(lapply(med_dirs, function(path) {
      year <- sub(".*lmdb([0-9]{4}).*", "\\1", basename(path))
      sql <- glue("
                  SELECT          
                  m.pnr,          
                  m.atc,          
                  m.eksd,          
                  m.volume,          
                  m.packsize,          
                  {year}::INTEGER AS source_year        
                  FROM parquet_scan({sql_quote_path(parquet_glob(path))}) AS m        
                  INNER JOIN pnr_filter AS f          
                  ON m.pnr = f.pnr        
                  WHERE m.atc LIKE 'C03%'           
                  OR m.atc LIKE 'C07%'        
                  {limit_clause()}      
                 ")
      read_sql_dt(con, sql)
    }), fill = TRUE)
    names(dat) <- tolower(names(dat))
    setDT(dat)
    medications <- list(
      diuretics = "C03",
      betablocker = "C07"
    )
    
    findCondition(dat, "atc", c("pnr", "atc", "eksd", "volume", "packsize"), medications, match = "start")
  }),
  
  # ---------------------------------------------------------------------------
  # DREAM / social benefits
  # ---------------------------------------------------------------------------
  # DREAM is often wide and then converted to long format with heaven::importDREAM().
  # Select only PNR and DREAM week/month columns before collect().
  # With DREAM the issues is multiple columns and only wanting those that start with
  # "y_". For this task arrow is better
  # ---------------------------------------------------------------------------
  tar_target(dream, {
    ds <- open_dataset(paste0(dirstart,"/Grunddata/Social/dream202509.parquet"))
    set_cpu_count(20)
    dream <- ds |>
      select(PNR,starts_with("Y_")) |>
      rename(pnr=PNR) |>
      semi_join(pnrlist,by="pnr") |>
      collect() 
    
    names(dream) <- tolower(names(dream))
    setDT(dream)
    # The huge example it to big for importDREAM - number of columns*number of rows exeeds limit
    dream <- dream[1:1000]
    importDREAM(dream)
  }),
  
  # ---------------------------------------------------------------------------
  # Education
  # ---------------------------------------------------------------------------
  tar_target(education, {
    con <- open_duckdb(threads = DUCKDB_THREADS)
    on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
    copy_pnr_filter(con, pnrlist)
    
    edu_dir <- file.path(dirstart, "Grunddata", "social")
    edu_dirs <- list.files(edu_dir, pattern = "^udda20(14|1[5-9]|2[0-2]).*", full.names = TRUE)
    
    dat <- rbindlist(lapply(edu_dirs, function(path) {
      year <- sub(".*udda([0-9]{4}).*", "\\1", basename(path))
      sql <- glue("        
                  SELECT         
                  u.pnr,          
                  u.hfaudd,          
                  {year}::INTEGER AS year        
                  FROM parquet_scan({sql_quote_path(parquet_glob(path))}) AS u        
                  INNER JOIN pnr_filter AS f\n          ON u.pnr = f.pnr        
                  {limit_clause()}      
                 ")
      read_sql_dt(con, sql)
    }), fill = TRUE)
    str(dat)
    names(dat) <- tolower(names(dat))
    # Optional study-specific step, if edu_code is available in the project:
    # merge(dat, edu_code, by = "hfaudd", all.x = TRUE)
  })
)
