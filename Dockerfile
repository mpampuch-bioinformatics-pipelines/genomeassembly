FROM mambaorg/micromamba:1.5.10-noble

# Install FastK first via conda
USER $MAMBA_USER
COPY --chown=$MAMBA_USER:$MAMBA_USER conda.yml /tmp/conda.yml
RUN micromamba install -y -n base -f /tmp/conda.yml \
    && micromamba install -y -n base conda-forge::procps-ng \
    && micromamba install -y -n base conda-forge::git \
    && micromamba install -y -n base conda-forge::pip \
    && micromamba clean -a -y

# Install smudgeplot from GitHub main branch
WORKDIR /tmp
RUN git clone https://github.com/KamilSJaron/smudgeplot.git \
    && cd smudgeplot \
    && git checkout main \
    && python -m pip install .

# Set PATH and verify installation
USER root
ENV PATH="$MAMBA_ROOT_PREFIX/bin:$PATH"
RUN smudgeplot -h

WORKDIR /work