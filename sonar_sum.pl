#!/usr/bin/perl
use strict;
use warnings;
use XML::LibXML;
use LWP::Simple;
use Env;

# %SonarServer% environmental variable must be set.
# %SonProject environmental variable must be set.
# %Project% environmental variable must be set.

my $sonarserver = $ENV{'SonarServer'};
my $sonproject = $ENV{'SonProject'};
my $file = "data_$ENV{'Project'}.txt";

# Downloading Sonar project XML
my $browser = get($sonarserver."/api/resources?resource=".$sonproject."&metrics=violations,blocker_violations,major_violations,critical_violations,minor_violations,info_violations,new_violations&format=xml");
die "Error: can't GET valid sonar response from $sonarserver" if (! defined $browser);

my $parser = XML::LibXML->new();
my $url=$sonarserver."/dashboard/index/".$sonproject."";
# Parsing the downloaded XML
my $doc= $parser->parse_string($browser);
# Opening the project XML file to append the sonar project data
open (my $fh, ">>", $file) or die "Could not open file '$file'. $!";
	my $newdoc= $parser->parse_file($file);
	my $root = $newdoc->getDocumentElement(); #Setting the root element of the XML
	# Creating the sonar element for the XML
	my $sonar = $newdoc->createElement("sonar");
	$root->appendChild($sonar);
	# Setting the attributes to the "sonar" element
	$sonar->setAttribute("url",$url);
		foreach my $msr ($doc->findnodes('/resources/resource/msr')) {
			my($key) = $msr->findnodes('./key');
			my($frmt_val) = $msr->findnodes('./frmt_val');
			my $aname = $key->to_literal;
			my $avalue = "0";
			if (defined $frmt_val)
			{
				$avalue = $frmt_val->to_literal;
			}
			
			$sonar->setAttribute($aname, $avalue);
		}
	$newdoc->toFile($file);	# Writing the new element with attributes to the XML file
close $fh;