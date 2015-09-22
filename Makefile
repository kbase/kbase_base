IMAGE=kbase/deplbase:latest


all:

docker:
	docker build -t $(IMAGE) .

initialize:
	docker run -it --rm --link mongo:mongo --link mysql:mysql $(IMAGE) initialize
