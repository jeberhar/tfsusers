**Project Description**

**If you're using TFS 2008 or later, check out TFS Projects, it uses the TFS API to generate email lists!  TFS Users is still useful for CLI operations, or if you have more specialized TFS user needs.**

TFSUsers.pl will gather how many users are supported on a given TFS instance. Default TFS installations don't provide this info without painful drudgery.

First, I created this script because in my environment we needed to know how
many users we are supporting with TFS, but the default installation does
not provide a way to gather or obtain this information.  It will isolate each
valid user into a domain ID, then append an email suffex to each one so that
notifications may be sent out to your entire user community, for events like
outages, upgrades, or other changes.

Since TFSUsers.pl is obviously a perl script, you will need a perl
interpreter.  Since Windows does not come with that, the standard installation
is ActiveState Perl, which you can download for free.  If
you don't want to expose your TFS server to potential vulnerabilities by
installing Perl onto it, you may run it from a UNC path that has execute
permissions for the ID you will use when running the script.  Just grant that
ID execute permissions on your Perl directory (C:\Perl or something similar) 
then call the interpreter at the command line via something like this:

\\computerName\Perl\bin\perl.exe

As far as the script goes, you can view the code by simply opening the .pl
file in the text editor of your choice.  It is sufficiently documented so 
if you need to customize to your local environment it shouldn't be too tricky
provided you know Perl.

I submitted this to codeplex because there are not a lot of TFS tools written
in languages that are outside the usual .Net landscape.  There may have been a
more elegant way via the TFS API, but those are all .Net objects.  If anyone 
feels so inclined to port this to C# or any other CLR language, feel free.  All
I ask is that proper credit be given where credit is due.  I'm not sure how
portable this code would be because I'm not an expert in the TFS API by any
means, but it would at least provide a high level blueprint.

For a project by project user audit check out my other tool at http://tfsprojects.codeplex.com

Copyright 2017 Jay Eberhard.
