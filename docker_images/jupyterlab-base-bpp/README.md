These dockerfile parts when combined create a multistage build with named stages; 
the `docker_chain_build.sh` script in the `scripts` directory is a simple utility to build and tag
each image based on metadata lines of format 

```
# TARGET targetname tag
```

the image name will be based on the targetname as in the FROM line; see example in source of `docker_chain_build.sh`. 

To build the images, first create the requisite `Dockerfile` from the split-for-navigability pieces:

```
cat *.dockerfile > Dockerfile
```

then run the chained build:

```
docker_chain_build.sh .
```
