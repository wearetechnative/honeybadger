FROM debian:latest

ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies and upgrade
RUN apt-get update && apt-get -y install \
    wget \
    unzip \
    apt-utils \
    htmldoc \
    libxml-writer-perl \
    libarchive-zip-perl \
    libjson-perl \
    make \
    perl \
    cpanminus \
    ca-certificates \
    && apt-get -y upgrade \
    && rm -rf /var/lib/apt/lists/*

# Install latest Perl modules from CPAN
RUN cpanm --notest \
    HTML::HTMLDoc \
    Excel::Writer::XLSX

# Install lynis-report-converter from GitHub (latest)
RUN wget https://github.com/wearetechnative/lynis-report-converter/archive/refs/heads/master.zip -P /tmp/lynis-converter-dist \
    && unzip /tmp/lynis-converter-dist/master.zip -d /opt \
    && cd /opt/lynis-report-converter-master/ \
    && perl Makefile.PL \
    && make \
    && make install

# Clean up to reduce image size
RUN apt-get autoremove -y \
    && rm -rf /tmp/* \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /root/.cpanm

CMD printf 'Lynis report converter is started' && tail -f /var/log/wtmp
