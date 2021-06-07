# For Instructors/Hub Admins

Welcome! We hope you'll enjoy using DS@OSU and find creative uses for its unique features. The design and implementation was driven by a long fact-finding process at Oregon State University, including a steering committee composed of deans of undergrad and grad education representing all colleges, technical and faculty advisory committees, and needs assessments broadly surveying social, biological, and technical sciences, as well as the humanities. 

DS@OSU balances several goals: first, to be cost-effective and flexible via autoscaling cloud-based compute; second, to be web-accessible and scalable to the needs of hundreds or thousands of diverse users; third, to be comfortable and familiar to those without 'devops' or engineering experience; and fourth, wherever possible, to put configuration and power in the hands of instructors. At its base, DS@OSU is build upon a sophisticated cloud-based JupyterHub stack knows as [Zero to JupyterHub With Kubernetes (Z2HJ)](https://zero-to-jupyterhub.readthedocs.io/en/stable/), used and partially engineered at UC Berkeley to support 1300+ student [data science classes](https://data.berkeley.edu/news/uc-berkeleys-data-science-major-takes) and growing rapidly in use at institutions nationwide. 

DS@OSU is an implementation of Z2JH with many customizations to support usability, familiarity, and flexibility. The most significant of these is the use of permissioned, shared storage enabling students to work together on code and data (where permitted), and instructors or other admins can easily install Python, R, and command-line packages for use by their entire class with no work on students' part or intervention from system administrators. Additionally, DS@OSU enables the use of 'compute profiles' providing more CPU, RAM, and even GPU-compute with a usage quota system to prevent arbitrarily large cloud-compute bills. Naturally, we preinstall a number of tools including JupyterLab, RStudio, and support Python, R, Julia, and bash with a large set of common packages for these languages. 

All of these features come with a small learning curve to make the best use of them. This is especially true where the autoscaling nature of the system is concerned--while the shared storage model may make it feel as though everyone is logging into a single computer, in reality compute nodes (cloud-hosted virtual machines) are created and destroyed as demand ebbs and flows. Scaleup events can take some minutes, and being aware of this and a few tricks can avoid frustrations for you and your students. Lastly, these docs will demonstrate some of the more powerful customization features you can use to tailor your classroom experience. 

## Nomenclature: Hubs and Servers

Before we go further, it is important to understand a few JupyterHub specific concepts. The first is that of a "hub," representing a single environment with shared storage and user information. Generally a single hub is associated with a single class or workgroup--although technically a class may utilize multiple hubs and a hub may serve several classes, it isn't easy to transfer data between hubs, and users within a hub may easily interact.

Second is the concept of a "server." This is a JupyterHub term referring to a process group running users' software, e.g. the JupyterLab interface and two Jupyter notebooks, or the JupyterLab interface, RStudio interface, and an R process. Here a server is technically a docker container and many such servers may be running on a single cloud virtual machine behind the scenes, so these servers share resources in a highly dynamic cluster for resource efficiency. A user server is associated with a single hub (though of course a singler person may be able to log into multiple hubs, as with `warwickr` below.)

![](media/hubs_and_servers_and_users.png ':size=50%;')


User servers are generally started on hub login (unless one is already running for that user in a given hub) and stop after an hour of 'inactivity,' which is configurable and defined more carefully below. 

One last nomenclature note: while JupyterHub is the central process controlling login and accounting for user servers, Jupyter*Lab* is the next-generation interface users see when working with their server. 

## Canvas Auth vs. Native Auth

DS@OSU supports two modes of login: the first, default, and preferred mode is via Canvas. By "connecting" a Canvas course (or Studio Site) to a hub, students
and instructors/TAs can log into a hub just by clicking a button from a Canvas Module or Assignment. In this mode permissions inside the hub are governed by Canvas user role: by default students have regular 'user' permissions (read+write in their home folders and other admin-designated areas) and instructors and TAs (or just instructors if so configured) have 'admin' permissions (read+write everywhere). At some institutions such as OSU where Canvas Studio Sites support social logins (Google, Facebook, etc.) these are also available, an excellent choice for summer camps, conference workshops, etc. 

Where Canvas is not option, the JupyterHub [NativeAuthenticator](https://native-authenticator.readthedocs.io/) can be used instead. This authentication method identifies an initial set of admin usernames, and allows other users to sign up with a chosen username and password, after which admins can authorize and de-authorize those logins. 

Either way, once logged in, everyone is either a hub admin or hub user, and the authentication mechanism is largely moot. Note though that users *can* change roles, for example by promoting a student to a TA in Canvas or to admin status in the NativeAuthenticator. 

## Prereqs: What Do You Need?

A hub can only be created or destroyed by a cluster-level system administrator on your behalf. To do so, they will need to know some basic information to properly allocate resources: 

#### Storage Space

How much space will you need in total? 20 gigabytes? 50? More? There are a couple of points of note here. First, storage cannot (yet) be changed afterward. If you run out of space, the only solution is to have a new hub created with more and painfully migrate data manually. Second, the storage is *shared* amongst all hub users and admins, and there are not yet any quota mechanisms for space. One a 20G hub, one student may use 19G, leaving only 1G for everyone else. While this supports the natural 'ambitious student' distribution, you may need to keep an eye out for data hogs (e.g. by opening the Terminal application and running `du -sh /home/*`). We recommend being generous, as the shared storage model is more efficient than storage-per-user allocation used in some other systems. 

#### Destroy Date

On what date can all the data be deleted and the hub decommissioned? While DS@OSU uses several backend systems to ensure data integrity, it is *not* designed for long-term data archival. We recommend enough time for you to complete grading and offload any important data. 

#### Default Profile RAM/CPU guarantees and limits

How many resources do you and your students need when working? When anyone (admin or user) logs into the hub, their server will be reserved some RAM and CPU; these 'guarantees' will be met regardless of the state of the system. Because users share resources in a dynamic system, at any given moment more may be available for use. Specific CPU and RAM 'limits' allow servers to utilize up to these limits before processes (e.g. R or Python notebooks) are automatically killed, *if those resources happen to be available*.

Because we also optionally support multiple profiles for servers for larger compute needs, we recommend these default settings be relatively small, enough to support basic coding and example-data analysis. Further, because CPU allocation is highly dynamic but RAM is not, it is useful to allow a larger dynamic range for CPU than RAM. In the end, our standard recommend for the default server profile is 0.1 CPU gauranteed with 2.0 CPU limit, and 0.5G RAM gauranteed with 1.0G RAM limit. (Note that while working, the JupyterLab interface can display a RAM usage meter for the user. This shows the amount of RAM used as an absolute number, and as a percentage of the *limit*.)

#### Optional Profiles and Quotas

Will you have a need for even more resources? For larger compute needs, DS@OSU can optionally support additional profiles, each will a different configuration of RAM/CPU gaurantees and limits, as well as experimental support for GPU-compute (which comes with a python-tensorflow stack preinstalled). Because these can be very expensive, we've designed a [custom quota mechanism](https://github.com/oneilsh/jh-profile-quota) that keeps a 'bank' of hours for each user and profile. For a given profile, the system administrator ca adjust various settings, such as the minimum balance required to start a server with that profile, how many hours banks start with, the rate at which hours are accumulated (e.g. 2 hours per day), and the maximum number of hours a bank may hold. 

When not using extra profiles, the 'server start' page displayed on login (if the users' server is not already running) will display a simple "start my server" button, and when using profiles descriptions will be shown with explanatory text provided when hovering over the quota information:

![](media/dshub_profiles.png ':size=35%')
![](media/dshub_profiles_popup.png ':size=35%')

When using larger profiles, users will often find login takes longer (up to 10 minutes), as it is much more likely that the larger reservations trigger a cluster autoscale event to support them. As the second screenshot above notes, we do not stop a users' server if they run out of hours to avoid interruption of work, but we do allow balances to go negative. 

If these profile and quota features are of interest to you, the system administrator responsible for deploying your hub can work with you to identify these various in coordination with the cluster configuration. 

## Canvas: Connecting a Hub

When using Canvas-based login, only someone with sufficient privileges in the Canvas course can connect the Canvas course to a hub; usually this includes instructors (Teachers in Canvas parlance), TAs, and Designers. As such, you may have the option of adding the system administator to your course with sufficient permissions that they can make the connection for you. Your sysadmin will let you know the best role for this or if this is the best route. 

Alternatively, you can make the connection yourself given 3 key pieces of information provided by the system administrator after they spin up the hub: A `Hub Launch URL`, a `Consumer Key`, and a `Shared Secret`. These will look something like this:

```
Hub launch URL: https://hub-green.datasci.oregonstate.edu/example-simple/hub/lti/launch
Consumer Key: 9cc6ebca80d7aa322cfbafb72565b79f35ee374c22d98f5fa4160fa28a98f330
Shared Secret: dbc3eb6f43a6ca0256c0a1a60c8fa11a336308cefc770d1afffb635e59e41974
```

To make the connection, under the course **Settings**, click the **Apps** tab, and then **View App Configurations** button. 

![](media/canvas_app_configurations.png ':size=90%')

Next, click the **+App** button near the top of the resulting page, and enter the launch URL, Consumer Key, and Shared Secret as shown below. Be sure to 
select "Public" in the privacy dropdown: this allows Canvas to share user login names with the hub (without which you won't know who's who in the hub).

![](media/addapp.png ':size=60%')

The hub can then be accessed in Canvas by adding either 1) an "External Tool" module in the Modules section, or 2) an Assignment with the "External Tool" submission type. In both cases, use the Find button to locate the newly installed app, or just enter the launch URL in the link section of the dialog. Be sure to check
"load This Tool In A New Tab" or it simply won't work. 

![](media/canvas_external_tool.png ':size=70%')

(More details on these workflows [here](https://community.canvaslms.com/t5/Instructor-Guide/How-do-I-add-an-external-tool-as-a-module-item/ta-p/1146) and [here](https://community.canvaslms.com/t5/Instructor-Guide/How-do-I-add-an-assignment-using-an-external-app/ta-p/656).)

Finally, users (instructors and students) can log into the hub from Canvas by opening the relavent assignment or module and click the "launch" button. The timeout for clicking the button after the Canvas page loads is short--if the the page is open for too long it will report an error, but refreshing the page restores the button and restarts the timer. 

## Native Auth: Signup and authorization

When not using Canvas-based login, the JupyterHub NativeAuthenticator can provide isolated user management, allowing admin users to authorize and de-authorize users who signup with a username and password of their choice, promote/demote users to admin status, and for all user to change their own password. Although thoroughly [documented](https://native-authenticator.readthedocs.io/en/latest/), the workflow for this mode is a little confusing. 

First, when the system administrator creates the hub, they will need one or more usernames to identify as 'initial admins' who are *pre-authorized*. The sysadmin will also provide you with a hub URL, generally of the form `https://some.hostname.edu/hubname`. When visiting this URL, it will redirect to the login page at `https://some.hostname.edu/hubname/hub/login`: 

![](media/login_native.png ':size=30%')

The Signup! page is linked from this login page, and will redirect to `https://some.hostname.edu/hubname/hub/signup`. This is where students and others can signup to gain access by specifying a username and password, but beware that the signup and login pages *look very similar* (both show a similar username/password box and orange header). The initial admin user (probably you) must also use this signup page to set the password for their corresponding initial admin username. After navigating back to to the login page, the admin user can then login with that password as they are pre-authorized.

Two other important pages do not have direct links in the interface: `https://some.hostname.edu/hubname/hub/authorize`, where admin users can authorize and de-authorize signed-up accounts, and `https://some.hostname.edu/hubname/hub/change-password`, where users can change their passwords if they wish. 

## Managing Your Server

When logging into a hub, you will be presented with the opportunity to "Start My Server" (first screenshot below) or to access your already-running server (second screenshot) if one already happens to be running from a previous session. 

![](media/start_my_server.png ':size=40%') ![](media/stop_my_server.png ':size=40%')

If starting a new server and the hub has implemented optional profiles, you'll be given the opportunity to select the profile of the server as described above. 

If there are not enough resources available to start the server (which usually happens when using a larger profile or many other users are logging in simultaneously), login can take several minutes while a new cloud-based node (virtual machine) is created to host the server. **Note: during this time you may see warnings indicating "pod didn't trigger scale up"; these are normal and not an indication of an error.** Please give the login process up to 10 minutes to start; startup times longer than this can be reported by hub admins to the system administrator for investigation. 

![](media/scale_up_scary_warning.png ':size=60%') 

After your server starts you'll be taken to the main JupyterLab interface. To return to the server management interface, aka the *Hub Control Panel*, in JupyterLab navigate to **File -> Hub Control Panel**. From the default 'Home' tab you can also stop your running server--for exampe to be a good samaritan and free resources for use by others, or to start a new server with a different profile. (Stopping your server also stops any processes or analyses running inside it.)

Remember: servers are subject to being stopped automatically due to "inactivity" (after 1 hour for most hubs), or after a maximum runtime (8 hours for most hubs). Activity is defined as a browser tab open to the JupyterLab interface; closing this browser tab to work in RStudio for example (which opens in a new tab) will make you 'inactive' even if you are actively computing, and leaving the JupyterLab interface tab open but doing nothing counts as activity. 

## Managing Other Servers/Hub Admin

As a hub admin, you can also start and stop servers on behalf of other users via the 'Admin' tab of the Hub Control Panel (found via the JupyterLab interface under **File -> Hub Control Panel**):

![](media/hub_control_admin.png ':size=60%') 

Pre-starting user servers ~30 minutes before a class or workshop can be a convenient way to ensure users don't need to wait on scale-up events during login. If the hub is configured to use multiple profiles, you'll have to click "start server" for users individually, selecting the profile to start for each. If not using profiles, a "start all" button near the top will appear allowing you to start all servers en masse, though for hubs with more than ~40 users we recommend avoiding this and starting servers in batches or in sequence to help the scheduler coordinate resources efficiently. 

The Admin tab of the hub control panel also allows you to "access" a running server *as that user*, effectively logging you into the users' server with their own username. (The shared-data model of DS@OSU largely obviates this need however.)

Finally, when using the Native Authenticator (not Canvas) you can promote/demote users to admin status via the "edit user" button, and remove user accounts with "delete user." Note that this does *not* delete the users' home directory or data; should the user ever become re-authorized and log back in their information will be intact. When using Canvas login the "edit user" and "delete user" buttons have no effect, as usernames and roles are served by Canvas during login. 

The "Shutdown Hub" button has no real effect - clicking it will stop the hub temporarily preventing login, but a new one will be spawn automatically within minutes to take its place. The "Add Users" button similarly has little use; though one could in theory create a user, start a server for it, and access that server via the "access server" button, there are betters to create test user accounts (see below). 

## Shared Data Space & Permissions

After login the left navigation menu in JupyterLab will show the contents of your hub home directory, as indicated above in the filepath showing `📁/<username>`, where 📁 references `/home` where all hub-specific/shared data lives. (Data outside of `/home` is defined by the server image and cannot be modified.) Clicking this icon reveals all users' home directories (to admins, students only see their own home directory in this view) as all as the `hub_data_share` folder. 

![](media/lab_initial_login.png ':size=45%') &nbsp; &nbsp;
![](media/terminal_permissions.png ':size=45%') 

Permissions in the hub are configured with Unix permissions to allow admins to read and write everywhere (inside `/home`) including other users' home folders, but for regular users to have read+write in their own home folder and read-only access to contents of `hub_data_share`, which can thus serve as a staging area for course data and materials. By default, files created by an admin user in another users' home folder are readable by that user, but not writable. For advanced users, these behaviors are accomplished via a combination of [umask](https://en.wikipedia.org/wiki/Umask), [setgid bits](https://linuxconfig.org/how-to-use-special-permissions-the-setuid-setgid-and-sticky-bits), and creative default ownership of home directories. All users are part of the `dsusers` group, and admins are additionally part of the `dsadmins` group--you can thus create new folders (inside `hub_data_share` or elsewhere inside `/home`) with custom access schemes via standard Unix permissions tooling.

*Note:* Users are assigned psuedorandom numeric user IDs (UIDs), however the mapping between these and usernames only happens on server start. If you are seeing numeric user IDs instead of usernames when listing files and permissions, try restarting your server to pick up newly added UID <-> username mappings. 

## Testing Student Permissions

Given the intricacies of file Unix permissions, it is important to periodically test that permissions are properly setup to allow the intended access: assigning students a homework they can't access is a sure way to make them feel unwelcome!

If are your using the Native Authenticator (non-Canvas login), the best way to do so is to simply signup with a 'teststudent' (or similar) user account for your own use. 

When using Canvas, you can instead use the [Student View](https://community.canvaslms.com/t5/Instructor-Guide/How-do-I-view-a-course-as-a-test-student-using-Student-View/ta-p/1122) feature provided by Canvas. Before doing so, first login to the hub with your regular admin/instructor account and then **log out** of the hub via the JupterLab interface under **File -> Log Out**. 

![](media/lab_logout.png ':size=45%') 

Next, in Canvas, open the Student View and then re-open the hub--this will open the hub as the student view user, with a username consisting of random letters and numbers. (The need to explicitly logout first is because otherwise the hub will remember your previous login session and not pickup the test from the canvas student view.)

## Installing Packages & Scripts Hub-Wide

Users generally are able to install Python packages, R packages, and command-line utilities in their home folders via standard means (`pip install --user`, `install.packages()`, etc.). For convenience, as an admin you can also install such tools for all users of your hub. 

**Python packages** can be installed in to the hub Python library with the custom `hubpip` utility (a simple wrapper around `pip --prefix=/home/.hub_local/python_libs`, where that package library is by default in users' `$PYTHONPATH`). For example, to install the `black` package just open a terminal and run `hubpip install black`. 

Note that as of this writing, this hub python library takes precendence over user libraries, which in turn take precendence over default installed package versions; it needs to be fixed so that user-installed library versions take precendence.

**R packages** from CRAN can be installed in the hub R library with the custom `hub.install.packages()` function, for example `hub.install.packages("rstackdeque")`. Similar helpers exist for installing hub-wide from BioConductor, as in `hub.install_bioconductor("DESeq2")`, and GitHub, as in `hub.install_github("oneilsh/tidytensor")`. 

By default, packages installed by a user ini their own home directory with `install.packages()` or similar will take precendence over the hub library, which in turn takes precendence over default installed versions. 

**Command-line scripts and software** can also be installed hub-wide; the path `/home/.hub_local/bin` is in all users' `$PATH`, so executables placed here are available for everyone. For configure/make/make install-based installations you should use `./configure --prefix=/home/.hub_local` so that `make && make install` will place binaries here. 

Unfortunately, while you are free to modify anything in the shared data space `/home`, we cannot give hub admins `sudo` or root access or the ability to install system-level software with Ubuntu's `apt-get`. If you need such a system-level package or dependency, please reach out to your system administrator. 



