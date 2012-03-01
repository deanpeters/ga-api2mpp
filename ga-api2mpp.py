##############################################################################
# $Id: 
##############################################################################
# ga-api2mpp.py - this script leverages the Google Analytics API
#		http://code.google.com/apis/analytics/docs/gdata/home.html
#
#		it generates 2 files:
#			mpp.rss - an rss of the top 20 stories from your website/blog
#			mpp.csv - a comma delmited file of all the stories from your website/blog 
#
# ASSUMPTIONS:
#		you have access to a Google Analytics (GA) account
#		you've obtained the profile id (not UA key) from the GA dashboard
#		your article paths include /yyyy/mm/dd ...
#		that you've read the following webpage 1st!
#			https://github.com/clintecker/python-googleanalytics/blob/master/USAGE.md
#
# DEPENDENCIES:
# 		python-googleanalytics- https://github.com/clintecker/python-googleanalytics
# 		PyRSS2Gen- http://www.dalkescientific.com/Python/PyRSS2Gen.html
#
# SYNTAX:
#       command  : python ga-api2mpp.py username\@gmail.com password 1234567
#       cronatab : * */12 * * * python ga-api2mpp.py username\@gmail.com password 1234567
#
# TO DO:
#       see if I can't bring in the profile id(s) from the API
#       use a yaml config file to drive the optional parameters
#		of course I need to not hard-code the dates
#		more robust commandline (getops) handling
#		employ utm tracking for outbound links
#			-- such as ?utm_source=ga-app2mpi&utm_medium=rss-widget&utm_campaign=most-popular-pages
#		once you empoy utm tracking, you'll want to employ utm filtering
#		deal with missing atom:link for validation
#			see: http://validator.w3.org/feed/docs/warning/MissingAtomSelfLink.html
#		more robust error & exception handling 
#			-- 5 retries on a get_data, duration of each doubles until all fail
# 		see if we can do anything more optimally w/libs: 
#			googleanalytics.data import DataPoint, DataSet
#			... espcially .aggregates for metrics (which I couldn't get working)
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
from googleanalytics import Connection		# google analytics api library for python
import PyRSS2Gen							# create our RSS
import pickle								# debugging
import datetime								# date time formatting
import sys									# manage command line args, also print to stdout (optionally)
import re									# regular expresions

# first, we need to set things up so we can encapsulate descriptions & titles in CDATA blocks
# 	big thanks to this page: http://stackoverflow.com/questions/5371704/python-generated-rss-outputting-raw-html
#   future for atom ref: http://stackoverflow.com/questions/2360641/supporting-pubsubhubbub-with-pyrss2gen
class NoOutput:
    def __init__(self):
        pass
    def publish(self, handler):
        pass

class IPhoneRSS2(PyRSS2Gen.RSSItem):
    def __init__(self, **kwargs):
        PyRSS2Gen.RSSItem.__init__(self, **kwargs)

    def publish(self, handler):
        self.do_not_autooutput_description = self.description
        self.description = NoOutput() # This disables the Py2GenRSS "Automatic" output of the description, which would be escaped.
        self.do_not_autooutput_title = self.title
        self.title = NoOutput() # This disables the Py2GenRSS "Automatic" output of the title, which would be escaped.
        PyRSS2Gen.RSSItem.publish(self, handler)

    def publish_extensions(self, handler):
        handler._out.write('<%s><![CDATA[%s]]></%s>' % ("description", self.do_not_autooutput_description, "description"))
        handler._out.write('<%s><![CDATA[%s]]></%s>' % ("title", self.do_not_autooutput_title, "title"))

# get the comman line args
# SYNTAX is: python ga_api2mpp.py myusername\@gmail.com mypassssword 1234567
username = sys.argv[1]
password = sys.argv[2]
profileid = sys.argv[3]
domain = 'http://healyourchurchwebsite.com/'		# we'll need this for full urls & guids
connection = Connection(username, password)     # pass in id & pw as strings **if** not in config file

# let's go ahead and create the request data variables
# see the following for args: http://code.google.com/apis/analytics/docs/gdata/dimsmets/dimsmets.html
maxresults = 50
account = connection.get_account(profileid)
start_date = datetime.date(2010, 02, 01)
end_date = datetime.date(2011, 02, 28)
metrics = ['uniquePageviews','pageviews','timeOnPage','bounces','entrances','exits']
dimensions = ['pageTitle','pagePath']
sorts = ['-uniquePageviews','-pageviews',]
filters = [
			['uniquePageviews', '>=', '50',]
		]				# yeah, note this one is different

# now let's plug in the variables into the get_data() call
data = account.get_data(
	start_date, 
	end_date, 
	metrics=metrics, 
	dimensions=dimensions, 
	sort=sorts,
	filters=filters)				# n	max_results = maxresults)

# we're going to use this array to help us print a CSV file
csvItems = ["item#\tpageTotalViews\tpageUniqeViews\tpageTimeOnPage\tpageBounces\tpageTitle\tpagePath",]			

# with each row, we'll append a stash of 'items'
rssItems = []			
ii = 0					# our indice counter
# now let's walk through all the data we collected
for row in data.list:

	# let's convert our datapoints into 2 dictionaries we can de-reerence
	dic_dimensions	=	dict(zip(dimensions, row[0]))
	dic_metrics		=	dict(zip(metrics, row[1]))
	
	# let's dereference the data into string variables, we're going to need this

	# NOTE *** this assumes your article paths include /yyyy/mm/dd 
	pagePath = dic_dimensions['pagePath']
	s_obj = re.search(r"^\/(20[0-1]\d)\/(\d{2})\/(\d{2})\/", pagePath)	# in perl it's {^/(20[0-1]\d)/(\d{2})/(\d{2})/}
	if s_obj:
		pagePubDate = datetime.datetime(int(s_obj.group(1)), int(s_obj.group(2)), int(s_obj.group(3)), 11, 30)
		ii = ii + 1							# we only count those item's that pass the post-pull testing
	else:
		#	pagePubDate = datetime.datetime.utcnow()					# default/fallback value 
		continue

	# now let's do the rest
	pageTitle = dic_dimensions['pageTitle']
	pageViews = dic_metrics['pageviews'] 
	pageUniqueViews = dic_metrics['uniquePageviews'] 
	pageTimeOnPage = dic_metrics['timeOnPage']
	pageBounces = dic_metrics['bounces']
	 	
	pageDescription = "%s %d - %s %s %s %s %s" % ("Item #", ii, "the article", pageTitle, "was viewed", pageViews, "times.")

	# let's keep the RSS file smaller than the CSV file
	if (ii <= 20):												
		# now let's stuff our array full of item goodness
		rssItems.append(
			IPhoneRSS2(
				title = pageTitle.encode('utf-8'), 
				link = domain + pagePath, 
				description = pageDescription.encode('utf-8'), 		# trust me, you'll want to do this
				guid = PyRSS2Gen.Guid(domain + pagePath + "#" + str(ii)), 
				pubDate = pagePubDate))
 
 	csvItems.append(
 		"%d\t%s\t%s\t%s\t%s\t%s\t%s" % (ii, pageViews, pageUniqueViews, pageTimeOnPage, pageBounces, pageTitle.encode('utf-8'), pagePath))
 	
# this is where we 'stuff' the rss object full of the array of items, plus otehr channel data
# this page was a big help figuring thsi out -> http://pastebin.com/J298tQD9
rss = PyRSS2Gen.RSS2(
   title = 'Most Popular Pages - HYCW',
   link = 'http://www.healyourchurchwebsite.com/',
   description = 'The most popular pages from HealYourChurchWebsite',
   lastBuildDate = datetime.datetime.utcnow(),			# or .now() depending on what you want
   items = rssItems)
   
# push it all out to a file ... then standard i/o
# also a big help on output: http://nullege.com/codes/search/PyRSS2Gen.RSS2.write_xml
rss.write_xml(open("mpp-py.rss", "w"), "utf-8")

# uncomment below if you want to display the rss to the console (stdout)
# rss.write_xml(sys.stdout)

# write out the CSV file
# this page was a helpful - http://stackoverflow.com/questions/899103/python-write-a-list-to-a-file
with open('mpp-py.csv', 'w') as file:
    for row in csvItems:
        file.write("{}\n".format(row))
print pickle.dumps(csvItems)

# Yipeee! We're Done -- that's all folks!
exit(0);
