
 use LWP::Simple;
 use XML::Simple;
  use Data::Dumper;
use Env;
  
# create object

$xml = new XML::Simple;
# read XML file

my $url=$ENV{'Url'};

 # trim whiespaces from VERSION_NUM
 $ENV{'VERSION_NUM'} =~ s/^\s+|\s+$//g;
 my $version=$ENV{'VERSION_NUM'};
 #if VERSION_NUM not defined - construct from version.properties file and triggering build buildnumber
 unless ( $ENV{'VERSION_NUM'} ) 
 {
	$ENV{'PREVIOUSVERSION'} =~ s/^\s+|\s+$//g;
	$ENV{'NEXT_BUILD_NUMBER'} =~ s/^\s+|\s+$//;
	$ENV{'BUILDNUMBER'} =~ s/^\s+|\s+$//g;
	my $internalBuild = $ENV{'NEXT_BUILD_NUMBER'} - 1;
	$version = "$ENV{'PREVIOUSVERSION'}.${internalBuild}-$ENV{'BUILDNUMBER'}";
}

 my $product_dir="$ENV{'PackDir'}\\${version}";

 my $FILE =  "data_$ENV{'Project'}.txt";
 
 #extract data to file in xml format
 open (MYFILE, ">$FILE");
 print MYFILE "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n";
 print MYFILE "<project>\n";
 print MYFILE "<name>".$ENV{'Project'}."</name>\n";
 print MYFILE "<url>".$url."</url>\n";
 $xml_url=$url."/api/xml";
 my $content = get $xml_url;
 die "Couldn't get $xml_url" unless defined $content;
 $data = $xml->XMLin($content);
 print MYFILE "<result>".$data->{result}."</result>\n";
 print MYFILE "<dir>".$product_dir."</dir>\n"; 

 print MYFILE "</project>\n";
  close (MYFILE); 
 
