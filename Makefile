VERSION=staging
IMAGE=kbase/kbase_base:staging
NGINX=kbase/kbase_nginx:staging


all:

updatetrigger:
	date > build.trigger


docker:
	docker build -t $(IMAGE) .

nginx:
	docker build -t $(NGINX) -f Dockerfile.nginx .

initialize:
	docker run -it --rm --link mongo:mongo --link mysql:mysql $(IMAGE) initialize
