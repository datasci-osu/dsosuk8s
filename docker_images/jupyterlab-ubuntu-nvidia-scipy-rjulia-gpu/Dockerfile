FROM oneilsh/jupyterlab-ubuntu-nvidia-scipy-rjulia:v1.0.2

############################################################################
########################## Dependency: gpulibs #############################
############################################################################

LABEL maintainer="Christoph Schranz <christoph.schranz@salzburgresearch.at>"

USER root

# Install Tensorflow, check compatibility here: https://www.tensorflow.org/install/gpu 
RUN conda install --quiet --yes \
    'tensorflow-estimator=2.1*' \
    'tensorflow-gpu=2.1*' \
    'keras-gpu' && \
    fix-permissions $CONDA_DIR && \
    fix-permissions /home/$NB_USER

# Install PyTorch with dependencies
RUN conda install --quiet --yes \
    pyyaml mkl mkl-include setuptools cmake cffi typing

# Check compatibility here: https://pytorch.org/get-started/locally/
RUN conda install --quiet --yes \
     pytorch \ 
     torchvision \
     cudatoolkit=10.1 -c pytorch
#    pip install torch_nightly -f https://download.pytorch.org/whl/nightly/cu90/torch_nightly.html && \

# Clean installation
RUN conda clean --all -f -y && \
    fix-permissions $CONDA_DIR && \
    fix-permissions /home/$NB_USER


USER $NB_USER

# let's check to make sure this works...
RUN python3 -c 'import tensorflow as tf'


#IMAGE oneilsh/jupyterlab-ubuntu-nvidia-scipy-rjulia-gpu
#TAG v1.0.3
