# DataScience@OregonState - Instructor Readme

Contents:

* [Features](#features)
* [QuickStart](#quickstart)
* [User Management](#user-management)
* [User Server Management](#user-server-management)


## Features

Welcome to the DataScience@OregonState instructional platform. This is still a work in progress, but we're excited to offer:

* A cloud-hosted platform scalable to campus-level needs
* A data analysis & programming environment supporting Python3, R, Julia, Jupyter Notebooks, RStudio, and the Linux command-line
* A large array of pre-installaed Python and R packages ([list](https://jupyter-docker-stacks.readthedocs.io/en/latest/using/selecting.html#jupyter-datascience-notebook))
* The ability for students and instructors/TAs to install Python3 and R packages for their own use
* The ability for instructors to install Python3 packages, R packages, and scripts for use by everyone
* Shared storage with classroom-appropriate permissions:
  * Students can read/write in their own home directories, and have read-only access to a designated `hub_data_share` folder
  * Instructors (or others with designated Admin access) have read+write to student directories and other locations

Some screenshots (Initial JupyterLab Interface, a Python Notebook, and RStudio):

<a href="https://raw.githubusercontent.com/oneilsh/dsosuk8s/userdocs/user_docs/images/launcher.png"><img src="images/launcher.png" width="30%"/></a>&nbsp;
<a href="https://raw.githubusercontent.com/oneilsh/dsosuk8s/userdocs/user_docs/images/python_notebook_autocomplete.png"><img src="images/python_notebook_autocomplete.png" width="30%"/></a>&nbsp;
<a href="https://raw.githubusercontent.com/oneilsh/dsosuk8s/userdocs/user_docs/images/rstudio.png"><img src="images/rstudio.png" width="30%"/></a>

## QuickStart

We've designed DS@OSU to balance user-friendliness with flexibility and power. Understanding the sections below 
will help you get the most from the platform. Nevertheless, here are some important notes to help you start playing quickly:

1. **Hubs:** A single "Hub" provides access to a shared environment for members of a class (instructors, TAs, students) at a specific URL, for 
   example `http://beta.datasci.oregonstate.edu/nmc-245/`, and different classes access different Hubs/URLs. Within a Hub, some users
   (instructors & TAs) have "Admin"-level access with special permissions.

2. **Login and User Management:** We don't yet have ONID or single-sign-on integration. In the meantime, the workflow is for students to request
   access by signing up to a Hub with their preferred username and password, after which an Admin user can authorize them to login. For details on this
   process, be sure to see section [user-management](#user-management) below. 

2. **Cloud-Based Servers:** Eacher user's "interface" (shown in the screenshots above) is running as an individual server (Docker container, actually) in 
   the cloud. This has some implications for Admins--for example, user servers may be shut down after a period of inactivity (e.g. 1. hour), or after
   a maximum amount of active time (e.g. 8 hours) to save on resources and costs. 

   Fortunately, user servers start up quickly on login (in a few seconds), *unless* a new cloud-based machine must be created behind-the-scenes to support
   that server. When this happens a delay of up to 10 minutes can occur on login. This is most likely to happen when a large number of students
   attempt to login simultaneously after a period of inactivity, such as at the start of a morning lab class. See section  [User Server Management](#user-server-managment)
   below for details on how avoid this and other implications of running in an auto-scaling cloud.

   *Activity*, by the way, means a browser tab open and the user logged in, *even if the user is not doing anything.* You can thus
   help us control costs by instructing your students to logout or close their browser tabs when they won't be using the system for an hour or more.

3. **For Python Users**: Each user can install python3 packages for their own use with `pip install --user packagename`. Admins can install packages "hub-wide"
   (for import by all users) with `hubpip install packagename`. Installed packages are available for import in Jupyter notebooks an on the
   command-line.

4. **For R Users**: Each user can install R packages for their own use with the standard `install.packages("packagename")` function or RStudio packages interface. 
   Github packages can be be installed for individual use with the usual `devtools::install_github("username/packagename")`, and the same
   for BioConductor packages. 

   Admins can install R packages hub-wide to the site-library with the helper functions `hub.install.packages("packagename")`, 
   `hub.install_github("username/packagename")`, and `hub.install_bioconductor("packagename")`. 

5. **File Permissions:** User home directories are located at `/home/username`; 
   files created in user home directories are by default read+write for their owner and Admins, with no access for non-Admin users. Files
   added to `/home/hub_data_share` are by default read+write for Admins and read-only for others. 

6. **For Command-Line Users:** Admins have read+write access to `/home/hub_local`, others have read-only access. Hub-wide Python and R packages are installed to subdirectories 
   here, and the file `/home/hub_local/hubrc` is used to configure the environment for every user on login (akin to lines added to all users' `.bashrc` 
   files). Executable scripts and programs may be placed in `/home/hub_local/bin` (which is added to every users' `$PATH` via the `hubrc` file--if
   compiling software, use `--prefix=/home/hub_local`). Some environment variables reference these locations; `env` shows a list these and others.

6. **Data Storage:** The `/home` directory and all its contents listed above exist on a single shared network drive. Currently there are no per-user
   limits within this space, so theoretically any user can fill the entire space accidentally. (Implementing per-user quotas is [on the todo list](https://github.com/oneilsh/dsosuk8s/issues/28)).
   If the drive fills up, it will interfere with first-time logins and prevent new file creation, but won't result in data loss. You can
   check space used and available by running `df -h /home` in a terminal. Creating a dashboard for space usage is also on the [todo list](https://github.com/oneilsh/dsosuk8s/issues/29).


## User Management

User management and access are in development--we don't yet have ONID or single-sign-on integration, 
and the login system we do have is a little clunky. 





## User Server Management 
