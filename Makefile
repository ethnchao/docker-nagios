build:
	@docker build -t nagios .

run:
	@docker-compose up

clean:
	@docker rm dockernagios_nagios_1 dockernagios_nagios_mysql_1 > /dev/null || true

tty:
	@docker exec -it dockernagios_nagios_1 /bin/bash

tty-mysql:
	@docker exec -it dockernagios_nagios_mysql_1 /bin/bash

stop:
	@docker stop dockernagios_nagios_1 dockernagios_nagios_mysql_1

start:
	@docker start dockernagios_nagios_1 dockernagios_nagios_mysql_1

all: build mount run import
