# DS@OSU

> Scalable, feature-rich compute infrastructure for data science in the classroom.



## Overview

DataScience@OregonState is an opinionated configuration of
the excellent [Zero to JupyterHub](https://zero-to-jupyterhub.readthedocs.io/en/stable/) (Z2JH) project.
Z2JH uses cloud-computing technologies, specifically Kubernetes, to provide browser-based access
to JupyterHub and related tools (JupyterLab, RStudio, command-line access) in a scalable and cost-effective way.



Via off-the-shelf and custom modules and configuration, DS@OSU additionally provides:

* Support for JupyterLab, Python3, Julia, R, RStudio, R Shiny
* A **shared data space** accessible by instructors/TAs and students, per-hub/course
* **Permissions** specific to instructor/TA and student roles
  * Students have full access their home folder in the shared data space, no access to other home folders, and read-only access to shared data folders (unless otherwise configured)
  * Instructors and TAs (Admins) have full access to all locations in the share data space
* Option (preferred) for Authorization and authentication handled per-hub by **Canvas**, with admin permissions determined by Canvas user role
  * Including support for Canvas "Studio Sites" enabling **social login** and designated admin delegation
  * A single hub may be configured for access by multiple Canvas courses, and a single Canvas course can access multiple hubs
  * "Student View" in Canvas can be used to **preview student-level permissions** in the hub
* Option to use [native authentication](https://native-authenticator.readthedocs.io/en/latest/) for non-Canvas **signup and instructor user management**
* **Admins can install R and Python libraries and command-line utilities** for all users via convenient utilities
  * All users can additionally manage individual libraries and scripts
* **Admin-configurable environment customization** for bash, Python, and R
* **Profile selection** for configurable resource allocation:
  * Configurable "small", "medium", "large" profiles with **varying CPU, RAM and GPU allotment** (with tensorflow 2.0 configured for GPU profiles)
  * Configurable per-profile **time-based quotas**


![](media/dshub_main.png ':size=90%')


