# Instructor Overview

<!-- panels:start -->

<!-- div:left-panel -->

> Make the easy things easy, and the hard things possible.

DS@OSU is designed to give power and flexibility to instructors. As a Hub admin, an instructor can install R and Python Packages,
manage data for all users, install command-line utilities and modify user environments. Custom utilities and features are included to
help with these (e.g. `hub.install.packages()` for R packages, `hubpip` for Python packages, and a `hub_data_share` folder with default
read+write permissions for instructors and read-only permissions for students), but more advanced users can dig into init scripts and other
configuration.

<!-- div:right-panel -->

<!-- panels:end -->

<!-- panels:start -->

<!-- div:left-panel -->


Because DS@OSU lives in the cloud on autoscaling compute resources, the experience is different in some ways than if everyone
were logging into a single server or their laptop. For example, if resources aren't available to host a logging-in user, a new cloud resource must be initialized,
and this can take several minutes. This is especially apparent at the start of lab sessions where many users are logging in simultaneously (the solution being
to ask students to login over a period of time before class if at all possible).

Understanding how these pieces fit together will help you and your students make the most effective use of the system!

<!-- div:right-panel -->

![Test](media/loading_screen.png ':size=90%')

The login progress screen may delay if a new cloud resource needs to be created to host the login. Message reported here are overly pessimistic:
"resources unavailable" messages are reported until the newly arrived compute resources come online. Refreshing the page can help update the messages, and if
no progress is made in 10 minutes please contact a system administrator for help.

<!-- div:title-panel -->

## Hubs

<!-- div:left-panel -->

DS@OSU is designed to run on a cloud-based, autoscaling cluster. A single cluster plays host to many **Hubs**, where a single Hub consists of a login
mechanism<sup>1</sup> for authorizing Hub admins (usually Instructors or TAs) or other users (students), a hub-specific data space shared by authorized users (with permissions depending on role), and configuration of compute-resources available to users to admins.

Hubs are managed (created, destroyed, and debugged when necessary) by **system administrators** with cluster-level permissions.


<!-- div:right-panel -->


![](media/login_native.png ':size=45%')

1: Login screen shown when using "native" authentication. When connected to a Canvas course (preferred), students login directly via a link created within Canvas (details below).

<!-- panels:end -->







<!-- panels:start -->

## Profiles and Resources

<!-- div:left-panel -->


When creating a Hub, some decisions need to be made:<sup>2</sup>

* How much space should be allocated (to be shared by all users)? 50G is a good starting point for many classes, larger spaces are possible.
* How much CPU and RAM should be allocated to each user for their work, for the various profiles?


Generally profiles come in "standard" and (optionally) "large" and "extra large," where standard profiles are available for unlimited use and others may be associated
with configurable time-based quotas<sup>3</sup>.

A profile specifies:

* The minimum CPU guaranteed to each user (e.g. 0.1, 1.2, or 2.0 CPU cores)
* The maximum CPU a user may use *if available* (e.g. 1.0, 1.5, or 4.0 CPU cores)
* The minimum RAM guaranteed each user (e.g. 0.5 G)
* The maximum RAM a user may use *if available* (e.g. 2.0 G)
* A number of GPU units to allocate for GPU-enabled computations

These guarantees/allowances account for the fact that multiple users may be sharing a cloud resource at any given time.

#### CPU

Of these, CPU is most flexible and prone to burst-needs: most users use very small fractions of a CPU most of the time, with larger amounts of CPU being
requested for heavy computation. If necessary heavy computations can be scaled back dynamically (for example if another user attempts to also use up to their maximum).
We thus generally allocate small guarantees with generous maximums. Larger guaranteed allotments (useful for exercises with known heavy computation) are possible but usually involve the on-demand creation of more expensive cloud resources.

#### RAM

Compared to CPU, RAM usage doesn't adjust easily or dynamically--once a user has loaded a large dataset into memory (in R or Python for example), that memory
is usually held for the duration of the session and cannot be released without *killing* the process using it. 


<!-- div:right-panel -->

2: Most of these settings are changeable after the fact, **except** for storage space. Migrating data from Hub-to-Hub is challenging (not impossible), so consider
space needs for your Hub carefully.


<br />
<br />


![](media/dshub_profiles.png ':size=45%')
![](media/dshub_profiles_popup.png ':size=45%')

3: Example screenshots for choosing a profile to use when logging in. Numbers in bold in "Quota Details" are configurable with different settings for admins and other users

<!-- panels:end -->
