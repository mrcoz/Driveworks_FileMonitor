FROM perl:5.20
COPY . /usr/src/myapp
WORKDIR /usr/src/myapp
CMD [ "perl", "./your-daemon-or-script.pl" ]

MAINTAINER Mark Cosby <markc@aluminumtrailer.com>
