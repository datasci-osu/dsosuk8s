FROM oneilsh/ktesting-datascience-notebook:v1.1.6

RUN pip install --no-cache-dir nbgitpuller==0.8.0

USER root

RUN apt-get update \
 && apt-get install -yq --no-install-recommends \
    less \
    tmux

# need to install rmarkdown, learnr, shinydashboard, leaflet (all cran, for learnr and bus-dashboard demo)
RUN echo "install.packages(\"rmarkdown\", repos=\"https://cran.rstudio.com\")" | R --no-save
RUN echo "install.packages(\"learnr\", repos=\"https://cran.rstudio.com\")" | R --no-save
RUN echo "install.packages(\"shinydashboard\", repos=\"https://cran.rstudio.com\")" | R --no-save
RUN echo "install.packages(\"leaflet\", repos=\"https://cran.rstudio.com\")" | R --no-save

COPY Rprofile /home/$NB_USER/.Rprofile
RUN chmod 644 /home/$NB_USER/.Rprofile

USER $NB_USER

