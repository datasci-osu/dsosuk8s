#!/usr/bin/env python3
import sys
import io
import os
import stat
import re
import subprocess
import collections.abc
import yaml # pip3 install pyyaml


# Why not kustomize? it's heavy. perhaps this will be replaced someday

# usage: helmer.py <chartdir> <modifications>

if len(sys.argv) != 2:
    sys.stderr.write("Usage: helmer.py <deployment.yaml>\n\n")
    sys.stderr.write("Where <deployment.yaml> is a special YAML file, see example.\n")
    sys.exit(1)

deploy_yaml = sys.argv[1]
# pre-flight checks

if not os.path.isfile(deploy_yaml):
    sys.stderr.write("Error: " + deploy_yaml + " is not a file we can try to read.\n")
    sys.exit(1)

## go there
os.chdir(os.path.dirname(deploy_yaml))

# given a string like "hi-$(basename $(pwd))", runs it through bash to interpolate it, if it's a string and has a $(). 
def interpolate(bashlike):
    if isinstance(bashlike, str) and len(re.findall(r"\$\(.+\)", bashlike)) > 0:        # why doesn't re.match work for these special chars?
        res = subprocess.check_output("echo " + bashlike, shell = True).decode('utf-8').strip()
        return res
    else:
        return bashlike

# https://stackoverflow.com/questions/32935232/python-apply-function-to-values-in-nested-dictionary
# modified to work with lists too
def map_nested_dicts(ob, func):
    if isinstance(ob, collections.abc.Mapping):
        return {k: map_nested_dicts(v, func) for k, v in ob.items()}
    elif isinstance(ob, collections.abc.MutableSequence):
        return [map_nested_dicts(v, func) for v in ob]
    else:
        return func(ob)

# opens an interpolates and entire yaml file
def interpolate_yaml_file(filename):
    with open(filename) as fhandle:
        yaml_dict = yaml.full_load(fhandle)
        interpolated = map_nested_dicts(yaml_dict, interpolate)

        return interpolated

# open an interpolate the deployment file
deployment = interpolate_yaml_file(os.path.basename(deploy_yaml))

# write each chart values.yaml files
for chart in deployment["application"]["charts"]:
    with open(chart["valuesFile"], "w") as outhandle:
        yaml.dump(chart["values"], outhandle)


try:
    ns = deployment["application"]["namespace"]
    print("")
    print("Checking namespace:")
    subprocess.check_output(["kubectl", "create", "namespace", ns])
except:
    sys.stderr.write("Did not create namespace.\n")

ns = deployment["application"]["namespace"]
counter = 0
for chart in deployment["application"]["charts"]:
    counter = counter + 1
    name = chart["name"]
    chartdir = chart["chartdir"]
    valuesFile = chart["valuesFile"]
    
    with open(str(counter) + "-" + valuesFile + ".sh", "w") as shandle:
        shandle.write("#!/bin/bash\n\n")
        cmd = " ".join(["helm", "upgrade", name, chartdir, "--atomic", "--cleanup-on-fail", "--install", "--values", valuesFile])
    
    # https://stackoverflow.com/questions/12791997/how-do-you-do-a-simple-chmod-x-from-within-python 
    st = os.stat('somefile')
    os.chmod('somefile', st.st_mode | stat.S_IEXEC)

