# The recipe below implements a Docker multi-stage build:
# <https://docs.docker.com/develop/develop-images/multistage-build/>

###############################################################################
## First stage: an image to build the planner.
## 
## We'll install here all packages we need to build the planner
###############################################################################
FROM ubuntu:18.04 AS builder

RUN apt-get update && apt-get install --no-install-recommends -y \
    cmake           \
    ca-certificates \
    curl            \
    g++             \
    make            \
    python3
    

WORKDIR /workspace/kstar/

# Set up some environment variables.
ENV CXX g++
ENV BUILD_COMMIT_ID dc641ce


# Fetch the code at the right commit ID from the Github repo
RUN curl -L https://github.com/ctpelok77/kstar/archive/${BUILD_COMMIT_ID}.tar.gz | tar xz --strip=1

# Invoke the build script with appropriate options
RUN python3 ./build.py -j4 release64

# Strip the main binary to reduce size
RUN strip --strip-all builds/release64/bin/downward

###############################################################################
## Second stage: the image to run the planner
## 
## This is the image that will be distributed, we will simply copy here
## the files that we fetched and compiled in the previous image and that 
## are strictly necessary to run the planner
###############################################################################
FROM ubuntu:18.04

# Install any package needed to *run* the planner
RUN apt-get update && apt-get install --no-install-recommends -y \
    python3  \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace/kstar/

# Copy the relevant files from the previous docker build into this build.
COPY --from=builder /workspace/kstar/fast-downward.py .
COPY --from=builder /workspace/kstar/builds/release64/bin/ ./builds/release64/bin/
COPY --from=builder /workspace/kstar/driver ./driver

WORKDIR /work

# ENTRYPOINT ["/usr/bin/python3", "/workspace/kstar/fast-downward.py", "--build", "release64"]
CMD /bin/bash
