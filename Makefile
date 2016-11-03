VERSION=staging
IMAGE=kbase/kbase_base:staging
NGINX=kbase/kbase_nginx:staging
UI=kbase/kbase_ui:$(VERSION)


all:

updatetrigger:
	date > build.trigger


docker:
	docker build -t $(IMAGE) .

nginx:
	docker build -t $(NGINX) -f Dockerfile.nginx .

ui:
	docker build -t $(UI) -f Dockerfile.kbaseui .

initialize:
	docker run -it --rm --link mongo:mongo --link mysql:mysql $(IMAGE) initialize
