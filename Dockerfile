FROM compneurobilbaolab/compneuro-fmriproc:1.0.0

RUN echo "Done pulling compneuro-fmriproc base image"

WORKDIR /app
COPY . /app