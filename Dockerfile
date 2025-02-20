FROM python:3.10-buster

LABEL org.opencontainers.image.authors="David Baetge <david.baetge@gmail.com>"

ARG WEEWX_VERSION="4.10.2"
ARG WDC_VERSION="v3.3.0"
ARG WEEWX_UID=2749
ENV WEEWX_HOME="/home/weewx"

EXPOSE 9877

COPY src/install-input.txt /tmp/
COPY src/start.sh /start.sh
COPY src/extensions.py /tmp
RUN chmod +x /start.sh

# @see https://blog.nuvotex.de/running-syslog-in-a-container/
RUN apt-get update &&\
    apt-get install -q -y --no-install-recommends rsyslog=8.1901.0-1+deb10u2 &&\
    apt-get clean &&\
    rm -rf /var/lib/apt/lists/*

RUN addgroup --system --gid ${WEEWX_UID} weewx &&\
    adduser --system --uid ${WEEWX_UID} --ingroup weewx weewx

# Configure timezone.
RUN ln -sf /usr/share/zoneinfo/Europe/Berlin /etc/localtime

WORKDIR /tmp

RUN wget -nv -O "weewx-${WEEWX_VERSION}.tar.gz" "https://github.com/weewx/weewx/archive/refs/tags/v${WEEWX_VERSION}.tar.gz" &&\
    wget -nv -O "weewx-interceptor.zip" "https://github.com/matthewwall/weewx-interceptor/archive/master.zip" &&\
    wget -nv -O "weewx-wdc-${WDC_VERSION}.zip" "https://github.com/Daveiano/weewx-wdc/releases/download/${WDC_VERSION}/weewx-wdc-${WDC_VERSION}.zip" &&\
    wget -nv -O "weewx-forecast.zip" "https://github.com/chaunceygardiner/weewx-forecast/archive/refs/heads/master.zip" &&\
    wget -nv -O "weewx-cmon.zip" "https://github.com/bellrichm/weewx-cmon/archive/refs/heads/master.zip" &&\
    wget -nv -O "weewx-xaggs.zip" "https://github.com/tkeffer/weewx-xaggs/archive/master.zip" &&\
    wget -nv -O "weewx-xcumulative.tar.gz" "https://github.com/gjr80/weewx-xcumulative/releases/download/v0.1.0/xcum-0.1.0.tar.gz" &&\
    tar xvfz "weewx-${WEEWX_VERSION}.tar.gz"

RUN mkdir /tmp/weewx-wdc/ &&\
    unzip /tmp/weewx-wdc-${WDC_VERSION}.zip -d /tmp/weewx-wdc/

WORKDIR /tmp/weewx-${WEEWX_VERSION}

RUN pip install --no-cache-dir -r ./requirements.txt &&\
    python ./setup.py build && python ./setup.py install < /tmp/install-input.txt

WORKDIR ${WEEWX_HOME}

RUN bin/wee_extension --install /tmp/weewx-interceptor.zip &&\
    bin/wee_extension --install /tmp/weewx-forecast.zip &&\
    bin/wee_extension --install /tmp/weewx-cmon.zip &&\
    bin/wee_extension --install /tmp/weewx-xaggs.zip &&\
    bin/wee_extension --install /tmp/weewx-xcumulative.tar.gz &&\
    bin/wee_extension --install /tmp/weewx-wdc/ &&\
    bin/wee_extension --list &&\
    #bin/wee_config --reconfigure --driver=user.interceptor --no-prompt
    bin/wee_config --reconfigure --driver=user.gw1000 --no-prompt

COPY src/skin.conf ./skins/weewx-wdc/

RUN sed -i -e 's/device_type = acurite-bridge/device_type = ecowitt-client\n    port = 9877\n    address = 0.0.0.0/g' weewx.conf &&\
    sed -i -z -e 's/skin = Seasons\n        enable = true/skin = Seasons\n        enable = false/g' weewx.conf &&\
    sed -i -z -e 's/skin = forecast/skin = forecast\n        enable = false/g' weewx.conf &&\
    cat /tmp/extensions.py >> "${WEEWX_HOME}"/bin/user/extensions.py

VOLUME [ "${WEEWX_HOME}/public_html" ]
VOLUME [ "${WEEWX_HOME}/archive" ]

ENTRYPOINT [ "/start.sh" ]
