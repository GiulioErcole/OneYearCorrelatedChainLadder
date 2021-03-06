
###### Initialize simulations parameters ######
ndiag <- 1
options(digits = 5)
# I collect just the rates
discount <- rfr[1,2] %>% unlist %>% unname ## beware of tibbles!
forward <- fwd_curve[1:(t-2),] %>% unlist ## needed fwd curve up to t - 2 terms ahead
spot <- rfr[1:t-1,2] %>% unlist %>% unname
######

###### 1 - I calculate the future BEST ESTIMATE for each parameters set #######
###### This computation is performed once
###### All these Best Estimates are then weighted according to 
###### the posterior probability distribution obtained from the simulated batch

expectations <- lapply(arranged_sets, function(p) expectation_function(p))

###### from the cumulative expectations I get the lower triangle
###### of incremental payments

lower_incrementals <- lapply(expectations, function(p) get_lower_incremental(p,t,ndiag))

###### I apply the forward discount to obtain the future bests estimates

future_best_estimates <- sapply(lower_incrementals, function(h) get_nextyear_be(h,forward))

#future_best_estimates %>% sim_recap
###### I have the future best estimates to weigh with the posterior probabilities
###### obtained by the simulations

###### 2- Simulating next year payments development ######

###### I create a function to get one value of the next year obligations #####

next_year_obligations <-function(arranged_sets,diagonal, ndiag, discount, future_best_estimates){
  
  
  ##### Simulation works in batches: for each parameters set I simulate 
  ##### a development scenario. These scenarios are the first batch of simulations
  ##### From a given batch the goal is to obtain a value of the next year obligations
  
  ##### 2.1 - I simulate a batch of 10000 diagonals, 1 for each parameters set
  ##### I have arranged parameters in memory
  
  batch <- lapply(1:length(arranged_sets), function(p) low.sim.mat(arranged_sets[[p]],ndiag))
  
  ##### 2.2 - Get the posterior probability of the simulated batch ######
  
  post_prob <- posterior_probability(batch,1)
  
  ##### 2.3 - Simulate the next year payments #######
  
  paid_oneyear <- sapply(batch, function(p) paid.1yr.batch(p,diagonal,discount))
  
  ##### 3 - weigh the best estimates values and obtain a value of the next year obligations
  
  expected_be = weighted.mean(future_best_estimates,post_prob)
  
  next_year_obligations <- sample(paid_oneyear,1) + (expected_be) / (1 + discount)
  
  return(next_year_obligations)
  
}

##### I simulate a value #####

tic()
test_value <- next_year_obligations(arranged_sets,diagonal,1,discount,future_best_estimates)
toc()

#set.seed(845921)
set.seed(101)

c1 <- makeCluster(3)
clusterExport(c1, "arranged_sets")
clusterExport(c1, "next_year_obligations")
clusterExport(c1, "low.sim.mat")
clusterExport(c1, "lkyhd")
clusterExport(c1, 'paid.1yr.batch')
clusterExport(c1, 'posterior_probability')
clusterExport(c1, "discount")
clusterExport(c1, "forward")
clusterExport(c1, 'diagonal')
clusterExport(c1, 'future_best_estimates')
clusterExport(c1, 't')
tic()
cc <- parSapply(c1,1:10000,function(p) next_year_obligations(arranged_sets,diagonal,1,discount,future_best_estimates))
toc()
stopCluster(c1)
#
hist(cc, col ='orange')

one_yr_ccl <- cc %>% sim_recap
ccl_compare
max(cc)
oneyr_on_total <- one_yr_ccl[3]/ccl_compare[3,1]
oneyr_on_total_alt <- one_yr_ccl[2]/ccl_compare[2,1]
#### get ccl implied best estimate
ube_list <- lapply(expectations, function(p) get_lower_incremental(p,t,0))
#### the function get next year be works also for the BE, just by using
#### a spot curve and ensuring to have the whole lower triangle
discount_be <- sapply(ube_list, function(h) get_nextyear_be(h,spot))

ccl_BE <- discount_be %>% mean

ccl_scr <- (one_yr_ccl[10] - ccl_BE) %>% unname
ccl_scr/ccl_BE %>%  unname

##### claims development result
(ccl_BE - cc) %>% hist(col = 'orange')
(ccl_BE - cc) %>% sim_recap()
# write.csv(cc,'one_year_simulations.csv')
# save(cc,file = "one_year_simulations.rda")
