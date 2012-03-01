#!/usr/bin/perl
##############################################################################
# $Id: 
##############################################################################
# ga-api2mpp.pl - this script leverages the Google Analytics API
#		http://code.google.com/apis/analytics/docs/gdata/home.html
#
#		it generates 2 files:
#			mpp.rss - an rss of the top 20 stories from your website/blog
#			mpp.csv - a comma delmited file of all the stories from your website/blog
#
# ASSUMPTIONS:
#		you have access to a Google Analytics (GA) account
#		you've obtained the profile id (not UA key) from the GA dashboard
#		your article paths include /yyyy/mm/dd ..
#
#
# DEPENDENCIES:
# 		Net::Google::Analytics - http://search.cpan.org/dist/Net-Google-Analytics/
# 		Net::Google::AuthSub - http://search.cpan.org/~simonw/Net-Google-AuthSub-0.5/lib/Net/Google/AuthSub.pm
#       XML::FeedPP	- http://search.cpan.org/~kawasaki/XML-FeedPP-0.43/lib/XML/FeedPP.pm
#
#		NOTE - for Net:Google::AuthSub, if you get a file permissions error from ExtUtil::MakeMaker
#			see this page: http://search.cpan.org/~leont/Module-Build-0.40/lib/Module/Build.pm
#			especially setting the makepl_arg arg for INSTALLMAN1DIR & INSTALLMAN3DIR
#
# SYNTAX:
#       command  : perl ga-api2mpp.pl username\@gmail.com password 1234567
#       cronatab : * */12 * * * perl ga-api2mpp.pl username\@gmail.com password 123467
#
# TO DO:
#       see if I can get filters working, perhaps an array or hash of arrays?
#       see if I can't bring in the profile id(s) from the API
#       use a yaml config file to drive the optional parameters
#		of course I need to not hard-code the dates
#		more robust commandline (getops) handling
#		figure out how to do CDATA blocks with the description & title fields using XML::FeedPP
#		it might be fun to direct output via Template Toolkit;
#		employ utm tracking for outbound links
#			-- such as ?utm_source=ga-app2mpi&utm_medium=rss-widget&utm_campaign=most-popular-pages
#		once you empoy utm tracking, you'll want to employ utm filtering
#		more robust error & exception handling 
#			-- 5 retries on a get_data, duration of each doubles until all fail
#
# LICENSE:
# 		ga-api2mpp.pl by Dean Peters is licensed under a 
#		Creative Commons Attribution-NonCommercial-ShareAlike 3.0 
#		United States License. For more details, read here:
#		http://creativecommons.org/licenses/by-nc-sa/3.0/us/
#
# WARANTEE:
#		absolutely none. use at your own peril
#
# KVETCH:
#		got a comment, complaint, criticism or contribution?
#		http://twitter.com/deanpeters
#		http://healyourchurchwebsite.com
#
##############################################################################
use strict;											# since I'm re-using variables w/in scoped blocks
no warnings 'utf8';									# shaddup, I'm giving a demo dude

# load'up them needed libraries
use Net::Google::Analytics;							# what I use for google analytic calls
use Net::Google::AuthSub;							# I need this to login to ga
use Data::Dumper;									# Keep it around for finding/fixing things
use XML::FeedPP;									# generates the RSS feed

# some local variables we'll use
my $user = $ARGV[0];								# don't forget to escape the \@ in foo\@bar.com
my $pass = $ARGV[1];								# shhh ... secret
my $gaid = $ARGV[2]; 								# this is NOT your GA UA Key
my $domain = 'http://healyourchurchwebsite.com';	# don't let the long name scare ya
my $startdate = '2010-02-23';
my $enddate = '2012-02-23';

# instantiate the objects we'll leverage to connect & siphon data
# authetication object
my $auth = Net::Google::AuthSub->new(service => 'analytics');
$auth->login($user, $pass);							# login/connect/authenticate

# analytics object
my $analytics = Net::Google::Analytics->new();
$analytics->auth_params($auth->auth_params);
my $data_feed = $analytics->data_feed;
my $req = $data_feed->new_request();
$req->ids('ga:'.$gaid ); 							# your Analytics profile ID


# here's where we pass arguments for our request
# see: http://code.google.com/apis/analytics/docs/gdata/dimsmets/dimsmets.html
# 
# let's define how we want the rows of data defined
$req->dimensions('ga:pageTitle,ga:pagePath');
# other possible dimensions for future use?
# ga:country			- session
# ga:adwordsCreativeId  - adwords
# ga:searchUsed			- search
# ga:campaign 			- traffic sources

# let's define the columns of data w/in our rows
$req->metrics('ga:uniquePageviews,ga:pageviews,ga:timeOnPage,ga:bounces,ga:entrances,ga:exits');
# other possible metrics for future use?
# ga:bounces			- session
# ga:searchUniques		- search
# ga:uniquePurchases	- ecommerce
# ga:impressions		- adwords
# ga:organicSearches 	- traffic sources

# we don't want EVERYTHING, so let's define ranges & sorting
$req->start_date($startdate);
$req->end_date($enddate);
$req->sort('-ga:uniquePageviews,-ga:pageviews');		# descending order

# Filtering
# http://code.google.com/apis/analytics/docs/gdata/v2/gdataReferenceDataFeed.html#filters
# bah! not working in Net::Google::Analytics -- I knew I shoulda done this in Python!
# $req->max_results('20');
# $req->filters('ga:uniquePageviews>50');

# Go get the feed
my $resp = $data_feed->retrieve($req);

if ( $resp->{"is_success"} eq "1" ) {
 print "Google Analytics API works...OK!\n";
} else {
 print "Google Analytics API has issues...FAIL!\n";
 exit(1);
}

# Do we have enough data?
my $total_results = $resp->{'total_results'};
if ($total_results < 5) {
 print "Google Analytics API works...but failed to find 5 or more records!\n";
 exit(2);
}

# Whoo Hoo! Rock-n-Roll, we gots data, now let's slice-it & dice-it to RSS & CSV files

# set up the channel block of the RSS file
my $feed = XML::FeedPP::RSS->new();
$feed->title( "Most Popular Pages - Heal Your Church Website" );
$feed->link( "http://healyourchurchwebsite.com/test/mpp.rss" );
$feed->pubDate( time() );

# we're going to use this array to help us print a CSV file
my @pages = ("item#\tpageTotalViews\tpageUniqeViews\tpageTimeOnPage\tpageBounces\tpageTitle\tpagePath\n");

# Okay, let's walk the elements 1 row at a time
# ... fyi --> this is where we demo how to progrmatically do fun things with your data
# 
for (my $i = 0; $i < $total_results; $i++) {

	# let's dereference some dimensions (rows) so life is a bit easier
	my $pageTitle = $resp->{'entries'}[$i]->{'dimensions'}[0]->{'value'};
	my $pagePath  = $resp->{'entries'}[$i]->{'dimensions'}[1]->{'value'};
	
	# dereferencing some metrics (columns) -- so lifeis even easier
	my $pageUniqeViews = $resp->{'entries'}[$i]->{'metrics'}[0]->{'value'};
	my $pageTotalViews = $resp->{'entries'}[$i]->{'metrics'}[1]->{'value'};
	my $pageTimeOnPage = $resp->{'entries'}[$i]->{'metrics'}[2]->{'value'};
	my $pageBounces    = $resp->{'entries'}[$i]->{'metrics'}[3]->{'value'};

	# example of post download filtering ...
	# ... especially since we found filtering wasn't working so good w/the perl lib
	next if ($pageTitle =~ m/^\s*$/ || $pagePath =~ m/^\s*$/);	# say no to empty titles & paths
	next if ($pagePath =~ m/^\/$/);								# no need to list the homepage
	next unless $pageUniqeViews > 100;							# let's limit it to really popular pages

	# is it a post page? lets see if there's a date stamp in the path, if so parse it, if not pass on it
	# NOTE *** this assumes your article paths include /yyyy/mm/dd 
	$pagePath =~ m{^/(20[0-1]\d)/(\d{2})/(\d{2})/};
	my ($yy, $mm, $dd) = ($1, $2, $3);							# assign if we find date in path
	next unless ($yy && $mm && $dd);							# no date, no thanks!

	# let's push ROW some data into our CSV file objects
	my $line = "$i\t$pageTotalViews\t$pageUniqeViews\t$pageTimeOnPage\t$pageBounces\t$pageTitle\t$pagePath\n";
	push(@pages, $line);

	# now pushing data into our RSS file object
	if ($i < 20) {											# let's keep the RSS small
		my  $pageDesc = "Item # $i - the article $pageTitle was viewed $pageTotalViews times.";
		my	$item = $feed->add_item( $domain.$pagePath);
			$item->title( $pageTitle );
			$item->description( $pageDesc );
			$item->guid( $domain.$pagePath."#$i" );
			$item->pubDate($yy."-".$mm."-".$dd."T11:30:00+00:00");
	}
}

# write the RSS file
$feed->to_file( "mpp-pl.rss" );

# write the tab delimited file
open(PAGE,">mpp-pl.csv") || die "I can't open mpp.csv"; #open the file to read
print PAGE @pages;
close(PAGE);

# output results to screen
print @pages;
printf ("Total URLs: %s\n", $resp->{'total_results'});

# Yipeee! We're Done -- that's all folks!
exit(0);

