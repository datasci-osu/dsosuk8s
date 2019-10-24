
MAKEFILEDIR = $(dir $(realpath $(firstword $(MAKEFILE_LIST))))


debug: 
	@$(MAKE) -C glauth debug
	@#echo ${MAKEFILEDIR}
	@#echo docker build -t ${IMG} -f ${TARGETDIR}/Dockerfile
	@#echo wget https://github.com/glauth/glauth/releases/download/${GLAUTHVERSION}/glauth64 -O ${TARGETDIR}/glauth64
	@#echo docker build -t ${IMG} -f ${TARGETDIR}/Dockerfile

build:
	@$(MAKE) -C glauth build
	     
push:
	@$(MAKE) -C glauth push
	   
login:
	@echo ${DOCKER_PASS} docker login -u ${DOCKER_USER} --password-stdin
