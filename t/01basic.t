use vars qw($tests);
BEGIN {
	push @INC, './t';
	$tests = 10;

	$^W= 1;
	$| = 1;
	print STDERR "*** Note: delays of several seconds may occur during these tests\n";
	print STDERR "*** Note2: several harmless \"Scalars leaked\" messages may be reported\n";
	print "1..$tests\n";
}

use LWP::Simple;
use LWP::UserAgent;
use LWPBulkFetch;
use strict;
use warnings;

#
# forks a child to run system('perl somescript.pl'),
#	which this process monitors
#
sub report_result {
	my ($testno, $result, $testmsg, $okmsg, $notokmsg) = @_;

	if ($result) {

		$okmsg = '' unless $okmsg;
		print STDOUT (($result eq 'skip') ?
			"ok $$testno # skip $testmsg\n" :
			"ok $$testno # $testmsg $okmsg\n");
	}
	else {
		$notokmsg = '' unless $notokmsg;
		print STDOUT
			"not ok $$testno # $testmsg $notokmsg\n";
	}
	$$testno++;
	return $result;
}

my $testno = 1;
my $child1;
my $sep = ($^O eq 'MSWin32') ? '\\' : '/';
unless ($ARGV[0]) {
 $child1 = fork();

die "Can't fork HTTP Client child: $!" unless defined $child1;

unless ($child1) {
	my $cmd = 'perl -w t' . $sep . 'httpdtest.pl -p 9876 -c 5 -d ./t -l 1 -s';
	system($cmd);
	exit 1;
}
#
#	wait a while for things to get rolling
#
sleep 5;
}

my $index = '<html><body>Some really simple HTML.</body></html>';
my ($ct, $cl, $mtime, $exp, $server);
#
#	now run each LWP request and see what we get back
#
#	1. simple HEAD
#
my $indexlen = length($index);	# change this!

($ct, $cl, $mtime, $exp, $server) = head('http://localhost:9876/index.html');
report_result(\$testno, (defined($ct) && ($ct eq 'text/html') &&
	defined($cl) && ($cl == $indexlen)), 'simple HEAD');
#
#	2. simple GET
#
my $page = get 'http://localhost:9876';
report_result(\$testno, (defined($page) && ($page eq $index)), 'simple GET');
#
#	3. document HEAD
#
my $jspage = '/*
 this would normally be a nice piece of javascript
*/
';

($ct, $cl, $mtime, $exp, $server) = head('http://localhost:9876/scripty.js');
report_result(\$testno,
	(defined($ct) && ($ct eq 'text/javascript') &&
	defined($cl) && (($cl == crlen($jspage)) || ($cl == length($jspage)))), 'document HEAD', '',
	"got CT: $ct CL: $cl; expected text/javascript, " . crlen($jspage) );
#
#	4. CGI HEAD
#
my $postpg = '<html><body>
that is other<br>
this is some<br>
when is right this minute<br>
where is up<br>
</body></html>';

($ct, $cl, $mtime, $exp, $server) = head('http://localhost:9876/posted?this=some&that=other&where=up&when=right%20this%20minute');
report_result(\$testno, (defined($ct) && ($ct eq 'text/html') &&
	defined($cl) && (($cl == crlen($postpg)) || ($cl == length($postpg)))), 'document HEAD', '',
	"got CT: $ct CL: $cl; expected text/html, " . crlen($postpg));
#
#	5. document GET
#
$page = get 'http://localhost:9876/scripty.js';
report_result(\$testno, (defined($page) && (!crcmp($page, $jspage))), 'document GET');
#
#	6. CGI GET
#
$page = get 'http://localhost:9876/posted?this=some&that=other&where=up&when=right%20this%20minute';
report_result(\$testno, (defined($page) && (!crcmp($page, $postpg))), 'CGI GET', '',
	"\n\nexpected $postpg\n, got $page\n");
#
#	7. multidoc GET
#
my %multidoc = (
'http://localhost:9876/frames.html',
"<html>
<head><title>Test Content Handler</title>
</head>

<frameset rows='55%,45%'>

	<frameset cols='80%,20%'>
		<frame id='sources' src='sourcepane.html' scrolling=no frameborder=1>
		<frame id='srctree' src='sourcetree.html' scrolling=yes frameborder=1>
	</frameset>

	<frame name='stackpane' src='stackpane.html' scrolling=no frameborder=0>

</frameset>
</html>
",

'http://localhost:9876/stackpane.html',
'<html>
<body>
Some other stuff goes here...
</body>
</html>
',
'http://localhost:9876/sourcepane.html',
'<html>
<body>
<center><h2>Here\'s a frame</h2></center>
</body>
</html>
',

'http://localhost:9876/sourcetree.html',
'<html>
<head>
<style type="text/css">
td, th, a {
	font-family: Verdana, Geneva, Arial, Helvetica, sans-serif;
	font-size: 10px;
	color: #666;
	white-space: nowrap;
}

a {
	text-decoration: none;
}

</style>

</head>
<body>
<div class="srctree">
<table border=0 id="treetable">
<tr><th colspan=2 align=left>Source Packages</th></tr>
<tr><td>&nbsp;&nbsp;</td><td align=left><a href="" onclick="">One</td></tr>
<tr><td>&nbsp;&nbsp;</td><td align=left><a href="" onclick="">Two</td></tr>
<tr><td>&nbsp;&nbsp;</td><td align=left><a href="" onclick="">Three</td></tr>
</table>
</div>

</body>
</html>
'

);

my $fetched = LWPBulkFetch->new('http://localhost:9876/frames.html');
my $url;
if ($fetched) {
	my $ok = 1;
	while (($url, $page) = each %multidoc) {
		$ok = undef, last
			unless $fetched->{$url} && (!crcmp($page, $fetched->{$url}));
	}
	report_result(\$testno, $ok, 'multidoc GET');
}
else {
	report_result(\$testno, undef, 'multidoc GET');
}

#
#	8. simple POST
#
my $ua = LWP::UserAgent->new();

$page = $ua->post('http://localhost:9876/posted',
	{ this => 'some', that => 'other', where => 'up', when => 'right this minute'});
unless (defined $page) {
	report_result(\$testno, undef, 'simple POST', '', 'No response');
}
else {
	$page = $page->content();
	report_result(\$testno, (defined($page) && (!crcmp($page, $postpg))), 'simple POST', '',
	"Got page $page\n");
}
#
#	9. POST w/ content
#
my $xml =
'<first>
	<second>this is the second</second>
	<third>this is the third</third>
</first>
';

my $r = HTTP::Request->new( POST => 'http://localhost:9876/postxml' );
$r->content( $xml );
$r->header('Content-type' => 'text/xml');

my $response = $ua->request( $r );
$page = $response->is_success ? $response->content : undef;
report_result(\$testno, (defined($page) && (!crcmp($page, $xml))), 'POST w/ content');
#
#	10. PUT (er, not yet...)
#
report_result(\$testno, 'skip', 'PUT content', 'Not ready for PUT yet...');

get 'http://localhost:9876/stop';

unless ($ARGV[0]) {
kill($child1);

waitpid($child1, 0);
}

sub crlen {
	my $crs = ($_[0]=~tr/\n//);
	return length($_[0]) + $crs;
}

sub crcmp {
	$_[0]=~s/[\r\n]//g;
	$_[1]=~s/[\r\n]//g;
	return ($_[0] cmp $_[1]);
}