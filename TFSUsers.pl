###############################################################################
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
###############################################################################
# TFSUsers.pl Copyright 2010, Jay Eberhard
#	1-28-2010 - Initial Version, Jay Eberhard
#
# Distribution list for Team Foundation Server is built by this script for each application within TFS on a specified server.
#
# USAGE: perl.exe TFSUsers.pl <TFS_server>
#
# The script takes three one arguments, the first is the hostname of the TFS server to query.  Second, the name of the domain where
# the TFS server resides.  Third, the email suffix in the organization; example.com for example.  The order of the arugments 
# DOES matter!  Exceptions to the list are maintained in the TFSExceptions.txt file which must be in the same directory as this
# script.  Directory lookups are performed by scripting ldifde.exe, an Active Directory lookup tool typically provided by default Microsoft
# Server installations.  Output files are tfsUsers.txt and TFSExceptions.txt which are stored in the same directory as the script.  
################################################################################

use strict;
require Env; 

my $server = shift;
my $windowsDomain = shift;
my $emailDomain = shift;
my $systemRoot = $ENV{SystemRoot};
my $ldifde = "$systemRoot\\system32\\ldifde.exe";
my $tfsSecurity;
my $tfsPath;
my $tfsPathComplete = "Tools\\TFSSecurity.exe";
my $line;
my $trim;
my $junk;
my $cmd;
my $result;
my $exception;
my $userCount = 0;
my @Exceptions;
my @TFS_User_List;
my @TFSUsers;
my @Users;
my @NonExceptedUsers;
my @NonUsers;
my @ActiveUsers;
my @ActiveUsersFinal;
my %usersHash;

###BEGIN SCRIPT###
print "\nTeam Foundation Server user list generation starting:\n\n";
validateArguments();
testADChecking();
checkTFSSecurity();
buildExceptions();
executeUsersCommand();
loadTFSArray();
removeExceptions();
validateUsers();
processNonUsers();
processActiveUsers();
cleanup();
countUsers();
print "\nTeam Foundation Server user list generation complete.\n";
###END SCRIPT###

sub validateArguments {
	if ($server eq "") {
		print "Server name must be passed in and can not have a null value.  Please supply a server name and try again.\n";
		print "\nUSAGE: perl.exe TFSUsers.pl (server_name) (windows_domain_name) (email_domain_suffix)\n";
		exit;
	}
	if ($windowsDomain eq "") {
		print "Windows domain name must be passed in and can not have a null value.  Please supply a windows domain name and try again.\n";
		print "\nUSAGE: perl.exe TFSUsers.pl (server_name) (windows_domain_name) (email_domain_suffix)\n";
		exit;
	}
	if ($emailDomain eq "") {
		print "Email domain name (example.com) must be passed in and can not have a null value.  Please supply an email domain name and try again.\n";
		print "\nUSAGE: perl.exe TFSUsers.pl (server_name) (windows_domain_name) (email_domain_suffix)\n";
		exit;
	}
}

sub testADChecking {
	print "Testing functionality of $ldifde...";
	$cmd = "$ldifde";
	$result = `$cmd 2>&1`;
	print "DONE!\n\n";

	if ($result =~ /not recognized/i) {
		print "FATAL ERROR: Could not locate ldifde, it is not in $ldifde where it needs to be.\n";
		print "Please use the Windows UI to install Active Directory Domain Services.\n";
		print "For more information please see:\n";
		print "\thttp://technet.microsoft.com/en-us/library/cc730825.aspx\n";
		exit;
	}
}

sub checkTFSSecurity {
	#get the value of the TFS installation directory - TFS 2008 ONLY (registry key will change for future versions)
	$cmd = "reg query HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\VisualStudio\\9.0\\TeamFoundation\\ \/v ATInstallPath";
	$result = `$cmd 2>&1`;

	if ($result =~ /error/i) {
		print "FATAL ERROR: Could not locate TFS Install Path.\n";
		exit;
	}
	
	($junk, $tfsPath) = split (/REG_SZ/, $result);
	($junk, $tfsPath) = split (/    /, $tfsPath);
	chop ($tfsPath);
	chomp ($tfsPath);
	$tfsSecurity = "$tfsPath$tfsPathComplete";
	
	#test execution of tfsSecurity.exe
	print "Testing functionality of $tfsSecurity...";
	$cmd = "\"$tfsSecurity\"";
	$result = `$cmd 2>&1`;
	print "DONE!\n\n";

	if ($result =~ /error/i) {
		print "FATAL ERROR: Could not execute TFSSecurity.exe which caused an error.\n";
		exit;
	}
	
	if ($result =~ /not recognized/i) {
		print "FATAL ERROR: Could not execute TFSSecurity.exe, it is not in $tfsPath\\Tools where it needs to be.\n";
		exit;
	}
}

sub buildExceptions {
	#open the exceptions list and put into @Exceptions
	print "Building the exceptions list from TFSExceptions.txt...";
	$cmd = "type TFSExceptions.txt";
	$result = `$cmd 2>&1`;
	@Exceptions = `type TFSExceptions.txt`;
	print "DONE!\n\n";
	
	if ($result =~ /system cannot/i) {
		print "FATAL ERROR: Could not open the file TFSExceptions.txt\n";
		exit;
	}
}

sub executeUsersCommand{
	#execute the necessary tfsSecurity.exe command
	print "Executing TFSSecurity.exe for TFS info on $server...";
	$cmd = `\"$tfsSecurity\" /imx "Team Foundation Valid Users" /server:$server >TFSTempOut.txt`;
	print "DONE!\n\n";
	if ($cmd =~ /error/i) {
		print "FATAL ERROR: Could not execute tfssecurity.exe, exiting.\n";
		exit;
	}
}

sub loadTFSArray {
	#put TFSTempOut.txt into an array put each entry in lower case
	print "Loading temp file TFSTempOut.txt from tfsSecurity.exe output into array...";
	$cmd = "type TFSTempOut.txt";
	$result = `$cmd 2>&1`;
	@TFS_User_List = `type TFSTempOut.txt`;

	
	if ($result =~ /system cannot/i) {
		print "FATAL ERROR: Could not view the file TFSTempOut.txt\n";
		exit;
	}
	TFSUSER:
	foreach $line (@TFS_User_List) {
		if ($line =~ /\[U\] $windowsDomain/) {
			if ($line =~ /\\/) {
				($junk, $line) = split(/\\/,$line);
				($line, $junk) = split(/ /,$line);
				$line = lc($line);
				push(@TFSUsers, $line);
				next TFSUSER;
			}
		} else {
			next TFSUSER;
		}
	}
	print "DONE!\n\n";
}

sub removeExceptions {
	# convert @TFSUsers into a hash, removing duplicates into @Users
	print "Removing exceptions in TFSExceptions.txt from the user list...";
	
	my %usersHash = map { $_ => 1 } @TFSUsers;
	my @Users = keys %usersHash;

	#remove the exceptions in the exceptions list from the array of users
	EXCEPT:foreach $line (@Users)  {
		chomp $line;
		foreach $exception (@Exceptions) {
			chomp $exception;
			if ($exception =~ /$line/i) {
				next EXCEPT;
			}
		}
		push (@NonExceptedUsers, $line);
	}
	print "DONE!\n\n";
}

sub validateUsers {
	#validate each ID using ldifde.exe and if invalid add to the invalid addresses array
	print "Validating all users in the list against the Active Directory...";
	foreach $line (@NonExceptedUsers) {
		chomp $line;
		$cmd = `$ldifde -f c:\\NULL.txt -l "cn" -r (samAccountName="$line")`;

		if ($cmd =~ /not recognized/i) {
			print "FATAL ERROR: Could not execute ldifde.exe which is required for Active Directory lookups.\n";
			print "Make sure the file ldifde.exe is present in the Windows\System32 directory.\n";
			#backout();
			exit;
		}
		#sort the users into active versus non users based on the result of the lookup
		if ($cmd =~ /No Entries found/i) {
			push(@NonUsers, "$line\n");
		}else {
			push(@ActiveUsers, "$line\n");
		}
	}
	print "DONE!\n\n";
}

sub processNonUsers {
	#print the sorted array of non users to the output file
	print "Updating the exception list with any new non-resolved domain names...";
	@NonUsers = sort(@NonUsers);
	open(EXCEPTIONS, ">>TFSExceptions.txt");
	foreach $line (@NonUsers) {
		print "EXCEPTION: $line\n";
		print EXCEPTIONS "$line"; #write this to the exceptions list
	}
	close EXCEPTIONS;
	print "DONE!\n\n";
}

sub processActiveUsers {
	#add back @$emailDomain; to each line for each of the users in @ActiveUsers
	print "Formatting each user name in the list into a valid email address...";
	foreach $line (@ActiveUsers) {
		chomp $line;
		$line = "$line\@$emailDomain;\n";
		unless ($line eq "\@$emailDomain;\n") { push(@ActiveUsersFinal, $line); }
		@ActiveUsersFinal = sort(@ActiveUsersFinal);
	}
	print "DONE!\n\n";

	#write @ActiveUsers to the outage distribution list
	print "Writing active TFS users to the distribution list file tfsUsers.txt...";
	open(LIST,">tfsUsers.txt");
	foreach $line (@ActiveUsersFinal) {
		print LIST $line;
		$userCount = $userCount + 1;
	}
	close LIST;
	print "DONE!\n\n";
}

sub cleanup {
	#delete the temp file that is created out of necessity by ldifde.exe
	$cmd = `del c:\\NULL.txt`;
	
	#delete the temp file that is created out of necessity by tfssecurity.exe
	$cmd = `del TFSTempOut.txt`;
	print "All temporary files created by this script have been removed.\n";
}

sub countUsers {
	print "\nThere are $userCount TFS users on $server\n";
}