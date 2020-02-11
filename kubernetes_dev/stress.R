#!/usr/bin/env Rscript

library(stringr)
library(rstackdeque)
library(pryr)

rand_iterations <- max(0, as.integer(rnorm(1, mean = 2, sd = 5)))
ram_request <- as.integer(max(1, rnorm(1, 256, 64))) # in megs

rows <- rstack()

for(i in 1:rand_iterations) {
  write <- system(paste0("sync; dd if=/dev/zero of=tempfile bs=1M count=256 2>&1 ; sync "), intern = TRUE)
  write_speed <- paste(str_split(write[3], " ")[[1]][c(10, 11)], collapse = " ")

  read <- system(paste0("sync; dd if=tempfile of=/dev/null bs=1M count=256 2>&1 ; sync "), intern = TRUE)
  read_speed <- paste(str_split(read[3], " ")[[1]][c(10, 11)], collapse = " ")
  
  user <- system("echo $USER", intern = TRUE)
  current_time <- Sys.time()
  iteration <- i
  
  rand_sleep <- max(0, 3 + rexp(1, 0.5))
  system(paste0("sleep ", rand_sleep))
  
  gc()
  big_vec <- runif((1000*1000/8)*ram_request)

  res_list <- list(current_time = current_time,
                   user = user,
                   iteration = iteration,
                   write_speed = write_speed,
                   read_speed = read_speed,
                   ram_request = ram_request,
                   mem_use = as.integer(mem_used() / (1000*1000))) # in megs
  
  rm(big_vec)
  rows <- insert_top(rows, res_list)
}

write.table(as.data.frame(rows),
            row.names = FALSE, file = "", quote = FALSE, sep = "\t")
