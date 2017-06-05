VERSION=develop
IMAGE=kbase/kbase_base:develop
NGINX=kbase/kbase_nginx:develop


all:

updatetrigger:
	date > build.trigger

docker:
	docker build -t $(IMAGE) .

initialize:
	docker run -it --rm --link mongo:mongo --link mysql:mysql $(IMAGE) initialize

nginx:
	date > build-nginx.trigger
	docker build -t $(NGINX) -f Dockerfile.nginx .

