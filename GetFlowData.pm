package GetFlowData;

# module:   GetFlowData.pm
# Author:   Yair Kirschner

use XML::LibXML;
use Exporter;
use Getopt::Long;
use Data::Dumper;
use Env;
use File::Copy;
@ISA = qw(Exporter);
@EXPORT_OK=qw(printdate userTriggered changeSet getUpStream firstJob parsexml printToTable printLargeHtml copyToWorkspace copyToReleaseNotes);

####GLOBAL VERIABLES###
my $output="";
#main hash
my %streamHash;
my $changeSetStorage = "\\\\netapp04\\mobility_builds\\changeSet";

###----------------------Methods-------------------###
sub printdate{
	my $output = "";
	#add current time
	my ($sec,$min,$hour,$day,$month,$yr19,@rest) =   localtime(time);#######To get the localtime of your system
	$output = $output."Date:\t$day-".++$month. "-".($yr19+1900)."\n"; ####To print date format as expected
	$output = $output."Time:\t".sprintf("%02d",$hour).":".sprintf("%02d",$min).":".sprintf("%02d",$sec)."\n\n";###To print the current time
	return($output); 
}

#Method to get the User who triggerd the job
sub userTriggered{
	
	my $firstjob = firstJob(@_);
	my $doc = parsexml($firstjob);
	my $userTriggeres = ($doc->findnodes('/*/action/cause/shortDescription'));
	$userTriggeres = $userTriggeres->to_literal;
	return $userTriggeres;
	
}

#Method to get the changeset recursivley
#Method creates A main Hash 
#with the streams names as a key
#and the value is another hash
#with the activities names as a key
#and the value is an array
#containing in the first cell ([0]) the user name
#and in the second cell([1]) comments if there are any.
sub changeSet{
	
	#initiate a new activitie hash for each stream
	my %activitiesHash;
	$streamName = "";
	$doc = parsexml(@_);
	# check if the source control is git
	if ($doc->findnodes('/freeStyleBuild/changeSet/item/commitId')){
		foreach my $item ($doc->findnodes('/freeStyleBuild/changeSet/item')) {
			my ($fullname) = $item->findnodes('./author/fullName');
			$fullname = $fullname->to_literal;
			my ($comment) = $item->findnodes('./comment');
			$comment = $comment->to_literal;
			my ($id) = $item->findnodes('./id');
			$id = $id->to_literal;
			push(@{$activitiesHash{$id}}, $fullname);
			push(@{$activitiesHash{$id}}, $comment);
		}
	} 
			#get all subactivities
			foreach my $activity ($doc->findnodes('/freeStyleBuild/changeSet/item')) {
			if($activity->findnodes('./hasSubActivities')){
				my($name) = $activity->findnodes('./name');
				$name = $name->to_literal;
				my($user) = $activity->findnodes('./user');
				$user = $user->to_literal;
				my($comment) = $activity->findnodes('./file/comment');
				
				#Ignore rebase and build activities
				if ( $name !~ m/rebase/ &&  $user !~ m/^(build)/i &&  $name !~ m/^(deliver)/i ){
					
					#push user name as an array to the hash value
					push(@{$activitiesHash{$name}}, $user);
					#push comments as an array to the hash value if no comments push "--"
					if($comment){
						$comment = $comment->to_literal;
						
						push(@{$activitiesHash{$name}}, $comment);
					}else{
						push(@{$activitiesHash{$name}}, "--");
					}
				}
			}
			}
			foreach my $subActivity ($doc->findnodes('/freeStyleBuild/changeSet/item/subActivity')) {
				
				my($name) = $subActivity->findnodes('./name');
				$name = $name->to_literal;
				my($user) = $subActivity->findnodes('./user');
				$user = $user->to_literal;
				my($comment) = $subActivity->findnodes('./file/comment');
				
				#Ignore rebase and build activities
				if ( $name !~ m/rebase/ &&  $user !~ m/^(build)/i ){
					
					#push user name as an array to the hash value
					push(@{$activitiesHash{$name}}, $user);
					#push comments as an array to the hash value if no comments push "--"
					if($comment){
						$comment = $comment->to_literal;
						push(@{$activitiesHash{$name}}, $comment);
					}else{
						push(@{$activitiesHash{$name}}, "--");
					}
				}
			}
			
			#get stream name
			if(keys %activitiesHash){
				foreach my $action ($doc->findnodes('/freeStyleBuild/action')) {
					my($stream) = $action->findnodes('./stream');
					if($stream){
						$stream = $stream->to_literal;
						$streamName = $streamName.$stream; 
					}
				}
				foreach my $action ($doc->findnodes('/freeStyleBuild/action')) {
					my($stream) = $action->findnodes('./remoteUrl');
					if($stream){
						$stream = $stream->to_literal;
						$streamName = $streamName.$stream; 
					}
				}

				#copy the activity hash as a value to the stream hash
				while (($key, $value) = each(%activitiesHash)){
					$streamHash{$streamName}{$key} = $value;
					}
			}
		 
			#get up stream
			my $upstream = getUpStream();
			#Recursive
			if($upstream){
				changeSet($upstream);
			}

		
return %streamHash;
}

#Method to parse an xml by the url
sub parsexml{
	$parser = XML::LibXML->new();
	($url)= @_;
   $xml_url=$url."/api/xml";
   $parsed = $parser->parse_file($xml_url);
   return $parsed;
}

#Method to get the first job
sub firstJob{
	$doc = parsexml(@_);
	my $upstream = getUpStream();
	if($upstream){
		firstJob($upstream);
	}else{
		($first) = @_;
	}
	return $first;
}

#Get the upstream url
sub getUpStream{
	$upsrtream = $doc->findnodes('/freeStyleBuild/action/cause/upstreamUrl');
	if ($upsrtream){
		my $url = $doc->findnodes('/freeStyleBuild/url');
		if($url =~ s/job.*$/$upsrtream/){
			$buildnumber=$doc->findnodes('/freeStyleBuild/action/cause/upstreamBuild');
			$url=$url.$buildnumber."/";
			return ($url);
		}
	}
}

#print the changeset data to html table
sub printToTable{
	%toprint = @_;
	$output = "";
	$output=$output."<H1>ChangeSet Summary</H1>\n";
	$output=$output."<style type=\"text/css\">
table.sample {
	border: 6px inset #8B8378;
	-moz-border-radius: 6px;
}
table.sample td {
	border: 1px solid black;
	padding: 0.2em 2ex 0.2em 2ex;
	color: black;
}
table.sample tr.d0 td {
	background-color: #FCF6CF;
}
table.sample tr.d1 td {
	background-color: #FEFEF2;
}
</style>";
 $output=$output."<table class=\"sample\">\n";
 $output=$output."<tr class=\"d0\"><td><big>Stream/Branch</big></td><td><big>Activity/Commit ID</big></td><td><big>User</big></td><td><big>Comments</big></td></tr>\n";
	
	#loop the streams
	while (($key, $value) = each(%toprint)){
		
		#boolean to print stream name or not
		my $flag=0;
		$output=$output."<tr><td>".$key."</td>\n";
		
		#loop and sort the activities
		foreach $k (sort {lc($a) cmp lc($b)} keys %$value) {
			#get the user and comments array
			$v=$value->{$k};
			#print blank instead of stream name if needed
			if($flag){
				$output=$output."<td></td>\n";
			}
			#print all cells
			$output=$output."<td>".$k."</td>\n";
			$output=$output."<td>".$$v[0]."</td>\n";
			$output=$output."<td>".$$v[1]."</td></tr>\n";
			$flag=1;
		}
		
		$output=$output."<tr bgcolor='#FCF6CF'><td>&#160;</td><td>&#160;</td><td>&#160;</td><td>&#160;</td></tr>\n";
	}
		$output=$output."</table>";
		return $output;
}

#print to large html format
sub printLargeHtml{
	
	return "<H1>@_</H1>\n";
}

#copy the change set to the release notes file
sub copyToReleaseNotes{
	
	my $changeSet = $changeSetStorage."\\$_[0]";
	print "the changeset file is: $changeSet";
	my $ReleaseNotes = $ENV{'PackDir'}."\\ReleaseNotes.html";
	print "the ReleaseNotes file is: $ReleaseNotes";
	my @changesetLines;
	my @releaseLines;

	#Open outfile
	if(-e $ReleaseNotes){
		open DATAFILE, "<$ReleaseNotes" or die "Can't open $ReleaseNotes";
		@releaseLines=<DATAFILE>;
		print @releaseLines;
		close (DATAFILE) or die "FILE: $ReleaseNotes can't be closed: $! ";
	}
	
	#Open first infile and write to outfile
	open (FILE, "<$changeSet") or die "can't open $changeSet: $! ";
	open DATAFILE, ">$ReleaseNotes" or die "Can't open $ReleaseNotes";
	print DATAFILE "<H1>";
	print DATAFILE "VERSION: $ENV{'VERSION_NUM'}";
	print DATAFILE "</H1></BR>";
	@changesetLines=<FILE>;
	
	#copy to 
	print DATAFILE @changesetLines;
	print DATAFILE "<BR>-------------------------------------------------------------------------------------------------------------------------------------------------</BR>";
	print DATAFILE @releaseLines;
	
	close (FILE) or warn "FILE: $changeSet can't be closed: $! ";

	#Close outfile
	close (DATAFILE) or die "FILE: $ReleaseNotes can't be closed: $! ";
}

sub copyToWorkspace{

	my $local = "$_[1]\\changeset.txt";
	print "Local change set file is: $local\n";

	my $changeSet = $changeSetStorage."\\$_[0]";
	print "Remote change set file is: $changeSet\n";
	if(-e $changeSet){
		print "The changeset file is: $changeSet\n";
		unlink "$local";
		if(-e $local) {print "$local could not be earased\n";}
		copy("$changeSet","$local") or die "Copy failed: $!";
		if ($_[2] == 0){
			unlink "$changeSet";
			if(-e $changeSet) {print "$changeSet could not be earased\n";}
		}
	}else{
	
		open (MYFILE, ">$local");
		print MYFILE "WARNING: could not identify change set\n";
		close (MYFILE);
	}
}

1;



