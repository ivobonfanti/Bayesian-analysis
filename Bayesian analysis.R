---
title: "CDS_BVAR_Code"
author: "GuidoGIacomoMussini, Ivo Bonfanti"
date: "2023-05-02"
output: html_document
editor_options: 
  chunk_output_type: console
---

Chunk 0: Functions
```{r}
#compute the mean per lag-------------------------------------------------------
lagmean <- function(vect, lag){
  vect = as.double(vect)
  meanlist <- c()
  mean = 0
  lim = (length(vect)/lag) -1
  for(i in 0: lim){
    pos = i*lag
    for(l in 1: lag){
      mean = mean + vect[pos+l]*(1 / 2^(l))
    }
    meanlist[i+1] <- mean
  }
  return(meanlist)
}

#set to zero elements in a matrix < 0-------------------------------------------
th_matrix <- function(mat){
  ret_mat = matrix(0, nrow(mat), ncol(mat))
  for(i in 1:nrow(mat)){
    for(j in 1:ncol(mat)){
      if(mat[i,j] >= 0)
      {ret_mat[i,j] = mat[i,j]}
    }
  }
  return(ret_mat)
}
```

Chunk 1: Libraries
```{r}
# Code inspired by https://www.r-econometrics.com/timeseries/bvar/
library(readxl)
library(vars)
library(dplyr)
library(stats)
library(bvartools)
library(LaplacesDemon)
library(ggplot2)
library(reshape2)
library(dplyr)
library(textshape)
library(tidyverse)

#setwd("C:XXXXXX")
setwd("C:XXXXXX")


```

Chunk 2: Upload the data
```{r}
cds <- read_excel("CDS.xlsx", na = "NA")
```

Chunk 3: Remove NA and useless columns
```{r}
#remove Na's
cds <- na.omit(cds)
#store a copy for the plots
cds_plot <- cds
#remove the Dates
cds <- cds %>% select(-c("Name"))
```

Chunk 4: Rename the columns
```{r}
cds <- cds %>% rename(
  'Banca_Intesa' = 'INTESA SANPAOLO SNR MM 5Y E - CDS PREM. MID',
  'Mediobanca' = 'MEDIOBANCA SPA SNR MM 5Y E - CDS PREM. MID',
  'Credit_Agricole' = 'CREDIT AGRICOLE SA SNR MM 5Y E - CDS PREM. MID',
  'Societe_Generale' = 'SOCIETE GENERALE SNR MM 5Y E - CDS PREM. MID',
  'Banco_Santander' = 'BANCO SANTANDER SNR MM 5Y E - CDS PREM. MID',
  'Deutsche_Bank' = 'DEUTSCHE BANK AG SNR MM 5Y E - CDS PREM. MID',
  'Commerzbank' = 'COMMERZBANK AG SNR MM 5Y E - CDS PREM. MID',
  'HSBC' = 'HSBC BANK PLC SNR MM 5Y E - CDS PREM. MID',
  'Lloyds_bank' = 'LLOYDS BANK SNR MM EUR 5Y - CDS PREM. MID',
  'BNP' = 'BNP PARIBAS SA SNR MM 5Y E - CDS PREM. MID',
  'Credit_Suisse' = 'CREDIT SUISSE GROUP SNR MM 5Y E - CDS PREM. MID',
  'UBS' = 'UBS AG SNR MM 5Y E - CDS PREM. MID', 
  'Danske_Bank' = 'DANSKE BANK A/S SNR MM 5Y E - CDS PREM. MID',
  'Swedbank' = 'SWEDBANK AB SNR MM 5Y E - CDS PREM. MID'
)
```

Chunk 5: Plot the series
```{r}
#rename the variables
#-------------------------------------------------------------------------------

cds_plot <- cds_plot %>% rename(
  'Banca_Intesa' = 'INTESA SANPAOLO SNR MM 5Y E - CDS PREM. MID',
  'Mediobanca' = 'MEDIOBANCA SPA SNR MM 5Y E - CDS PREM. MID',
  'Credit_Agricole' = 'CREDIT AGRICOLE SA SNR MM 5Y E - CDS PREM. MID',
  'Societe_Generale' = 'SOCIETE GENERALE SNR MM 5Y E - CDS PREM. MID',
  'Banco_Santander' = 'BANCO SANTANDER SNR MM 5Y E - CDS PREM. MID',
  'Deutsche_Bank' = 'DEUTSCHE BANK AG SNR MM 5Y E - CDS PREM. MID',
  'Commerzbank' = 'COMMERZBANK AG SNR MM 5Y E - CDS PREM. MID',
  'HSBC' = 'HSBC BANK PLC SNR MM 5Y E - CDS PREM. MID',
  'Lloyds_bank' = 'LLOYDS BANK SNR MM EUR 5Y - CDS PREM. MID',
  'BNP' = 'BNP PARIBAS SA SNR MM 5Y E - CDS PREM. MID',
  'Credit_Suisse' = 'CREDIT SUISSE GROUP SNR MM 5Y E - CDS PREM. MID',
  'UBS' = 'UBS AG SNR MM 5Y E - CDS PREM. MID', 
  'Danske_Bank' = 'DANSKE BANK A/S SNR MM 5Y E - CDS PREM. MID',
  'Swedbank' = 'SWEDBANK AB SNR MM 5Y E - CDS PREM. MID',
  'Banks' = 'Name'
  
)
#-------------------------------------------------------------------------------

cds_plot = t(cds_plot)
colnames(cds_plot) <- cds_plot[1,]
cds_plot <- data.frame(cds_plot[-1,])
cds_plot <- tibble::rownames_to_column(cds_plot, "Banks")

data <- melt(cds_plot,id.vars=c("Banks"),value.name="value",
                     variable.name="Day")
data$value <- as.integer(data$value)
cds_min = min(data$value)
cds_max = max(data$value)

ts_plot <- ggplot(data=data, aes(x=Day, y=value, group = Banks,
                                            colour = Banks))+ 
  geom_line() +labs(y= "CDS Value", x = "Day")+
  scale_y_continuous(breaks=seq(cds_min,cds_max,50))+
  scale_x_discrete(breaks=c("X2008.10.31",
                            "X2023.04.20"))+
  ggtitle("5 Year CDS MM SNR by Bank") + theme_classic()
 
# x11()
# ts_plot
rm(data, ts_plot, cds_plot, cds_max, cds_min)
```

Chunk 6: Generate the Model
```{r}
#transform the data set in a 'time series' object
cds <- as.ts(cds[1:200, 1:5])
#take the log first difference
cds <- diff(log(cds))*100

set.seed(19)
#define number of lags
lag=3
#create the model
model <- gen_var(cds, p=lag)
#extract the data
y <- t(model$data$Y)
x <- t(model$data$Z)
```

Chunk 7: Define the Litterman prior object
```{r}
Litterman_prior <- minnesota_prior(
  model,
  kappa0 = 0.04,
  kappa1 = 0.25,
  kappa2 = NULL,
  kappa3 = 5,
  max_var = NULL,
  coint_var = TRUE,
  sigma = "VAR"
)
```

Chunk 8: Define the parameters for the Gibbs sampler
```{r}
draws <- 10000 # Number of iterations of the Gibbs sampler
burnin <- 1000 # Number of burn-in draws
store = draws-burnin

tt <- ncol(y) # Number of observations 
k <- nrow(y) # Number of endogenous variables (number of banks) 
m <- k * nrow(x) # Number of estimated coefficients for each VAR

#Litterman prior parameters 
beta_mu_prior <- Litterman_prior$mu # Vector of prior parameter means
beta_v_i_prior <- Litterman_prior$v_i # Inverse of the prior covariance matrix

#Inverse Wishart parameters
u_nu_prior <- k+1 #degrees of freedom
zeta_scale_prior<- diag(1, k) #scale matrix
u_nu_post <- tt + u_nu_prior # Posterior degrees of freedom
u_sigma <- diag(1, k) #Sigma initialization (ones could take 10*I or use OLS estimator instead)
```

Chunk 9: Gibbs sampler
```{r}
# Data containers for posterior draws
draws_a <- matrix(NA, m, store) #for each iteration m coefficients
draws_sigma <- matrix(NA, k*k, store)#for each iteration k^2 coefficients --> VAR-COV matrices

#define progress bar
pb <- txtProgressBar(min = 0, max = draws, style = 3, width = 50, char = "=")

# Start Gibbs sampler
for (draw in 1:draws) {
setTxtProgressBar(pb, draw) #progress bar
  
# Draw conditional mean parameters
beta <- post_normal(y, x, u_sigma, beta_mu_prior, beta_v_i_prior)

# Draw variance-covariance matrix
u <- y - matrix(beta, k) %*% x # Obtain residuals
u_zeta_post <-zeta_scale_prior + tcrossprod(u) #obtain posterior scale matrix
u_sigma <-rinvwishart(u_nu_post, u_zeta_post) #estimate Sigma with iW

#store Beta and Sigma
if (draw > burnin) {
  draws_a[, draw - burnin] <- beta 
  draws_sigma[, draw - burnin] <- u_sigma 
  }
}
```

Chunk 10: Create the adjacency Matrix for the Graph
```{r}
#Obtain the mean-coefficient matrix---------------------------------------------
A <- rowMeans(draws_a) # Obtain means for every row
A <- matrix(A, k) # Transform mean vector into a matrix
A <- round(A, 3) # Round values
dimnames(A) <- list(dimnames(y)[[1]], dimnames(x)[[1]]) # Rename matrix dimensions

#Convert the matrix to a dataframe
A <- data.frame(A)

#Order the columns alphabetically
order = sort(colnames(A))
A <- A[, order]

#remove the constant
A <- A %>% select(-c('const'))

#create the dataframe for the adjacency matrix----------------------------------

col_names <- row.names(A)
df = data.frame(matrix(nrow = 0, ncol = (length(col_names)) ))
colnames(df) <- col_names 

#derive the weighted mean for the 3 lags of the coefficients
for(j in 1: k){
  lmean = c()
  row = A[j, ]
  lmean = lagmean(row, lag)
  df[nrow(df)+1, ] <- lmean
} 

#assign the banks' names as rownames
df['Banks'] <- col_names
df <- df %>% remove_rownames %>% column_to_rownames(var="Banks")
```

Chunk 11: Transform the dataframe in the adjacency matrix
```{r}
#convert to matrix
ad_mat <- as.matrix(df)

#set to zero the elements of the main diagonal 
diag(ad_mat) <- 0

#retrieve the mean of the matrix
mat_mean = mean(ad_mat)

#use the total mean of the matrix as threshold
ad_mat = ad_mat - mat_mean

#set to zero the elements < 0 and round the results
graph_mat = round(th_matrix(ad_mat), 3)
```

Chunk 12: Store the Adj. matrix
```{r}
#write.csv(graph_mat, 
          #file = "C:\\Users\\Guido\\Desktop\\Bayesian_Analysis\\Project\\data.csv",
          #row.names=FALSE)
write.csv(graph_mat,
           file = "C:\\Users\\ivobo\\OneDrive - Università degli Studi di Milano\\Desktop\\data1.csv",
           row.names=FALSE)
```

Chunk 13: Prediction
```{r}
#create the BVAR object
bvar_est <- bvar(y = model$data$Y, x = model$data$Z, A = draws_a[1:(m-k),],
                 C = draws_a[(m-k+1):m, ], Sigma = draws_sigma)

#thinning
bvar_est <- thin(bvar_est, thin = 20)

#compute the estimation
bvar_pred <- predict(bvar_est, n.ahead = 10, new_d = rep(1, 10))
```

Chunk 14: Plot the estimation results
```{r}
par(mar=c(1,1,1,1))
plot(bvar_pred)
```

