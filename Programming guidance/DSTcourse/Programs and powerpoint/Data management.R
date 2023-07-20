# Data management - Basics
setwd('/Users/ctp/Dropbox/undvis/kursus register r')
load('frmgham2.rdata')
library(data.table)
library(heaven) # if not installed: devtools::install_github('tagteam/heaven')
library(Publish)

# Householding functions for data
str(Framingham) # lists variables, types and first values
names(Framingham) # String of names
head(Framingham) # First 5 records
class(Framingham) # Type
dim(Framingham) # dimensions
# When working with large data data.table is much more efficient than data.frame
# All examples of data management issues are described via data.table.
setDT(Framingham) # Change to data.table
class(Framingham) # Now data.table AND data.frame
# The data have one record per visit to the Framingham clinic and thus provides
# similar data to many datasets in Statistics Denmark.
# There are always a number of ways to obtain a result so the exaples are in
# no way the only option.
# 
# Many aspects of data.table become more efficient if it is supplied with a key
# to criticial variables
setkeyv(Framingham,c("randid","time")) #keyt by id and time of visit
# It is usually wise to have categorical variables as factors and in many
# cases this is not the outset.  An exception is "outcome" variables which in
# many cases function better as c(0,1) or c(0,1,2)
# An efficient way to convert multiple variables to factors is 
# Publish::lazyFactorCoding.  This function suggests programs lines to change each variable
# with a user defined number of levels to be changed to factors.  The output needs
# to be copied to the program:
lazyFactorCoding(Framingham)
# For the current exercise on datamanagement the copying is not done, but it can
# be found in Typical Programs 1.R
# Subsets of data:
temp <- Framingham[,.SD[1],by="randid"] # Selects the first in each group by randid
temp <- Framingham[,.SD[2],by="randid"] # Selects the second
temp <- Framingham[,.SD[.N],by="randid"] # Selects the last
# Subset with selected variables
temp1 <- Framingham[,.SD[1],.SDcols=c("sex"),by="randid"]
temp2 <- Framingham[,.SD[1],.SDcols=c("sysbp"),by="randid"]
temp3 <- Framingham[,.SD[1],.SDcols=c("diabetes"),by="randid"]
# If the first and last record of a group needs to be flagged the procedure is to use 
# the join facility of data.table (see manual) and perform an autojoin using "mult"
# to mark the first and last of a group
urandid <- unique(Framingham[,.SD,.SDcols="randid"]) #unique series of randid
Framingham[, c("first","last"):=0L] # first zero for first and last
Framingham[urandid, first:=1L, mult="first"]
Framingham[urandid, last:=1L, mult="last"]
# Selection of a subset of records
Fsex <- Framingham[sex==1]  # all records with sex=1
# Make a single new variable
# Note than no "<-" is necessary when creating new vectors in a dataset, but it is necessary
# if you are selecting part of a data.table
Framingham[,smoke_diab:=cursmoke*diabetes] # maybe not useful
# Make a series of new variables
Framingham[,':='(smoke_diab=cursmoke*diabetes,
                 smoke_sex=cursmoke*sex)]
# Make a new variable, but based on a condition
Framingham[,sex2:=0]
Framingham[sex==2,sex2:=1] # New sex variable with 0/1
# Make a new variable and define a factor for blood pressure by mean
Framingham[,sysbp2:=factor(sysbp>median(sysbp),levels=c(TRUE,FALSE),labels=c("above","below"))]
# Make a new variable which is quartiles of sysbp
Framingham[,sysbp4:=cut(sysbp, breaks=c(quantile(sysbp, probs = seq(0, 1, by = 0.25))), 
                      labels=c("Q1","Q2","Q3","Q4"), include.lowest=TRUE)] # note, result=factor
# Merging - simple merge of two
temp <- merge(temp1,temp2,by="randid",all=TRUE)
# Merge a set of data.tables
temp <- Reduce(function(...) merge(..., all = TRUE, by="randid"), list(temp1,temp2,temp3))
# Note "all=" controls type of join. 
# all=TRUE, all records in all data.tables
# all=FALSE, inner join, only where all contributes
# all.x=TRUE, left join, the leftmost table decides which records should be ratined
# all.y=TRUE, right join, the most right data.table decides
#
# Append
# Use rbind() to add data.tables to bottom of other tables
# Use cbind() to add by column (merge without by)
#
# rename
# Use setnames(data,c(),c())
#
# Column order
# use setcolorder(dat,c())
###############################################
# Special Heaven functions
############################################








