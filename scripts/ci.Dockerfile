ARG OTP_IMAGE=erlang:28
FROM ${OTP_IMAGE}

RUN apt-get update \
    && apt-get install -y --no-install-recommends libxml2-utils \
    && rm -rf /var/lib/apt/lists/*
