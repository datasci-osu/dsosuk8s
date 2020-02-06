#!/usr/bin/env python3
import sys
import io
import os
import stat
import re
import subprocess
import collections.abc
import yaml # pyyaml package
import dpath.util
import pprint

# Why not kustomize? values are still not scriptable
# why not umbrella helm charts? same as above, and this is more modular


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
goto_dir = os.path.dirname(deploy_yaml)
if goto_dir != "": # is true if deploy_yaml is in pwd, eg "deployment.yaml" vs "./deployment.yaml"
    os.chdir(os.path.dirname(deploy_yaml))

# given a string like "hi-$(basename $(pwd))", runs it through bash to interpolate it, if it's a string and has a $(). 
def bash_interpolate(bashlike):
    # this depends on "and" doing short-circuit logic, should refactor...
    if isinstance(bashlike, str) and len(re.findall(r"\$\(.+\)", bashlike)) > 0:        # why doesn't re.match work for these special chars?
        res = subprocess.check_output("echo " + bashlike, shell = True).decode('utf-8').strip()
        return res
    else:
        return bashlike


def build_plusvar_interpolator(yaml_dict):
    def plusvar_interpolate(string):
        # it might not actually be a string; again relying on short-circuit of 'and'
        if isinstance(string, str) and len(re.findall(r"\+\+[^+]+?\+\+", string)) > 0:
            matches = re.findall(r"\+\+[^+]+?\+\+", string)
            otherparts = re.split(r"\+\+[^+]+?\+\+", string)
            # use dpath to substitute by path
            for i in range(0, len(matches)):
                match_i = matches[i]
                match_i_trimmed = re.sub(r"\+", "", match_i)
                matches[i] = dpath.util.get(yaml_dict, match_i_trimmed, separator = ".")

            build_list = [] 
            matches.append("") # to make them same length
            # build the value back up
            for i in range(0, len(matches)):
                build_list.append(otherparts[i])
                build_list.append(matches[i])

            # return it as a string
            result = "".join(build_list)
            return result
        else:
            return string

    return plusvar_interpolate

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
def bash_interpolate_yaml_dict(yaml_dict):
        interpolated = map_nested_dicts(yaml_dict, bash_interpolate)

        return interpolated

def plusvar_interpolate_yaml_dict(yaml_dict):
    interpolator = build_plusvar_interpolator(yaml_dict)
    # this does one round of interpolation, but doesn't "walk the tree" if one interpolation references another.
    interpolated = map_nested_dicts(yaml_dict, interpolator)

    def has_plusvar(x):
        if isinstance(x, str) and len(re.findall(r"\+\+[^+]+?\+\+", x)) > 0:
            return True
        return False

    pp = pprint.PrettyPrinter(indent = 2)
    # a hacky workaround is to repeat as long any plusvars still exist
    counter = 1
    while len(dpath.util.search(interpolated, "**", afilter = has_plusvar)) > 0:
        interpolated = map_nested_dicts(interpolated, interpolator)
        counter = counter + 1
        if counter > 100:
            sys.stderr.write("Interpolating plusvars as iterated 100 times and still not done - are you sure you don't have a self-referential plusvar? Here's what's left:\n\n")
            sys.stderr.write(yaml.dump(dpath.util.search(interpolated, "**", afilter = has_plusvar)))
            sys.exit(1)

    print("Interpolating plusvars required " + str(counter) + " iterations of interpolation.")
    return interpolated

# open and interpolate the deployment file
deployment = None

with open(deploy_yaml) as fhandle:
    yaml_dict = yaml.full_load(fhandle)

deployment = bash_interpolate_yaml_dict(yaml_dict)
deployment = plusvar_interpolate_yaml_dict(deployment)




if not deployment["app"]["actions"]:
    sys.stderr.write("No actions found, exiting.\n")
    sys.exit(0)

# write each chart values.yaml files
for action in deployment["app"]["actions"]:
    if action["type"] == "chart":
        with open(action["valuesFile"], "w") as outhandle:
            yaml.dump(action["values"], outhandle)



ns = deployment["app"]["namespace"]
try:
    print("")
    print("Checking namespace:")
    subprocess.check_output(["kubectl", "create", "namespace", ns])
except:
    sys.stderr.write("Did not create namespace.\n")




counter = 0
for action in deployment["app"]["actions"]:
    if action["type"] == "chart" and False:
        counter = counter + 1
        name = action["name"]
        chartdir = action["chartdir"]
        valuesFile = action["valuesFile"]
       
        scriptFile = str(counter) + "-" + valuesFile + ".sh"
        with open(scriptFile, "w") as shandle:
            shandle.write("#!/bin/bash\n\n")
            cmd = " ".join(["helm", "upgrade", name, chartdir, "--namespace", ns, "--atomic", "--cleanup-on-fail", "--force", "--install", "--values", valuesFile])
            shandle.write(cmd + "\n") 
        # https://stackoverflow.com/questions/12791997/how-do-you-do-a-simple-chmod-x-from-within-python 
        st = os.stat(scriptFile)
        os.chmod(scriptFile, st.st_mode | stat.S_IEXEC)
    
        print("Running " + scriptFile + ":")
        os.system("./" + scriptFile)
        print("")

    elif action["type"] == "commands":
        for command in action["exec"]:
            os.system(command)

    elif action["type"] == "setValues":
        set_dict = action["set"]
        for var in set_dict:
            val = set_dict[var]
            print(set_dict)
            dpath.util.new(deployment, var, val)

    
print("Done!")

