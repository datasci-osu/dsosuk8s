# Instructor Overview

<!-- panels:start -->

<!-- div:left-panel -->

These sections assume a Hub has been created for you by a DS@OSU system administrator.

For hubs linked into
For hubs linked into your Canvas site, either by
 a system administrator added to your class with the "Designer" role, or by following the linking instructions --
Section TODO below provides details on Canvas <-> Hub linkage (but we recommend adding a sysadmin as Designer).



<!-- div:title-panel -->

## Hubs and Canvas Courses

<!-- div:left-panel -->


A Canvas course (whether a standard one or a Studio Site) may be 'linked' to a Hub - a particular installation of JupyterHub, RStudio, and related tools. Hubs linked to Canvas courses can only be logged into from within Canvas via a special Assignment or Module section (so clicking that link won't work). Hubs
are configured as Apps in Canvas



A Hub provides a shared space for student and instructor data; each user (students, instructors, TAs) has a 'home directory' containing their own files. Hub Admins are by default Canvas Instructors and TAs. A `hub_data_share` folder is also available, defaulting to read+write access for admins and read-only for students.

<!-- div:right-panel -->

<!-- panels:end -->


<!-- panels:start -->

<!-- div:left-panel -->


Admins may install packages (e.g. R and Python packages, command-line programs and scripts) Hub-wide for use by all users. Other users can install packages in their own home directories. Hub admins have read+write permissions on almost<sup>1</sup> all hub data, including inside of student directories. Students on the other hand only have read+write in their own home directory, and no read access to other users' home directories.

<!-- div:right-panel -->

1: "Almost all" because this excludes locked-down-by-default directories like `.ssh` folders, and users savvy with Unix permissions could make some contents of their home directory private from hub admins.


<!-- div:title-panel -->

## Launching

<!-- div:left-panel -->




<!-- panels:end -->
