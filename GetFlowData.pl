#!/usr/bin/perl -l

# Script:   ChangeSet.pl
# Author:   Yair Kirschner
# Purpose:  Will recursively collect data from hudson jobs 

use Getopt::Long;
use LWP::Simple;
use XML::Simple;
use Data::Dumper;
use Env;

Getopt::Long::Configure("bundling");

GetOptions("triggered|t", "changeset|c", "nonrecursive|n", "help|?");

if (defined($opt_help)) {
print qq{
Usage: ChangeSet.pl [OPTIONS] 
Will recursively collect data from hudson jobs 

  -n,--nonrecursive   will collect data only from a specific job, not recursively.(default if recursively)
  -t, --triggered      prints who triggered the jobs
  -c, --changeset      prints the changeset done since last build
  --help               display this help and exit
};
exit(0);
}
	#output file
	my $FILE =  "changeset_$ENV{'Project'}.txt";
	open (MYFILE, ">$FILE");
	#add current time
	my ($sec,$min,$hour,$day,$month,$yr19,@rest) =   localtime(time);#######To get the localtime of your system
	print MYFILE "Date:\t$day-".++$month. "-".($yr19+1900); ####To print date format as expected
	print MYFILE "Time:\t".sprintf("%02d",$hour).":".sprintf("%02d",$min).":".sprintf("%02d",$sec)."\n";###To print the current time

sub main{

	# create object
	$xml = new XML::Simple;

	# read XML file
	my ($url)= @_;

	#add /api/xml extension
	$xml_url=$url."/api/xml";
	
	#parse xml
	my $content = get $xml_url;
	die "Couldn't get $xml_url" unless defined $content;
	$data = $xml->XMLin($content);

	if (defined($opt_changeset)) {
		changeSet();
	}
	
	unless (defined($opt_nonrecursive)) {
		recursive();
	}
	
		#print MYFILE Dumper($data);
	close (MYFILE); 
}
 my $url='http://hudson-dev01:8080/view/Mobile/view/Encore/view/ATT%20Messages%20AUI%20-%20V2/job/3.%20ATT%20Messages%20AUI%20-%20ATT_Messages_AUI%20Source%20Control/116/';
main($url);


###----------------------Methods-------------------###

#check for upstream recursively
sub recursive{
	#if has updtream:
	if ($data->{action}->[1]->{cause}->{upstreamProject}){
		$upstream=$data->{url};
		if($upstream =~ s/job.*$/$data->{action}->[1]->{cause}->{upstreamUrl}/){
			$buildnumber=$data->{action}->[1]->{cause}->{upstreamBuild};
			$upstream=$upstream.$buildnumber."/api/xml";
		}
		main($upstream);
	}else{
		if (defined($opt_triggered)) {
			userTriggered ();
		}
	}
}


#Method to print the User who triggerd the job
sub userTriggered{
	#if triggered by user, print the name.
	my $whostarted="";
	$userTriggeres = $data->{action}->[1]->{cause}->{userName};
		if ( $userTriggeres){ 
			$whostarted=$whostarted."User triggered the build is: $userTriggeres\n";
		}
		if($whostarted){
	print MYFILE $whostarted;
	}else{
	print MYFILE "The build was triggered by TIMER\n";
	}
}

#Method to print the changeset for each job
sub changeSet{
	#print change set
	$streamName=$data->{action}->[3]->{stream};
	my $string="";
	
	##only one item
	$singleItem=($data->{changeSet}->{item});
	 if(($singleItem->{hasSubActivities}) eq true){
			$singleItem = ($singleItem->{subActivitie});
			while (($key, $value) = each(%{$singleItem})){
			$activity = ($value->{headline});
			$user = ($value->{user});
			$comment=($value->{file}->[4]->{comment});
			if($activity !~ m/rebase/ && $value->{user} !~ m/^(build)/i){
				$string=$string."	The Activity is: $activity\n";
				$string=$string."	The User is: $user\n\n";
				
				if($comment&&$comment!~ m/HASH/){
					$string=$string."	Comments: $comment\n\n";
				}else{
					$string=$string."\n";
				}
			}
			}
	   }else{
	
	
	
	##single subactivitie
	   if($key eq subActivitie){
			$activity = ($value->{headline});
			$user = ($value->{user});
			$comment=($value->{file}->[4]->{comment});
			if($activity !~ m/rebase/ && $value->{user} !~ m/^(build)/i){
				$string=$string."	The Activity is: $activity\n";
				$string=$string."	The User is: $user\n\n";
				
				if($comment&&$comment!~ m/HASH/){
					$string=$string."	Comments: $comment\n\n";
				}else{
					$string=$string."\n";
				}
			}
	   }else{
			##no subactivities
			if ($value->{hasSubActivities} eq false){
				if($value != ""){
				$comment=($value->{file}->{comment});
				$user = ($value->{user});
					if($key !~ m/rebase/ && $value->{user} !~ m/^(build)/i){
						$string=$string."	The Activity is: $key\n";
						$string=$string."	The User is: $user\n";
						if($comment&&$comment!~ m/HASH/){
							$string=$string."	Comments: $comment\n\n";
						}else{
							$string=$string."\n";
						}
					}
				}
			}else{

				##few subactivities
				while (($k, $v) = each(%{$value->{subActivitie}})){
					if($v != ""){
					#$c=($v->{file}->[4]->{comment});
						if($v->{headline} !~ m/rebase/ && $v->{user} !~ m/^(build)/i){
							$string=$string."	The Activity is: $v->{headline}\n";
							$string=$string."	The User is: $v->{user}\n\n";
							#print MYFILE "Comments: $c\n";
						}
					}
				}
			}
		}
	}
	
	#if there are atcivities, print them
	if($string){
		print MYFILE "The stream is: $streamName\n";
		print MYFILE $string;
	}
	
}






