GLAUTHVERSION  := v1.1.1

MAKEFILEDIR = $(dir $(realpath $(firstword $(MAKEFILE_LIST))))
TARGETDIR := ${MAKEFILEDIR}/../../../applications/glauth

NAME   := oneilsh/ktesting-glauth
TAG    := $(shell git log -1 --pretty=%h)
IMG    := ${NAME}:${TAG}
LATEST := ${NAME}:latest

debug:
	@echo Debug for glauth/Makefile:	
	@#echo ${MAKEFILEDIR}
	@#echo docker build -t ${IMG} -f ${TARGETDIR}/Dockerfile
	@#echo wget https://github.com/glauth/glauth/releases/download/${GLAUTHVERSION}/glauth64 -O ${TARGETDIR}/glauth64
	@#echo docker build -t ${IMG} -f ${TARGETDIR}/Dockerfile

build:
ifeq (${DOWNLOAD}, true)
	wget https://github.com/glauth/glauth/releases/download/${GLAUTHVERSION}/glauth64 -O ${TARGETDIR}/glauth64
endif
	docker build -t ${IMG} -f ${TARGETDIR}/Dockerfile ${TARGETDIR}
	docker tag ${IMG} ${LATEST}
	     
push:
	@docker push ${NAME}
	   
login:
	@echo ${DOCKER_PASS} docker login -u ${DOCKER_USER} --password-stdin
