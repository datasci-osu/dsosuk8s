#!/usr/bin/env python3

import yaml
import sys

fhandle = open(sys.argv[1])
yamlres = yaml.load(fhandle, Loader=yaml.FullLoader)
fhandle.close()

for question in yamlres["questions"]:
    var = question["variable"]
    desc = question.get("description")
    label = question.get("label")
    vartype = question.get("type")
    default = question.get("default")
    
    if desc:
        print(desc)

    if label:
        sys.stdout.write(label)
    if default:
        sys.stdout.write(" (" + str(default) + ")")
    print(":")

    print("")
