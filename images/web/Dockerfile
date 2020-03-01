FROM jupyter/tensorflow-notebook

USER root

#
# Install SSH
#
ARG SSH_PSWD=root
RUN apt-get update \
    && apt-get -y install openssh-server \
    && sed -i 's/UsePAM yes/UsePAM no/g' /etc/ssh/sshd_config \
    && sed -i 's/#ClientAliveInterval 0/ClientAliveInterval 30/g' /etc/ssh/sshd_config \
    && sed -i 's/#ClientAliveCountMax 3/ClientAliveCountMax 1200/g' /etc/ssh/sshd_config \
    && sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/g' /etc/ssh/sshd_config \
    && echo "root:${SSH_PSWD}" | chpasswd \
    && echo "${NB_USER}:${SSH_PSWD}" | chpasswd

#
# Prepare for start
#
ENV NOTEBOOK_TOKEN=""
COPY docker-bootstrap /usr/local/bin/

CMD ["docker-bootstrap"]