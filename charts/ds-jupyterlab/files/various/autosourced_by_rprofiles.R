# create user R library
if(!dir.exists(Sys.getenv("R_LIBS_USER"))) {
  dir.create(path = Sys.getenv("R_LIBS_USER"), recursive = TRUE)
}

# make user R library the default
.libPaths(c(Sys.getenv("R_LIBS_USER"), .libPaths()))

# fix github install issues (https://github.com/conda-forge/r-devtools-feedstock/issues/4)
Sys.setenv(TAR = "/bin/tar")

# we're going to put custom functions into base, so they don't show up in the global environment but are still accessible
base <- getNamespace("base")

# set hub.install.packages to install into R_LIBS_SITE for everyone
base$hub.install.packages <- function(...) {
  install.packages(..., lib = Sys.getenv("R_LIBS_SITE"))
}

# for devtools::install_github
base$hub.install_github <- function(...) {
  withr::with_libpaths(Sys.getenv("R_LIBS_SITE"), 
                       devtools::install_github(...))
}

# for bioconductor installs
base$hub.install_bioconductor <- function(...) {
  withr::with_libpaths(Sys.getenv("R_LIBS_SITE"), {
                         if (!requireNamespace("BiocManager", quietly = TRUE)) {
                           install.packages("BiocManager")
                         }
                         BiocManager::install(...)}
                       )
}

# done with the base env, we can remove it from the global environment
rm(base)
