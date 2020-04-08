FROM oneilsh/ktesting-datascience-notebook:v1.1.5

RUN pip install --no-cache-dir nbgitpuller==0.8.0

USER root

RUN apt-get update \
 && apt-get install -yq --no-install-recommends \
    less \
    tmux

# need to install rmarkdown, learnr, shinydashboard, leaflet (all cran, for learnr and bus-dashboard demo)
echo "install.packages(\"rmarkdown\", repos=\"https://cran.rstudio.com\")" | R --no-save
echo "install.packages(\"learnr\", repos=\"https://cran.rstudio.com\")" | R --no-save
echo "install.packages(\"shinydashboard\", repos=\"https://cran.rstudio.com\")" | R --no-save
echo "install.packages(\"leaflet\", repos=\"https://cran.rstudio.com\")" | R --no-save

USER $NB_USER
