BEGIN {
	use FindBin '$Bin';
	push @INC, $Bin;
}

use GetFlowData qw(userTriggered);

my $url = pop;

$username= userTriggered($url);

if ( $username eq "Started by timer" )
{
	print "timer";
}
else
{
	print "not timer";
}
