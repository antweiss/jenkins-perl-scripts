
# script:   GetChangeset.pl
# Author:   Yair Kirschner
# Purpose:  Will recursively collect data from hudson jobs 


use Getopt::Long;
use File::Find;

Getopt::Long::Configure("bundling");

GetOptions("getchangeset|G", "copy|C", "copyLeave|L", "copyToReleaseNotes|D", "help|?");

if (defined($opt_help)) {
print qq{
Usage: GetChangeset.pl [OPTIONS]
creating change set or copying existing to library

  -G, --getchangeset   recursively collect data from hudson jobs
  -C, --copy	       exclude directories(erase files)
  -L,  --copyLeave	   exclude directories(dont erase files)
  -D, --copyToReleaseNotes copy change list to data base (html)
  --help               display this help and exit
};
exit(0);
}

BEGIN {
        push @INC,"M:/Att.CMTools_Mobile_int/InstallDev/Scripts";
}
use GetFlowData qw(printdate userTriggered changeSet printToTable printLargeHtml copyToWorkspace copyToReleaseNotes);

#the file holdint the change set for the current build
$FILE =  "$ENV{'DataFolder'}\\changeset_$ENV{'Product'}_$ENV{'VERSION_NUM'}.txt";
#remove white spaces
$FILE =~ s/\s+//g;
my $url=$ENV{'Url'};

#Get the change set
if (defined($opt_getchangeset)) {
	open (MYFILE, ">$FILE");
	print $FILE;

	print MYFILE printdate();
	$changeset = changeSet($url);
	if($changeset){
		print MYFILE printToTable(changeSet($url));
	}else{
		print MYFILE printLargeHtml("No changes found for this build");
	}
	$username= userTriggered($url);
	print MYFILE printLargeHtml($username);
}

#create release notes
if (defined($opt_copyToReleaseNotes)) {
	my $changesfile = "changeset_$ENV{'Product'}_$ENV{'VERSION_NUM'}.txt";
	$changesfile =~ s/\s+//g;
	copyToReleaseNotes($changesfile, $ENV{'Product'});
}
#copy to workspace and erase 
if (defined($opt_copy)) {

	my $leave = 0;
	my $changesfile = "changeset_$ENV{'Product'}_$ENV{'VERSION_NUM'}.txt";
	$changesfile =~ s/\s+//g;
	copyToWorkspace($changesfile, $ENV{'WORKSPACE'}, $leave);
}

#copy to workspace but dont erase
if (defined($opt_copyLeave)) {

	my $leave = 1;
	my $changesfile = "changeset_$ENV{'Product'}_$ENV{'VERSION_NUM'}.txt";
	$changesfile =~ s/\s+//g;
	copyToWorkspace($changesfile, $ENV{'WORKSPACE'}, $leave);
}
close (MYFILE);




