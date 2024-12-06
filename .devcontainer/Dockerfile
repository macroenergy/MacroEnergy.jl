FROM julia:1.11-bookworm

WORKDIR /home/

RUN apt-get update
RUN apt-get install -y --no-install-recommends \
  curl \
  wget \
  git \
  gnupg2 \
  sudo \
  vim \
  build-essential \
  openssl \
  python3 \
  python3-pip \
  python3-venv \
  python3-setuptools \
  ca-certificates \
  gpg

ENV VIRTUAL_ENV /home/.venv
RUN python3 -m venv $VIRTUAL_ENV
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

RUN pip3 install jupyterlab

COPY . /home/

RUN julia -e 'using Pkg; Pkg.add("IJulia")'
RUN julia --project -e 'using Pkg; Pkg.instantiate(); Pkg.precompile()'