#!/usr/bin/env/python3

import io
import sys
import yaml

from yamlpath.func import get_yaml_data, get_yaml_editor
from yamlpath.wrappers import ConsolePrinter
from yamlpath import Processor


with open(sys.argv[1]) as fhandle:
    yaml_dict = yaml.full_load(fhandle)
    args = processcli()
    log = ConsolePrinter(args)
    yaml = prep_yaml_editor()
    yaml_data = get_yaml_data(yaml, log, yaml_dict)
    print(yaml_data)
